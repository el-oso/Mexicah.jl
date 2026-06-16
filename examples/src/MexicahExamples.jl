"""
    MexicahExamples

Example functions exported to MATLAB by the scripts in `examples/`. They live in
a package module (not a script) so juliac can `import MexicahExamples` and resolve
each callee when compiling a MEX — a function defined in a script's `Main` cannot
be compiled, because the generated wrapper does `import Main`.

The multi-function areas expose a `build_shared_mex`-shaped list `(function,
input_types, output_types)` (`LINALG`, `HANDLES`) so their driver scripts don't
restate the type signatures; the single-function scalar/matrix/sparse examples
pass an explicit tuple to mirror the quickstart.

Only trim-compilable, framework-free examples live here. The Enzyme / JuMP /
ModelingToolkit / DataFrames examples require heavy frameworks that do not
`--trim=safe` compile, and the GPU example embeds PTX and needs no module import;
those keep their own standalone scripts.
"""
module MexicahExamples

using Mexicah
using SparseArrays: SparseMatrixCSC, nonzeros
using LinearAlgebra: I, tril, triu

# ── Core scalar / array / sparse ──────────────────────────────────────────────

@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    return x + y
end

@mexfunction function matrix_scale(A::Matrix{Float64}, s::Float64)::Matrix{Float64}
    return A .* s
end

@mexfunction function sparse_frobnorm(A::SparseMatrixCSC{Float64, Int})::Float64
    acc = 0.0
    for v in nonzeros(A)
        acc += v * v
    end
    return sqrt(acc)
end

# ── LinearAlgebra bridge (stateless + handle-based factorizations) ────────────

@mexfunction function la_svd(
        A::Matrix{Float64},
    )::Tuple{Matrix{Float64}, Vector{Float64}, Matrix{Float64}}
    return Mexicah.la_svd(A)
end

@mexfunction function la_solve(A::Matrix{Float64}, b::Vector{Float64})::Vector{Float64}
    return Mexicah.la_solve(A, b)
end

@mexfunction function la_det(A::Matrix{Float64})::Float64
    return Mexicah.la_det(A)
end

@mexfunction function la_inv(A::Matrix{Float64})::Matrix{Float64}
    return Mexicah.la_inv(A)
end

@mexfunction function la_lu_factorize(A::Matrix{Float64})::UInt64
    return Mexicah.la_lu_factorize(A)
end

@mexfunction function la_lu_solve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    return Mexicah.la_lu_solve(id, b)
end

@mexfunction function la_lu_destroy(id::UInt64)::Bool
    return Mexicah.la_lu_destroy(id)
end

const LINALG = [
    (la_svd, Type[Matrix{Float64}], Type[Matrix{Float64}, Vector{Float64}, Matrix{Float64}]),
    (la_solve, Type[Matrix{Float64}, Vector{Float64}], Type[Vector{Float64}]),
    (la_det, Type[Matrix{Float64}], Type[Float64]),
    (la_inv, Type[Matrix{Float64}], Type[Matrix{Float64}]),
    (la_lu_factorize, Type[Matrix{Float64}], Type[UInt64]),
    (la_lu_solve, Type[UInt64, Vector{Float64}], Type[Vector{Float64}]),
    (la_lu_destroy, Type[UInt64], Type[Bool]),
]

# ── Opaque-handle pattern: persist a Julia struct across MEX calls ────────────

struct FactoredSystem
    L::Matrix{Float64}
    U::Matrix{Float64}
    p::Vector{Int64}
end

@mexfunction function factorize_system(A::Matrix{Float64})::UInt64
    n = size(A, 1)
    L = tril(A) + Matrix{Float64}(I, n, n)
    U = triu(A)
    p = collect(Int64, 1:n)
    return Mexicah._handle_store!(FactoredSystem(L, U, p))
end

@mexfunction function solve_system(id::UInt64, b::Vector{Float64})::Vector{Float64}
    obj = Mexicah._handle_get(id)
    obj === nothing && error("solve_system: invalid or destroyed handle $id")
    fs = obj::FactoredSystem
    return fs.U \ (fs.L \ b[fs.p])
end

@mexfunction function destroy_system(id::UInt64)::Bool
    return Mexicah._handle_delete!(id)
end

const HANDLES = [
    (factorize_system, Type[Matrix{Float64}], Type[UInt64]),
    (solve_system, Type[UInt64, Vector{Float64}], Type[Vector{Float64}]),
    (destroy_system, Type[UInt64], Type[Bool]),
]

end # module
