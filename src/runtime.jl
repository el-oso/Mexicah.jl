# The Julia runtime is already initialized by the time mexFunction is called —
# MATLAB embeds its own process and Julia is started once per session. This
# module provides a lightweight guard so that any per-session setup (e.g.
# precompiled package state, thread pool) is initialized exactly once across
# all MEX files that ship Mexicah inside the same MATLAB process.

const _initialized = Threads.Atomic{Int}(0)

# The Julia logo as ASCII art (the classic REPL banner), printed to the MATLAB
# command window the first time any Mexicah MEX runs in a session — analogous to
# Julia's own startup banner. Kept as plain ASCII (no ANSI colour) because the
# MATLAB command window does not interpret terminal escape codes. Each line is a
# constant string handed to `mex_printf`, so the whole thing stays juliac
# --trim=safe (no allocation, no dynamic dispatch). Literal backslashes in the
# art are doubled for the Julia string parser.
function _mexicah_print_logo()::Cvoid
    mex_printf("\n")
    mex_printf("               _\n")
    mex_printf("   _       _ _(_)_     |  Built with Mexicah.jl\n")
    mex_printf("  (_)     | (_) (_)    |  Julia, compiled to a MATLAB MEX\n")
    mex_printf("   _ _   _| |_  __ _   |\n")
    mex_printf("  | | | | | | |/ _` |  |\n")
    mex_printf("  | | |_| | | | (_| |  |\n")
    mex_printf(" _/ |\\__'_|_|_|\\__'_|  |\n")
    mex_printf("|__/                   |\n")
    mex_printf("\n")
    return
end

# Print the logo, followed by the optional user-defined `message` (empty = none).
# The message is printed via `mex_printf`'s "%s" path, so any character is safe.
function _mexicah_print_banner(message::String)::Cvoid
    _mexicah_print_logo()
    if !isempty(message)
        mex_printf(message)
        mex_printf("\n\n")
    end
    return
end

# Runs the once-per-session setup the first time any Mexicah MEX entry executes.
# `banner` is an optional user-defined message baked in at build time; the Julia
# logo is always printed. Subsequent calls (this or any other co-resident MEX
# entry sharing the same library) return immediately.
function _mexicah_init_once(banner::String = "")::Cvoid
    Threads.atomic_cas!(_initialized, 0, 1) == 0 || return
    # Place any one-time session setup here (currently just the banner).
    _mexicah_print_banner(banner)
    return
end
