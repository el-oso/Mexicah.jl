# Pure-Julia FFI declarations for the MATLAB C API.
#
# No headers or stub libraries are needed at build time. MATLAB loads its own
# libmx/libmex into the process before loading a MEX file.
#
# Symbol resolution differs by platform:
#   * Linux: the host process exposes MATLAB's symbols globally and `libmx`/`libmex`
#     still export the *bare* C-API names, so a bare `ccall(:mxFoo, …)` resolves.
#   * Windows: no global symbol table, so the ccall must name the owning library
#     (`libmx` for mx*, `libmex` for mex*); the bare names are exported there too.
#   * macOS: symbols are visible in the default scope, BUT `libmx` exports only the
#     version-suffixed names (the headers `#define mxCreateDoubleMatrix
#     mxCreateDoubleMatrix_730` under the 64-bit large-array ABI). The bare aliases
#     Linux/Windows keep are absent, so a bare `ccall(:mxCreateDoubleMatrix, …)`
#     fails with "symbol not found" even though `mxGetScalar` (unversioned) works.
# The `@mxccall` / `@mexccall` macros paper over all three: name the library on
# Windows, resolve via `_mxsym` (bare → _730 → _800) on macOS, bare on Linux.

@static if Sys.isapple()
    # macOS RTLD_DEFAULT == (void*)-2 — search every image already in the process
    # (MATLAB has loaded libmx/libmex by the time any MEX runs).
    const _RTLD_DEFAULT = Ptr{Cvoid}(-2 % UInt)
    # Resolve a MATLAB C-API symbol, accounting for the header-level version
    # renaming. Try the bare name first, then the 64-bit large-array variants:
    # `_730` (separate-complex ABI, which our split Pr/Pi marshalers target) and
    # `_800` (interleaved). Unversioned symbols resolve on the first try.
    function _mxsym(name::Symbol)::Ptr{Cvoid}
        s = String(name)
        for suffix in ("", "_730", "_800", "_700")
            cand = s * suffix
            p = ccall(:dlsym, Ptr{Cvoid}, (Ptr{Cvoid}, Cstring), _RTLD_DEFAULT, cand)
            p == C_NULL || return p
        end
        # Nothing matched: return the bare lookup so the ccall raises a clear error.
        return ccall(:dlsym, Ptr{Cvoid}, (Ptr{Cvoid}, Cstring), _RTLD_DEFAULT, s)
    end
end

# Rewrite a `ccall(:sym, …)`: name `lib` on Windows, resolve via `_mxsym` on macOS,
# leave bare on Linux.
function _ccall_with_lib(ccall_expr::Expr, lib::String)
    (ccall_expr.head === :call && ccall_expr.args[1] === :ccall) ||
        error("@mxccall/@mexccall expects a `ccall(...)` expression")
    a = collect(ccall_expr.args)
    if Sys.iswindows()
        a[2] = Expr(:tuple, a[2], lib)   # :mxFoo  ->  (:mxFoo, "libmx")
    elseif Sys.isapple()
        a[2] = Expr(:call, :_mxsym, a[2])   # :mxFoo  ->  _mxsym(:mxFoo)
    else
        return esc(ccall_expr)
    end
    return esc(Expr(:call, a...))
end
macro mxccall(e)
    return _ccall_with_lib(e, "libmx")
end
macro mexccall(e)
    return _ccall_with_lib(e, "libmex")
end

# ── Dimensions ────────────────────────────────────────────────────────────────

mx_get_m(pa::MxArray)::Csize_t = @mxccall ccall(:mxGetM, Csize_t, (MxArray,), pa)
mx_get_n(pa::MxArray)::Csize_t = @mxccall ccall(:mxGetN, Csize_t, (MxArray,), pa)
mx_get_number_of_elements(pa::MxArray)::Csize_t =
    @mxccall ccall(:mxGetNumberOfElements, Csize_t, (MxArray,), pa)
mx_get_number_of_dimensions(pa::MxArray)::Csize_t =
    @mxccall ccall(:mxGetNumberOfDimensions, Csize_t, (MxArray,), pa)
mx_get_dimensions(pa::MxArray)::Ptr{Csize_t} =
    @mxccall ccall(:mxGetDimensions, Ptr{Csize_t}, (MxArray,), pa)

# ── Type queries ──────────────────────────────────────────────────────────────

mx_get_class_id(pa::MxArray)::Cint =
    @mxccall ccall(:mxGetClassID, Cint, (MxArray,), pa)
mx_is_double(pa::MxArray)::Bool = (@mxccall ccall(:mxIsDouble, Cint, (MxArray,), pa)) != 0
mx_is_single(pa::MxArray)::Bool = (@mxccall ccall(:mxIsSingle, Cint, (MxArray,), pa)) != 0
mx_is_int32(pa::MxArray)::Bool = (@mxccall ccall(:mxIsInt32, Cint, (MxArray,), pa)) != 0
mx_is_int64(pa::MxArray)::Bool = (@mxccall ccall(:mxIsInt64, Cint, (MxArray,), pa)) != 0
mx_is_logical(pa::MxArray)::Bool = (@mxccall ccall(:mxIsLogical, Cint, (MxArray,), pa)) != 0
mx_is_complex(pa::MxArray)::Bool = (@mxccall ccall(:mxIsComplex, Cint, (MxArray,), pa)) != 0
mx_is_sparse(pa::MxArray)::Bool = (@mxccall ccall(:mxIsSparse, Cint, (MxArray,), pa)) != 0
mx_is_numeric(pa::MxArray)::Bool = (@mxccall ccall(:mxIsNumeric, Cint, (MxArray,), pa)) != 0

# ── Double (real) ─────────────────────────────────────────────────────────────

mx_get_pr(pa::MxArray)::Ptr{Cdouble} =
    @mxccall ccall(:mxGetPr, Ptr{Cdouble}, (MxArray,), pa)
mx_get_pi(pa::MxArray)::Ptr{Cdouble} =
    @mxccall ccall(:mxGetPi, Ptr{Cdouble}, (MxArray,), pa)
mx_get_scalar(pa::MxArray)::Cdouble =
    @mxccall ccall(:mxGetScalar, Cdouble, (MxArray,), pa)

mx_create_double_matrix(m::Csize_t, n::Csize_t, flag::Cint)::MxArray =
    @mxccall ccall(:mxCreateDoubleMatrix, MxArray, (Csize_t, Csize_t, Cint), m, n, flag)
mx_create_double_scalar(v::Cdouble)::MxArray =
    @mxccall ccall(:mxCreateDoubleScalar, MxArray, (Cdouble,), v)

# Interleaved complex API (R2018a+) — unused by the marshalers (they use the
# split Pr/Pi API), kept for completeness.
mx_get_complex_doubles(pa::MxArray)::Ptr{Cdouble} =
    @mxccall ccall(:mxGetComplexDoubles, Ptr{Cdouble}, (MxArray,), pa)

# ── Logical ───────────────────────────────────────────────────────────────────

mx_get_logicals(pa::MxArray)::Ptr{Cuchar} =
    @mxccall ccall(:mxGetLogicals, Ptr{Cuchar}, (MxArray,), pa)
mx_create_logical_scalar(v::Bool)::MxArray =
    @mxccall ccall(:mxCreateLogicalScalar, MxArray, (Cuchar,), v ? Cuchar(1) : Cuchar(0))
mx_create_logical_array(m::Csize_t, n::Csize_t)::MxArray =
    @mxccall ccall(:mxCreateLogicalMatrix, MxArray, (Csize_t, Csize_t), m, n)

# ── Numeric (generic) ─────────────────────────────────────────────────────────

mx_create_numeric_matrix(m::Csize_t, n::Csize_t, classid::Cint, flag::Cint)::MxArray =
    @mxccall ccall(
    :mxCreateNumericMatrix,
    MxArray,
    (Csize_t, Csize_t, Cint, Cint),
    m,
    n,
    classid,
    flag,
)
mx_get_data(pa::MxArray)::Ptr{Cvoid} =
    @mxccall ccall(:mxGetData, Ptr{Cvoid}, (MxArray,), pa)

# ── Sparse ────────────────────────────────────────────────────────────────────

mx_create_sparse(m::Csize_t, n::Csize_t, nzmax::Csize_t, flag::Cint)::MxArray =
    @mxccall ccall(:mxCreateSparse, MxArray, (Csize_t, Csize_t, Csize_t, Cint), m, n, nzmax, flag)
mx_get_nzmax(pa::MxArray)::Csize_t = @mxccall ccall(:mxGetNzmax, Csize_t, (MxArray,), pa)
mx_get_ir(pa::MxArray)::Ptr{Csize_t} =
    @mxccall ccall(:mxGetIr, Ptr{Csize_t}, (MxArray,), pa)
mx_get_jc(pa::MxArray)::Ptr{Csize_t} =
    @mxccall ccall(:mxGetJc, Ptr{Csize_t}, (MxArray,), pa)

# ── Memory management ─────────────────────────────────────────────────────────

mx_destroy_array(pa::MxArray)::Cvoid =
    @mxccall ccall(:mxDestroyArray, Cvoid, (MxArray,), pa)
mx_duplicate_array(pa::MxArray)::MxArray =
    @mxccall ccall(:mxDuplicateArray, MxArray, (MxArray,), pa)

# ── Additional type queries ───────────────────────────────────────────────────

mx_is_uint64(pa::MxArray)::Bool = (@mxccall ccall(:mxIsUint64, Cint, (MxArray,), pa)) != 0
mx_is_struct(pa::MxArray)::Bool = (@mxccall ccall(:mxIsStruct, Cint, (MxArray,), pa)) != 0
mx_is_char(pa::MxArray)::Bool = (@mxccall ccall(:mxIsChar, Cint, (MxArray,), pa)) != 0

# ── Struct arrays ─────────────────────────────────────────────────────────────
# mxSTRUCT_CLASS arrays are MATLAB's representation of named-field compound types.
# Each element has the same field names; elements are indexed 0-based (C convention).

mx_get_number_of_fields(pa::MxArray)::Cint =
    @mxccall ccall(:mxGetNumberOfFields, Cint, (MxArray,), pa)

function mx_get_field_name_by_number(pa::MxArray, n::Cint)::String
    ptr = @mxccall ccall(:mxGetFieldNameByNumber, Ptr{UInt8}, (MxArray, Cint), pa, n)
    ptr == C_NULL && error("mxGetFieldNameByNumber: invalid field index $n")
    return unsafe_string(ptr)
end

function mx_get_field(pa::MxArray, index::Csize_t, fieldname::String)::MxArray
    return @mxccall ccall(:mxGetField, MxArray, (MxArray, Csize_t, Cstring), pa, index, fieldname)
end

function mx_set_field!(pa::MxArray, index::Csize_t, fieldname::String, value::MxArray)::Cvoid
    @mxccall ccall(:mxSetField, Cvoid, (MxArray, Csize_t, Cstring, MxArray), pa, index, fieldname, value)
    return
end

function mx_add_field!(pa::MxArray, fieldname::String)::Cint
    return @mxccall ccall(:mxAddField, Cint, (MxArray, Cstring), pa, fieldname)
end

# fieldnames must outlive this call; we build explicit null-terminated byte vectors.
function mx_create_struct_matrix(m::Csize_t, n::Csize_t, fieldnames::Vector{String})::MxArray
    cnames = [vcat(codeunits(s), UInt8(0)) for s in fieldnames]
    ptrs = pointer.(cnames)
    GC.@preserve cnames begin
        return @mxccall ccall(
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
    rc = @mxccall ccall(:mxGetString, Cint, (MxArray, Ptr{UInt8}, Csize_t), pa, buf, Csize_t(n + 1))
    rc != 0 && error("mxGetString failed")
    return unsafe_string(pointer(buf))
end

function mx_create_string(s::String)::MxArray
    return @mxccall ccall(:mxCreateString, MxArray, (Cstring,), s)
end

# ── MEX error / output ────────────────────────────────────────────────────────

mex_errorf(id::AbstractString, msg::AbstractString)::Cvoid =
    @mexccall ccall(:mexErrMsgIdAndTxt, Cvoid, (Cstring, Cstring), id, msg)
