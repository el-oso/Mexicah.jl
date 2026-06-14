# GPU kernels (CUDA)

Mexicah can compile a [KernelAbstractions.jl](https://github.com/JuliaGPU/KernelAbstractions.jl)
`@kernel` into a MEX that runs on an NVIDIA GPU — with **no CUDA.jl or Julia GPU
stack required at runtime**. The kernel is compiled to PTX at build time and
embedded in the MEX; at runtime the binary talks to the NVIDIA driver
(`libcuda.so.1` / `nvcuda.dll`) directly.

## How it works

```
BUILD TIME (developer machine: NVIDIA GPU + CUDA.jl + KernelAbstractions.jl)
  @kernel function  ──►  CUDA compiles to PTX  ──►  PTX embedded in a .jl wrapper
                                                    juliac --trim=safe ──► .mexa64

RUNTIME (end-user machine: only the NVIDIA driver)
  MATLAB loads the MEX
  first call:  cuInit → context → cuModuleLoadDataEx(PTX)   (driver JITs PTX once)
  each call:   cuMemAlloc → cuMemcpyHtoD → cuLaunchKernel → cuMemcpyDtoH → cuMemFree
```

Writing the kernel in KernelAbstractions (rather than raw CUDA) keeps the door
open for other backends: if AMDGPU/Metal/oneAPI gain ahead-of-time kernel
loaders, the same `@kernel` will target them through a new extension. Today,
**CUDA is the only backend with a complete AOT path** — see the
[comparison with MATFrost](../guide/comparison.md) for the broader landscape.

## Requirements

Build-time only (the developer's machine): CUDA.jl and KernelAbstractions.jl.
They are **weak** dependencies of Mexicah — loading them activates
`MexicahCUDAExt` — and are **not** needed by anyone running the finished MEX.

Because they are weak deps, they cannot be loaded from Mexicah's own project, so
GPU MEX files are built from a small environment that lists them alongside
Mexicah. This repository ships one at `examples/`:

```bash
julia --project=examples -e 'using Pkg; Pkg.instantiate()'   # once
```

## Example: vector add

```julia
# examples/cuda_vector_add.jl
using Mexicah
using CUDA
using KernelAbstractions

# The kernel takes (output, inputs...) — all 1-D Float64 arrays of equal length.
@kernel function vadd!(c, a, b)
    i = @index(Global)
    @inbounds c[i] = a[i] + b[i]
end

# The trailing `function` supplies only the MATLAB-visible signature; its body
# is ignored. `block` is threads-per-block; the grid is cld(n, block).
@mexgpukernel kernel = vadd! block = 256 output = "mex/" function cuda_vector_add(
        a::Vector{Float64}, b::Vector{Float64},
    )::Vector{Float64}
end
```

Build it:

```bash
julia --project=examples examples/cuda_vector_add.jl
```

## MATLAB session

```matlab
run('mex/mexicah_setup.m')

a = rand(1024, 1);
b = rand(1024, 1);
c = cuda_vector_add(a, b);

assert(max(abs(c - (a + b))) < 1e-12)
```

## The `@mexgpukernel` contract (MVP)

| Aspect | Requirement |
|---|---|
| Kernel signature | `(output, inputs...)` in the same order as the wrapper |
| Element type | `Float64` for every array |
| Rank | 1-D arrays (`Vector{Float64}`); use `@index(Global)` |
| Length | output and all inputs share the same length `n` |
| Outputs | exactly one |
| `block` | threads per block (default `256`); grid is `cld(n, block)` |

Multiple outputs, integer/`Float32` element types, and 2-D (`Matrix`) arrays are
planned follow-ons. The single point that must be validated on real hardware is
the kernel-launch ABI (the `CuDeviceArray` parameter layout); the bundled
`@testitem`s tagged `:cuda` exercise the build-time PTX extraction, and the
MATLAB round-trip above is the end-to-end check.

## What ships to the end user

Only the MEX binary, its bundled `libjulia`, and `mexicah_setup.m` — plus
whatever NVIDIA driver the user already has. No CUDA toolkit, no CUDA.jl, no
Julia GPU packages.
