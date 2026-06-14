module MexicahJuMPExt

using Mexicah
using JuMP: JuMP, Model, @variable, @objective, @constraint, optimize!, termination_status
using JuMP: value, objective_value, OPTIMAL, INFEASIBLE, INFEASIBLE_OR_UNBOUNDED, UNBOUNDED

# ── Overview ──────────────────────────────────────────────────────────────────
#
# JuMP models are stateful (they are built incrementally, solved, then queried).
# They cannot be returned by value to MATLAB. Two usage patterns are supported:
#
# Pattern A — stateless (most common): the Julia function creates a model, solves
#   it, extracts the solution, and returns arrays. MATLAB never sees the model.
#   Use the helpers below inside your @mexfunction.
#
#   Example:
#     @mexfunction function solve_portfolio(
#         c::Vector{Float64}, A::Matrix{Float64}, b::Vector{Float64}
#     )::Tuple{Vector{Float64}, Float64, Int64}
#         return MexicahJuMPExt.solve_lp_with(HiGHS.Optimizer, c, A, b,
#                                              fill(0.0, length(c)),
#                                              fill(Inf, length(c)))
#     end
#
# Pattern B — handle-based (for warm-starting / multi-step): use the handle API
#   to store a JuMP model in the Mexicah registry and pass its UInt64 id to MATLAB.
#
#   Example:
#     @mexfunction function create_lp_model(
#         c::Vector{Float64}, A::Matrix{Float64}, b::Vector{Float64}
#     )::UInt64
#         return MexicahJuMPExt.jump_model_to_handle(
#             MexicahJuMPExt.build_lp(HiGHS.Optimizer, c, A, b,
#                                      fill(0.0, length(c)),
#                                      fill(Inf, length(c))))
#     end
#
#     @mexfunction optimize_model(h::UInt64)::Int64
#         return MexicahJuMPExt.jump_optimize!(h)
#     end
#
#     @mexfunction get_solution(h::UInt64)::Vector{Float64}
#         return MexicahJuMPExt.jump_get_values(h)
#     end
#
#     @mexfunction destroy_model(h::UInt64)::Bool
#         return Mexicah._handle_delete!(h)
#     end

# ── JuMP termination status integer codes ─────────────────────────────────────
# Returned as Int64 to MATLAB. These match JuMP's TerminationStatusCode enum.
# 1 = OPTIMAL, 2 = INFEASIBLE, 3 = DUAL_INFEASIBLE (unbounded), etc.
# MATLAB callers should check status == 1 before trusting the solution.

const STATUS_OPTIMAL = Int64(1)
const STATUS_INFEASIBLE = Int64(2)
const STATUS_UNBOUNDED = Int64(3)
const STATUS_OTHER = Int64(99)

function _status_code(model::Model)::Int64
    s = termination_status(model)
    s == OPTIMAL && return STATUS_OPTIMAL
    s == INFEASIBLE && return STATUS_INFEASIBLE
    (s == INFEASIBLE_OR_UNBOUNDED || s == UNBOUNDED) && return STATUS_UNBOUNDED
    return STATUS_OTHER
end

# ── Stateless helpers ─────────────────────────────────────────────────────────

"""
    build_lp(optimizer_type, c, A_ub, b_ub, lb, ub) → JuMP.Model

Set up a JuMP LP model:
  minimize    c' * x
  subject to  A_ub * x  ≤  b_ub
              lb ≤ x ≤ ub

`optimizer_type` is a concrete optimizer constructor (e.g. `HiGHS.Optimizer`).
The model is returned unsolved; call `optimize!` or `solve_lp_with` to solve it.
"""
function build_lp(
        optimizer_type,
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
    )::Model
    n = length(c)
    length(lb) == n && length(ub) == n ||
        error("Mexicah/JuMP: lb, ub, and c must have the same length")
    size(A_ub, 1) == length(b_ub) ||
        error("Mexicah/JuMP: A_ub rows ($(size(A_ub, 1))) must equal length(b_ub) ($(length(b_ub)))")
    size(A_ub, 2) == n ||
        error("Mexicah/JuMP: A_ub columns ($(size(A_ub, 2))) must equal length(c) ($n)")

    model = Model(optimizer_type)
    JuMP.set_silent(model)
    @variable(model, lb[i] <= x[i = 1:n] <= ub[i])
    @objective(model, JuMP.Min, sum(c[i] * x[i] for i in 1:n))
    nub = size(A_ub, 1)
    nub > 0 && @constraint(model, A_ub * x .<= b_ub)
    return model
end

"""
    solve_lp_with(optimizer_type, c, A_ub, b_ub, lb, ub)
        → Tuple{Vector{Float64}, Float64, Int64}

Stateless LP solve. Creates a JuMP model, solves it, and returns
`(x_opt, objective, status_code)`. Status code 1 = OPTIMAL.

Use this directly inside a `@mexfunction` body. The JuMP model is
created and destroyed within this call — MATLAB never sees it.
"""
function solve_lp_with(
        optimizer_type,
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
    )::Tuple{Vector{Float64}, Float64, Int64}
    model = build_lp(optimizer_type, c, A_ub, b_ub, lb, ub)
    optimize!(model)
    status = _status_code(model)
    if status == STATUS_OPTIMAL
        return value.(model[:x]), objective_value(model), status
    else
        return zeros(length(c)), 0.0, status
    end
end

"""
    build_qp(optimizer_type, Q, c, A_ub, b_ub, lb, ub) → JuMP.Model

Set up a convex QP:
  minimize    (1/2) * x' * Q * x  +  c' * x
  subject to  A_ub * x  ≤  b_ub
              lb ≤ x ≤ ub

`Q` must be symmetric positive-semidefinite.
"""
function build_qp(
        optimizer_type,
        Q::Matrix{Float64},
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
    )::Model
    n = length(c)
    size(Q) == (n, n) || error("Mexicah/JuMP: Q must be $n × $n")

    model = Model(optimizer_type)
    JuMP.set_silent(model)
    @variable(model, lb[i] <= x[i = 1:n] <= ub[i])
    @objective(
        model,
        JuMP.Min,
        0.5 * sum(Q[i, j] * x[i] * x[j] for i in 1:n, j in 1:n) +
            sum(c[i] * x[i] for i in 1:n)
    )
    nub = size(A_ub, 1)
    nub > 0 && @constraint(model, A_ub * x .<= b_ub)
    return model
end

"""
    solve_qp_with(optimizer_type, Q, c, A_ub, b_ub, lb, ub)
        → Tuple{Vector{Float64}, Float64, Int64}

Stateless QP solve analogous to `solve_lp_with`.
"""
function solve_qp_with(
        optimizer_type,
        Q::Matrix{Float64},
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
    )::Tuple{Vector{Float64}, Float64, Int64}
    model = build_qp(optimizer_type, Q, c, A_ub, b_ub, lb, ub)
    optimize!(model)
    status = _status_code(model)
    if status == STATUS_OPTIMAL
        return value.(model[:x]), objective_value(model), status
    else
        return zeros(length(c)), 0.0, status
    end
end

# ── Handle-based (stateful) API ───────────────────────────────────────────────

"""
    jump_model_to_handle(model::JuMP.Model) → UInt64

Store an unsolved JuMP model in the Mexicah handle registry. Returns an opaque
UInt64 key that MATLAB can pass to subsequent MEX calls.
"""
jump_model_to_handle(model::Model)::UInt64 = Mexicah._handle_store!(model)

"""
    jump_model_from_handle(id::UInt64) → JuMP.Model

Retrieve the JuMP model stored under `id`. Throws if the handle is not found.
"""
function jump_model_from_handle(id::UInt64)::Model
    obj = Mexicah._handle_get(id)
    obj === nothing && error("Mexicah: no JuMP.Model found for handle $id (already destroyed?)")
    return obj::Model
end

"""
    jump_optimize!(id::UInt64) → Int64

Solve the model at `id` and return the termination status code (1 = OPTIMAL).
The model remains in the registry; call `Mexicah._handle_delete!` when done.
"""
function jump_optimize!(id::UInt64)::Int64
    model = jump_model_from_handle(id)
    optimize!(model)
    return _status_code(model)
end

"""
    jump_get_values(id::UInt64) → Vector{Float64}

Return `value.(x)` for the primal variable `x` in the model at `id`.
Only valid after a successful `jump_optimize!` call with status OPTIMAL.
"""
function jump_get_values(id::UInt64)::Vector{Float64}
    model = jump_model_from_handle(id)
    return value.(model[:x])
end

"""
    jump_get_objective(id::UInt64) → Float64

Return the objective value of the solved model at `id`.
"""
function jump_get_objective(id::UInt64)::Float64
    return objective_value(jump_model_from_handle(id))
end

end # module MexicahJuMPExt
