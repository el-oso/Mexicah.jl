@testitem "marshaler_for returns correct marshaler type" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Float64) isa Mexicah.Float64Marshaler
    @test Mexicah.marshaler_for(Vector{Float64}) isa Mexicah.VectorFloat64Marshaler
    @test Mexicah.marshaler_for(Matrix{Float64}) isa Mexicah.MatrixFloat64Marshaler
    @test Mexicah.marshaler_for(Int32) isa Mexicah.Int32Marshaler
    @test Mexicah.marshaler_for(Int64) isa Mexicah.Int64Marshaler
    @test Mexicah.marshaler_for(Bool) isa Mexicah.BoolMarshaler
    import SparseArrays: SparseMatrixCSC
    @test Mexicah.marshaler_for(SparseMatrixCSC{Float64, Int}) isa Mexicah.SparseFloat64Marshaler
end

@testitem "marshaler_for: non-Float64 sparse" begin
    using Mexicah, Test, SparseArrays
    @test Mexicah.marshaler_for(SparseMatrixCSC{ComplexF64, Int}) isa
        Mexicah.SparseComplexF64Marshaler
    @test Mexicah.marshaler_for(SparseMatrixCSC{Bool, Int}) isa Mexicah.SparseLogicalMarshaler
    @test Mexicah.mx_class_id(Mexicah.SparseComplexF64Marshaler()) == Mexicah.mxDOUBLE_CLASS
    @test Mexicah.mx_class_id(Mexicah.SparseLogicalMarshaler()) == Mexicah.mxLOGICAL_CLASS
end

@testitem "marshaler_for errors on unsupported type" begin
    using Mexicah, Test
    @test_throws ErrorException Mexicah.marshaler_for(Complex{Int32})
    @test_throws ErrorException Mexicah.marshaler_for(AbstractVector)
end

@testitem "mx_class_id returns Cint for all marshalers" begin
    using Mexicah, Test
    @test Mexicah.mx_class_id(Mexicah.Float64Marshaler()) isa Cint
    @test Mexicah.mx_class_id(Mexicah.VectorFloat64Marshaler()) isa Cint
    @test Mexicah.mx_class_id(Mexicah.MatrixFloat64Marshaler()) isa Cint
    @test Mexicah.mx_class_id(Mexicah.Int32Marshaler()) isa Cint
    @test Mexicah.mx_class_id(Mexicah.Int64Marshaler()) isa Cint
    @test Mexicah.mx_class_id(Mexicah.BoolMarshaler()) == Mexicah.mxLOGICAL_CLASS
    @test Mexicah.mx_class_id(Mexicah.SparseFloat64Marshaler()) isa Cint
    @test Mexicah.mx_class_id(Mexicah.ComplexFloat64Marshaler()) isa Cint
end

@testitem "marshaler_for: extended numeric scalars" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Float32) isa Mexicah.Float32Marshaler
    @test Mexicah.marshaler_for(Int8) isa Mexicah.Int8Marshaler
    @test Mexicah.marshaler_for(Int16) isa Mexicah.Int16Marshaler
    @test Mexicah.marshaler_for(UInt8) isa Mexicah.UInt8Marshaler
    @test Mexicah.marshaler_for(UInt16) isa Mexicah.UInt16Marshaler
    @test Mexicah.marshaler_for(UInt32) isa Mexicah.UInt32Marshaler
    @test Mexicah.mx_class_id(Mexicah.Float32Marshaler()) == Mexicah.mxSINGLE_CLASS
    @test Mexicah.mx_class_id(Mexicah.UInt8Marshaler()) == Mexicah.mxUINT8_CLASS
end

@testitem "marshaler_for: dense numeric arrays of any rank/eltype" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Vector{Float32}) isa Mexicah.DenseArrayMarshaler{Float32, 1}
    @test Mexicah.marshaler_for(Matrix{Int32}) isa Mexicah.DenseArrayMarshaler{Int32, 2}
    @test Mexicah.marshaler_for(Array{Float64, 3}) isa Mexicah.DenseArrayMarshaler{Float64, 3}
    @test Mexicah.marshaler_for(Array{UInt8, 4}) isa Mexicah.DenseArrayMarshaler{UInt8, 4}
    # Float64 Vector/Matrix keep their dedicated (non-parametric) marshalers
    @test Mexicah.marshaler_for(Vector{Float64}) isa Mexicah.VectorFloat64Marshaler
    @test Mexicah.marshaler_for(Matrix{Float64}) isa Mexicah.MatrixFloat64Marshaler
    @test Mexicah.mx_class_id(Mexicah.DenseArrayMarshaler{Int16, 2}()) == Mexicah.mxINT16_CLASS
end

@testitem "marshaler_for: logical (Bool) arrays" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Vector{Bool}) isa Mexicah.LogicalArrayMarshaler{1}
    @test Mexicah.marshaler_for(Matrix{Bool}) isa Mexicah.LogicalArrayMarshaler{2}
    @test Mexicah.marshaler_for(Array{Bool, 3}) isa Mexicah.LogicalArrayMarshaler{3}
    # Bool scalar keeps its dedicated marshaler
    @test Mexicah.marshaler_for(Bool) isa Mexicah.BoolMarshaler
    @test Mexicah.mx_class_id(Mexicah.LogicalArrayMarshaler{2}()) == Mexicah.mxLOGICAL_CLASS
end

@testitem "marshaler_for: complex matrices / N-D" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Matrix{ComplexF64}) isa Mexicah.ComplexArrayMarshaler{2}
    @test Mexicah.marshaler_for(Array{ComplexF64, 3}) isa Mexicah.ComplexArrayMarshaler{3}
    # Vector{ComplexF64} keeps its dedicated marshaler
    @test Mexicah.marshaler_for(Vector{ComplexF64}) isa Mexicah.ComplexFloat64Marshaler
    @test Mexicah.mx_class_id(Mexicah.ComplexArrayMarshaler{2}()) == Mexicah.mxDOUBLE_CLASS
    # ComplexF32 arrays (single-precision complex)
    @test Mexicah.marshaler_for(Vector{ComplexF32}) isa Mexicah.ComplexF32ArrayMarshaler{1}
    @test Mexicah.marshaler_for(Matrix{ComplexF32}) isa Mexicah.ComplexF32ArrayMarshaler{2}
    @test Mexicah.mx_class_id(Mexicah.ComplexF32ArrayMarshaler{2}()) == Mexicah.mxSINGLE_CLASS
end

@testitem "marshaler_for: cell arrays and string vectors" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Tuple{Float64, Int64}) isa
        Mexicah.CellArrayMarshaler{Tuple{Float64, Int64}}
    @test Mexicah.marshaler_for(Tuple{Float64, String}) isa
        Mexicah.CellArrayMarshaler{Tuple{Float64, String}}
    @test Mexicah.marshaler_for(Vector{String}) isa Mexicah.StringVectorMarshaler
    @test Mexicah.mx_class_id(Mexicah.CellArrayMarshaler{Tuple{Float64, Int64}}()) ==
        Mexicah.mxCELL_CLASS
    @test Mexicah.mx_class_id(Mexicah.StringVectorMarshaler()) == Mexicah.mxCELL_CLASS
    # Matrix{String} → MATLAB string array (distinct from Vector{String} → cell)
    @test Mexicah.marshaler_for(Matrix{String}) isa Mexicah.StringArrayMarshaler
    @test Mexicah.mx_class_id(Mexicah.StringArrayMarshaler()) isa Cint
end

@testitem "marshaler_for: structs and NamedTuples" begin
    using Mexicah, Test
    struct Pt
        x::Float64
        y::Float64
    end
    @test Mexicah.marshaler_for(Pt) isa Mexicah.StructMarshaler{Pt}
    @test Mexicah.marshaler_for(@NamedTuple{a::Float64, n::Int64}) isa
        Mexicah.StructMarshaler
    @test Mexicah.mx_class_id(Mexicah.StructMarshaler{Pt}()) == Mexicah.mxSTRUCT_CLASS
    # Array of structs → N-D MATLAB struct array (one StructArrayMarshaler{T,N});
    # StructVectorMarshaler/StructMatrixMarshaler are aliases for N=1/N=2.
    @test Mexicah.marshaler_for(Vector{Pt}) isa Mexicah.StructVectorMarshaler{Pt}
    @test Mexicah.marshaler_for(Vector{Pt}) isa Mexicah.StructArrayMarshaler{Pt, 1}
    @test Mexicah.marshaler_for(Matrix{Pt}) isa Mexicah.StructMatrixMarshaler{Pt}
    @test Mexicah.marshaler_for(Matrix{Pt}) isa Mexicah.StructArrayMarshaler{Pt, 2}
    @test Mexicah.marshaler_for(Array{Pt, 3}) isa Mexicah.StructArrayMarshaler{Pt, 3}
    @test Mexicah.mx_class_id(Mexicah.StructArrayMarshaler{Pt, 3}()) == Mexicah.mxSTRUCT_CLASS
    # Not struct-marshaled: Complex scalar (a Number) is excluded;
    # Tuple now routes to CellArrayMarshaler (no longer an error here).
    @test_throws ErrorException Mexicah.marshaler_for(ComplexF64)
end

@testitem "marshaler_for: Matrix{Char} char matrix" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(Matrix{Char}) isa Mexicah.CharMatrixMarshaler
    @test Mexicah.mx_class_id(Mexicah.CharMatrixMarshaler()) == Mexicah.mxCHAR_CLASS
end

# ── Tests requiring MATLAB API symbols in the process ─────────────────────────
# Tagged :matlab — skipped automatically when MATLAB is not loaded.

@testitem "Float64Marshaler scalar round-trip" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.Float64Marshaler()
    pa = Mexicah.mx_create_double_scalar(Cdouble(3.14))
    @test pa != C_NULL
    v = Mexicah.load(m, pa)
    @test v isa Float64
    @test v ≈ 3.14
    Mexicah.mx_destroy_array(pa)
end

@testitem "VectorFloat64Marshaler zero-copy load" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.VectorFloat64Marshaler()
    pa = Mexicah.mx_create_double_matrix(Csize_t(4), Csize_t(1), Mexicah.mxREAL)
    ptr = Mexicah.mx_get_pr(pa)
    for i in 1:4
        unsafe_store!(ptr, Float64(i * 10), i)
    end
    v = Mexicah.load(m, pa)
    @test v isa Vector{Float64}
    @test length(v) == 4
    @test v == [10.0, 20.0, 30.0, 40.0]
    v[1] = 99.0
    @test unsafe_load(ptr, 1) == 99.0
    Mexicah.mx_destroy_array(pa)
end

@testitem "VectorFloat64Marshaler store! round-trip" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.VectorFloat64Marshaler()
    src = [1.1, 2.2, 3.3]
    pa = Mexicah.create(m, (3,))
    Mexicah.store!(m, pa, src)
    @test Mexicah.load(m, pa) ≈ src
    Mexicah.mx_destroy_array(pa)
end

@testitem "MatrixFloat64Marshaler zero-copy load is column-major" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.MatrixFloat64Marshaler()
    pa = Mexicah.mx_create_double_matrix(Csize_t(2), Csize_t(3), Mexicah.mxREAL)
    ptr = Mexicah.mx_get_pr(pa)
    for i in 1:6
        unsafe_store!(ptr, Float64(i), i)
    end
    A = Mexicah.load(m, pa)
    @test size(A) == (2, 3)
    @test A[:, 1] == [1.0, 2.0]
    @test A[:, 2] == [3.0, 4.0]
    Mexicah.mx_destroy_array(pa)
end

@testitem "BoolMarshaler round-trip" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.BoolMarshaler()
    for val in (true, false)
        pa = Mexicah.create(m, Dims{0}(()))
        Mexicah.store!(m, pa, val)
        @test Mexicah.load(m, pa) === val
        Mexicah.mx_destroy_array(pa)
    end
end

@testitem "StructMatrixMarshaler 2×3 round-trip" tags = [:matlab] begin
    using Mexicah, Test
    struct GridPt
        x::Float64
        y::Float64
    end
    m = Mexicah.StructMatrixMarshaler{GridPt}()
    src = [GridPt(Float64(i + j), Float64(i * j)) for i in 1:2, j in 1:3]
    pa = Mexicah.create(m, (2, 3))
    Mexicah.store!(m, pa, src)
    got = Mexicah.load(m, pa)
    @test size(got) == (2, 3)
    @test all(got[i, j] == src[i, j] for i in 1:2, j in 1:3)
    Mexicah.mx_destroy_array(pa)
end

@testitem "CharMatrixMarshaler round-trip" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.CharMatrixMarshaler()
    src = ['A' 'B' 'C'; 'D' 'E' 'F']   # 2×3 Matrix{Char}
    pa = Mexicah.create(m, (2, 3))
    Mexicah.store!(m, pa, src)
    got = Mexicah.load(m, pa)
    @test size(got) == (2, 3)
    @test got == src
    Mexicah.mx_destroy_array(pa)
end

@testitem "StructArrayMarshaler 2×2×2 (3-D) round-trip" tags = [:matlab] begin
    using Mexicah, Test
    struct Cell3
        a::Float64
        b::Int64
    end
    m = Mexicah.StructArrayMarshaler{Cell3, 3}()
    src = [Cell3(Float64(i + 10j + 100k), i * j * k) for i in 1:2, j in 1:2, k in 1:2]
    pa = Mexicah.create(m, (2, 2, 2))
    Mexicah.store!(m, pa, src)
    got = Mexicah.load(m, pa)
    @test size(got) == (2, 2, 2)
    @test all(got[idx] == src[idx] for idx in eachindex(src))
    Mexicah.mx_destroy_array(pa)
end

@testitem "StringArrayMarshaler (Matrix{String}) round-trip" tags = [:matlab] begin
    using Mexicah, Test
    src = ["a" "bb"; "ccc" "d"]   # 2×2 Matrix{String}
    # Output goes through the store_result(::Matrix{String}) override (string array
    # built via mexCallMATLAB("string")); load reads it back via "cellstr".
    slot = Ref{Mexicah.MxArray}(C_NULL)
    GC.@preserve slot begin
        Mexicah.store_result(Base.unsafe_convert(Ptr{Mexicah.MxArray}, slot), 1, src)
        got = Mexicah.load(Mexicah.StringArrayMarshaler(), slot[])
        @test size(got) == (2, 2)
        @test got == src
    end
end

# ── Temporary-cleanup discipline guard (NOT a real-MATLAB leak detector) ───────
# The libmx stub counts live mx_stub_t arrays via mx_stub_live_count(). The stub does
# NOT emulate MATLAB's auto-free of temporaries at MEX return, so it is intentionally
# stricter than MATLAB: a round trip (incl. the throwing path) must net back to the
# starting count, which catches a marshaler that orphans a temporary without destroying
# it. In real MATLAB such a temporary is reclaimed at return — explicit cleanup is
# peak-memory/robustness hygiene, not a leak fix (see CLAUDE.md Memory-safety section).
@testitem "leak-regression: store_result frees intermediates on success + error" tags = [:matlab] begin
    using Mexicah, Test

    # `_LeakS` has a Vector field (so an intermediate child mxArray is created and
    # attached) followed by a String field carrying an embedded NUL, which makes
    # mx_create_string's Cstring conversion throw *after* the parent struct + the
    # vector child are allocated — the canonical mid-store! throw shape.
    struct _LeakS
        v::Vector{Float64}
        s::String
    end

    live() = ccall(:mx_stub_live_count, Clong, ())

    # Sanity: the counter is wired up (a create+destroy nets to baseline).
    base = live()
    pa = Mexicah.mx_create_double_matrix(Csize_t(3), Csize_t(1), Mexicah.mxREAL)
    @test live() == base + 1
    Mexicah.mx_destroy_array(pa)
    @test live() == base

    # 1. Clean Matrix{String} round trip nets to baseline (load + store_result both
    #    own a mexCallMATLAB array now destroyed promptly; under this strict stub it
    #    showed as a non-zero net before the guard — in MATLAB it freed at return).
    base = live()
    slot = Ref{Mexicah.MxArray}(C_NULL)
    GC.@preserve slot begin
        src = ["a" "bb"; "ccc" "d"]
        Mexicah.store_result(Base.unsafe_convert(Ptr{Mexicah.MxArray}, slot), 1, src)
        got = Mexicah.load(Mexicah.StringArrayMarshaler(), slot[])
        @test got == src
        Mexicah.mx_destroy_array(slot[])   # the plhs output is the caller's to free here
    end
    @test live() == base

    # 2. Throwing path: store_result on a struct whose String field has an embedded
    #    NUL throws inside the nested mx_create_string AFTER the parent struct and the
    #    Vector child are allocated. The try/finally guard must destroy the parent
    #    (recursively freeing the attached child) so the count returns to baseline.
    base = live()
    slot2 = Ref{Mexicah.MxArray}(C_NULL)
    GC.@preserve slot2 begin
        bad = _LeakS([1.0, 2.0, 3.0], "embedded\0nul")
        @test_throws ArgumentError Mexicah.store_result(
            Base.unsafe_convert(Ptr{Mexicah.MxArray}, slot2), 1, bad,
        )
    end
    @test live() == base   # no orphaned struct/vector intermediate

    # 3. Clean cell-array (Tuple) round trip nets to baseline — exercises the
    #    per-element guard's SUCCESS path (the "disarm"/ownership-transfer move):
    #    each child must be handed to the cell exactly once, no double-free, no leak.
    base = live()
    slot3 = Ref{Mexicah.MxArray}(C_NULL)
    GC.@preserve slot3 begin
        tup = ([4.0, 5.0], Int32(7))
        Mexicah.store_result(Base.unsafe_convert(Ptr{Mexicah.MxArray}, slot3), 1, tup)
        @test slot3[] != C_NULL
        Mexicah.mx_destroy_array(slot3[])
    end
    @test live() == base

    # 4. Throwing path through a struct ARRAY (per-element field guard): the Vector
    #    field is created + attached, then the String-with-NUL field throws.
    base = live()
    slot4 = Ref{Mexicah.MxArray}(C_NULL)
    GC.@preserve slot4 begin
        badarr = [_LeakS([1.0], "ok"), _LeakS([2.0, 3.0], "bad\0here")]
        @test_throws ArgumentError Mexicah.store_result(
            Base.unsafe_convert(Ptr{Mexicah.MxArray}, slot4), 1, badarr,
        )
    end
    @test live() == base
end
