# Example: scale every element of a matrix by a scalar (zero-copy input).
#
# The function lives in the MexicahExamples package (examples/src/) so juliac can
# import and compile it — functions defined in a script's Main cannot be built.
#
# Build (from the repo root):
#   julia --project=examples examples/matrix_scale.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   B = matrix_scale(rand(4,4), 2.5)

using Mexicah, MexicahExamples

build_shared_mex(
    [(MexicahExamples.matrix_scale, Type[Matrix{Float64}, Float64], Type[Matrix{Float64}])];
    output = "mex/",
)
