# The Julia runtime is already initialized by the time mexFunction is called —
# MATLAB embeds its own process and Julia is started once per session. This
# module provides a lightweight guard so that any per-session setup (e.g.
# precompiled package state, thread pool) is initialized exactly once across
# all MEX files that ship Mexicah inside the same MATLAB process.

const _initialized = Threads.Atomic{Int}(0)

function _mexicah_init_once()::Cvoid
    Threads.atomic_cas!(_initialized, 0, 1) == 0 || return
    # Place any one-time session setup here (currently a no-op).
    return
end
