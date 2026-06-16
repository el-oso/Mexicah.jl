module Mexicah

using SparseArrays: SparseMatrixCSC, nnz

include("types.jl")
include("api.jl")
include("marshaling.jl")
include("contracts.jl")
include("runtime.jl")
include("handles.jl")
include("codegen.jl")
include("cuda_driver.jl")
include("cuda_codegen.jl")
include("build.jl")
include("macros.jl")
include("linalg.jl")

export build_mex,
    build_all_mex,
    build_shared_mex,
    mex_ext,
    @mexfunction,
    @mexgradient,
    @mexgpukernel,
    MxArray,
    # Marshaling utilities (useful for extension authors)
    load_arg,
    store_result,
    marshaler_for,
    # Opaque handle registry (Julia object ↔ MATLAB uint64 id)
    _handle_store!,
    _handle_get,
    _handle_delete!,
    _handle_count,
    # LinearAlgebra bridge
    la_det,
    la_trace,
    la_norm_frob,
    la_opnorm,
    la_cond,
    la_rank,
    la_inv,
    la_pinv,
    la_solve,
    la_svd,
    la_svdvals,
    la_eig_sym,
    la_eig_symvals,
    la_qr,
    la_chol,
    la_lu_factorize,
    la_lu_solve,
    la_lu_det,
    la_lu_destroy,
    la_chol_factorize,
    la_chol_solve,
    la_chol_destroy

# Re-populate TypeContracts._registry on every load so that interface_trait
# works correctly even when loaded from a precompile cache.
function __init__()
    return _reinit_registry!()
end

end
