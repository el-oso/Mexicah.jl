# Mexicah.jl

> **Mexicah** — *Matrix-Laboratory EXecutable Interop: Compiled, AOT, Host-free.*
>
> *Pronounced meh-SHEE-kah, after the Mexica of central Mexico.*

Compile Julia functions into standalone MATLAB MEX extensions (`.mexa64`,
`.mexw64`, `.mexmaca64`) using [`juliac`](https://github.com/JuliaLang/julia)
ahead-of-time compilation — **no Julia installation required on the end user's
machine**.

juliac compiles from disk, so your functions live in a small package module:

```julia
# MySolvers/src/MySolvers.jl
module MySolvers
using Mexicah

@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    return x + y
end

@mexfunction function scale_rows(A::Matrix{Float64}, s::Float64)::Matrix{Float64}
    return A .* s
end
end
```

```julia
# build script — run with the project that has Mexicah + MySolvers
using Mexicah, MySolvers

build_shared_mex(
    [
        (MySolvers.add_doubles, Type[Float64, Float64], Type[Float64]),
        (MySolvers.scale_rows,  Type[Matrix{Float64}, Float64], Type[Matrix{Float64}]),
    ];
    output = "mex/",
)
```

```matlab
% MATLAB side — no Julia installed on this machine
run('mex/mexicah_setup.m')
add_doubles(3, 4)              % → 7
scale_rows([1 2; 3 4], 10)     % → [10 20; 30 40]
```

## Highlights

- **Host-free binaries** — the MEX bundles its own runtime; the target machine
  needs only MATLAB.
- **Zero-copy inputs** — array arguments are wrapped directly over MATLAB's
  buffers; one `memcpy` for outputs.
- **GPU kernels** — compile a KernelAbstractions `@kernel` to PTX and ship a MEX
  that drives the NVIDIA driver directly, with no CUDA.jl at runtime.
- **Extensible** — Enzyme/ForwardDiff gradients, ModelingToolkit, DataFrames,
  JuMP, and a LinearAlgebra bridge via package extensions.

## Documentation

Full guide, examples, and reference: see the [documentation](docs/src/index.md).

## License

MIT — see [LICENSE](LICENSE).
