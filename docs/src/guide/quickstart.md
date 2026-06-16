# Quickstart

We'll go from a Julia function to a working MATLAB call. Budget ~5 minutes
(plus a minute or two the first time `juliac` compiles).

> **Why a package?** `juliac` compiles your code in a *separate* process, so it
> can only see functions that live in a real Julia **package** on disk — not
> functions typed into the REPL or a loose script. Step 1 makes that package; it
> takes one command.

## Step 1 — Put your function in a small package

```julia
using Pkg
Pkg.generate("MySolvers")          # creates MySolvers/ with Project.toml + src/
Pkg.activate("MySolvers")
Pkg.add(url = "https://github.com/el-oso/Mexicah.jl")
```

Now edit `MySolvers/src/MySolvers.jl` to define a typed function:

```julia
module MySolvers

using Mexicah

# Every argument and the return value must have a CONCRETE type — Mexicah uses
# them to generate the MATLAB glue.
@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    return x + y
end

@mexfunction function scale_rows(A::Matrix{Float64}, s::Float64)::Matrix{Float64}
    return A .* s
end

end
```

The supported argument/return types are listed in
[Type Support](../reference/marshaling.md) (scalars, vectors, matrices, sparse,
integers, booleans, …).

## Step 2 — Build the MEX files

From the activated `MySolvers` project:

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

This writes a `mex/` folder:

```
mex/
├── add_doubles.mexa64          # ← one tiny gateway MEX per function
├── scale_rows.mexa64
├── mexicah_shared_impl.so      # the compiled Julia code (shared by both)
├── lib/                        # bundled libjulia + runtime
└── mexicah_setup.m             # run this once in MATLAB
```

`build_shared_mex` compiles **all** your functions into one shared library, so
they share a single Julia runtime and can be used together in the same MATLAB
session. (Building one function on its own? `build_mex(f; input_types=…,
output_types=…, output="mex/")` works too.)

## Step 3 — Set up MATLAB (once per session)

Copy the `mex/` folder to your MATLAB machine, then:

```matlab
run('mex/mexicah_setup.m')
```

This puts the bundled `libjulia` on the library path and adds `mex/` to your
MATLAB path so the functions are callable.

## Step 4 — Call from MATLAB

```matlab
add_doubles(3, 4)                 % ans = 7

scale_rows([1 2; 3 4], 10)        % ans = [10 20; 30 40]
```

They behave like ordinary MATLAB functions.

## Step 5 — Ship it

Hand the `mex/` folder to your MATLAB users. They need **only MATLAB** — no
Julia, no toolchain. The Julia runtime is bundled inside.

::: tip One runtime per bundle
Functions built together with `build_shared_mex` share one Julia runtime, so you
can call any mix of them in a session. Functions built **separately** each carry
their own runtime and can't be loaded into the same MATLAB session — so build
everything you'll use together in one `build_shared_mex` call.
:::

## Where to go next

- [Examples](../examples/index.md) — scalars, matrices, sparse, AD gradients, ODEs, GPU.
- [How it runs](runtime.md) — what the gateway and bundle actually do.
- [Type Support](../reference/marshaling.md) — the full type table.
