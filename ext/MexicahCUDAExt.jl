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

    # Static-ndrange KA metadata is a zero-size leading argument and contributes
    # no kernel parameter; see cuda_codegen.jl. If a future KA emits a non-ghost
    # context this is where its constant bytes would be supplied.
    meta_bytes = UInt8[]

    src = Mexicah.generate_cuda_mex_source(
        mex_name, entry, ptx, n_inputs, meta_bytes, block_dim,
    )
    return Mexicah._compile_generated_source(src, mex_name, output)
end

end # module MexicahCUDAExt
