# Examples

juliac compiles functions from disk, so the example functions live in the
`MexicahExamples` package (`examples/src/MexicahExamples.jl`) rather than in a
script's `Main` — a `Main`-defined function cannot be compiled. Each
`examples/<name>.jl` is a thin driver that builds a subset of those functions,
and each has a matching documentation page.

## Lean, verified examples

These build into a real MEX with `--trim=safe`, exercised end to end in CI:

| Example | What it demonstrates |
|---|---|
| [Scalar addition](scalar.md) | Hello-world: two `Float64` arguments, one output |
| [Matrix scaling](matrix.md) | Zero-copy `Matrix{Float64}` input, one-copy output |
| [Sparse Frobenius norm](sparse.md) | `SparseMatrixCSC` marshaling |
| [LinearAlgebra](linalg.md) | SVD, solve, det/inv, and handle-based LU solvers |
| [Opaque handles](handles.md) | Persist Julia structs across MEX calls via `UInt64` registry keys |

Build any of them (instantiate the environment once):

```bash
julia --project=examples -e 'using Pkg; Pkg.instantiate()'   # once
julia --project=examples examples/scalar_add.jl
```

## Experimental extensions

Mexicah ships package extensions for **DataFrames**, **Enzyme**, **ForwardDiff**,
**JuMP**, **ModelingToolkit**, and **CUDA**. They are **experimental**: each pulls
in a large framework whose runtime is fundamentally dynamic, so a MEX that uses one
**does not compile under `--trim=safe`** (verified — Enzyme's `autodiff`, JuMP's MOI
layer, DataFrames' internals, and MTK/DiffEq's solvers all emit unresolved dynamic
calls). The same applies to `DifferentialEquations.jl`. There are deliberately **no
example pages** for them, because every example here is one that actually compiles
and runs.

If you need one of these frameworks, load it in your environment and build with
`trim=false` — you get a large, working (un-trimmed) MEX. For an ODE, the trim-safe
route is to write the right-hand side and a fixed-step integrator as plain Julia
(no framework), which compiles cleanly like the examples above.

### ModelingToolkit

`build_mex_from_mtk(sys)` (in `MexicahMTKExt`) generates the right-hand side and
Jacobian of a simplified `ODESystem` as `f(u, p, t)` / `J(u, p, t)`. The `(u, p, t)`
callables are numerically correct: `u` is in `unknowns(sys)` order and `p` (a flat
vector of parameter values) in `parameters(sys)` order — `structural_simplify` reorders
both — and `p` is assembled into the `MTKParameters` object current MTK requires (passing
a flat vector straight through silently produced wrong numbers in older versions). The
generated functions use `RuntimeGeneratedFunction`s and pull MTK into the runtime, so the
result is `trim=false`. Producing a fully juliac-compiled MEX additionally needs the
generated closures emitted into an importable on-disk package (they currently live in the
extension module, which juliac cannot `import`) — a known limitation.

### Enzyme / ForwardDiff gradients (`trim=false` recipe)

`@mexgradient` compiles the gradient of a scalar loss `f(x::Vector{Float64})::Float64`
into a MEX `[g] = f_grad(x)`. Enzyme is not trim-safe, so pass `trim=false`:

```julia
module Grad
using Mexicah, Enzyme          # loading Enzyme activates the backend

loss(x) = sum(abs2, x)         # scalar-valued, one Vector{Float64} argument

@mexgradient loss backend=:enzyme trim=false
end
```

```matlab
run('mex/mexicah_setup.m')
loss_grad([1 2 3])             % → [2 4 6]
```

`trim=false` yields a large but working (un-trimmed) MEX that bundles Enzyme's AD
runtime. `backend=:forwarddiff` can build trim-safe for small inputs (omit `trim`). This
is the general pattern for any experimental extension: load the framework and pass
`trim=false`.
