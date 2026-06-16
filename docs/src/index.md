---
layout: home

hero:
  name: "Mexicah.jl"
  text: "Julia functions → MATLAB MEX"
  tagline: "Compile your Julia code into native MATLAB extensions. No Julia install on the user's machine."
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
  - icon: 📦
    title: No Julia at runtime
    details: The MEX bundle ships its own libjulia. Your MATLAB users just call the function — they never install Julia.
  - icon: 🛠️
    title: No MATLAB at build time
    details: Build with Julia 1.12+ and a C compiler. No MATLAB, no headers, no toolbox licenses to compile.
  - icon: ⚡
    title: Zero-copy arrays
    details: Array inputs are read straight from MATLAB's buffers — no copy in, one copy out.
  - icon: 🧩
    title: Batteries included
    details: Enzyme/ForwardDiff gradients, ModelingToolkit ODEs, DataFrames, JuMP, LinearAlgebra, and CUDA GPU kernels.
---

# What is Mexicah?

Mexicah compiles a typed Julia function into a native MATLAB **MEX** file
(`.mexa64` / `.mexw64` / `.mexmaca64`) that MATLAB calls like any built-in. The
heavy lifting is done by Julia's ahead-of-time compiler (`juliac`); Mexicah
generates the marshaling glue and a tiny loader so the result drops cleanly into
MATLAB.

> **Pronunciation:** *meh-SHEE-kah* — after the Mexica of central Mexico.
> The name unpacks to *Matrix-Laboratory EXecutable Interop: Compiled, AOT, Host-free.*

## A 30-second taste

Write a typed function in a small Julia package:

```julia
module MySolvers
using Mexicah

@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    return x + y
end
end
```

Build it (from a project that has both `Mexicah` and `MySolvers`):

```julia
using Mexicah, MySolvers
build_shared_mex([(MySolvers.add_doubles, Type[Float64, Float64], Type[Float64])];
                 output = "mex/")
```

Call it in MATLAB:

```matlab
run('mex/mexicah_setup.m')   % once per session
add_doubles(3, 4)            % ans = 7
```

That's the whole loop. The [Quickstart](guide/quickstart.md) walks through it
step by step, and [Installation](guide/installation.md) covers the one-time setup.

## How it works (one paragraph)

`juliac --trim=safe` compiles your function and a minimal Julia runtime into a
shared library. Because MATLAB can't load that library as a MEX directly,
Mexicah ships a **tiny C gateway** as the actual `.mex*` file: MATLAB loads the
gateway, which loads the Julia library once and forwards the call. Multiple
functions are compiled into **one** shared library (so they share a single Julia
runtime and can all be used in the same MATLAB session). See
[How it runs](guide/runtime.md) for the details.

## Platform support

| Platform | Status |
|---|---|
| Linux (x86-64) | ✅ supported |
| Windows / macOS | 🚧 in progress |

GPU kernels (NVIDIA, via KernelAbstractions) compile to PTX and run with only
the NVIDIA driver — see the [GPU example](examples/cuda.md).
