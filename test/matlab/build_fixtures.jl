# Builds one MEX fixture per marshaled type into `mex/`, for the MATLAB
# end-to-end CI (.github/workflows/MATLAB.yml). The fixtures live in the
# MexFixtures package (this dir) so juliac can `import` them.
#
# Run from the repo root (no --project needed; this activates MexFixtures):
#   julia test/matlab/build_fixtures.jl
#
# Requires `juliac` on PATH. build_mex compiles against the active project
# (MexFixtures), which provides both Mexicah and the fixture module.
#
# juliac --bundle copies the Julia runtime next to the MEX and errors if those
# files already exist, so we bundle once (first fixture) and build the rest with
# bundle=false into the same dir; they share that libjulia, resolved at load time
# via the loader path the workflow exports (mex/, mex/lib, mex/lib/julia).

using Pkg
Pkg.activate(joinpath(@__DIR__, "MexFixtures"))
Pkg.instantiate()

using Mexicah
using MexFixtures

const OUT = get(ENV, "MEXICAH_FIXTURE_DIR", "mex")

# One shared juliac library (single Julia runtime) + one thin gateway MEX per
# fixture, so the fixtures can be called together in one MATLAB session.
build_shared_mex(MexFixtures.FIXTURES; output = OUT, name = :mexicah_fixtures)

@info "Mexicah: built $(length(MexFixtures.FIXTURES)) fixtures into $(abspath(OUT))"
