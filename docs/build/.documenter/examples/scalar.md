
# Scalar Addition {#Scalar-Addition}

The simplest possible MEX function: add two `Float64` scalars.

## Julia source (`examples/scalar_add.jl`) {#Julia-source-examples/scalar_add.jl}

```julia
using Mexicah

@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    x + y
end

build_mex(add_doubles; output="mex/")
```


## Build {#Build}

```bash
julia --project=. examples/scalar_add.jl
# or
mexicah compile examples/scalar_add.jl --function add_doubles --output mex/
```


Output:

```
mex/add_doubles.mexa64
mex/libjulia.so
mex/mexicah_setup.m
```


## MATLAB {#MATLAB}

```matlab
run('mex/mexicah_setup.m')
result = add_doubles(3.0, 4.0)
% result = 7.0
```


## Notes {#Notes}
- Scalar `Float64` values are passed by value through `mxGetScalar` / `mxCreateDoubleScalar` — no heap allocation, no copy.
  
- The MEX binary with `--trim=safe` is approximately 1–2 MB.
  
