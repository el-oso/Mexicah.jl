module MexicahDataFramesExt

using Mexicah
using DataFrames: DataFrames, DataFrame, nrow, ncol, names, eachcol

# ── Answer to "can Julia structs be shared with MATLAB?" ─────────────────────
#
# Short answer: no — MATLAB only understands mxArray types. Julia structs are
# GC-managed heap objects with no stable ABI visible outside the Julia runtime.
#
# Solution used here: the opaque handle pattern.
#   1. Call df_to_handle(df) from within a Julia function to store a DataFrame
#      in Mexicah's handle registry and receive a UInt64 key.
#   2. Return that key to MATLAB (as a uint64 scalar mxArray).
#   3. MATLAB passes the key back on subsequent MEX calls.
#   4. Julia calls df_from_handle(id) to recover the DataFrame.
#   5. When MATLAB is finished, call df_destroy_handle(id) to allow GC.
#
# For small DataFrames where MATLAB needs to read the actual data, use
# df_to_struct() / struct_to_df() to do a value-copy conversion to/from a
# MATLAB struct with one field per column.

# ── Handle-based API ──────────────────────────────────────────────────────────

"""
    df_to_handle(df::DataFrame) → UInt64

Store `df` in the Mexicah object registry and return an opaque handle.
Call this inside a `@mexfunction`-decorated function to let MATLAB hold a
reference to a Julia DataFrame without copying its data.
"""
df_to_handle(df::DataFrame)::UInt64 = Mexicah._handle_store!(df)

"""
    df_from_handle(id::UInt64) → DataFrame

Retrieve the DataFrame stored under `id`. Throws if the handle is not found.
"""
function df_from_handle(id::UInt64)::DataFrame
    obj = Mexicah._handle_get(id)
    obj === nothing && error("Mexicah: no DataFrame found for handle $id (already destroyed?)")
    return obj::DataFrame
end

"""
    df_destroy_handle(id::UInt64) → Bool

Remove the DataFrame handle from the registry, allowing GC. Returns `true` on
success and `false` if the handle did not exist.
"""
df_destroy_handle(id::UInt64)::Bool = Mexicah._handle_delete!(id)

# ── Column accessors (via handle) ─────────────────────────────────────────────

"""
    df_nrows(id::UInt64) → Int64

Return the number of rows in the DataFrame at `id`.
"""
df_nrows(id::UInt64)::Int64 = Int64(nrow(df_from_handle(id)))

"""
    df_ncols(id::UInt64) → Int64

Return the number of columns in the DataFrame at `id`.
"""
df_ncols(id::UInt64)::Int64 = Int64(ncol(df_from_handle(id)))

"""
    df_get_col_f64(id::UInt64, col::Int64) → Vector{Float64}

Return column `col` (1-based) of the DataFrame at `id` as a `Vector{Float64}`.
Copies the column data — the result is independent of the stored DataFrame.
"""
function df_get_col_f64(id::UInt64, col::Int64)::Vector{Float64}
    df = df_from_handle(id)
    (col < 1 || col > ncol(df)) &&
        error("Mexicah: column index $col out of range (1:$(ncol(df)))")
    return Float64.(df[!, col])
end

# ── Value-copy struct conversion ──────────────────────────────────────────────
# For DataFrames small enough to copy: DataFrame ↔ MATLAB scalar struct.
# Each column becomes a struct field with the column name as field name.
# Supported column types: Float64, Int32, Int64, Bool.

"""
    df_to_struct(df::DataFrame) → MxArray

Convert `df` to a MATLAB scalar struct where each field corresponds to a column.
Returns a raw mxArray pointer — only call this from within a compiled MEX context.
"""
function df_to_struct(df::DataFrame)::Mexicah.MxArray
    colnames = names(df)
    pa = Mexicah.mx_create_struct_matrix(
        Csize_t(1),
        Csize_t(1),
        String.(colnames),
    )
    for (j, col) in enumerate(eachcol(df))
        field_pa = _col_to_mx(col)
        Mexicah.mx_set_field!(pa, Csize_t(0), String(colnames[j]), field_pa)
    end
    return pa
end

function _col_to_mx(col::AbstractVector)::Mexicah.MxArray
    T = eltype(col)
    m = Mexicah.marshaler_for(T === Float32 ? Float64 : T)
    n = length(col)
    pa = if T <: AbstractFloat
        Mexicah.mx_create_double_matrix(Csize_t(n), Csize_t(1), Mexicah.mxREAL)
    elseif T === Bool
        Mexicah.mx_create_logical_array(Csize_t(n), Csize_t(1))
    else
        Mexicah.mx_create_numeric_matrix(
            Csize_t(n),
            Csize_t(1),
            Mexicah.mx_class_id(m),
            Mexicah.mxREAL,
        )
    end
    Mexicah.store!(m, pa, convert(Vector{T === Float32 ? Float64 : T}, col))
    return pa
end

"""
    struct_to_df(pa::MxArray) → DataFrame

Convert a MATLAB scalar struct `pa` to a Julia DataFrame. Each struct field
becomes a column. Only `double`, `int32`, `int64`, and `logical` fields
are supported; other types are silently skipped.
"""
function struct_to_df(pa::Mexicah.MxArray)::DataFrame
    Mexicah.mx_is_struct(pa) || error("Mexicah: expected a struct mxArray")
    nf = Int(Mexicah.mx_get_number_of_fields(pa))
    cols = Dict{Symbol, AbstractVector}()
    for i in 0:(nf - 1)
        name = Mexicah.mx_get_field_name_by_number(pa, Cint(i))
        field_pa = Mexicah.mx_get_field(pa, Csize_t(0), name)
        field_pa == C_NULL && continue
        col = _mx_to_col(field_pa)
        col === nothing && continue
        cols[Symbol(name)] = col
    end
    return DataFrame(cols)
end

function _mx_to_col(pa::Mexicah.MxArray)::Union{AbstractVector, Nothing}
    n = Int(Mexicah.mx_get_number_of_elements(pa))
    cid = Mexicah.mx_get_class_id(pa)
    if cid == Mexicah.mxDOUBLE_CLASS
        m = Mexicah.VectorFloat64Marshaler()
        return copy(Mexicah.load(m, pa))
    elseif cid == Mexicah.mxINT32_CLASS
        ptr = Ptr{Int32}(Mexicah.mx_get_data(pa))
        return copy(unsafe_wrap(Array, ptr, n; own = false))
    elseif cid == Mexicah.mxINT64_CLASS
        ptr = Ptr{Int64}(Mexicah.mx_get_data(pa))
        return copy(unsafe_wrap(Array, ptr, n; own = false))
    elseif cid == Mexicah.mxLOGICAL_CLASS
        ptr = Mexicah.mx_get_logicals(pa)
        raw = unsafe_wrap(Array, ptr, n; own = false)
        return Bool.(raw)
    end
    return nothing
end

end # module MexicahDataFramesExt
