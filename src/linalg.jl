using LinearAlgebra:
    LinearAlgebra,
    lu,
    cholesky,
    svd,
    svdvals,
    eigen,
    qr,
    det,
    tr,
    norm,
    opnorm,
    cond,
    rank,
    inv,
    pinv

# ── Overview ──────────────────────────────────────────────────────────────────
#
# Stateless helpers — each call builds and discards the factorization:
#   la_det, la_trace, la_norm_frob, la_opnorm, la_cond, la_rank,
#   la_inv, la_pinv, la_solve,
#   la_svd, la_svdvals, la_eig_sym, la_eig_symvals, la_qr, la_chol
#
# Handle-based — reuse the same factorization for multiple right-hand sides:
#   la_lu_factorize / la_lu_solve / la_lu_det / la_lu_destroy
#   la_chol_factorize / la_chol_solve / la_chol_destroy
#
# MATLAB callers receive the UInt64 handle from the factorize call and pass it
# back to every subsequent solve call. Call _destroy when done to allow GC.

# ── Scalar / matrix scalars ───────────────────────────────────────────────────

"""
    la_det(A) → Float64

Determinant of `A` (via LU factorization).
"""
la_det(A::Matrix{Float64})::Float64 = det(A)

"""
    la_trace(A) → Float64

Sum of diagonal elements of `A`.
"""
la_trace(A::Matrix{Float64})::Float64 = tr(A)

"""
    la_norm_frob(A) → Float64

Frobenius norm of `A`: `sqrt(sum(A.^2))`.

Note: MATLAB's `norm(A)` returns the 2-norm (largest singular value).
Use `la_opnorm` for that. Use `la_norm_frob` for the Frobenius norm.
"""
la_norm_frob(A::Matrix{Float64})::Float64 = norm(A)

"""
    la_opnorm(A) → Float64

Operator 2-norm of `A` (largest singular value). Equivalent to MATLAB's `norm(A)`.
"""
la_opnorm(A::Matrix{Float64})::Float64 = opnorm(A, 2)

"""
    la_cond(A) → Float64

2-norm condition number of `A` (ratio of largest to smallest singular value).
Returns `Inf` if `A` is singular.
"""
la_cond(A::Matrix{Float64})::Float64 = cond(A)

"""
    la_rank(A) → Int64

Numerical rank of `A` estimated via SVD with default tolerance.
"""
la_rank(A::Matrix{Float64})::Int64 = Int64(rank(A))

# ── Dense linear algebra ──────────────────────────────────────────────────────

"""
    la_inv(A) → Matrix{Float64}

Matrix inverse of `A`. Prefer `la_solve` or the handle-based LU API for
solving linear systems — `la_inv` is provided for cases where the inverse
itself is needed.
"""
la_inv(A::Matrix{Float64})::Matrix{Float64} = inv(A)

"""
    la_pinv(A) → Matrix{Float64}

Moore-Penrose pseudoinverse of `A`.
"""
la_pinv(A::Matrix{Float64})::Matrix{Float64} = pinv(A)

"""
    la_solve(A, b) → Vector{Float64}

Solve the linear system `A * x = b` using Julia's backslash operator.
For repeated solves with the same `A`, use `la_lu_factorize` / `la_lu_solve`
instead to amortize the factorization cost.
"""
la_solve(A::Matrix{Float64}, b::Vector{Float64})::Vector{Float64} = A \ b

# ── Decompositions ────────────────────────────────────────────────────────────

"""
    la_svd(A) → (U, s, Vt)

Full SVD: `A = U * diagm(s) * Vt`. Returns three outputs:
- `U` — left singular vectors (m × k matrix)
- `s` — singular values in descending order (vector of length k = min(m,n))
- `Vt` — transposed right singular vectors (k × n matrix, i.e. `V'`)

MATLAB call: `[U, s, Vt] = la_svd(A)`
"""
function la_svd(
        A::Matrix{Float64},
    )::Tuple{Matrix{Float64}, Vector{Float64}, Matrix{Float64}}
    F = svd(A)
    return F.U, F.S, F.Vt
end

"""
    la_svdvals(A) → Vector{Float64}

Singular values of `A` in descending order. Faster than `la_svd` when only
the values are needed.
"""
la_svdvals(A::Matrix{Float64})::Vector{Float64} = svdvals(A)

"""
    la_eig_sym(A) → (lambda, V)

Eigendecomposition of a real symmetric matrix `A`. Returns:
- `lambda` — eigenvalues in ascending order (real-valued)
- `V`      — columns are the corresponding eigenvectors

`A` must be symmetric; only the lower triangle is read. For non-symmetric
matrices the result is undefined.

MATLAB call: `[lambda, V] = la_eig_sym(A)`
"""
function la_eig_sym(
        A::Matrix{Float64},
    )::Tuple{Vector{Float64}, Matrix{Float64}}
    F = eigen(LinearAlgebra.Symmetric(A))
    return F.values, F.vectors
end

"""
    la_eig_symvals(A) → Vector{Float64}

Eigenvalues of the real symmetric matrix `A` in ascending order.
Faster than `la_eig_sym` when only eigenvalues are needed.
"""
function la_eig_symvals(A::Matrix{Float64})::Vector{Float64}
    return eigen(LinearAlgebra.Symmetric(A)).values
end

"""
    la_qr(A) → (Q, R)

Thin QR factorization of `A` (m × n, m ≥ n).
- `Q` — orthonormal columns (m × n)
- `R` — upper triangular (n × n)

MATLAB call: `[Q, R] = la_qr(A)`
"""
function la_qr(A::Matrix{Float64})::Tuple{Matrix{Float64}, Matrix{Float64}}
    F = qr(A)
    return Matrix(F.Q), F.R
end

"""
    la_chol(A) → R

Upper Cholesky factor of the symmetric positive-definite matrix `A`.
Returns `R` such that `A = R' * R`.
"""
function la_chol(A::Matrix{Float64})::Matrix{Float64}
    return cholesky(LinearAlgebra.Symmetric(A)).U
end

# ── Handle-based LU factorization ─────────────────────────────────────────────

"""
    la_lu_factorize(A) → UInt64

Compute the LU factorization of `A` and store it in the Mexicah handle registry.
Returns an opaque handle that MATLAB passes to `la_lu_solve` and `la_lu_det`.
Call `la_lu_destroy` when finished to allow garbage collection.
"""
function la_lu_factorize(A::Matrix{Float64})::UInt64
    return _handle_store!(lu(A))
end

"""
    la_lu_solve(id, b) → Vector{Float64}

Solve `A * x = b` using the LU factorization stored at `id`.
"""
function la_lu_solve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    obj = _handle_get(id)
    obj === nothing && error("Mexicah/LinearAlgebra: no LU factorization at handle $id")
    # Narrow the Any from the handle registry to the concrete factorization so the
    # `\` solve dispatches statically — required for juliac --trim=safe.
    F = obj::LinearAlgebra.LU{Float64, Matrix{Float64}, Vector{Int64}}
    return F \ b
end

"""
    la_lu_det(id) → Float64

Determinant of the matrix whose LU factorization is stored at `id`.
Cheaper than `la_det` for an already-factored matrix.
"""
function la_lu_det(id::UInt64)::Float64
    obj = _handle_get(id)
    obj === nothing && error("Mexicah/LinearAlgebra: no LU factorization at handle $id")
    F = obj::LinearAlgebra.LU{Float64, Matrix{Float64}, Vector{Int64}}
    return det(F)
end

"""
    la_lu_destroy(id) → Bool

Remove the LU factorization at `id` from the registry.
Returns `true` if the handle existed, `false` if already deleted.
"""
la_lu_destroy(id::UInt64)::Bool = _handle_delete!(id)

# ── Handle-based Cholesky factorization ───────────────────────────────────────

"""
    la_chol_factorize(A) → UInt64

Compute the Cholesky factorization of the symmetric positive-definite matrix `A`
and store it in the handle registry. Only the lower triangle of `A` is read.
"""
function la_chol_factorize(A::Matrix{Float64})::UInt64
    return _handle_store!(cholesky(LinearAlgebra.Symmetric(A)))
end

"""
    la_chol_solve(id, b) → Vector{Float64}

Solve `A * x = b` using the Cholesky factorization stored at `id`.
"""
function la_chol_solve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    obj = _handle_get(id)
    obj === nothing && error("Mexicah/LinearAlgebra: no Cholesky factorization at handle $id")
    # Narrow to the concrete factorization so `\` is statically dispatched (trim-safe).
    F = obj::LinearAlgebra.Cholesky{Float64, Matrix{Float64}}
    return F \ b
end

"""
    la_chol_destroy(id) → Bool

Remove the Cholesky factorization at `id` from the registry.
"""
la_chol_destroy(id::UInt64)::Bool = _handle_delete!(id)
