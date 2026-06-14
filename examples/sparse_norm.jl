# Example: compute the Frobenius norm of a sparse matrix.
#
# Build:
#   julia --project=. examples/sparse_norm.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   A = sparse(magic(5));
#   n = sparse_frobnorm(A)

using Mexicah
using SparseArrays: SparseMatrixCSC, nnz

@mexfunction function sparse_frobnorm(
    A::SparseMatrixCSC{Float64, Int},
)::Float64
    sqrt(sum(x^2 for x in A.nzval))
end

build_mex(sparse_frobnorm; output="mex/")
