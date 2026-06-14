# Example: a GPU vector-add MEX built from a KernelAbstractions @kernel.
#
# Build (on a machine with an NVIDIA GPU, CUDA.jl, and KernelAbstractions.jl).
# Use the bundled examples environment — CUDA/KernelAbstractions are *weak* deps
# of Mexicah, so they are not loadable from the package's own project:
#   julia --project=examples -e 'using Pkg; Pkg.instantiate()'   # once
#   julia --project=examples examples/cuda_vector_add.jl
#
# This compiles the kernel to PTX, embeds it in a juliac --trim=safe MEX, and
# writes mex/cuda_vector_add.<ext>. The resulting binary needs only the NVIDIA
# driver at runtime — not CUDA.jl or a Julia GPU stack.
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   a = rand(1024,1); b = rand(1024,1);
#   c = cuda_vector_add(a, b);
#   assert(max(abs(c - (a + b))) < 1e-12)

using Mexicah
using CUDA
using KernelAbstractions

# The kernel takes (output, inputs...) — all 1-D Float64 arrays of equal length.
@kernel function vadd!(c, a, b)
    i = @index(Global)
    @inbounds c[i] = a[i] + b[i]
end

# The trailing `function` gives only the MATLAB-visible signature; its body is
# ignored. `block` is the threads-per-block; the grid is cld(n, block).
@mexgpukernel kernel = vadd! block = 256 output = "mex/" function cuda_vector_add(
        a::Vector{Float64}, b::Vector{Float64},
    )::Vector{Float64}
end
