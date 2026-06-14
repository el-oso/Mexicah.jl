module MexicahCUDAExt

# BUILD-TIME ONLY. This extension runs on a developer machine that has an NVIDIA
# GPU, CUDA.jl, and KernelAbstractions.jl. It compiles a user `@kernel` to PTX and
# hands the PTX to Mexicah's GPU codegen. The PTX is then embedded in a juliac
# --trim=safe binary that, at runtime, needs only the NVIDIA driver — never CUDA.jl
# or KernelAbstractions. None of this module is compiled into the MEX.

using Mexicah
using CUDA: CUDA, CuArray, CUDABackend
using KernelAbstractions: KernelAbstractions

# Extract the PTX module and its entry-point symbol for `kernelobj` launched over
# `dummy_args` (output first, then inputs) with the given block size.
#
# We capture PTX via CUDA's documented `@device_code_ptx` reflection rather than
# reconstructing KernelAbstractions' CompilerMetadata by hand — that keeps us off
# KA internals and robust across KA/CUDA versions. KA performs its normal launch
# inside the block; we read back the emitted assembly.
function _extract_ptx(kernelobj, dummy_args, block_dim::Int)
    out = dummy_args[1]
    ndrange = length(out)

    ptx = mktemp() do path, io
        CUDA.@device_code_ptx io = io begin
            k = kernelobj(CUDABackend(), block_dim)
            k(dummy_args...; ndrange = ndrange)
            CUDA.synchronize()
        end
        flush(io)
        return read(path, String)
    end

    entry = Mexicah._parse_ptx_entry(ptx)
    entry === nothing &&
        error("MexicahCUDAExt: could not find a `.entry` symbol in the generated PTX.")
    return ptx, entry
end

# Reach KA's launch-context constructor across CUDA.jl versions.
_mkcontext(kobj, ndrange, iterspace) =
    isdefined(CUDA, :mkcontext) ? CUDA.mkcontext(kobj, ndrange, iterspace) :
    KernelAbstractions.mkcontext(kobj, ndrange, iterspace)

# Measure the size of KA's `CompilerMetadata` param and confirm the runtime ABI
# the generated wrapper relies on: launched with a *dynamic* ndrange the metadata
# is a real (non-ghost) param whose bytes are `[n, cld(n, block)]` (both Int64).
# cuda_codegen.jl writes exactly those words; if a future KA changes the layout
# this errors at build time rather than producing a silently wrong MEX.
function _meta_param_bytes(kernelobj, block_dim::Int)::Int
    kobj = kernelobj(CUDABackend(), block_dim)
    sz = 0
    # Lengths that are not multiples of block_dim, to exercise the n/nblocks split.
    for n in (997, 2003)
        ndrange, _, iterspace, _ = KernelAbstractions.launch_config(kobj, (n,), nothing)
        ctx = _mkcontext(kobj, ndrange, iterspace)
        words = reinterpret(Int64, [ctx])
        (length(words) >= 2 && words[1] == n && words[2] == cld(n, block_dim)) || error(
            "MexicahCUDAExt: CompilerMetadata layout $(words) ≠ expected [n=$n, nblocks=$(cld(n, block_dim))]; " *
                "the runtime ABI in cuda_codegen.jl assumes meta = [n, cld(n, block)].",
        )
        sz = sizeof(typeof(ctx))
    end
    return sz
end

"""
    _ka_cuda_build_mex(kernelobj, mex_name, argtypes, rettypes, block_dim, output) -> String

Compile a KernelAbstractions `@kernel` into a GPU MEX. MVP contract: every input
is `Vector{Float64}`, the single output is `Vector{Float64}`, and the kernel
signature is `(output, inputs...)` with 1-D `@index(Global)` indexing.
"""
function _ka_cuda_build_mex(
        kernelobj,
        mex_name::Symbol,
        argtypes::Vector{Type},
        rettypes::Vector{Type},
        block_dim::Int,
        output::String,
    )::String
    all(==(Vector{Float64}), argtypes) ||
        error("MexicahCUDAExt MVP: all inputs must be Vector{Float64}, got $argtypes")
    (length(rettypes) == 1 && rettypes[1] === Vector{Float64}) ||
        error("MexicahCUDAExt MVP: the single output must be Vector{Float64}, got $rettypes")

    n_inputs = length(argtypes)

    # Dummy device arrays drive type inference for PTX generation. Length is
    # irrelevant to the emitted code; use a couple of blocks' worth.
    L = max(block_dim * 2, 1024)
    dummy_out = CuArray{Float64}(undef, L)
    dummy_ins = ntuple(_ -> CuArray{Float64}(undef, L), n_inputs)
    dummy_args = (dummy_out, dummy_ins...)

    ptx, entry = _extract_ptx(kernelobj, dummy_args, block_dim)

    # The real kernel ABI (see cuda_codegen.jl): CUDA.jl prepends a `KernelState`
    # param, KA prepends a `CompilerMetadata` param, then the CuDeviceArrays.
    state_bytes = sizeof(CUDA.KernelState)
    meta_bytes = _meta_param_bytes(kernelobj, block_dim)

    # Cross-check against the PTX param list (ground truth): the entry must declare
    # exactly [KernelState, CompilerMetadata, (1 + n_inputs)×CuDeviceArray(32B)].
    param_sizes = Mexicah._parse_ptx_param_sizes(ptx)
    expected = Int[state_bytes, meta_bytes, fill(Mexicah._CU_DEVARRAY_SIZE, 1 + n_inputs)...]
    param_sizes == expected || error(
        "MexicahCUDAExt: PTX kernel param sizes $(param_sizes) ≠ expected $(expected); " *
            "the kernel-launch ABI assumed by cuda_codegen.jl does not match this kernel.",
    )

    src = Mexicah.generate_cuda_mex_source(
        mex_name, entry, ptx, n_inputs, block_dim, state_bytes, meta_bytes,
    )
    return Mexicah._compile_generated_source(src, mex_name, output)
end

end # module MexicahCUDAExt
