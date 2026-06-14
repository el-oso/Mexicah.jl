
# Quickstart {#Quickstart}

This page walks through the complete workflow from a Julia function to a working MATLAB call in five steps.

## Step 1 — Write a typed Julia function {#Step-1-—-Write-a-typed-Julia-function}

All argument and return types must be **concrete**. Mexicah uses them to generate the marshaling code and to guide `juliac --trim=safe`.

```julia
# mymodel.jl
using Mexicah

@mexfunction function lorenz_rhs(
    u::Vector{Float64},
    p::Vector{Float64},
    t::Float64,
)::Vector{Float64}
    σ, ρ, β = p[1], p[2], p[3]
    [σ * (u[2] - u[1]), u[1] * (ρ - u[3]) - u[2], u[1] * u[2] - β * u[3]]
end
```


## Step 2 — Build the MEX file {#Step-2-—-Build-the-MEX-file}

```julia
build_mex(lorenz_rhs; output="./mex/")
```


This produces:

```
./mex/
├── lorenz_rhs.mexa64        # the MEX extension (Linux)
├── libjulia.so              # Julia runtime (shared across all MEX files)
├── …other Julia deps…
└── mexicah_setup.m          # run this once in MATLAB
```


Or use the CLI:

```bash
mexicah compile mymodel.jl --function lorenz_rhs --output ./mex/
```


## Step 3 — Set up MATLAB {#Step-3-—-Set-up-MATLAB}

In MATLAB (once per session):

```matlab
run('mex/mexicah_setup.m')
```


This adds the bundle directory to `LD_LIBRARY_PATH` so MATLAB can find `libjulia.so` when it loads the MEX file.

## Step 4 — Call from MATLAB {#Step-4-—-Call-from-MATLAB}

```matlab
u0 = [1.0; 0.0; 0.0];
p  = [10.0; 28.0; 8/3];  % σ, ρ, β
t  = 0.0;

du = lorenz_rhs(u0, p, t);
disp(du)   % [-10.0; 28.0; 0.0]
```


## Step 5 — Share the MEX file {#Step-5-—-Share-the-MEX-file}

Distribute the contents of `./mex/` to your MATLAB users. They do **not** need Julia installed. The bundle is self-contained.

::: tip Runtime sharing

When multiple MEX files built with Mexicah are in the same directory, they all share the same `libjulia.so`. The Julia runtime is initialized exactly once per MATLAB session regardless of how many MEX files are loaded.

:::
