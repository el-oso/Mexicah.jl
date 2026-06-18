using SparseArrays: SparseMatrixCSC

# Each marshaler is a zero-size struct implementing AbstractMexMarshaler.
# load()  — wraps the mxArray data pointer directly (zero-copy for arrays).
# store!() — writes a Julia value into a caller-allocated mxArray buffer.
# create() — allocates a new mxArray of the right class and shape.
#
# All store! methods accept ::Any as the third argument so that hasmethod
# succeeds for the AbstractMexMarshaler contract (which uses ::Any to allow
# any marshaler value type). The internal convert/unsafe_store! remains
# type-safe because the callers always dispatch with a concrete type.
#
# All create() methods accept ::Tuple so that hasmethod succeeds for the
# contract (Dims{N} <: Tuple for all N). Each method pattern-matches the
# tuple at runtime.

# ── Float64 scalar ────────────────────────────────────────────────────────────

struct Float64Marshaler end

load(::Float64Marshaler, pa::MxArray)::Float64 = Float64(mx_get_scalar(pa))

function store!(::Float64Marshaler, pa::MxArray, v::Any)::Cvoid
    ptr = mx_get_pr(pa)
    unsafe_store!(ptr, convert(Cdouble, v))
    return
end

create(::Float64Marshaler, ::Tuple)::MxArray = mx_create_double_scalar(Cdouble(0.0))

mx_class_id(::Float64Marshaler)::Cint = mxDOUBLE_CLASS

# ── Vector{Float64} ───────────────────────────────────────────────────────────

struct VectorFloat64Marshaler end

function load(::VectorFloat64Marshaler, pa::MxArray)::Vector{Float64}
    ptr = mx_get_pr(pa)
    n = Int(mx_get_number_of_elements(pa))
    return unsafe_wrap(Array, ptr, n; own = false)
end

function store!(::VectorFloat64Marshaler, pa::MxArray, v::Any)::Cvoid
    vec = v::Vector{Float64}
    ptr = mx_get_pr(pa)
    GC.@preserve vec unsafe_copyto!(ptr, pointer(vec), length(vec))
    return
end

function create(::VectorFloat64Marshaler, dims::Tuple)::MxArray
    n = dims[1]::Int
    return mx_create_double_matrix(Csize_t(n), Csize_t(1), mxREAL)
end

mx_class_id(::VectorFloat64Marshaler)::Cint = mxDOUBLE_CLASS

# ── Matrix{Float64} ───────────────────────────────────────────────────────────

struct MatrixFloat64Marshaler end

function load(::MatrixFloat64Marshaler, pa::MxArray)::Matrix{Float64}
    ptr = mx_get_pr(pa)
    m = Int(mx_get_m(pa))
    n = Int(mx_get_n(pa))
    return unsafe_wrap(Array, ptr, (m, n); own = false)
end

function store!(::MatrixFloat64Marshaler, pa::MxArray, v::Any)::Cvoid
    mat = v::Matrix{Float64}
    ptr = mx_get_pr(pa)
    GC.@preserve mat unsafe_copyto!(ptr, pointer(mat), length(mat))
    return
end

function create(::MatrixFloat64Marshaler, dims::Tuple)::MxArray
    m = dims[1]::Int
    n = dims[2]::Int
    return mx_create_double_matrix(Csize_t(m), Csize_t(n), mxREAL)
end

mx_class_id(::MatrixFloat64Marshaler)::Cint = mxDOUBLE_CLASS

# ── Int32 scalar ──────────────────────────────────────────────────────────────

struct Int32Marshaler end

load(::Int32Marshaler, pa::MxArray)::Int32 = Int32(mx_get_scalar(pa))

function store!(::Int32Marshaler, pa::MxArray, v::Any)::Cvoid
    ptr = Ptr{Int32}(mx_get_data(pa))
    unsafe_store!(ptr, convert(Int32, v))
    return
end

function create(::Int32Marshaler, ::Tuple)::MxArray
    return mx_create_numeric_matrix(Csize_t(1), Csize_t(1), mxINT32_CLASS, mxREAL)
end

mx_class_id(::Int32Marshaler)::Cint = mxINT32_CLASS

# ── Int64 scalar ──────────────────────────────────────────────────────────────

struct Int64Marshaler end

load(::Int64Marshaler, pa::MxArray)::Int64 = Int64(mx_get_scalar(pa))

function store!(::Int64Marshaler, pa::MxArray, v::Any)::Cvoid
    ptr = Ptr{Int64}(mx_get_data(pa))
    unsafe_store!(ptr, convert(Int64, v))
    return
end

function create(::Int64Marshaler, ::Tuple)::MxArray
    return mx_create_numeric_matrix(Csize_t(1), Csize_t(1), mxINT64_CLASS, mxREAL)
end

mx_class_id(::Int64Marshaler)::Cint = mxINT64_CLASS

# ── Bool scalar ───────────────────────────────────────────────────────────────

struct BoolMarshaler end

function load(::BoolMarshaler, pa::MxArray)::Bool
    ptr = mx_get_logicals(pa)
    return unsafe_load(ptr) != 0x00
end

function store!(::BoolMarshaler, pa::MxArray, v::Any)::Cvoid
    ptr = mx_get_logicals(pa)
    unsafe_store!(ptr, convert(Bool, v) ? Cuchar(1) : Cuchar(0))
    return
end

create(::BoolMarshaler, ::Tuple)::MxArray = mx_create_logical_array(Csize_t(1), Csize_t(1))

mx_class_id(::BoolMarshaler)::Cint = mxLOGICAL_CLASS

# ── SparseMatrixCSC{Float64, Int} ─────────────────────────────────────────────

struct SparseFloat64Marshaler end

function load(::SparseFloat64Marshaler, pa::MxArray)::SparseMatrixCSC{Float64, Int}
    m = Int(mx_get_m(pa))
    n = Int(mx_get_n(pa))
    nzmax = Int(mx_get_nzmax(pa))
    ir_ptr = mx_get_ir(pa)
    jc_ptr = mx_get_jc(pa)
    pr_ptr = mx_get_pr(pa)
    # Zero-copy wrap; convert 0-based → 1-based indices
    ir_raw = unsafe_wrap(Array, ir_ptr, nzmax; own = false)
    jc_raw = unsafe_wrap(Array, jc_ptr, n + 1; own = false)
    pr = unsafe_wrap(Array, pr_ptr, nzmax; own = false)
    rowval = Int.(ir_raw) .+ 1
    colptr = Int.(jc_raw) .+ 1
    return SparseMatrixCSC{Float64, Int}(m, n, colptr, rowval, copy(pr))
end

function store!(::SparseFloat64Marshaler, pa::MxArray, v::Any)::Cvoid
    s = v::SparseMatrixCSC{Float64}
    nz = nnz(s)
    ir_ptr = mx_get_ir(pa)
    jc_ptr = mx_get_jc(pa)
    pr_ptr = mx_get_pr(pa)
    GC.@preserve s begin
        for i in 1:nz
            unsafe_store!(ir_ptr, Csize_t(s.rowval[i] - 1), i)
        end
        for j in eachindex(s.colptr)
            unsafe_store!(jc_ptr, Csize_t(s.colptr[j] - 1), j)
        end
        unsafe_copyto!(pr_ptr, pointer(s.nzval), nz)
    end
    return
end

function create(::SparseFloat64Marshaler, dims::Tuple)::MxArray
    m = dims[1]::Int
    n = dims[2]::Int
    return mx_create_sparse(Csize_t(m), Csize_t(n), Csize_t(0), mxREAL)
end

mx_class_id(::SparseFloat64Marshaler)::Cint = mxDOUBLE_CLASS

# ── SparseMatrixCSC{ComplexF64, Int} ─────────────────────────────────────────

struct SparseComplexF64Marshaler end

function load(::SparseComplexF64Marshaler, pa::MxArray)::SparseMatrixCSC{ComplexF64, Int}
    m = Int(mx_get_m(pa))
    n = Int(mx_get_n(pa))
    nzmax = Int(mx_get_nzmax(pa))
    ir_ptr = mx_get_ir(pa)
    jc_ptr = mx_get_jc(pa)
    pr_ptr = mx_get_pr(pa)
    pi_ptr = mx_get_pi(pa)
    ir_raw = unsafe_wrap(Array, ir_ptr, nzmax; own = false)
    jc_raw = unsafe_wrap(Array, jc_ptr, n + 1; own = false)
    pr = unsafe_wrap(Array, pr_ptr, nzmax; own = false)
    pim = pi_ptr == C_NULL ? zeros(Float64, nzmax) : unsafe_wrap(Array, pi_ptr, nzmax; own = false)
    rowval = Int.(ir_raw) .+ 1
    colptr = Int.(jc_raw) .+ 1
    nzval = complex.(pr, pim)
    return SparseMatrixCSC{ComplexF64, Int}(m, n, colptr, rowval, copy(nzval))
end

function store!(::SparseComplexF64Marshaler, pa::MxArray, v::Any)::Cvoid
    s = v::SparseMatrixCSC{ComplexF64}
    nz = nnz(s)
    ir_ptr = mx_get_ir(pa)
    jc_ptr = mx_get_jc(pa)
    pr_ptr = mx_get_pr(pa)
    pi_ptr = mx_get_pi(pa)
    GC.@preserve s begin
        for i in 1:nz
            unsafe_store!(ir_ptr, Csize_t(s.rowval[i] - 1), i)
        end
        for j in eachindex(s.colptr)
            unsafe_store!(jc_ptr, Csize_t(s.colptr[j] - 1), j)
        end
        for i in 1:nz
            unsafe_store!(pr_ptr, real(s.nzval[i]), i)
            unsafe_store!(pi_ptr, imag(s.nzval[i]), i)
        end
    end
    return
end

function create(::SparseComplexF64Marshaler, dims::Tuple)::MxArray
    m = dims[1]::Int
    n = dims[2]::Int
    return mx_create_sparse(Csize_t(m), Csize_t(n), Csize_t(0), mxCOMPLEX)
end

mx_class_id(::SparseComplexF64Marshaler)::Cint = mxDOUBLE_CLASS

# ── SparseMatrixCSC{Bool, Int} ────────────────────────────────────────────────

struct SparseLogicalMarshaler end

function load(::SparseLogicalMarshaler, pa::MxArray)::SparseMatrixCSC{Bool, Int}
    m = Int(mx_get_m(pa))
    n = Int(mx_get_n(pa))
    nzmax = Int(mx_get_nzmax(pa))
    ir_ptr = mx_get_ir(pa)
    jc_ptr = mx_get_jc(pa)
    data_ptr = Ptr{Cuchar}(mx_get_data(pa))
    ir_raw = unsafe_wrap(Array, ir_ptr, nzmax; own = false)
    jc_raw = unsafe_wrap(Array, jc_ptr, n + 1; own = false)
    rowval = Int.(ir_raw) .+ 1
    colptr = Int.(jc_raw) .+ 1
    nzval = [unsafe_load(data_ptr, i) != 0x00 for i in 1:nzmax]
    return SparseMatrixCSC{Bool, Int}(m, n, colptr, rowval, nzval)
end

function store!(::SparseLogicalMarshaler, pa::MxArray, v::Any)::Cvoid
    s = v::SparseMatrixCSC{Bool}
    nz = nnz(s)
    ir_ptr = mx_get_ir(pa)
    jc_ptr = mx_get_jc(pa)
    data_ptr = Ptr{Cuchar}(mx_get_data(pa))
    GC.@preserve s begin
        for i in 1:nz
            unsafe_store!(ir_ptr, Csize_t(s.rowval[i] - 1), i)
        end
        for j in eachindex(s.colptr)
            unsafe_store!(jc_ptr, Csize_t(s.colptr[j] - 1), j)
        end
        for i in 1:nz
            unsafe_store!(data_ptr, s.nzval[i] ? Cuchar(1) : Cuchar(0), i)
        end
    end
    return
end

function create(::SparseLogicalMarshaler, dims::Tuple)::MxArray
    m = dims[1]::Int
    n = dims[2]::Int
    return mx_create_sparse_logical(Csize_t(m), Csize_t(n), Csize_t(0))
end

mx_class_id(::SparseLogicalMarshaler)::Cint = mxLOGICAL_CLASS

# ── Complex{Float64} (interleaved, R2018a+) ───────────────────────────────────

struct ComplexFloat64Marshaler end

# The cc gateway is a legacy MEX, so MATLAB presents complex arrays in split
# real/imaginary storage (mxGetPr/mxGetPi). The interleaved mxGetComplexDoubles
# (R2018a) is not available to a legacy MEX — declaring that API needs MATLAB's
# headers at build time, which Mexicah deliberately avoids.
function load(::ComplexFloat64Marshaler, pa::MxArray)::Vector{ComplexF64}
    n = Int(mx_get_number_of_elements(pa))
    pr = mx_get_pr(pa)
    pim = mx_get_pi(pa)
    out = Vector{ComplexF64}(undef, n)
    @inbounds for k in 1:n
        im = pim == C_NULL ? 0.0 : unsafe_load(pim, k)
        out[k] = complex(unsafe_load(pr, k), im)
    end
    return out
end

function store!(::ComplexFloat64Marshaler, pa::MxArray, v::Any)::Cvoid
    vec = v::Vector{ComplexF64}
    pr = mx_get_pr(pa)
    pim = mx_get_pi(pa)
    @inbounds for k in eachindex(vec)
        unsafe_store!(pr, real(vec[k]), k)
        unsafe_store!(pim, imag(vec[k]), k)
    end
    return
end

function create(::ComplexFloat64Marshaler, dims::Tuple)::MxArray
    n = dims[1]::Int
    return mx_create_double_matrix(Csize_t(n), Csize_t(1), mxCOMPLEX)
end

mx_class_id(::ComplexFloat64Marshaler)::Cint = mxDOUBLE_CLASS

# ── UInt64 scalar (opaque handle IDs) ────────────────────────────────────────
# MATLAB uint64 preserves the full 64-bit range; mxGetScalar would truncate
# IDs above 2^53 via double conversion, so we read raw bytes via mx_get_data.

struct UInt64Marshaler end

function load(::UInt64Marshaler, pa::MxArray)::UInt64
    return unsafe_load(Ptr{UInt64}(mx_get_data(pa)))
end

function store!(::UInt64Marshaler, pa::MxArray, v::Any)::Cvoid
    ptr = Ptr{UInt64}(mx_get_data(pa))
    unsafe_store!(ptr, convert(UInt64, v))
    return
end

function create(::UInt64Marshaler, ::Tuple)::MxArray
    return mx_create_numeric_matrix(Csize_t(1), Csize_t(1), mxUINT64_CLASS, mxREAL)
end

mx_class_id(::UInt64Marshaler)::Cint = mxUINT64_CLASS

# ── String (mxCHAR) ──────────────────────────────────────────────────────────
# mx_create_string allocates and fills the char array in one call, so the
# create+store! pattern does not apply for output. store_result(String) below
# is overridden to call mx_create_string directly.

struct StringMarshaler end

load(::StringMarshaler, pa::MxArray)::String = mx_get_string(pa)

store!(::StringMarshaler, pa::MxArray, v::Any)::Cvoid = nothing

create(::StringMarshaler, ::Tuple)::MxArray = mx_create_string("")

mx_class_id(::StringMarshaler)::Cint = mxCHAR_CLASS

# ── Real numeric element type → mxClassID ─────────────────────────────────────
# One method per supported bitstype; the absence of a fallback is intentional, so
# an unsupported element type is a method error caught by marshaler_for.

_mx_class_for(::Type{Float64})::Cint = mxDOUBLE_CLASS
_mx_class_for(::Type{Float32})::Cint = mxSINGLE_CLASS
_mx_class_for(::Type{Int8})::Cint = mxINT8_CLASS
_mx_class_for(::Type{Int16})::Cint = mxINT16_CLASS
_mx_class_for(::Type{Int32})::Cint = mxINT32_CLASS
_mx_class_for(::Type{Int64})::Cint = mxINT64_CLASS
_mx_class_for(::Type{UInt8})::Cint = mxUINT8_CLASS
_mx_class_for(::Type{UInt16})::Cint = mxUINT16_CLASS
_mx_class_for(::Type{UInt32})::Cint = mxUINT32_CLASS
_mx_class_for(::Type{UInt64})::Cint = mxUINT64_CLASS

# Read the array extents as an N-tuple of Int. A Julia Vector (N==1) maps to a
# MATLAB n×1 column, so its length is the element count; for N≥2 read the first
# N MATLAB dimensions (mxGetDimensions).
function _load_dims(pa::MxArray, ::Val{N})::NTuple{N, Int} where {N}
    if N == 1
        return (Int(mx_get_number_of_elements(pa)),)
    else
        nd = Int(mx_get_number_of_dimensions(pa))
        # Guard the unsafe_load below: reading more extents than MATLAB reports
        # would run past the mxGetDimensions buffer.
        nd == N || error("Mexicah: expected a $(N)-D array argument, got $(nd)-D")
        dptr = mx_get_dimensions(pa)
        return ntuple(i -> Int(unsafe_load(dptr, i)), Val(N))
    end
end

# ── Additional real numeric scalars (Float32, Int8/16, UInt8/16/32) ───────────
# Generated to match the Int32/Int64 pattern: read/write the raw element via
# mxGetData, allocate a 1×1 numeric matrix of the right class.

for (Tname, cls) in (
        (:Float32, mxSINGLE_CLASS),
        (:Int8, mxINT8_CLASS),
        (:Int16, mxINT16_CLASS),
        (:UInt8, mxUINT8_CLASS),
        (:UInt16, mxUINT16_CLASS),
        (:UInt32, mxUINT32_CLASS),
    )
    T = getfield(Base, Tname)
    Mname = Symbol(Tname, :Marshaler)
    @eval begin
        struct $Mname end
        load(::$Mname, pa::MxArray)::$T = unsafe_load(Ptr{$T}(mx_get_data(pa)))
        function store!(::$Mname, pa::MxArray, v::Any)::Cvoid
            unsafe_store!(Ptr{$T}(mx_get_data(pa)), convert($T, v))
            return
        end
        create(::$Mname, ::Tuple)::MxArray =
            mx_create_numeric_matrix(Csize_t(1), Csize_t(1), $cls, mxREAL)
        mx_class_id(::$Mname)::Cint = $cls
    end
end

# ── Dense real numeric arrays of any element type and rank ────────────────────
# Float64 Vector/Matrix keep their dedicated marshalers (above); this covers
# every other element type and rank N (including Float64 with N ≥ 3).

struct DenseArrayMarshaler{T, N} end

function load(::DenseArrayMarshaler{T, N}, pa::MxArray)::Array{T, N} where {T, N}
    ptr = Ptr{T}(mx_get_data(pa))
    return unsafe_wrap(Array, ptr, _load_dims(pa, Val(N)); own = false)
end

function store!(::DenseArrayMarshaler{T, N}, pa::MxArray, v::Any)::Cvoid where {T, N}
    arr = v::Array{T, N}
    ptr = Ptr{T}(mx_get_data(pa))
    GC.@preserve arr unsafe_copyto!(ptr, pointer(arr), length(arr))
    return
end

function create(::DenseArrayMarshaler{T, N}, dims::Tuple)::MxArray where {T, N}
    cls = _mx_class_for(T)
    if N == 1
        return mx_create_numeric_matrix(Csize_t(dims[1]::Int), Csize_t(1), cls, mxREAL)
    elseif N == 2
        return mx_create_numeric_matrix(Csize_t(dims[1]::Int), Csize_t(dims[2]::Int), cls, mxREAL)
    else
        d = Csize_t[Csize_t(x) for x in dims]
        GC.@preserve d begin
            return mx_create_numeric_array(Csize_t(N), pointer(d), cls, mxREAL)
        end
    end
end

function mx_class_id(::DenseArrayMarshaler{T, N})::Cint where {T, N}
    return _mx_class_for(T)
end

# ── Complex arrays (Matrix / N-D), split Pr/Pi like the Vector marshaler ──────

struct ComplexArrayMarshaler{N} end

function load(::ComplexArrayMarshaler{N}, pa::MxArray)::Array{ComplexF64, N} where {N}
    dims = _load_dims(pa, Val(N))
    pr = mx_get_pr(pa)
    pim = mx_get_pi(pa)
    out = Array{ComplexF64, N}(undef, dims)
    @inbounds for k in 1:length(out)
        im = pim == C_NULL ? 0.0 : unsafe_load(pim, k)
        out[k] = complex(unsafe_load(pr, k), im)
    end
    return out
end

function store!(::ComplexArrayMarshaler{N}, pa::MxArray, v::Any)::Cvoid where {N}
    arr = v::Array{ComplexF64, N}
    pr = mx_get_pr(pa)
    pim = mx_get_pi(pa)
    @inbounds for k in eachindex(arr)
        unsafe_store!(pr, real(arr[k]), k)
        unsafe_store!(pim, imag(arr[k]), k)
    end
    return
end

function create(::ComplexArrayMarshaler{N}, dims::Tuple)::MxArray where {N}
    if N == 1
        return mx_create_double_matrix(Csize_t(dims[1]::Int), Csize_t(1), mxCOMPLEX)
    elseif N == 2
        return mx_create_double_matrix(Csize_t(dims[1]::Int), Csize_t(dims[2]::Int), mxCOMPLEX)
    else
        d = Csize_t[Csize_t(x) for x in dims]
        GC.@preserve d begin
            return mx_create_numeric_array(Csize_t(N), pointer(d), mxDOUBLE_CLASS, mxCOMPLEX)
        end
    end
end

mx_class_id(::ComplexArrayMarshaler)::Cint = mxDOUBLE_CLASS

# ── Single-precision complex arrays (ComplexF32), any rank ────────────────────
# Same split real/imag scheme, but the real/imag buffers are Float32 — reached
# via mxGetData / mxGetImagData (the class-agnostic accessors) rather than the
# double-typed mxGetPr/mxGetPi.

struct ComplexF32ArrayMarshaler{N} end

function load(::ComplexF32ArrayMarshaler{N}, pa::MxArray)::Array{ComplexF32, N} where {N}
    dims = _load_dims(pa, Val(N))
    pr = Ptr{Float32}(mx_get_data(pa))
    pim = Ptr{Float32}(mx_get_imag_data(pa))
    out = Array{ComplexF32, N}(undef, dims)
    @inbounds for k in 1:length(out)
        im = pim == C_NULL ? 0.0f0 : unsafe_load(pim, k)
        out[k] = complex(unsafe_load(pr, k), im)
    end
    return out
end

function store!(::ComplexF32ArrayMarshaler{N}, pa::MxArray, v::Any)::Cvoid where {N}
    arr = v::Array{ComplexF32, N}
    pr = Ptr{Float32}(mx_get_data(pa))
    pim = Ptr{Float32}(mx_get_imag_data(pa))
    @inbounds for k in eachindex(arr)
        unsafe_store!(pr, real(arr[k]), k)
        unsafe_store!(pim, imag(arr[k]), k)
    end
    return
end

function create(::ComplexF32ArrayMarshaler{N}, dims::Tuple)::MxArray where {N}
    if N == 1
        return mx_create_numeric_matrix(Csize_t(dims[1]::Int), Csize_t(1), mxSINGLE_CLASS, mxCOMPLEX)
    elseif N == 2
        return mx_create_numeric_matrix(Csize_t(dims[1]::Int), Csize_t(dims[2]::Int), mxSINGLE_CLASS, mxCOMPLEX)
    else
        d = Csize_t[Csize_t(x) for x in dims]
        GC.@preserve d begin
            return mx_create_numeric_array(Csize_t(N), pointer(d), mxSINGLE_CLASS, mxCOMPLEX)
        end
    end
end

mx_class_id(::ComplexF32ArrayMarshaler)::Cint = mxSINGLE_CLASS

# ── Logical (Bool) arrays, any rank ───────────────────────────────────────────
# MATLAB logical storage is one byte per element (0/1), matching Julia `Bool`, so
# load is zero-copy. (Bool *scalars* keep `BoolMarshaler`; numeric `Array{T,N}`
# can't carry Bool because mxCreateNumericMatrix rejects the logical class.)

struct LogicalArrayMarshaler{N} end

function load(::LogicalArrayMarshaler{N}, pa::MxArray)::Array{Bool, N} where {N}
    ptr = Ptr{Bool}(mx_get_logicals(pa))
    return unsafe_wrap(Array, ptr, _load_dims(pa, Val(N)); own = false)
end

function store!(::LogicalArrayMarshaler{N}, pa::MxArray, v::Any)::Cvoid where {N}
    arr = v::Array{Bool, N}
    ptr = Ptr{Bool}(mx_get_logicals(pa))
    GC.@preserve arr unsafe_copyto!(ptr, pointer(arr), length(arr))
    return
end

function create(::LogicalArrayMarshaler{N}, dims::Tuple)::MxArray where {N}
    if N == 1
        return mx_create_logical_array(Csize_t(dims[1]::Int), Csize_t(1))
    elseif N == 2
        return mx_create_logical_array(Csize_t(dims[1]::Int), Csize_t(dims[2]::Int))
    else
        d = Csize_t[Csize_t(x) for x in dims]
        GC.@preserve d begin
            return mx_create_logical_nd(Csize_t(N), pointer(d))
        end
    end
end

mx_class_id(::LogicalArrayMarshaler)::Cint = mxLOGICAL_CLASS

# ── Struct / NamedTuple ↔ MATLAB 1×1 struct ───────────────────────────────────
# A flat Julia struct (or NamedTuple) maps to a scalar MATLAB struct, one field
# per Julia field. The load/store!/create methods are @generated so the field
# list is unrolled at compile time (fieldnames/fieldtype reflection happens during
# code generation, never at runtime) — required for juliac --trim=safe. Each field
# recurses through marshaler_for, so fields may themselves be scalars, arrays, or
# nested structs. String fields go through mx_create_string directly (the String
# marshaler has no create+store! form).

struct StructMarshaler{T} end

@generated function load(::StructMarshaler{T}, pa::MxArray)::T where {T}
    vals = [
        let m = marshaler_for(fieldtype(T, i)), MT = typeof(m)
                :(load($MT(), mx_get_field(pa, Csize_t(0), $(string(fieldname(T, i))))))
        end
            for i in 1:fieldcount(T)
    ]
    return T <: NamedTuple ? :($T(($(vals...),))) : :($T($(vals...)))
end

@generated function store!(::StructMarshaler{T}, pa::MxArray, v::Any)::Cvoid where {T}
    stmts = Any[:(s = v::$T)]
    for i in 1:fieldcount(T)
        FT = fieldtype(T, i)
        FM = typeof(marshaler_for(FT))
        nm = string(fieldname(T, i))
        if FT === String
            push!(stmts, :(mx_set_field!(pa, Csize_t(0), $nm, mx_create_string(getfield(s, $i)))))
        else
            push!(
                stmts,
                quote
                    let fv = getfield(s, $i)
                        fdims = fv isa AbstractArray ? size(fv) : ()
                        fpa = create($FM(), fdims)
                        # mx_set_field! transfers ownership of fpa to the parent. Until
                        # then fpa is orphaned, so a throw from store! would leak it.
                        attached = false
                        try
                            store!($FM(), fpa, fv)
                            mx_set_field!(pa, Csize_t(0), $nm, fpa)
                            attached = true
                        finally
                            attached || mx_destroy_array(fpa)
                        end
                    end
                end,
            )
        end
    end
    push!(stmts, :(return nothing))
    return Expr(:block, stmts...)
end

@generated function create(::StructMarshaler{T}, ::Tuple)::MxArray where {T}
    names = String[string(fieldname(T, i)) for i in 1:fieldcount(T)]
    return :(mx_create_struct_matrix(Csize_t(1), Csize_t(1), $names))
end

mx_class_id(::StructMarshaler)::Cint = mxSTRUCT_CLASS

# A concrete fixture so the contract + trim-compat check can be verified on a
# real instantiation of the @generated methods (see contracts.jl).
struct _StructProbe
    x::Float64
    n::Int64
    v::Vector{Float64}
end

# ── Array of structs ↔ MATLAB N-D struct array ────────────────────────────────
# One marshaler for every rank (paralleling DenseArrayMarshaler{T,N}). MATLAB
# struct arrays use the same column-major linear element order as Julia, so the
# per-element field copy via mx_get_field / mx_set_field with a linear index is
# rank-independent. Only `create` varies by rank (N×1 column, M×N matrix, or
# N-D array) and `load` reads the dims back via _load_dims. Field marshalers are
# resolved at code-gen time (static dispatch); String fields are special-cased.

struct StructArrayMarshaler{T, N} end

# Backward-compatible names: N=1 column vector, N=2 matrix.
const StructVectorMarshaler{T} = StructArrayMarshaler{T, 1}
const StructMatrixMarshaler{T} = StructArrayMarshaler{T, 2}

@generated function load(::StructArrayMarshaler{T, N}, pa::MxArray)::Array{T, N} where {T, N}
    reads = [
        let m = marshaler_for(fieldtype(T, k)), MT = typeof(m)
                :(load($MT(), mx_get_field(pa, Csize_t(idx - 1), $(string(fieldname(T, k))))))
        end
            for k in 1:fieldcount(T)
    ]
    ctor = T <: NamedTuple ? :($T(($(reads...),))) : :($T($(reads...)))
    return quote
        dims = _load_dims(pa, Val(N))
        out = Array{$T, N}(undef, dims)
        @inbounds for idx in 1:prod(dims)
            out[idx] = $ctor
        end
        return out
    end
end

@generated function store!(::StructArrayMarshaler{T, N}, pa::MxArray, v::Any)::Cvoid where {T, N}
    setters = Any[]
    for k in 1:fieldcount(T)
        FT = fieldtype(T, k)
        FM = typeof(marshaler_for(FT))
        nm = string(fieldname(T, k))
        if FT === String
            push!(setters, :(mx_set_field!(pa, Csize_t(idx - 1), $nm, mx_create_string(getfield(el, $k)))))
        else
            push!(
                setters,
                quote
                    let fv = getfield(el, $k)
                        fdims = fv isa AbstractArray ? size(fv) : ()
                        fpa = create($FM(), fdims)
                        # See StructMarshaler.store!: guard fpa until mx_set_field!
                        # transfers ownership to the parent struct array.
                        attached = false
                        try
                            store!($FM(), fpa, fv)
                            mx_set_field!(pa, Csize_t(idx - 1), $nm, fpa)
                            attached = true
                        finally
                            attached || mx_destroy_array(fpa)
                        end
                    end
                end,
            )
        end
    end
    return quote
        arr = v::Array{$T, N}
        @inbounds for idx in eachindex(arr)
            el = arr[idx]
            $(setters...)
        end
        return nothing
    end
end

@generated function create(::StructArrayMarshaler{T, N}, dims::Tuple)::MxArray where {T, N}
    names = String[string(fieldname(T, k)) for k in 1:fieldcount(T)]
    if N == 1
        return :(mx_create_struct_matrix(Csize_t(dims[1]::Int), Csize_t(1), $names))
    elseif N == 2
        return :(mx_create_struct_matrix(Csize_t(dims[1]::Int), Csize_t(dims[2]::Int), $names))
    else
        return quote
            d = Csize_t[Csize_t(x) for x in dims]
            GC.@preserve d mx_create_struct_array(Csize_t(N), pointer(d), $names)
        end
    end
end

mx_class_id(::StructArrayMarshaler)::Cint = mxSTRUCT_CLASS

# ── Tuple{A,B,…} ↔ MATLAB 1×N cell array ────────────────────────────────────
# A heterogeneous Julia tuple maps to a 1×N MATLAB cell, each element marshaled
# by its own type. The @generated body unrolls element types at codegen time
# (fieldtype/fieldcount reflection happens during code generation) — required
# for juliac --trim=safe. The same @generated pattern as StructMarshaler applies.

struct CellArrayMarshaler{T} end

@generated function load(::CellArrayMarshaler{T}, pa::MxArray)::T where {T}
    loads = [
        let m = marshaler_for(fieldtype(T, i)), MT = typeof(m)
                :(load($MT(), mx_get_cell(pa, Csize_t($(i - 1)))))
        end
            for i in 1:fieldcount(T)
    ]
    return :(($(loads...),))
end

@generated function store!(::CellArrayMarshaler{T}, pa::MxArray, v::Any)::Cvoid where {T}
    stmts = Any[:(tup = v::$T)]
    for i in 1:fieldcount(T)
        FT = fieldtype(T, i)
        FM = typeof(marshaler_for(FT))
        push!(
            stmts,
            quote
                let fv = getfield(tup, $i)
                    fdims = fv isa AbstractArray ? size(fv) : ()
                    fpa = create($FM(), fdims)
                    # Guard fpa until mx_set_cell! transfers ownership to the cell.
                    attached = false
                    try
                        store!($FM(), fpa, fv)
                        mx_set_cell!(pa, Csize_t($(i - 1)), fpa)
                        attached = true
                    finally
                        attached || mx_destroy_array(fpa)
                    end
                end
            end,
        )
    end
    push!(stmts, :(return nothing))
    return Expr(:block, stmts...)
end

@generated function create(::CellArrayMarshaler{T}, ::Tuple)::MxArray where {T}
    N = fieldcount(T)   # known at compile time; the dims arg is ignored
    return :(mx_create_cell_matrix(Csize_t(1), Csize_t($N)))
end

mx_class_id(::CellArrayMarshaler)::Cint = mxCELL_CLASS

# A concrete probe so the @verify in contracts.jl can instantiate the @generated methods.
const _CellProbe = Tuple{Float64, Int64}

# ── Vector{String} ↔ MATLAB N×1 cell of char ─────────────────────────────────
# Each Julia String maps to a 1×N char mxArray (mxCreateString); the enclosing
# cell is an N×1 mxCELL array. This is the natural MATLAB representation of a
# string vector: strsplit / string arrays in MATLAB code produce cell arrays of
# char when passed to older MEX, so this is the compatible representation.

# ── Matrix{Char} ↔ MATLAB M×N char array ─────────────────────────────────────
# MATLAB char arrays store elements as UTF-16 (mxChar = uint16_t), column-major.
# Julia Char is a 32-bit Unicode codepoint; BMP characters (U+0000–U+FFFF) round-
# trip losslessly. Non-BMP characters (U+10000+) are silently truncated to their
# low 16 bits on store! (consistent with MATLAB's own char type limits).

struct CharMatrixMarshaler end

function load(::CharMatrixMarshaler, pa::MxArray)::Matrix{Char}
    m = Int(mx_get_m(pa))
    n = Int(mx_get_n(pa))
    ptr = mx_get_chars(pa)
    out = Matrix{Char}(undef, m, n)
    for i in 1:(m * n)
        out[i] = Char(unsafe_load(ptr, i))
    end
    return out
end

function store!(::CharMatrixMarshaler, pa::MxArray, v::Any)::Cvoid
    mat = v::Matrix{Char}
    ptr = mx_get_chars(pa)
    for i in eachindex(mat)
        unsafe_store!(ptr, UInt16(codepoint(mat[i])), i)
    end
    return
end

function create(::CharMatrixMarshaler, dims::Tuple)::MxArray
    return mx_create_char_array((dims[1]::Int, dims[2]::Int))
end

mx_class_id(::CharMatrixMarshaler)::Cint = mxCHAR_CLASS

struct StringVectorMarshaler end

function load(::StringVectorMarshaler, pa::MxArray)::Vector{String}
    n = Int(mx_get_number_of_elements(pa))
    out = Vector{String}(undef, n)
    for i in 1:n
        out[i] = mx_get_string(mx_get_cell(pa, Csize_t(i - 1)))
    end
    return out
end

function store!(::StringVectorMarshaler, pa::MxArray, v::Any)::Cvoid
    vec = v::Vector{String}
    for i in eachindex(vec)
        mx_set_cell!(pa, Csize_t(i - 1), mx_create_string(vec[i]))
    end
    return
end

function create(::StringVectorMarshaler, dims::Tuple)::MxArray
    n = dims[1]::Int
    return mx_create_cell_matrix(Csize_t(1), Csize_t(n))  # 1×n row — MATLAB string-cell convention
end

mx_class_id(::StringVectorMarshaler)::Cint = mxCELL_CLASS

# ── Matrix{String} ↔ MATLAB string array ──────────────────────────────────────
# MATLAB's modern `string` array (R2016b+) is opaque in the legacy C Matrix API
# (no mxSTRING_CLASS, no create/get). We bridge through a cell of char using
# MATLAB's own string()/cellstr() builtins via mexCallMATLAB. Asymmetric like
# StringMarshaler: load is normal; output goes through the store_result override
# below (Mexicah cannot allocate an empty string array for the create+store! flow).
#
# Mapping (Option B): Matrix{String} → string array; Vector{String} stays cell of
# char. MATLAB string arrays are always ≥2-D (a "1-D" one is 1×N), so a 1×N string
# array round-trips as a 1×N Matrix{String}. If the Vector-vs-Matrix split becomes
# an ergonomic problem, switch to a dedicated wrapper type (Option A) — the
# mexCallMATLAB bridge below is reused as-is, only the dispatch type changes.

struct StringArrayMarshaler end

function load(::StringArrayMarshaler, pa::MxArray)::Matrix{String}
    # `cell` is a mexCallMATLAB *output*: MATLAB hands ownership to the caller, so we
    # must mxDestroyArray it. try/finally guarantees that on every exit, including a
    # throw from mx_get_string mid-loop (the Julia analogue of __attribute__((cleanup))).
    cell = mex_call_matlab_1("cellstr", pa)   # string array → M×N cell of char
    try
        m = Int(mx_get_m(cell))
        n = Int(mx_get_n(cell))
        out = Matrix{String}(undef, m, n)
        @inbounds for idx in 1:(m * n)
            out[idx] = mx_get_string(mx_get_cell(cell, Csize_t(idx - 1)))
        end
        return out
    finally
        mx_destroy_array(cell)
    end
end

# No-op: real output is the store_result(::Matrix{String}) override below.
store!(::StringArrayMarshaler, pa::MxArray, v::Any)::Cvoid = nothing

# Placeholder (unused — output goes through store_result); satisfies the contract.
create(::StringArrayMarshaler, ::Tuple)::MxArray = mx_create_cell_matrix(Csize_t(0), Csize_t(0))

# String arrays are opaque (no dedicated class id); the marshaler bridges via cells.
mx_class_id(::StringArrayMarshaler)::Cint = mxCELL_CLASS

# ── Dispatch: pick a marshaler for a Julia type ───────────────────────────────

function marshaler_for(@nospecialize(T::Type))
    T === Float64 && return Float64Marshaler()
    T === Vector{Float64} && return VectorFloat64Marshaler()
    T === Matrix{Float64} && return MatrixFloat64Marshaler()
    T === Int32 && return Int32Marshaler()
    T === Int64 && return Int64Marshaler()
    T === UInt64 && return UInt64Marshaler()
    T === Bool && return BoolMarshaler()
    T === SparseMatrixCSC{Float64, Int} && return SparseFloat64Marshaler()
    T === SparseMatrixCSC{ComplexF64, Int} && return SparseComplexF64Marshaler()
    T === SparseMatrixCSC{Bool, Int} && return SparseLogicalMarshaler()
    T === Vector{ComplexF64} && return ComplexFloat64Marshaler()
    T === String && return StringMarshaler()
    # Additional real numeric scalars
    T === Float32 && return Float32Marshaler()
    T === Int8 && return Int8Marshaler()
    T === Int16 && return Int16Marshaler()
    T === UInt8 && return UInt8Marshaler()
    T === UInt16 && return UInt16Marshaler()
    T === UInt32 && return UInt32Marshaler()
    # Dense numeric / complex / logical arrays, and Vector-of-struct → struct array
    if T <: Array
        ET = eltype(T)
        ND = ndims(T)
        ET === Bool && return LogicalArrayMarshaler{ND}()
        ET === ComplexF64 && return ComplexArrayMarshaler{ND}()
        ET === ComplexF32 && return ComplexF32ArrayMarshaler{ND}()
        if ET === Float64 || ET === Float32 ||
                ET === Int8 || ET === Int16 || ET === Int32 || ET === Int64 ||
                ET === UInt8 || ET === UInt16 || ET === UInt32 || ET === UInt64
            return DenseArrayMarshaler{ET, ND}()
        end
        ET === String && ND == 1 && return StringVectorMarshaler()
        ET === String && ND == 2 && return StringArrayMarshaler()
        ET === Char && ND == 2 && return CharMatrixMarshaler()
        _is_user_struct(ET) && return StructArrayMarshaler{ET, ND}()
    end
    # A heterogeneous Julia Tuple → 1×N MATLAB cell array.
    T <: Tuple && fieldcount(T) >= 1 && return CellArrayMarshaler{T}()
    # A flat struct / NamedTuple → 1×1 MATLAB struct.
    _is_user_struct(T) && return StructMarshaler{T}()
    error(
        "Mexicah: no marshaler for type $T. Supported: real numeric scalars " *
            "(Float64/Float32, Int8/16/32/64, UInt8/16/32/64), Bool, dense numeric " *
            "arrays Array{T,N} of those element types, " *
            "SparseMatrixCSC{Float64/ComplexF64/Bool,Int}, " *
            "complex arrays Array{ComplexF64,N}, flat struct/NamedTuple, " *
            "Array{<struct>,N} of any rank (→ N-D struct array), " *
            "Tuple{...} (→ cell array), Vector{String} (→ cell of char), " *
            "Matrix{String} (→ string array), Matrix{Char} (→ M×N char array), and String.",
    )
end

# A flat user composite (struct or NamedTuple) we marshal as a MATLAB struct —
# excludes numbers (e.g. Complex), arrays, tuples, and strings, which are types
# `isstructtype` also reports true for but that we handle elsewhere.
_is_user_struct(@nospecialize(T::Type))::Bool =
    isstructtype(T) && !(T <: Number) && !(T <: AbstractArray) &&
    !(T <: Tuple) && !(T <: AbstractString) && fieldcount(T) >= 1

# prhs/plhs are the MEX `mxArray *prhs[]` / `mxArray *plhs[]` arrays, i.e.
# `mxArray**`. Since MxArray == Ptr{Cvoid} is the `mxArray*` handle, these are
# `Ptr{MxArray}` (NOT `Ptr{Ptr{MxArray}}` — that extra level made unsafe_load
# yield a Ptr{MxArray} and load/store dispatch fail with a MethodError at runtime).
function load_arg(prhs::Ptr{MxArray}, k::Int, ::Type{T}) where {T}
    pa = unsafe_load(prhs, k)
    m = marshaler_for(T)
    return load(m, pa)
end

function store_result(plhs::Ptr{MxArray}, k::Int, v::T) where {T}
    m = marshaler_for(T)
    # `v isa AbstractArray ? size(v) : ()` rather than ndims(v): scalars and
    # structs are not arrays and have no ndims method; struct create ignores dims.
    dims = v isa AbstractArray ? size(v) : ()
    pa = create(m, dims)
    # MATLAB takes ownership of `pa` only once unsafe_store! hands it to plhs[]. If
    # store! throws midway (a nested marshaler erroring), `pa` is still ours and would
    # leak — its already-attached children leak with it. Destroy it on the throwing
    # path, then "disarm" the guard by nulling `ok`'d-out `pa` once ownership transfers
    # (the Rust "pass it to the owner" move). try/finally is the trim-safe Julia
    # analogue of ParselTongue's C __attribute__((cleanup)) + ArgPlan.disarm.
    owned = true
    try
        store!(m, pa, v)
        unsafe_store!(plhs, pa, k)
        owned = false
    finally
        owned && mx_destroy_array(pa)
    end
    return
end

function store_result(plhs::Ptr{MxArray}, k::Int, v::String)
    unsafe_store!(plhs, mx_create_string(v), k)
    return
end

# Matrix{String} → MATLAB string array. Concrete Matrix{String} so this is strictly
# more specific than the generic store_result and does NOT capture Vector{String}
# (which stays the cell-of-char path). Build an M×N cell of char, then let MATLAB's
# string() builtin convert it to a string array (shape preserved).
function store_result(plhs::Ptr{MxArray}, k::Int, v::Matrix{String})
    m, n = size(v)
    cell = mx_create_cell_matrix(Csize_t(m), Csize_t(n))
    # `cell` is only ever a mexCallMATLAB *input* (string() consumes a copy, not
    # ownership) — so we own it on every path and must destroy it. Without the
    # finally, a throw from mx_create_string mid-loop, or a mexCallMATLAB failure,
    # leaks `cell` (and even the success path leaked it before this guard).
    try
        @inbounds for idx in 1:(m * n)
            mx_set_cell!(cell, Csize_t(idx - 1), mx_create_string(v[idx]))
        end
        unsafe_store!(plhs, mex_call_matlab_1("string", cell), k)
    finally
        mx_destroy_array(cell)
    end
    return
end
