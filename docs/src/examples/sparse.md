# Sparse Matrix: Frobenius Norm

Shows how `SparseMatrixCSC{Float64, Int}` is marshaled from MATLAB's
Compressed Sparse Column format with zero-copy on the non-zero value array.

## Julia source

The function lives in the `MexicahExamples` package
(`examples/src/MexicahExamples.jl`) so juliac can import and compile it:

```julia
module MexicahExamples
using Mexicah
using SparseArrays: SparseMatrixCSC, nonzeros

@mexfunction function sparse_frobnorm(A::SparseMatrixCSC{Float64, Int})::Float64
    acc = 0.0
    for v in nonzeros(A)
        acc += v * v
    end
    return sqrt(acc)
end
end
```

and the driver `examples/sparse_norm.jl` builds it:

```julia
using Mexicah, MexicahExamples

build_shared_mex(
    [(MexicahExamples.sparse_frobnorm, Type[Mexicah.SparseMatrixCSC{Float64, Int}], Type[Float64])];
    output = "mex/",
)
```

## Build

```bash
julia --project=examples examples/sparse_norm.jl
```

## MATLAB

```matlab
run('mex/mexicah_setup.m')
A = sparse(magic(5));
n = sparse_frobnorm(A)    % Frobenius norm of the 5×5 magic square
```

## Data transfer for sparse matrices

MATLAB stores sparse matrices in CSC format (same as Julia's `SparseMatrixCSC`).

| Field | MATLAB API | Julia side |
|---|---|---|
| Row indices (`rowval`) | `mxGetIr` → `Ptr{Csize_t}` | copied: 0-based → 1-based |
| Column pointers (`colptr`) | `mxGetJc` → `Ptr{Csize_t}` | copied: 0-based → 1-based |
| Non-zero values (`nzval`) | `mxGetPr` → `Ptr{Float64}` | `unsafe_wrap` — **zero-copy** |

The index arrays require a copy because MATLAB uses 0-based indexing while
Julia uses 1-based. The non-zero values are always zero-copy.
