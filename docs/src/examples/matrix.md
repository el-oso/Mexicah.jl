# Matrix Scaling

Demonstrates zero-copy input and single-copy output for `Matrix{Float64}`.

## Julia source (`examples/matrix_scale.jl`)

```julia
using Mexicah

@mexfunction function matrix_scale(A::Matrix{Float64}, s::Float64)::Matrix{Float64}
    A .* s
end

build_mex(matrix_scale; output="mex/")
```

## Build

```bash
julia --project=. examples/matrix_scale.jl
```

## MATLAB

```matlab
run('mex/mexicah_setup.m')
A = rand(1000, 1000);
B = matrix_scale(A, 2.5);
```

## Data transfer

| Direction | What happens |
|---|---|
| `A` (input) | `unsafe_wrap` on `mxGetPr` — Julia sees MATLAB's buffer directly, **zero copy** |
| `s` (input) | `mxGetScalar` — by value |
| `B` (output) | `mxCreateDoubleMatrix` allocates MATLAB-owned buffer; `A .* s` writes into it via `copyto!` — **one `memcpy`** |

!!! tip "Zero-copy output with in-place functions"
    For an in-place variant like `scale!(A, s)` that writes into `A` directly,
    Mexicah can wrap the output slot around `A`'s existing buffer — making
    output also zero-copy. See the Reference for details.
