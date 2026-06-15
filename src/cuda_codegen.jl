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
# The full kernel parameter list, verified against the emitted PTX on real
# hardware (RTX 4070, CUDA driver 13.0, CUDA.jl + KernelAbstractions), is:
#
#   param 0  CUDA.KernelState        state_bytes   (exception_info ptr + seed)
#   param 1  KA.CompilerMetadata     meta_bytes    ([n, nblocks], both Int64)
#   param 2  output  CuDeviceArray   32
#   param 3+ inputs  CuDeviceArray   32 each
#
# Two leading params the earlier MVP wrongly assumed away:
#   • CUDA.jl prepends a hidden `KernelState`. MVP @inbounds kernels never read
#     it (the PTX declares but never loads param 0), so we pass it zero-filled.
#   • KA's `CompilerMetadata` is NOT a ghost: launched with a *dynamic* ndrange
#     (as the build-time PTX extraction does) it carries the ndrange, so it is a
#     real param. For a 1-D `@index(Global)` kernel its bytes are
#     `[n::Int64, nblocks::Int64]`; the kernel reads `n` (meta[0]) as the bounds
#     check `global_index > n → return`. We therefore write `n` and
#     `cld(n, block)` into it at runtime. `state_bytes`/`meta_bytes` are measured
#     by the build-time extension and cross-checked against the PTX param sizes.
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

# Byte sizes of each `.param` in the first `.entry`'s parameter list, in order.
# Each param is declared `.param .align 8 .b8 <name>[SIZE]`; the SIZEs are the
# ground-truth ABI (e.g. [16, 16, 32, 32, 32] for KernelState + CompilerMetadata
# + three CuDeviceArrays). Used by the build-time extension to validate that the
# layout this codegen assumes matches what the kernel actually declares.
function _parse_ptx_param_sizes(ptx::String)::Vector{Int}
    # The param list runs from the entry's `(` to the first `)`; PTX places
    # `.maxntid`/other directives between that `)` and the body `{`, and params
    # never contain `)`, so anchor on the closing paren rather than the brace.
    m = match(r"\.entry\s+[A-Za-z_][\w$]*\s*\(([^)]*)\)", ptx)
    m === nothing && return Int[]
    return Int[parse(Int, x.captures[1]) for x in eachmatch(r"\.param[^\[]*\[(\d+)\]", m.captures[1])]
end

# Embed an arbitrary ASCII string (PTX blob, entry symbol, …) as a valid Julia
# string literal. PTX and some symbol names use `$` and newlines, so escape both
# (escape_string handles `"`, `\`, control chars; the extra `\$` guards against
# string interpolation).
function _jl_str_literal(s::String)::String
    return "\"" * escape_string(s, "\$") * "\""
end

"""
    generate_cuda_mex_source(mex_name, entry, ptx, n_inputs, block_dim, state_bytes, meta_bytes) -> String

Return the full Julia source of a GPU MEX wrapper.

- `mex_name`    — MATLAB-visible function name.
- `entry`       — PTX `.entry` symbol name to launch.
- `ptx`         — the PTX module text.
- `n_inputs`    — number of `Vector{Float64}` inputs (kernel takes output + these).
- `block_dim`   — threads per block; grid is `cld(n, block_dim)`.
- `state_bytes` — size of the leading CUDA.jl `KernelState` param; passed
                  zero-filled (0 ⇒ no such param).
- `meta_bytes`  — size of KernelAbstractions' `CompilerMetadata` param. Filled at
                  runtime with `[n, cld(n, block_dim)]` (0 ⇒ no such param).
"""
function generate_cuda_mex_source(
        mex_name::Symbol,
        entry::String,
        ptx::String,
        n_inputs::Int,
        block_dim::Int,
        state_bytes::Int,
        meta_bytes::Int,
    )::String
    has_state = state_bytes > 0
    has_meta = meta_bytes > 0

    # Lay out argument blobs sequentially in one 8-aligned buffer:
    #   [ KernelState | CompilerMetadata | output | inputs... ]
    off_state = 0
    off_meta = has_state ? _align8(state_bytes) : 0
    off_out = off_meta + (has_meta ? _align8(meta_bytes) : 0)
    off_inputs = Int[off_out + _CU_DEVARRAY_SIZE * i for i in 1:n_inputs]
    total = off_out + _CU_DEVARRAY_SIZE * (1 + n_inputs)
    nparams = (has_state ? 1 : 0) + (has_meta ? 1 : 0) + 1 + n_inputs

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

    # The KernelState param stays zero-filled (the argbuf is zero-initialized);
    # MVP @inbounds kernels never read it. The CompilerMetadata param carries the
    # dynamic ndrange: meta[0]=n (read as the bounds check), meta[8]=nblocks.
    blob_lines = String[]
    if has_meta
        push!(blob_lines, "        unsafe_store!(Ptr{Int64}(_bp + $off_meta + 0), Int64(_n))")
        meta_bytes >= 16 &&
            push!(blob_lines, "        unsafe_store!(Ptr{Int64}(_bp + $off_meta + 8), Int64(_gx))")
    end
    push!(blob_lines, blob_writes(off_out, "_d_out"))
    for i in 1:n_inputs
        push!(blob_lines, blob_writes(off_inputs[i], "_d_in$i"))
    end

    # kernelParams pointer entries, in kernel-argument order.
    kparam_lines = String[]
    pidx = 1
    if has_state
        push!(kparam_lines, "        _kparams[$pidx] = Ptr{Cvoid}(_bp + $off_state)")
        pidx += 1
    end
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
    const _MOD = Ref{Ptr{Cvoid}}(C_NULL)
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
            plhs::Ptr{Mexicah.MxArray},
            nrhs::Cint,
            prhs::Ptr{Mexicah.MxArray},
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
        _gx = cld(_n, $block_dim)

        _d_out = Mexicah._cu_alloc(_n * 8)
    $(join(h2d_lines, "\n"))

        _argbuf = zeros(UInt8, $total)
        _kparams = Vector{Ptr{Cvoid}}(undef, $nparams)
        _out = Vector{Float64}(undef, _n)
        GC.@preserve _argbuf _kparams _out $preserve_ins begin
            _bp = pointer(_argbuf)
    $(join(blob_lines, "\n"))
    $(join(kparam_lines, "\n"))
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
