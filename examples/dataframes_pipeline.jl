# Example: DataFrames handle lifecycle — load a CSV in Julia, query columns in MATLAB.
#
# ⚠️  ILLUSTRATIVE — not part of the lean, CI-built example set. DataFrames + CSV
# are large and may not compile under juliac `--trim=safe`. For a real build,
# define the wrappers in a package (like examples/src/MexicahExamples.jl), depend
# on DataFrames/CSV directly (not via Main), and build from an environment that
# has them. The lean, verified examples are scalar_add / matrix_scale /
# sparse_norm / linalg / handle_solver.
#
# Requires DataFrames (and optionally CSV) to be installed:
#   julia --project=. -e 'using Pkg; Pkg.add(["DataFrames", "CSV"])'
#
# Build:
#   julia --project=. examples/dataframes_pipeline.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   path_bytes = double('data/measurements.csv');   % encode path as double char codes
#   id = df_load_csv(path_bytes);                   % → uint64 handle
#   n  = df_nrows(id);                              % number of rows
#   x  = df_get_col(id, 1);                        % first column as double vector
#   y  = df_get_col(id, 2);                        % second column
#   df_close(id);                                   % release Julia-side DataFrame

using Mexicah

@mexfunction function df_load_csv(path_bytes::Vector{Float64})::UInt64
    isdefined(Main, :DataFrames) ||
        error("DataFrames is not loaded — add it to your Julia environment")
    isdefined(Main, :CSV) ||
        error("CSV is not loaded — add it to your Julia environment")
    path = String(UInt8.(round.(Int, path_bytes)))
    df = Main.CSV.read(path, Main.DataFrames.DataFrame)
    ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
    ext === nothing && error("MexicahDataFramesExt not loaded")
    return ext.df_to_handle(df)
end

@mexfunction function df_nrows(id::UInt64)::Int64
    ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
    ext === nothing && error("MexicahDataFramesExt not loaded")
    return ext.df_nrows(id)
end

@mexfunction function df_get_col(id::UInt64, col::Int64)::Vector{Float64}
    ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
    ext === nothing && error("MexicahDataFramesExt not loaded")
    return ext.df_get_col_f64(id, col)
end

@mexfunction function df_close(id::UInt64)::Bool
    ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
    ext === nothing && error("MexicahDataFramesExt not loaded")
    return ext.df_destroy_handle(id)
end

build_all_mex(; output = "mex/")
