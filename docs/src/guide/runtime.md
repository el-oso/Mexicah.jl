# Julia Runtime and Shared Libraries

## How the runtime is bundled

When `build_mex` is called with `bundle=true` (the default), `juliac --bundle`
copies `libjulia.so` and all required Julia artifacts into the output directory
alongside the MEX file. This makes the bundle self-contained — no Julia
installation is needed on the end-user's machine.

```
mex/
├── myfunction.mexa64
├── libjulia.so              ← shared by all MEX files
├── libjulia-internal.so
├── libopenlibm.so
├── sys.so                   ← trimmed system image
└── mexicah_setup.m
```

## Sharing the runtime across multiple MEX files

When MATLAB loads a MEX file with `dlopen`, the OS dynamic linker maps
`libjulia.so` by its soname. If another MEX file requests the same soname,
the linker reuses the already-mapped copy — the runtime lives in memory
exactly once per MATLAB session, no matter how many MEX files are loaded.

This means:
- Memory footprint does not grow linearly with the number of MEX files.
- GC runs are shared across all MEX files (one GC, no fragmentation).

## The `mexicah_setup.m` file

Before calling any MEX function for the first time, the MATLAB user must run:

```matlab
run('path/to/mex/mexicah_setup.m')
```

This prepends the bundle directory to `LD_LIBRARY_PATH` (Linux) or
`DYLD_LIBRARY_PATH` (macOS) so MATLAB can resolve `libjulia.so` when it loads
the MEX file with `dlopen`.

Add this call to your MATLAB project's startup script to make it transparent.

## Windows

On Windows (`mexw64`) the runtime DLLs must be on the system `PATH` or in the
same directory as the MEX file. `mexicah_setup.m` adds the bundle directory to
`PATH` accordingly. Windows support is a Phase 2 feature.

## Initialization guard

Each MEX file calls `_mexicah_init_once()` at the top of `mexFunction`. This
function uses a `Threads.Atomic{Int}` compare-and-swap to ensure that any
per-session setup code runs exactly once, even if MATLAB calls the MEX function
concurrently from multiple threads.

Because all co-resident Mexicah MEX files share one `libjulia.so` (and therefore
one `_initialized` atomic), the guard fires exactly **once per MATLAB session** —
the first call into any Mexicah MEX trips it, and every later call (from that or
any other Mexicah MEX in the session) returns immediately.

## Startup banner

The first time any Mexicah MEX runs in a session, `_mexicah_init_once` prints the
Julia logo as ASCII art to the MATLAB command window — analogous to Julia's own
startup banner:

```text
               _
   _       _ _(_)_     |  Built with Mexicah.jl
  (_)     | (_) (_)    |  Julia, compiled to a MATLAB MEX
   _ _   _| |_  __ _   |
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |
 _/ |\__'_|_|_|\__'_|  |
|__/                   |
```

The logo always prints. You can add an optional message after it by passing
`message` to `build_mex` (or `build_shared_mex` / `build_all_mex`):

```julia
build_mex(myfunc;
    input_types  = [Float64],
    output_types = [Float64],
    message      = "MyTool v1.0 — © 2026 Example Corp",
)
```

The message is baked into the generated wrapper at build time and printed once,
right below the logo. It is emitted through MATLAB's `mexPrintf` with a literal
`"%s"` format, so any character (including `%`) is safe.

Both the logo and the message are emitted line-by-line from constant strings, so
the whole path stays `juliac --trim=safe` (no allocation, no dynamic dispatch).
GPU MEX files built with [`@mexgpukernel`](../examples/cuda.md) print the logo
too (with no message).
