
# Sparse Matrix: Frobenius Norm {#Sparse-Matrix:-Frobenius-Norm}

Shows how `SparseMatrixCSC{Float64, Int}` is marshaled from MATLAB's Compressed Sparse Column format with zero-copy on the non-zero value array.

## Julia source (`examples/sparse_norm.jl`) {#Julia-source-examples/sparse_norm.jl}

```julia
using Mexicah, SparseArrays

@mexfunction function sparse_frobnorm(A::SparseMatrixCSC{Float64, Int})::Float64
    sqrt(sum(x^2 for x in A.nzval))
end

build_mex(sparse_frobnorm; output="mex/")
```


## Build {#Build}

```bash
julia --project=. examples/sparse_norm.jl
```


## MATLAB {#MATLAB}

```matlab
run('mex/mexicah_setup.m')
A = sparse(magic(5));
n = sparse_frobnorm(A)    % Frobenius norm of the 5×5 magic square
```


## Data transfer for sparse matrices {#Data-transfer-for-sparse-matrices}

MATLAB stores sparse matrices in CSC format (same as Julia's `SparseMatrixCSC`).

|                      Field |                 MATLAB API |                    Julia side |
| --------------------------:| --------------------------:| -----------------------------:|
|     Row indices (`rowval`) | `mxGetIr` → `Ptr{Csize_t}` |     copied: 0-based → 1-based |
| Column pointers (`colptr`) | `mxGetJc` → `Ptr{Csize_t}` |     copied: 0-based → 1-based |
|  Non-zero values (`nzval`) | `mxGetPr` → `Ptr{Float64}` | `unsafe_wrap` — **zero-copy** |


The index arrays require a copy because MATLAB uses 0-based indexing while Julia uses 1-based. The non-zero values are always zero-copy.
