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
