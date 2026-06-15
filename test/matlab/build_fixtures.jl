# Builds one MEX fixture per marshaled type into `mex/`, for the MATLAB
# end-to-end CI (.github/workflows/MATLAB.yml). Each fixture is the smallest
# function that exercises a distinct marshaler; the matching assertions live in
# test/matlab/tMexicahFixtures.m.
#
# Run from the repo root:
#   julia --project=. test/matlab/build_fixtures.jl
#
# Requires `juliac` on PATH (the JuliaC app).
#
# juliac --bundle copies the Julia runtime (libjulia, share/julia/…) next to the
# MEX, and JuliaC errors if those bundle files already exist. So we bundle the
# runtime exactly once (the first fixture) and build the rest with bundle=false
# into the same dir; they share that one libjulia, resolved at load time via the
# loader path the workflow exports (mex/, mex/lib, mex/lib/julia).

using Mexicah
using SparseArrays: SparseMatrixCSC, nonzeros

const OUT = get(ENV, "MEXICAH_FIXTURE_DIR", "mex")

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

# (function, input types, output types). The first entry bundles the Julia
# runtime; the rest reuse it (bundle = false) to avoid juliac's bundle-file
# collision in a shared output directory.
const FIXTURES = [
    (add_doubles, Type[Float64, Float64], Type[Float64]),
    (matrix_scale, Type[Matrix{Float64}, Float64], Type[Matrix{Float64}]),
    (sparse_fro, Type[SparseMatrixCSC{Float64, Int}], Type[Float64]),
    (complex_conj, Type[Vector{ComplexF64}], Type[Vector{ComplexF64}]),
    (int64_double, Type[Int64], Type[Int64]),
    (int32_double, Type[Int32], Type[Int32]),
    (bool_not, Type[Bool], Type[Bool]),
]

for (i, (f, intypes, outtypes)) in enumerate(FIXTURES)
    build_mex(
        f;
        input_types = intypes,
        output_types = outtypes,
        name = nameof(f),
        output = OUT,
        bundle = (i == 1),
    )
end

@info "Mexicah: built $(length(FIXTURES)) fixtures into $(abspath(OUT))"
