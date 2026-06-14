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

# ── MEX error / output ────────────────────────────────────────────────────────

mex_errorf(id::Cstring, msg::Cstring)::Cvoid =
    ccall(:mexErrMsgIdAndTxt, Cvoid, (Cstring, Cstring), id, msg)
