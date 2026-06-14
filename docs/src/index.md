# Mexicah.jl

> **Pronunciation:** *Me-shee-cah* — named after the Mexica, the Nahuatl-speaking people of central Mexico.

**Compile Julia functions into standalone MATLAB MEX extensions.**

Mexicah.jl takes existing Julia code and compiles it into native MEX files
(`.mexa64`, `.mexw64`, `.mexmaca64`) that MATLAB users call like any other
built-in — with no Julia installation required at runtime.

```julia
using Mexicah

@mexfunction function solve_ode(u0::Vector{Float64}, t::Float64)::Vector{Float64}
    # … your Julia solver …
end

build_mex(solve_ode; output="./mex/")
```

```matlab
% MATLAB side
run('mex/mexicah_setup.m')
u = solve_ode([1.0; 0.0], 10.0);
```

## Key properties

| Property | Detail |
|---|---|
| **Build requires MATLAB?** | No — only Julia 1.12+ and a C linker |
| **Runtime requires Julia?** | No — `libjulia` is bundled alongside the MEX file |
| **Data transfer overhead** | Zero-copy for array inputs; one `memcpy` for array outputs |
| **Binary size** | ~2 MB per function with `--trim=safe` (vs 200 MB for a full sysimage) |
| **AD support** | Enzyme.jl (reverse-mode) and ForwardDiff.jl (forward-mode) |
| **MTK support** | Compile ODE RHS and Jacobian directly from a `ODESystem` |

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/el-oso/Mexicah.jl")
```

Julia 1.12 or later is required. `juliac` must be on your `PATH` (it ships with Julia 1.12+).
