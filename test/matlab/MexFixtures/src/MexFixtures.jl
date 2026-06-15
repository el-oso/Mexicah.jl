module MexFixtures

# One fixture per marshaled type, exercised end-to-end in real MATLAB by
# test/matlab/tMexicahFixtures.m. Defined in a package (not a script) so juliac
# can `import MexFixtures` and resolve each callee when compiling the MEX.

using Mexicah
using SparseArrays: SparseMatrixCSC, nonzeros

# Float64 scalar
function add_doubles(x::Float64, y::Float64)::Float64
    return x + y
end

# Matrix{Float64} (zero-copy in, one-copy out)
function matrix_scale(A::Matrix{Float64}, s::Float64)::Matrix{Float64}
    return A .* s
end

# SparseMatrixCSC{Float64,Int} — Frobenius norm of the stored values
function sparse_fro(A::SparseMatrixCSC{Float64, Int})::Float64
    acc = 0.0
    for v in nonzeros(A)
        acc += v * v
    end
    return sqrt(acc)
end

# Vector{ComplexF64} (interleaved complex, R2018a+)
function complex_conj(v::Vector{ComplexF64})::Vector{ComplexF64}
    return conj(v)
end

# Int64 scalar
function int64_double(n::Int64)::Int64
    return 2n
end

# Int32 scalar (distinct marshaler / mxGetData path)
function int32_double(n::Int32)::Int32
    return Int32(2) * n
end

# Bool scalar (logical)
function bool_not(b::Bool)::Bool
    return !b
end

# (function, input types, output types), in build order. The first entry bundles
# the Julia runtime; the rest reuse it (see build_fixtures.jl).
const FIXTURES = [
    (add_doubles, Type[Float64, Float64], Type[Float64]),
    (matrix_scale, Type[Matrix{Float64}, Float64], Type[Matrix{Float64}]),
    (sparse_fro, Type[SparseMatrixCSC{Float64, Int}], Type[Float64]),
    (complex_conj, Type[Vector{ComplexF64}], Type[Vector{ComplexF64}]),
    (int64_double, Type[Int64], Type[Int64]),
    (int32_double, Type[Int32], Type[Int32]),
    (bool_not, Type[Bool], Type[Bool]),
]

end # module MexFixtures
