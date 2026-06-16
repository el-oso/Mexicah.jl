# Scalar Addition

The simplest possible MEX function: add two `Float64` scalars.

## Julia source

juliac compiles from disk, so the function must live in a package module (a
function defined in a script's `Main` cannot be compiled). It is defined in the
`MexicahExamples` package at `examples/src/MexicahExamples.jl`:

```julia
module MexicahExamples
using Mexicah

@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    return x + y
end
end
```

and built by the thin driver `examples/scalar_add.jl`:

```julia
using Mexicah, MexicahExamples

build_shared_mex(
    [(MexicahExamples.add_doubles, Type[Float64, Float64], Type[Float64])];
    output = "mex/",
)
```

## Build

```bash
julia --project=examples examples/scalar_add.jl
```

Output:
```
mex/add_doubles.mexa64        # the MEX gateway MATLAB loads
mex/mexicah_shared_impl.so    # the juliac-compiled Julia library
mex/lib/                      # bundled libjulia
mex/mexicah_setup.m           # adds mex/ to the MATLAB path
```

## MATLAB

```matlab
run('mex/mexicah_setup.m')
result = add_doubles(3.0, 4.0)
% result = 7.0
```

## Notes

- Scalar `Float64` values are passed by value through `mxGetScalar` /
  `mxCreateDoubleScalar` — no heap allocation, no copy.
- Building several functions in one `build_shared_mex` call puts them in a single
  shared library so they share one Julia runtime in a MATLAB session.
