# Run with: julia --project=test test/runtests.jl
using Libdl
using Mexicah
using LibMx
using ReTestItems

# On Linux, build + preload the canonical libmx host (owned by LibMx, the same source
# Unmex's runtime uses) so :matlab-tagged tests run without a real MATLAB. With
# RTLD_GLOBAL the bare ccall(:mxGetScalar, ...) resolves to it. (The real-MATLAB CI runs
# build_fixtures.jl, not this file, so there's nothing to shadow here.)
if Sys.islinux()
    host = LibMx.build_libmxhost(joinpath(@__DIR__, "libmxhost.so"))
    dlopen(host, RTLD_GLOBAL | RTLD_NOW)
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
