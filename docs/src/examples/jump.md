# JuMP Optimization

The `MexicahJuMPExt` extension (loaded when `JuMP` is in your environment)
lets MATLAB drive LP and QP optimization problems solved by any JuMP-compatible
solver. Two usage patterns are supported.

!!! warning "Illustrative — requires JuMP + a solver"
    This page demonstrates the `MexicahJuMPExt` API. JuMP and a solver are large
    dependencies that may not compile under juliac `--trim=safe`; build from an
    environment that has them, with the wrappers defined in a package module (not
    a script's `Main`, and depending on the solver directly rather than via
    `Main`). It is not part of the lean, CI-built example set
    ([scalar](scalar.md) / [matrix](matrix.md) / [sparse](sparse.md) /
    [linalg](linalg.md) / [handles](handles.md)).

## Pattern A — Stateless (most common)

Julia creates a model, solves it, and returns arrays. MATLAB never sees the
model object. This is the right choice for one-shot problems where the model
structure is the same every call.

```
MATLAB  ──→  [c, A, b, lb, ub]  ──→  Julia MEX
                                       build model
                                       optimize!
                                       extract x, obj, status
        ←──  [x, obj, status]  ←──
```

## Pattern B — Handle-based (stateful)

Julia builds a model and stores it in the handle registry. MATLAB holds a
`uint64` key and can call `optimize!`, retrieve values, or modify the model
across multiple MEX calls. Use this for warm-starting or multi-step workflows.

```
MATLAB  ──→  create_model(c, A, b)  ──→  Julia: build + _handle_store! → id
        ←──  id (uint64)             ←──
MATLAB  ──→  solve_model(id)         ──→  Julia: optimize!(model at id)
        ←──  status (int64)          ←──
MATLAB  ──→  get_solution(id)        ──→  Julia: value.(x)
        ←──  x (double vector)       ←──
MATLAB  ──→  close_model(id)         ──→  Mexicah._handle_delete!(id)
```

## Extension API

```julia
# Stateless helpers
MexicahJuMPExt.solve_lp_with(optimizer_type, c, A_ub, b_ub, lb, ub)
    → Tuple{Vector{Float64}, Float64, Int64}    # (x, objective, status)

MexicahJuMPExt.solve_qp_with(optimizer_type, Q, c, A_ub, b_ub, lb, ub)
    → Tuple{Vector{Float64}, Float64, Int64}

# Build (returns unsolved model)
MexicahJuMPExt.build_lp(optimizer_type, c, A_ub, b_ub, lb, ub) → JuMP.Model
MexicahJuMPExt.build_qp(optimizer_type, Q, c, A_ub, b_ub, lb, ub) → JuMP.Model

# Handle-based
MexicahJuMPExt.jump_model_to_handle(model)  → UInt64
MexicahJuMPExt.jump_model_from_handle(id)   → JuMP.Model
MexicahJuMPExt.jump_optimize!(id)           → Int64   # status code
MexicahJuMPExt.jump_get_values(id)          → Vector{Float64}
MexicahJuMPExt.jump_get_objective(id)       → Float64

# Status codes
MexicahJuMPExt.STATUS_OPTIMAL    = 1
MexicahJuMPExt.STATUS_INFEASIBLE = 2
MexicahJuMPExt.STATUS_UNBOUNDED  = 3
MexicahJuMPExt.STATUS_OTHER      = 99
```

## Example: LP (Pattern A)

Solve a portfolio allocation LP from MATLAB:

```
minimize    c' * x
subject to  A_ub * x  ≤  b_ub
            lb ≤ x ≤ ub
```

```julia
# examples/jump/solve_lp.jl
using Mexicah, JuMP, HiGHS

@mexfunction function solve_lp(
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
)::Tuple{Vector{Float64}, Float64, Int64}
    return MexicahJuMPExt.solve_lp_with(HiGHS.Optimizer, c, A_ub, b_ub, lb, ub)
end
```

```bash
julia --project=. -e '
    using Mexicah
    include("examples/jump/solve_lp.jl")
    build_all_mex(; output="mex/")
'
```

```matlab
addpath('mex/')
mexicah_setup

% minimize -x1 - 2*x2  s.t.  x1 + x2 <= 4,  x in [0,10]^2
c    = [-1.0; -2.0];
A_ub = [1.0, 1.0];
b_ub = [4.0];
lb   = [0.0; 0.0];
ub   = [10.0; 10.0];

[x, obj, status] = solve_lp(c, A_ub, b_ub, lb, ub);
% status == 1 (OPTIMAL)
% obj ≈ -8.0
% x   ≈ [0; 4]
```

## Example: QP (Pattern A)

```
minimize    (1/2) x' Q x + c' x
subject to  A_ub * x  ≤  b_ub
            lb ≤ x ≤ ub
```

```julia
@mexfunction function solve_qp(
        Q::Matrix{Float64},
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
)::Tuple{Vector{Float64}, Float64, Int64}
    return MexicahJuMPExt.solve_qp_with(HiGHS.Optimizer, Q, c, A_ub, b_ub, lb, ub)
end
```

```matlab
% minimize (1/2)||x||^2  s.t.  x >= [1,1]
n  = 2;
Q  = eye(n);
c  = zeros(n, 1);
A_ub = zeros(0, n);
b_ub = [];
lb = ones(n, 1);
ub = 10 * ones(n, 1);

[x, obj, status] = solve_qp(Q, c, A_ub, b_ub, lb, ub);
% x ≈ [1; 1],  obj ≈ 1.0
```

## Example: warm-starting (Pattern B)

Build a model once, re-optimize after modifying it in Julia:

```julia
@mexfunction function create_lp_model(
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
)::UInt64
    model = MexicahJuMPExt.build_lp(HiGHS.Optimizer, c, A_ub, b_ub, lb, ub)
    return MexicahJuMPExt.jump_model_to_handle(model)
end

@mexfunction function optimize_model(id::UInt64)::Int64
    return MexicahJuMPExt.jump_optimize!(id)
end

@mexfunction function get_solution(id::UInt64)::Vector{Float64}
    return MexicahJuMPExt.jump_get_values(id)
end

@mexfunction function get_objective(id::UInt64)::Float64
    return MexicahJuMPExt.jump_get_objective(id)
end

@mexfunction function close_model(id::UInt64)::Bool
    return Mexicah._handle_delete!(id)
end
```

```matlab
id     = create_lp_model(c, A_ub, b_ub, lb, ub);
status = optimize_model(id);
if status == 1
    x   = get_solution(id);
    obj = get_objective(id);
end
close_model(id);
```

## Choosing a solver

The `optimizer_type` argument is a concrete optimizer constructor, e.g.:

| Solver | Package | Type |
|---|---|---|
| HiGHS (LP, MIP, QP) | `HiGHS.jl` | `HiGHS.Optimizer` |
| GLPK (LP, MIP) | `GLPK.jl` | `GLPK.Optimizer` |
| Ipopt (NLP) | `Ipopt.jl` | `Ipopt.Optimizer` |
| Clarabel (SOCP, SDP) | `Clarabel.jl` | `Clarabel.Optimizer` |

Pass the type directly — this keeps the call `--trim=safe` compatible because
juliac can statically dispatch to the concrete optimizer's methods.

## juliac compatibility

The extension uses concrete optimizer types (not abstract `AbstractOptimizer`)
so the entire dispatch chain is statically resolvable by juliac `--trim=safe`.
The `@verify trim_compat=true` check in `contracts.jl` scans the extension's IR
to confirm this at precompile time.
