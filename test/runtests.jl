# Run with: julia --project=test test/runtests.jl
using Libdl
using Mexicah
using ReTestItems

# On Linux, try to preload the libmx stub so that :matlab-tagged tests can run
# without a real MATLAB installation. When preloaded with RTLD_GLOBAL the bare
# ccall(:mxGetScalar, ...) resolves to the stub implementation.
if Sys.islinux()
    stub = joinpath(@__DIR__, "matlab", "libmx_stub", "libmx_stub.so")
    if isfile(stub)
        dlopen(stub, RTLD_GLOBAL | RTLD_NOW)
    end
end

# Skip tests tagged :matlab when MATLAB (or the stub) symbols are not available.
const MATLAB_AVAILABLE = try
    ptr = cglobal(:mxGetScalar)
    ptr != C_NULL
catch
    false
end

runtests(
    ti -> !((!MATLAB_AVAILABLE) && (:matlab in ti.tags)),
    Mexicah;
    testitem_timeout = 120,
    nworkers = 0,
)
