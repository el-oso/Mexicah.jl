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
