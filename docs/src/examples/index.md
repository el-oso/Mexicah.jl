# Examples

Each example is a self-contained Julia file in `examples/` and a matching
documentation page showing the Julia source, build command, and MATLAB call
side by side.

| Example | What it demonstrates |
|---|---|
| [Scalar addition](scalar.md) | Hello-world: two `Float64` arguments, one output |
| [Matrix scaling](matrix.md) | Zero-copy `Matrix{Float64}` input, one-copy output |
| [Sparse Frobenius norm](sparse.md) | `SparseMatrixCSC` marshaling |
| [Enzyme gradient](ad_enzyme.md) | Reverse-mode AD via `@mexgradient` |
| [ModelingToolkit ODE](mtk_ode.md) | Spring-mass system RHS + Jacobian MEX |
| [Opaque handles](handles.md) | Persist Julia structs across MEX calls via `UInt64` registry keys |

Run any example with:

```bash
julia --project=. examples/<name>.jl
```
