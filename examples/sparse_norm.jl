# Example: compute the Frobenius norm of a sparse matrix.
#
# The function lives in the MexicahExamples package (examples/src/) so juliac can
# import and compile it — functions defined in a script's Main cannot be built.
#
# Build (from the repo root):
#   julia --project=examples examples/sparse_norm.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   A = sparse(magic(5));
#   n = sparse_frobnorm(A)

using Mexicah, MexicahExamples

build_shared_mex(
    [(MexicahExamples.sparse_frobnorm, Type[Mexicah.SparseMatrixCSC{Float64, Int}], Type[Float64])];
    output = "mex/",
)
