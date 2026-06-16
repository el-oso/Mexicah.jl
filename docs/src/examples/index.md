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

## GPU example

| Example | What it demonstrates |
|---|---|
| [GPU kernels (CUDA)](cuda.md) | KernelAbstractions `@kernel` → PTX → driver-only MEX |

The GPU example embeds PTX and has its own environment (CUDA is kept out of the
lean project so CPU builds don't bundle ~800 MiB of CUDA artifacts):

```bash
julia --project=examples/gpu -e 'using Pkg; Pkg.instantiate()'   # once
julia --project=examples/gpu examples/cuda_vector_add.jl         # needs an NVIDIA GPU
```

## Illustrative framework examples

These show how the package extensions are used, but depend on large frameworks
that may not compile under `--trim=safe`; they require the framework in your
environment and are not part of the CI-built set.

| Example | What it demonstrates |
|---|---|
| [Enzyme gradient](ad_enzyme.md) | Reverse-mode AD via `@mexgradient` |
| [ModelingToolkit ODE](mtk_ode.md) | Spring-mass system RHS + Jacobian MEX |
| [DataFrames](dataframes.md) | Handle-based DataFrame lifecycle and value-copy struct conversion |
| [JuMP optimization](jump.md) | Stateless LP/QP solvers and handle-based model lifecycle |
