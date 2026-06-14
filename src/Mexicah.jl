module Mexicah

using SparseArrays: SparseMatrixCSC, nnz

include("types.jl")
include("api.jl")
include("marshaling.jl")
include("contracts.jl")
include("runtime.jl")
include("codegen.jl")
include("build.jl")
include("macros.jl")

export build_mex,
    build_all_mex,
    mex_ext,
    @mexfunction,
    @mexgradient,
    MxArray,
    # Marshaling utilities (useful for extension authors)
    load_arg,
    store_result,
    marshaler_for

# Re-populate TypeContracts._registry on every load so that interface_trait
# works correctly even when loaded from a precompile cache.
function __init__()
    return _reinit_registry!()
end

end
