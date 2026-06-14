# Generates the self-contained Julia source for a GPU MEX wrapper.
#
# The wrapper embeds PTX (produced at build time by MexicahCUDAExt from a
# KernelAbstractions @kernel) as a string literal and launches it through the
# raw driver wrappers in cuda_driver.jl. It is compiled by juliac --trim=safe
# into a standalone MEX that needs only the NVIDIA driver at runtime.
#
# ── Kernel argument ABI (MVP) ─────────────────────────────────────────────────
# MVP scope: every kernel array argument is a 1-D Float64 array, lowered by the
# CUDA/KernelAbstractions stack to a `CuDeviceArray{Float64,1,CUDA.AS.Global}`
# passed by value. That struct's field layout is stable:
#
#   ptr::LLVMPtr{Float64,Global}   offset  0   (8 bytes, the device pointer)
#   maxsize::Int                   offset  8   (8 bytes, == len * sizeof(Float64))
#   dims::Tuple{Int}               offset 16   (8 bytes, == len)
#   len::Int                       offset 24   (8 bytes)
#                                  total size  32 bytes
#
# KernelAbstractions prepends a `__ctx__::CompilerMetadata` argument. Launched
# with a fully static ndrange it is a zero-size (ghost) type and contributes no
# kernel parameter, so `meta_bytes` is empty. The build-time extension passes
# its constant bytes if that ever changes; this keeps the runtime ABI a single
# centralized assumption, validated by the :cuda GPU smoke test.
#
# Kernel argument order (matches the @kernel signature convention the macro
# documents): (output, inputs...).

const _CU_DEVARRAY_SIZE = 32   # sizeof(CuDeviceArray{Float64,1,Global})

_align8(n::Int)::Int = (n + 7) & ~7

# Pull the kernel entry name out of a PTX module: matches `.visible .entry <name>`
# or a bare `.entry <name>`. PTX symbol names may contain `$`.
function _parse_ptx_entry(ptx::String)::Union{String, Nothing}
    m = match(r"\.entry\s+([A-Za-z_][\w$]*)", ptx)
    m === nothing && return nothing
    return String(m.captures[1])
end

# Embed an arbitrary ASCII string (PTX blob, entry symbol, …) as a valid Julia
# string literal. PTX and some symbol names use `$` and newlines, so escape both
# (escape_string handles `"`, `\`, control chars; the extra `\$` guards against
# string interpolation).
function _jl_str_literal(s::String)::String
    return "\"" * escape_string(s, "\$") * "\""
end

"""
    generate_cuda_mex_source(mex_name, entry, ptx, n_inputs, meta_bytes, block_dim) -> String

Return the full Julia source of a GPU MEX wrapper.

- `mex_name`   — MATLAB-visible function name.
- `entry`      — PTX `.entry` symbol name to launch.
- `ptx`        — the PTX module text.
- `n_inputs`   — number of `Vector{Float64}` inputs (kernel takes output + these).
- `meta_bytes` — constant bytes of KernelAbstractions' leading context argument
                 (empty when it is a zero-size static-ndrange type).
- `block_dim`  — threads per block; grid is `cld(n, block_dim)`.
"""
function generate_cuda_mex_source(
        mex_name::Symbol,
        entry::String,
        ptx::String,
        n_inputs::Int,
        meta_bytes::Vector{UInt8},
        block_dim::Int,
    )::String
    has_meta = !isempty(meta_bytes)
    mlen = length(meta_bytes)

    # Lay out argument blobs sequentially in one 8-aligned buffer.
    off_meta = 0
    off_out = has_meta ? _align8(mlen) : 0
    off_inputs = Int[off_out + _CU_DEVARRAY_SIZE + (i - 1) * _CU_DEVARRAY_SIZE for i in 1:n_inputs]
    total = off_out + _CU_DEVARRAY_SIZE * (1 + n_inputs)
    nparams = (has_meta ? 1 : 0) + 1 + n_inputs

    meta_decl = has_meta ? "const _META = UInt8[$(join(meta_bytes, ", "))]\n" : ""

    load_lines = String[]
    h2d_lines = String[]
    free_lines = String[]
    for i in 1:n_inputs
        push!(load_lines, "    _in$i = Mexicah.load_arg(prhs, $i, Vector{Float64})")
        push!(
            h2d_lines,
            "    _d_in$i = Mexicah._cu_alloc(_n * 8)\n" *
                "    GC.@preserve _in$i Mexicah._cu_h2d(_d_in$i, Ptr{Cvoid}(pointer(_in$i)), _n * 8)",
        )
        push!(free_lines, "    Mexicah._cu_free(_d_in$i)")
    end

    # Write a CuDeviceArray blob (ptr, maxsize, dim, len) for device pointer
    # `dptr` at byte offset `off` within the argbuf rooted at `_bp`.
    function blob_writes(off::Int, dptr::String)::String
        return join(
            String[
                "        unsafe_store!(Ptr{UInt64}(_bp + $off + 0), $dptr)",
                "        unsafe_store!(Ptr{Int64}(_bp + $off + 8), Int64(_n * 8))",
                "        unsafe_store!(Ptr{Int64}(_bp + $off + 16), Int64(_n))",
                "        unsafe_store!(Ptr{Int64}(_bp + $off + 24), Int64(_n))",
            ],
            "\n",
        )
    end

    blob_lines = String[]
    has_meta && push!(blob_lines, "        unsafe_copyto!(_bp + $off_meta, pointer(_META), $mlen)")
    push!(blob_lines, blob_writes(off_out, "_d_out"))
    for i in 1:n_inputs
        push!(blob_lines, blob_writes(off_inputs[i], "_d_in$i"))
    end

    # kernelParams pointer entries, in kernel-argument order.
    kparam_lines = String[]
    pidx = 1
    if has_meta
        push!(kparam_lines, "        _kparams[$pidx] = Ptr{Cvoid}(_bp + $off_meta)")
        pidx += 1
    end
    push!(kparam_lines, "        _kparams[$pidx] = Ptr{Cvoid}(_bp + $off_out)")
    pidx += 1
    for i in 1:n_inputs
        push!(kparam_lines, "        _kparams[$pidx] = Ptr{Cvoid}(_bp + $(off_inputs[i]))")
        pidx += 1
    end

    preserve_ins = join(["_in$i" for i in 1:n_inputs], " ")

    return """
    # AUTO-GENERATED by Mexicah.jl GPU path — do not edit by hand.
    using Mexicah

    const _PTX = $(_jl_str_literal(ptx))
    const _ENTRY = $(_jl_str_literal(entry))
    $(meta_decl)const _MOD = Ref{Ptr{Cvoid}}(C_NULL)
    const _FN = Ref{Ptr{Cvoid}}(C_NULL)
    const _GPU_LOADED = Threads.Atomic{Int}(0)

    function _ensure_module_loaded()::Cvoid
        Threads.atomic_cas!(_GPU_LOADED, 0, 1) == 0 || return
        Mexicah._cuda_init_once!()
        _m = Mexicah._cu_module_load(_PTX)
        _MOD[] = _m
        _FN[] = Mexicah._cu_fn(_m, _ENTRY)
        return
    end

    Base.@ccallable function mexFunction(
            nlhs::Cint,
            plhs::Ptr{Ptr{Mexicah.MxArray}},
            nrhs::Cint,
            prhs::Ptr{Ptr{Mexicah.MxArray}},
        )::Cvoid
        Mexicah._mexicah_init_once()
        if nrhs != $n_inputs
            Mexicah.mex_errorf(
                "Mexicah:argCount",
                "Expected $n_inputs input(s), got " * string(Int(nrhs)),
            )
        end
        _ensure_module_loaded()

    $(join(load_lines, "\n"))
        _n = length(_in1)

        _d_out = Mexicah._cu_alloc(_n * 8)
    $(join(h2d_lines, "\n"))

        _argbuf = zeros(UInt8, $total)
        _kparams = Vector{Ptr{Cvoid}}(undef, $nparams)
        _out = Vector{Float64}(undef, _n)
        GC.@preserve _argbuf _kparams _out $preserve_ins begin
            _bp = pointer(_argbuf)
    $(join(blob_lines, "\n"))
    $(join(kparam_lines, "\n"))
            _gx = cld(_n, $block_dim)
            Mexicah._cu_launch(_FN[], _gx, 1, 1, $block_dim, 1, 1, 0, pointer(_kparams))
            Mexicah._cu_sync()
            Mexicah._cu_d2h(Ptr{Cvoid}(pointer(_out)), _d_out, _n * 8)
        end

        Mexicah._cu_free(_d_out)
    $(join(free_lines, "\n"))

        Mexicah.store_result(plhs, 1, _out)
        return
    end
    """
end
