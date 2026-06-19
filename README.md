# Mexicah.jl

[![CI](https://github.com/el-oso/Mexicah.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/el-oso/Mexicah.jl/actions/workflows/CI.yml)
[![MATLAB](https://github.com/el-oso/Mexicah.jl/actions/workflows/MATLAB.yml/badge.svg)](https://github.com/el-oso/Mexicah.jl/actions/workflows/MATLAB.yml)
[![Docs](https://github.com/el-oso/Mexicah.jl/actions/workflows/Documentation.yml/badge.svg)](https://el-oso.github.io/Mexicah.jl/dev/)
[![Julia 1.12](https://img.shields.io/badge/Julia-1.12-9558B2?logo=julia)](https://julialang.org)

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

## Requirements (build machine only)

| Tool | Linux / macOS | Windows |
|---|---|---|
| Julia 1.12+ | `juliaup add 1.12` | same |
| `juliac` | `julia -e 'using Pkg; Pkg.Apps.add("JuliaC")'` | same |
| C compiler | `cc` / `gcc` / `clang` (auto-detected) | `gcc` (MinGW/MSYS2) or `clang` (LLVM) |

End users need only MATLAB — no Julia, no compiler.

## Highlights

- **Host-free binaries** — the MEX bundles its own runtime; the target machine
  needs only MATLAB.
- **Zero-copy inputs** — array arguments are wrapped directly over MATLAB's
  buffers; one `memcpy` for outputs.
- **LinearAlgebra bridge** — trim-safe SVD, solve, det/inv, and LU/Cholesky.
- **Experimental extensions** — DataFrames, Enzyme/ForwardDiff gradients, JuMP,
  ModelingToolkit, and CUDA GPU kernels via package extensions. These pull in
  large, dynamic frameworks and **do not compile under `--trim=safe`** (build them
  with `trim=false`); they are not covered by the trim-built example set.

## Documentation

Full guide, examples, and reference: see the [documentation](docs/src/index.md).

Planned work and known issues: see [ROADMAP.md](ROADMAP.md).

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

This package was developed with assistance from [Claude](https://claude.ai) (Anthropic). All generated code has been reviewed and is maintained by the author.

## Provenance & trademarks

This software is an independent, clean-room implementation of the publicly
documented MATLAB® C Matrix API — it contains no MathWorks headers, source, or
binaries. MATLAB and MEX are trademarks of The MathWorks, Inc.; this project is
not affiliated with, sponsored by, or endorsed by The MathWorks, Inc. See
[NOTICE](NOTICE) for details.
