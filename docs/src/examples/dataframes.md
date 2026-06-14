# DataFrames

The `MexicahDataFramesExt` extension (loaded automatically when `DataFrames` is
in your environment) bridges Julia `DataFrame`s to MATLAB in two ways:

| Strategy | When to use |
|---|---|
| **Handle-based** | Large or dynamically-typed DataFrames; MATLAB holds a `uint64` key and calls Julia to query columns |
| **Value copy (struct)** | Small DataFrames you want to inspect in MATLAB as a struct with named fields |

## Setup

```toml
# your package Project.toml — add DataFrames as a dependency
[deps]
DataFrames = "a93c6f00-e57d-5684-b466-afe8fa294f15"
Mexicah    = "..."
```

The extension activates automatically when `DataFrames` is loaded in the same
Julia session. No extra registration step needed.

## Handle-based API

```julia
MexicahDataFramesExt.df_to_handle(df::DataFrame)  → UInt64
MexicahDataFramesExt.df_from_handle(id::UInt64)   → DataFrame   # throws if missing
MexicahDataFramesExt.df_destroy_handle(id::UInt64)→ Bool

MexicahDataFramesExt.df_nrows(id::UInt64)         → Int64
MexicahDataFramesExt.df_ncols(id::UInt64)         → Int64
MexicahDataFramesExt.df_get_col_f64(id::UInt64, col::Int64) → Vector{Float64}
```

### Example: load a CSV, process in Julia, read columns in MATLAB

```julia
# examples/dataframes/csv_pipeline.jl
using Mexicah, DataFrames, CSV

@mexfunction function load_csv(path_bytes::Vector{Float64})::UInt64
    # MATLAB passes strings as double arrays of char codes
    path = String(UInt8.(round.(Int, path_bytes)))
    df = CSV.read(path, DataFrame)
    return MexicahDataFramesExt.df_to_handle(df)
end

@mexfunction function df_nrows(id::UInt64)::Int64
    return MexicahDataFramesExt.df_nrows(id)
end

@mexfunction function df_get_col(id::UInt64, col::Int64)::Vector{Float64}
    return MexicahDataFramesExt.df_get_col_f64(id, col)
end

@mexfunction function df_close(id::UInt64)::Bool
    return MexicahDataFramesExt.df_destroy_handle(id)
end
```

```matlab
addpath('mex/')
mexicah_setup

path_bytes = double('data/measurements.csv');   % convert string to double codes
id = load_csv(path_bytes);

n  = df_nrows(id);           % number of rows
x  = df_get_col(id, 1);      % first column as double vector
y  = df_get_col(id, 2);      % second column

% ... process x, y in MATLAB ...

df_close(id);                 % release Julia-side DataFrame
```

## Value-copy (struct) API

For DataFrames that are small enough to copy:

```julia
MexicahDataFramesExt.df_to_struct(df::DataFrame) → MxArray   # → MATLAB scalar struct
MexicahDataFramesExt.struct_to_df(pa::MxArray)   → DataFrame
```

Each column becomes a field in the MATLAB struct. Supported column element
types: `Float64`, `Int32`, `Int64`, `Bool`.

### Example: compute summary statistics in Julia, return as struct

```julia
@mexfunction function summarize(A::Matrix{Float64})::UInt64
    # build a summary DataFrame — one row per column of A
    df = DataFrame(
        mean = vec(sum(A; dims=1) ./ size(A, 1)),
        std  = vec(sqrt.(sum((A .- sum(A; dims=1) ./ size(A, 1)).^2; dims=1) ./ (size(A, 1) - 1))),
    )
    # value-copy to MATLAB struct — returns MxArray directly
    # (not a handle — MATLAB owns the struct immediately)
    return MexicahDataFramesExt.df_to_struct(df)
end
```

> **Note:** `df_to_struct` returns an `MxArray` (pointer), not a `UInt64` handle.
> Use this only inside a MEX wrapper where the `MxArray` is set into `plhs` directly,
> not returned via the normal marshaling path. For the common case, wrap the result
> in a handle or use the `df_get_col_f64` approach instead.

```matlab
stats = summarize(randn(100, 3));   % → 1×1 struct with fields 'mean' and 'std'
stats.mean    % → [m1, m2, m3]
stats.std     % → [s1, s2, s3]
```

## Column type support

| Julia column type | MATLAB field type |
|---|---|
| `Vector{Float64}` | `double` row vector |
| `Vector{Int32}` | `int32` row vector |
| `Vector{Int64}` | `int64` row vector |
| `Vector{Bool}` | `logical` row vector |

Columns of other types are skipped (with a warning) during `df_to_struct`.
Use `df_get_col_f64` for explicit `Float64` access; convert other types in Julia
before calling `df_to_struct`.
