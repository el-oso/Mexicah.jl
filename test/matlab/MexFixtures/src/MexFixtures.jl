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

# Float32 scalar (mxSINGLE)
function float32_double(x::Float32)::Float32
    return 2.0f0 * x
end

# Int16 scalar (a smaller-width integer class)
function int16_double(n::Int16)::Int16
    return Int16(2) * n
end

# Matrix{Float32} — dense non-Float64 array (DenseArrayMarshaler)
function mat_f32_scale(A::Matrix{Float32}, s::Float32)::Matrix{Float32}
    return A .* s
end

# 3-D Float64 array — rank > 2 (DenseArrayMarshaler{Float64,3})
function cube_add1(A::Array{Float64, 3})::Array{Float64, 3}
    return A .+ 1.0
end

# Matrix{ComplexF64} — complex 2-D (ComplexArrayMarshaler{2})
function cmat_conj(A::Matrix{ComplexF64})::Matrix{ComplexF64}
    return conj(A)
end

# Struct output — Julia struct → MATLAB scalar struct (StructMarshaler)
struct Stats
    mean::Float64
    n::Int64
end

function make_stats(v::Vector{Float64})::Stats
    return Stats(sum(v) / length(v), length(v))
end

# Multiple outputs — exercises the nlhs-aware store (calling with one output must
# not write past plhs).
function minmax_vec(v::Vector{Float64})::Tuple{Float64, Float64}
    return (minimum(v), maximum(v))
end

# Struct INPUT — exercises StructMarshaler load (MATLAB struct → Julia Stats).
function stats_total(s::Stats)::Float64
    return s.mean * Float64(s.n)
end

# Matrix{Bool} — logical array (LogicalArrayMarshaler)
function logical_not_arr(A::Matrix{Bool})::Matrix{Bool}
    return .!A
end

# Vector{Stats} in & out — MATLAB N×1 struct array (StructVectorMarshaler)
function scale_stats(xs::Vector{Stats}, k::Float64)::Vector{Stats}
    return [Stats(s.mean * k, s.n) for s in xs]
end

# Vector{ComplexF32} — single-precision complex (ComplexF32ArrayMarshaler)
function cf32_conj(v::Vector{ComplexF32})::Vector{ComplexF32}
    return conj(v)
end

# SparseMatrixCSC{ComplexF64, Int} — complex sparse Frobenius norm
function sparse_complex_fro(A::SparseMatrixCSC{ComplexF64, Int})::Float64
    acc = 0.0
    for v in nonzeros(A)
        acc += abs2(v)
    end
    return sqrt(acc)
end

# SparseMatrixCSC{Bool, Int} — logical sparse identity (tests both load and store)
function logical_sparse_identity(A::SparseMatrixCSC{Bool, Int})::SparseMatrixCSC{Bool, Int}
    return A
end

# Tuple{Float64, Int64} → 1×2 MATLAB cell (CellArrayMarshaler output)
function tuple_passthrough(x::Float64, n::Int64)::Tuple{Float64, Int64}
    return (x, n)
end

# Vector{String} → N×1 MATLAB cell of char (StringVectorMarshaler both ways)
function strs_upper(v::Vector{String})::Vector{String}
    return map(uppercase, v)
end

# Matrix{String} ↔ MATLAB string array (StringArrayMarshaler; via mexCallMATLAB
# string()/cellstr()). Exercises the real string() / cellstr() builtins in CI.
function str_arr_upper(m::Matrix{String})::Matrix{String}
    return map(uppercase, m)
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
    (float32_double, Type[Float32], Type[Float32]),
    (int16_double, Type[Int16], Type[Int16]),
    (mat_f32_scale, Type[Matrix{Float32}, Float32], Type[Matrix{Float32}]),
    (cube_add1, Type[Array{Float64, 3}], Type[Array{Float64, 3}]),
    (cmat_conj, Type[Matrix{ComplexF64}], Type[Matrix{ComplexF64}]),
    (make_stats, Type[Vector{Float64}], Type[Stats]),
    (minmax_vec, Type[Vector{Float64}], Type[Float64, Float64]),
    (stats_total, Type[Stats], Type[Float64]),
    (logical_not_arr, Type[Matrix{Bool}], Type[Matrix{Bool}]),
    (scale_stats, Type[Vector{Stats}, Float64], Type[Vector{Stats}]),
    (cf32_conj, Type[Vector{ComplexF32}], Type[Vector{ComplexF32}]),
    (sparse_complex_fro, Type[SparseMatrixCSC{ComplexF64, Int}], Type[Float64]),
    (logical_sparse_identity, Type[SparseMatrixCSC{Bool, Int}], Type[SparseMatrixCSC{Bool, Int}]),
    (tuple_passthrough, Type[Float64, Int64], Type[Tuple{Float64, Int64}]),
    (strs_upper, Type[Vector{String}], Type[Vector{String}]),
    (str_arr_upper, Type[Matrix{String}], Type[Matrix{String}]),
]

end # module MexFixtures
