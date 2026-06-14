# Example: scale every element of a matrix by a scalar (zero-copy input).
#
# Build:
#   julia --project=. examples/matrix_scale.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   B = matrix_scale(rand(4,4), 2.5)

using Mexicah

@mexfunction function matrix_scale(A::Matrix{Float64}, s::Float64)::Matrix{Float64}
    A .* s
end

build_mex(matrix_scale; output="mex/")
