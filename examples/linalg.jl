# Example: LinearAlgebra bridge — SVD, solve, det/inv, and handle-based LU.
#
# The functions live in the MexicahExamples package (examples/src/) so juliac can
# import and compile them; MexicahExamples.LINALG is the build_shared_mex list.
#
# Build (from the repo root):
#   julia --project=examples examples/linalg.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#
#   A = randn(4, 3);
#   [U, s, Vt] = la_svd(A);
#
#   b = randn(4, 1);
#   x = la_solve(A, b);            % least-squares solution
#
#   % Repeated solves: factorize once, solve many times
#   B = rand(100, 100) + 100*eye(100);
#   id = la_lu_factorize(B);
#   for k = 1:50
#     x = la_lu_solve(id, rand(100, 1));
#   end
#   la_lu_destroy(id);

using Mexicah, MexicahExamples

build_shared_mex(MexicahExamples.LINALG; output = "mex/")
