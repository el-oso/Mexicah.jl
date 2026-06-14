# Opaque Handle Pattern

MATLAB only understands `mxArray` values. Julia structs and GC-managed objects
live on the Julia heap and cannot be returned to MATLAB directly. The **opaque
handle** pattern bridges them: store the Julia object in a registry keyed by a
`UInt64`, give MATLAB that integer, and retrieve the object when MATLAB passes
the key back.

## Why handles?

- The object stays **GC-rooted** (alive) for as long as it is in the registry.
- MATLAB sees a plain `uint64` scalar — a lightweight opaque token.
- Handles are **monotonically increasing and never reused**, so a stale ID
  from a destroyed handle is detected as missing rather than aliasing a new object.
- The registry is **thread-safe** via a `ReentrantLock`.

## Lifecycle

```
MATLAB                              Julia (MEX)
------                              -----------
id = create_solver(A, b)    →   builds object, calls _handle_store!, returns id
x  = run_solver(id)         →   _handle_get(id), calls solver, returns result
    destroy_solver(id)      →   _handle_delete!(id)  — object may now be GC'd
```

## Core API

```julia
Mexicah._handle_store!(obj)         → UInt64   # store and get id
Mexicah._handle_get(id::UInt64)     → Any      # retrieve (returns nothing if missing)
Mexicah._handle_delete!(id::UInt64) → Bool     # remove; true if it existed
Mexicah._handle_count()             → Int      # number of live handles (for leak checks)
```

## Example: custom struct

Define a Julia type you want to persist across MEX calls:

```julia
# examples/handles/solver.jl
using Mexicah

struct FactoredSystem
    L::Matrix{Float64}
    U::Matrix{Float64}
    p::Vector{Int}   # permutation
end
```

Write MEX functions that follow the create → use → destroy lifecycle:

```julia
@mexfunction function factorize_system(A::Matrix{Float64})::UInt64
    # LU factorization (placeholder — swap for your real solver)
    n = size(A, 1)
    L = tril(A) + I
    U = triu(A)
    p = collect(1:n)
    return Mexicah._handle_store!(FactoredSystem(L, U, p))
end

@mexfunction function solve_system(
        id::UInt64, b::Vector{Float64}
)::Vector{Float64}
    sys = Mexicah._handle_get(id)
    sys === nothing && error("solve_system: invalid or destroyed handle $id")
    fs = sys::FactoredSystem
    # simplified back-substitution placeholder
    return fs.U \ (fs.L \ b[fs.p])
end

@mexfunction function destroy_system(id::UInt64)::Bool
    return Mexicah._handle_delete!(id)
end
```

Build all three MEX files:

```bash
julia --project=. -e '
    using Mexicah
    include("examples/handles/solver.jl")
    build_all_mex(; output="mex/")
'
```

## MATLAB session

```matlab
addpath('mex/')
mexicah_setup          % set up library paths

A = [4.0, 3.0; 6.0, 3.0];
b = [10.0; 12.0];

id = factorize_system(A);   % → uint64 scalar

x  = solve_system(id, b);   % use the factorization
% x ≈ [1; 2]

ok = destroy_system(id);    % release; ok = 1 (true)
```

## Leak detection

Call `Mexicah._handle_count()` inside any MEX function to check that handles
are being cleaned up:

```julia
@mexfunction function live_handle_count()::Int64
    return Int64(Mexicah._handle_count())
end
```

```matlab
n = live_handle_count();   % should be 0 when nothing is open
```

## Multiple object types

The registry stores `Any`, so you can mix types freely. Each type should define
its own typed accessor that narrows the `Any`:

```julia
function _get_factored(id::UInt64)::FactoredSystem
    obj = Mexicah._handle_get(id)
    obj isa FactoredSystem || error("handle $id is not a FactoredSystem")
    return obj
end
```

Passing a wrong-type handle fails at the Julia `isa` check, not silently.
