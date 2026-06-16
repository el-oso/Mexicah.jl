# Example: export the gradient of a scalar objective via Enzyme.jl.
#
# ⚠️  ILLUSTRATIVE — not part of the lean, CI-built example set. It requires
# Enzyme.jl in your environment, and AD frameworks are large and may not compile
# under juliac `--trim=safe`. For a real build, define the objective in a package
# (like examples/src/MexicahExamples.jl) so juliac can import it, then build from
# an environment that also has Enzyme. The lean, verified examples are
# scalar_add / matrix_scale / sparse_norm / linalg / handle_solver.
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
    return s
end

@mexgradient rosenbrock backend = :enzyme output = "mex/" name = :rosenbrock_grad
