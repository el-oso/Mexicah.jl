# Mexicah.jl

> **Mexicah** — *Matrix-Laboratory EXecutable Interop: Compiled, AOT, Host-free.*
>
> *Pronounced meh-SHEE-kah, after the Mexica of central Mexico.*

Compile Julia functions into standalone MATLAB MEX extensions (`.mexa64`,
`.mexw64`, `.mexmaca64`) using [`juliac`](https://github.com/JuliaLang/julia)
ahead-of-time compilation — **no Julia installation required on the end user's
machine**.

```julia
using Mexicah

@mexfunction function solve_ode(u0::Vector{Float64}, t::Float64)::Vector{Float64}
    # … your Julia solver …
end

build_mex(solve_ode; output = "./mex/")
```

```matlab
% MATLAB side
run('mex/mexicah_setup.m')
u = solve_ode([1.0; 0.0], 10.0);
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
