# Example: opaque handle pattern — persist a Julia struct across MEX calls.
#
# Julia structs cannot be returned to MATLAB directly (MATLAB only understands
# mxArray values). The handle pattern stores the struct in a registry and gives
# MATLAB a uint64 key. MATLAB passes the key back on subsequent calls.
#
# The functions live in the MexicahExamples package (examples/src/) so juliac can
# import and compile them; MexicahExamples.HANDLES is the build_shared_mex list.
#
# Build (from the repo root):
#   julia --project=examples examples/handle_solver.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   A  = [4.0, 3.0; 6.0, 3.0];
#   b  = [10.0; 12.0];
#   id = factorize_system(A);    % → uint64 scalar
#   x  = solve_system(id, b);    % → [1; 2]
#   ok = destroy_system(id);     % → 1 (handle released)

using Mexicah, MexicahExamples

build_shared_mex(MexicahExamples.HANDLES; output = "mex/")
