# The Julia runtime is already initialised by the time mexFunction is called —
# MATLAB embeds its own process and Julia is started once per session. This
# module provides a lightweight guard so that any per-session setup (e.g.
# precompiled package state, thread pool) is initialised exactly once across
# all MEX files that ship Mexicah inside the same MATLAB process.

const _initialised = Threads.Atomic{Int}(0)

function _mexicah_init_once()::Cvoid
    Threads.atomic_cas!(_initialised, 0, 1) == 0 || return
    # Place any one-time session setup here (currently a no-op).
    return
end
