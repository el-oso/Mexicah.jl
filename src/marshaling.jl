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

function to_mx(::Float64Marshaler, v::Float64)::MxArray
    return mx_create_double_scalar(Cdouble(v))
end

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

# ── Complex{Float64} (interleaved, R2018a+) ───────────────────────────────────

struct ComplexFloat64Marshaler end

function load(::ComplexFloat64Marshaler, pa::MxArray)::Vector{ComplexF64}
    ptr = mx_get_complex_doubles(pa)
    n = Int(mx_get_number_of_elements(pa))
    raw = unsafe_wrap(Array, ptr, 2n; own = false)
    return reinterpret(ComplexF64, raw)
end

function store!(::ComplexFloat64Marshaler, pa::MxArray, v::Any)::Cvoid
    vec = v::Vector{ComplexF64}
    ptr = mx_get_complex_doubles(pa)
    n = length(vec)
    GC.@preserve vec unsafe_copyto!(ptr, Ptr{Cdouble}(pointer(vec)), 2n)
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
    T === Vector{ComplexF64} && return ComplexFloat64Marshaler()
    T === String && return StringMarshaler()
    error(
        "Mexicah: no marshaler for type $T. Supported: Float64, Vector{Float64}, " *
            "Matrix{Float64}, Int32, Int64, UInt64, Bool, SparseMatrixCSC{Float64,Int}, " *
            "Vector{ComplexF64}, String",
    )
end

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
    dims = ndims(v) == 0 ? () : size(v)
    pa = create(m, dims)
    store!(m, pa, v)
    unsafe_store!(plhs, pa, k)
    return
end

function store_result(plhs::Ptr{MxArray}, k::Int, v::String)
    unsafe_store!(plhs, mx_create_string(v), k)
    return
end
