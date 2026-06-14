# Example: compile ModelingToolkit ODE (spring-mass) RHS and Jacobian as MEX.
#
# Build:
#   julia --project=. examples/mtk_spring_mass.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   du = spring_mass_rhs([1.0; 0.0], [1.0; 0.5], 0.0)   % [velocity; -k/m * position]
#   J  = spring_mass_jac([1.0; 0.0], [1.0; 0.5], 0.0)

using Mexicah
using ModelingToolkit: ModelingToolkit as MTK, @variables, @parameters, @named, D_nounits as D
using ModelingToolkit: ODESystem, structural_simplify

@variables t x(t) v(t)
@parameters k m

eqs = [D(x) ~ v, D(v) ~ -(k / m) * x]

@named spring_mass = ODESystem(eqs, t, [x, v], [k, m])
sys = structural_simplify(spring_mass)

build_mex_from_mtk(sys; output="mex/")
