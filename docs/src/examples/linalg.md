# LinearAlgebra

The `MexicahLinearAlgebraExt` extension (loaded when `using LinearAlgebra` is in
your session) exposes Julia's LAPACK-backed linear algebra routines as MEX-callable
functions.

## API overview

| Function | Returns | Description |
|---|---|---|
| `la_det(A)` | `Float64` | Determinant |
| `la_trace(A)` | `Float64` | Trace (sum of diagonal) |
| `la_norm_frob(A)` | `Float64` | Frobenius norm |
| `la_opnorm(A)` | `Float64` | Operator 2-norm (largest singular value) |
| `la_cond(A)` | `Float64` | 2-norm condition number |
| `la_rank(A)` | `Int64` | Numerical rank via SVD |
| `la_inv(A)` | `Matrix{Float64}` | Matrix inverse |
| `la_pinv(A)` | `Matrix{Float64}` | Moore-Penrose pseudoinverse |
| `la_solve(A, b)` | `Vector{Float64}` | Solve `Ax = b` |
| `la_svd(A)` | `(U, s, Vt)` | Full SVD |
| `la_svdvals(A)` | `Vector{Float64}` | Singular values only |
| `la_eig_sym(A)` | `(lambda, V)` | Symmetric eigenproblem |
| `la_eig_symvals(A)` | `Vector{Float64}` | Eigenvalues of symmetric `A` |
| `la_qr(A)` | `(Q, R)` | Thin QR factorization |
| `la_chol(A)` | `Matrix{Float64}` | Upper Cholesky factor |
| `la_lu_factorize(A)` | `UInt64` | Store LU in registry → handle |
| `la_lu_solve(id, b)` | `Vector{Float64}` | Solve with stored LU |
| `la_lu_det(id)` | `Float64` | Determinant from stored LU |
| `la_lu_destroy(id)` | `Bool` | Release LU handle |
| `la_chol_factorize(A)` | `UInt64` | Store Cholesky in registry → handle |
| `la_chol_solve(id, b)` | `Vector{Float64}` | Solve with stored Cholesky |
| `la_chol_destroy(id)` | `Bool` | Release Cholesky handle |

> **Note on norms:** Julia's `norm(A)` for matrices returns the Frobenius norm,
> while MATLAB's `norm(A)` returns the 2-norm. `la_norm_frob` matches Julia's
> default; `la_opnorm` matches MATLAB's default.

## Example: stateless decompositions

```julia
# examples/linalg.jl
using Mexicah

@mexfunction function factor_svd(
        A::Matrix{Float64},
)::Tuple{Matrix{Float64}, Vector{Float64}, Matrix{Float64}}
    return Mexicah.la_svd(A)
end

@mexfunction function solve_ls(
        A::Matrix{Float64}, b::Vector{Float64}
)::Vector{Float64}
    return Mexicah.la_solve(A, b)
end

@mexfunction function eig_symmetric(
        A::Matrix{Float64},
)::Tuple{Vector{Float64}, Matrix{Float64}}
    return Mexicah.la_eig_sym(A)
end

build_all_mex(; output="mex/")
```

```bash
julia --project=. examples/linalg.jl
```

```matlab
addpath('mex/')
mexicah_setup

A = randn(4, 3);
[U, s, Vt] = factor_svd(A);    % U is 4×3, s is length-3, Vt is 3×3

b = randn(4, 1);
x = solve_ls(A, b);             % least-squares solution

S = (A' * A);                   % symmetric positive definite
[lambda, V] = eig_symmetric(S);
```

## Example: handle-based LU (repeated solves)

When solving `A * x = b` for many different right-hand sides, factorize once and
reuse:

```julia
@mexfunction function factorize(A::Matrix{Float64})::UInt64
    return Mexicah.la_lu_factorize(A)
end

@mexfunction function backsolve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    return Mexicah.la_lu_solve(id, b)
end

@mexfunction function release_lu(id::UInt64)::Bool
    return Mexicah.la_lu_destroy(id)
end
```

```matlab
A  = rand(500, 500);
id = factorize(A);            % one LU factorization

for k = 1:100
    b  = rand(500, 1);
    x  = backsolve(id, b);   % O(n^2) solve, not O(n^3)
end

release_lu(id);               % free memory
```

## Example: handle-based Cholesky (SPD systems)

For symmetric positive-definite matrices, Cholesky is twice as fast as LU:

```julia
@mexfunction function chol_factorize(A::Matrix{Float64})::UInt64
    return Mexicah.la_chol_factorize(A)
end

@mexfunction function chol_solve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    return Mexicah.la_chol_solve(id, b)
end

@mexfunction function chol_destroy(id::UInt64)::Bool
    return Mexicah.la_chol_destroy(id)
end
```

```matlab
K  = K_stiffness_matrix();    % assumed SPD
id = chol_factorize(K);

for t = 1:n_timesteps
    f  = load_vector(t);
    u  = chol_solve(id, f);
end

chol_destroy(id);
```

## Why use Julia's LinearAlgebra from MATLAB?

- Julia wraps **LAPACK** and **OpenBLAS** (or MKL with MKL.jl), giving access
  to the same high-performance routines MATLAB uses — but composable with any
  Julia package.
- The handle-based factorization API lets you factorize once and solve many
  times across MATLAB loop iterations without re-entering Julia with the full
  matrix on every call.
- Functions like `la_pinv` and `la_eig_sym` can be combined with Enzyme-based
  automatic differentiation via `@mexgradient`, enabling gradient computation
  through LA operations for sensitivity analysis.
