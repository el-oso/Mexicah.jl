# ModelingToolkit ODE

Compile the right-hand side and Jacobian of a ModelingToolkit `ODESystem`
directly into MEX files — no manual function writing required.

!!! warning "Illustrative — requires ModelingToolkit"
    This page demonstrates `build_mex_from_mtk`. ModelingToolkit is a large
    dependency and its generated RHS lives in a runtime-generated module, so it
    may not compile under juliac `--trim=safe`; build it from an environment that
    has MTK loaded. It is not part of the lean, CI-built example set
    ([scalar](scalar.md) / [matrix](matrix.md) / [sparse](sparse.md) /
    [linalg](linalg.md) / [handles](handles.md)).

## Julia source (`examples/mtk_spring_mass.jl`)

```julia
using Mexicah, ModelingToolkit

@variables t x(t) v(t)
@parameters k m

eqs = [D(x) ~ v, D(v) ~ -(k / m) * x]

@named spring_mass = ODESystem(eqs, t, [x, v], [k, m])
sys = structural_simplify(spring_mass)

build_mex_from_mtk(sys; output="mex/")
```

## Build

```bash
julia --project=. examples/mtk_spring_mass.jl
```

Produces:
```
mex/spring_mass_rhs.mexa64
mex/spring_mass_jac.mexa64
mex/libjulia.so
mex/mexicah_setup.m
```

## MATLAB

```matlab
run('mex/mexicah_setup.m')

u  = [1.0; 0.0];    % [x; v]
p  = [1.0; 0.5];    % [k; m]  →  ω² = k/m = 2.0
t  = 0.0;

du = spring_mass_rhs(u, p, t)
% du = [0.0; -2.0]   (velocity = 0, acceleration = -k/m * x = -2)

J  = spring_mass_jac(u, p, t)
% J = [0  1; -2  0]

% Simple Euler integration
dt = 0.01;
for i = 1:1000
    u = u + spring_mass_rhs(u, p, t) * dt;
    t = t + dt;
end
disp(u)   % u ≈ [cos(√2); -√2·sin(√2)] after t=10s
```

## MEX signatures

| MEX file | Inputs | Output |
|---|---|---|
| `spring_mass_rhs` | `u` (state), `p` (parameters), `t` (time) | `du` (derivative) |
| `spring_mass_jac` | `u` (state), `p` (parameters), `t` (time) | `J` (Jacobian matrix) |

All arrays are `Vector{Float64}` or `Matrix{Float64}`.

## How it works

`build_mex_from_mtk` calls `MTK.generate_rhs` and `MTK.generate_jacobian`
with `expression=Val{false}` to get compiled Julia closures (not expression
trees). These closures are then passed directly to `build_mex`. The
`eval_module=MexicahMTKExt` kwarg ensures generated functions are world-age
compatible with `juliac --trim=safe`.
