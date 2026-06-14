# Example: export the gradient of a scalar objective via Enzyme.jl.
#
# Build:
#   julia --project=. examples/enzyme_gradient.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   g = rosenbrock_grad([1.5; 0.5])   % gradient at (1.5, 0.5)

using Mexicah
using Enzyme: Enzyme

function rosenbrock(x::Vector{Float64})::Float64
    n = length(x)
    s = 0.0
    for i in 1:(n - 1)
        s += 100.0 * (x[i + 1] - x[i]^2)^2 + (1.0 - x[i])^2
    end
    s
end

@mexgradient rosenbrock backend = :enzyme output = "mex/" name = :rosenbrock_grad
