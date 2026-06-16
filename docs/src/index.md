```@raw html
---
layout: home

hero:
  name: Mexicah.jl
  text: Julia functions → MATLAB MEX
  tagline: Compile a typed Julia function into a native MATLAB extension. Your MATLAB users just call it — no Julia install, no toolchain, no MATLAB needed to build.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/installation
    - theme: alt
      text: Quickstart
      link: /guide/quickstart
    - theme: alt
      text: Examples
      link: /examples/

features:
  - title: No Julia at runtime
    icon: 📦
    details: "The MEX bundle ships its own libjulia. Your MATLAB users just call the function — they never install Julia."
  - title: No MATLAB at build time
    icon: 🛠️
    details: "Build with Julia 1.12+ and a C compiler. No MATLAB, no headers, no toolbox licenses to compile."
  - title: Zero-copy arrays
    icon: ⚡
    details: "Array inputs are read straight from MATLAB's buffers — no copy in, one copy out."
  - title: Batteries included
    icon: 🧩
    details: "Enzyme/ForwardDiff gradients, ModelingToolkit ODEs, DataFrames, JuMP, LinearAlgebra, and CUDA GPU kernels."
---
```

```@raw html
<div style="text-align:center; max-width:780px; margin:2.5rem auto 1rem;">
  <div style="font-size:1.7rem; font-weight:700; line-height:1.3;">
    Mexicah&nbsp;·&nbsp;<span style="font-style:italic; color:var(--vp-c-brand-1);">meh-SHEE-kah</span>
  </div>
  <div style="font-size:1.2rem; line-height:1.55; margin-top:.6rem; color:var(--vp-c-text-2);">
    Named after the <strong>Mexica</strong> of central Mexico — the name spells out
    <strong>M</strong>atrix-Laboratory <strong>EX</strong>ecutable
    <strong>I</strong>nterop: <strong>C</strong>ompiled, <strong>A</strong>OT,
    <strong>H</strong>ost-free.
  </div>
</div>
```

## What is Mexicah.jl?

Mexicah compiles a typed Julia function into a native MATLAB **MEX** file
(`.mexa64` / `.mexw64` / `.mexmaca64`) that MATLAB calls like any built-in. You
write plain Julia, mark the functions you want to expose, and run one command to
get MEX files — a self-contained bundle that needs no Julia on the user's machine.

```julia
# In a small package — juliac compiles from disk, so functions live in a module.
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
run('mex/mexicah_setup.m')        % once per session — no Julia on this machine
add_doubles(3, 4)                 % ans = 7
scale_rows([1 2; 3 4], 10)        % ans = [10 20; 30 40]
```

## How it works

```
@mexfunction  ─►  generated Base.@ccallable mexFunction wrappers (Julia, C-ABI)
              ─►  juliac --output-lib --trim=safe --privatize  ─►  one shared library
              ─►  a tiny C gateway per function  ─►  add_doubles.mexa64, …
              ─►  bundle: gateways + shared lib + libjulia runtime
```

MATLAB can't load a raw juliac library as a MEX, so Mexicah ships a **tiny C
gateway** as each `.mex*`: MATLAB loads the gateway, which loads the shared Julia
library once and forwards the call. Building several functions together puts them
in **one** library, so they share a single Julia runtime and work side by side in
the same MATLAB session. See [How it runs](guide/runtime.md) for the details.

## Get going

- [Installation](guide/installation.md) — one-time setup (Julia, `juliac`, a C compiler).
- [Quickstart](guide/quickstart.md) — function → MEX → MATLAB in five steps.
- [Examples](examples/index.md) — scalars, matrices, sparse, AD gradients, ODEs, GPU.

## Platform support

| Platform | Status |
|---|---|
| Linux (x86-64) | ✅ supported |
| Windows (x86-64) | ✅ supported |
| macOS (Apple Silicon) | ✅ supported |

All three are exercised end-to-end in CI: every build loads and runs its MEX in
real MATLAB. (Sparse matrices are supported on Linux and macOS; Windows sparse is
in progress.)

GPU kernels (NVIDIA, via KernelAbstractions) compile to PTX and run with only the
NVIDIA driver — see the [GPU example](examples/cuda.md).
