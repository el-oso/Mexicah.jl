# Pure-Julia FFI declarations for the MATLAB C API.
#
# No headers or stub libraries are needed at build time. MATLAB loads its own
# libmx/libmex into the process before loading a MEX file, so all mxXxx symbols
# are already present in the process symbol table when these ccalls execute.
#
# On Linux the ELF dynamic linker resolves undefined symbols lazily at runtime.
# On macOS juliac must be invoked with `-undefined dynamic_lookup`.

# ── Dimensions ────────────────────────────────────────────────────────────────

mx_get_m(pa::MxArray)::Csize_t = ccall(:mxGetM, Csize_t, (MxArray,), pa)
mx_get_n(pa::MxArray)::Csize_t = ccall(:mxGetN, Csize_t, (MxArray,), pa)
mx_get_number_of_elements(pa::MxArray)::Csize_t =
    ccall(:mxGetNumberOfElements, Csize_t, (MxArray,), pa)
mx_get_number_of_dimensions(pa::MxArray)::Csize_t =
    ccall(:mxGetNumberOfDimensions, Csize_t, (MxArray,), pa)
mx_get_dimensions(pa::MxArray)::Ptr{Csize_t} =
    ccall(:mxGetDimensions, Ptr{Csize_t}, (MxArray,), pa)

# ── Type queries ──────────────────────────────────────────────────────────────

mx_get_class_id(pa::MxArray)::Cint =
    ccall(:mxGetClassID, Cint, (MxArray,), pa)
mx_is_double(pa::MxArray)::Bool = ccall(:mxIsDouble, Cint, (MxArray,), pa) != 0
mx_is_single(pa::MxArray)::Bool = ccall(:mxIsSingle, Cint, (MxArray,), pa) != 0
mx_is_int32(pa::MxArray)::Bool = ccall(:mxIsInt32, Cint, (MxArray,), pa) != 0
mx_is_int64(pa::MxArray)::Bool = ccall(:mxIsInt64, Cint, (MxArray,), pa) != 0
mx_is_logical(pa::MxArray)::Bool = ccall(:mxIsLogical, Cint, (MxArray,), pa) != 0
mx_is_complex(pa::MxArray)::Bool = ccall(:mxIsComplex, Cint, (MxArray,), pa) != 0
mx_is_sparse(pa::MxArray)::Bool = ccall(:mxIsSparse, Cint, (MxArray,), pa) != 0
mx_is_numeric(pa::MxArray)::Bool = ccall(:mxIsNumeric, Cint, (MxArray,), pa) != 0

# ── Double (real) ─────────────────────────────────────────────────────────────

mx_get_pr(pa::MxArray)::Ptr{Cdouble} =
    ccall(:mxGetPr, Ptr{Cdouble}, (MxArray,), pa)
mx_get_pi(pa::MxArray)::Ptr{Cdouble} =
    ccall(:mxGetPi, Ptr{Cdouble}, (MxArray,), pa)
mx_get_scalar(pa::MxArray)::Cdouble =
    ccall(:mxGetScalar, Cdouble, (MxArray,), pa)

mx_create_double_matrix(m::Csize_t, n::Csize_t, flag::Cint)::MxArray =
    ccall(:mxCreateDoubleMatrix, MxArray, (Csize_t, Csize_t, Cint), m, n, flag)
mx_create_double_scalar(v::Cdouble)::MxArray =
    ccall(:mxCreateDoubleScalar, MxArray, (Cdouble,), v)

# Interleaved complex API (R2018a+)
mx_get_complex_doubles(pa::MxArray)::Ptr{Cdouble} =
    ccall(:mxGetComplexDoubles, Ptr{Cdouble}, (MxArray,), pa)

# ── Logical ───────────────────────────────────────────────────────────────────

mx_get_logicals(pa::MxArray)::Ptr{Cuchar} =
    ccall(:mxGetLogicals, Ptr{Cuchar}, (MxArray,), pa)
mx_create_logical_scalar(v::Bool)::MxArray =
    ccall(:mxCreateLogicalScalar, MxArray, (Cuchar,), v ? Cuchar(1) : Cuchar(0))
mx_create_logical_array(m::Csize_t, n::Csize_t)::MxArray =
    ccall(:mxCreateLogicalMatrix, MxArray, (Csize_t, Csize_t), m, n)

# ── Numeric (generic) ─────────────────────────────────────────────────────────

mx_create_numeric_matrix(m::Csize_t, n::Csize_t, classid::Cint, flag::Cint)::MxArray =
    ccall(
    :mxCreateNumericMatrix,
    MxArray,
    (Csize_t, Csize_t, Cint, Cint),
    m,
    n,
    classid,
    flag,
)
mx_get_data(pa::MxArray)::Ptr{Cvoid} =
    ccall(:mxGetData, Ptr{Cvoid}, (MxArray,), pa)

# ── Sparse ────────────────────────────────────────────────────────────────────

mx_create_sparse(m::Csize_t, n::Csize_t, nzmax::Csize_t, flag::Cint)::MxArray =
    ccall(:mxCreateSparse, MxArray, (Csize_t, Csize_t, Csize_t, Cint), m, n, nzmax, flag)
mx_get_nzmax(pa::MxArray)::Csize_t = ccall(:mxGetNzmax, Csize_t, (MxArray,), pa)
mx_get_ir(pa::MxArray)::Ptr{Csize_t} =
    ccall(:mxGetIr, Ptr{Csize_t}, (MxArray,), pa)
mx_get_jc(pa::MxArray)::Ptr{Csize_t} =
    ccall(:mxGetJc, Ptr{Csize_t}, (MxArray,), pa)

# ── Memory management ─────────────────────────────────────────────────────────

mx_destroy_array(pa::MxArray)::Cvoid =
    ccall(:mxDestroyArray, Cvoid, (MxArray,), pa)
mx_duplicate_array(pa::MxArray)::MxArray =
    ccall(:mxDuplicateArray, MxArray, (MxArray,), pa)

# ── Additional type queries ───────────────────────────────────────────────────

mx_is_uint64(pa::MxArray)::Bool = ccall(:mxIsUint64, Cint, (MxArray,), pa) != 0
mx_is_struct(pa::MxArray)::Bool = ccall(:mxIsStruct, Cint, (MxArray,), pa) != 0
mx_is_char(pa::MxArray)::Bool = ccall(:mxIsChar, Cint, (MxArray,), pa) != 0

# ── Struct arrays ─────────────────────────────────────────────────────────────
# mxSTRUCT_CLASS arrays are MATLAB's representation of named-field compound types.
# Each element has the same field names; elements are indexed 0-based (C convention).

mx_get_number_of_fields(pa::MxArray)::Cint =
    ccall(:mxGetNumberOfFields, Cint, (MxArray,), pa)

function mx_get_field_name_by_number(pa::MxArray, n::Cint)::String
    ptr = ccall(:mxGetFieldNameByNumber, Ptr{UInt8}, (MxArray, Cint), pa, n)
    ptr == C_NULL && error("mxGetFieldNameByNumber: invalid field index $n")
    return unsafe_string(ptr)
end

function mx_get_field(pa::MxArray, index::Csize_t, fieldname::String)::MxArray
    return ccall(:mxGetField, MxArray, (MxArray, Csize_t, Cstring), pa, index, fieldname)
end

function mx_set_field!(pa::MxArray, index::Csize_t, fieldname::String, value::MxArray)::Cvoid
    ccall(:mxSetField, Cvoid, (MxArray, Csize_t, Cstring, MxArray), pa, index, fieldname, value)
    return
end

function mx_add_field!(pa::MxArray, fieldname::String)::Cint
    return ccall(:mxAddField, Cint, (MxArray, Cstring), pa, fieldname)
end

# fieldnames must outlive this call; we build explicit null-terminated byte vectors.
function mx_create_struct_matrix(m::Csize_t, n::Csize_t, fieldnames::Vector{String})::MxArray
    cnames = [vcat(codeunits(s), UInt8(0)) for s in fieldnames]
    ptrs = pointer.(cnames)
    GC.@preserve cnames begin
        return ccall(
            :mxCreateStructMatrix,
            MxArray,
            (Csize_t, Csize_t, Cint, Ptr{Ptr{UInt8}}),
            m,
            n,
            Cint(length(fieldnames)),
            ptrs,
        )
    end
end

# ── Char arrays (strings) ─────────────────────────────────────────────────────

function mx_get_string(pa::MxArray)::String
    # mxGetNumberOfElements gives the character count (incl. terminator in R2018a+)
    n = Int(mx_get_number_of_elements(pa))
    buf = Vector{UInt8}(undef, n + 1)
    rc = ccall(:mxGetString, Cint, (MxArray, Ptr{UInt8}, Csize_t), pa, buf, Csize_t(n + 1))
    rc != 0 && error("mxGetString failed")
    return unsafe_string(pointer(buf))
end

function mx_create_string(s::String)::MxArray
    return ccall(:mxCreateString, MxArray, (Cstring,), s)
end

# ── MEX error / output ────────────────────────────────────────────────────────

mex_errorf(id::AbstractString, msg::AbstractString)::Cvoid =
    ccall(:mexErrMsgIdAndTxt, Cvoid, (Cstring, Cstring), id, msg)
