# Run with: julia --project=test test/runtests.jl
using Mexicah
using ReTestItems

# Skip tests tagged :matlab when MATLAB symbols are not present in the process
# (standard dev workflow — no MATLAB installation needed to run the test suite).
const MATLAB_AVAILABLE = try
    ptr = cglobal(:mxGetScalar)
    ptr != C_NULL
catch
    false
end

runtests(
    ti -> !((!MATLAB_AVAILABLE) && (:matlab in ti.tags)),
    Mexicah;
    testitem_timeout=120,
    nworkers=0,
)
