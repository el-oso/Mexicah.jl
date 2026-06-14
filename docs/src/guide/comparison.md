# Comparison with MATFrost.jl

[MATFrost.jl](https://github.com/ASML-Labs/MATFrost.jl) is the other Julia→MATLAB
bridging library. The two projects share the same goal — call Julia from MATLAB —
but make opposite architectural bets.

## Architecture

| | **Mexicah** | **MATFrost** |
|---|---|---|
| Delivery model | AOT-compiled MEX binary (`juliac --trim`) | Runtime server (`matfrost_spawn`) |
| Julia on end-user machine | **Not required** | Required |
| IPC mechanism | None — MEX runs in-process | TCP socket (loopback) |
| Startup latency | MEX loads in milliseconds | Julia server starts once, stays alive |
| Per-call overhead | Minimal — just the MEX ccall | Serialization + TCP round-trip |

Mexicah compiles Julia functions into standalone `.mexa64`/`.mexw64` files that
MATLAB loads like any other MEX. There is no Julia process, no sockets, and no
runtime dependency on the target machine. The trade-off: `juliac --trim=safe` is
stricter than full Julia — not all packages compile cleanly.

MATFrost keeps a persistent Julia process running alongside MATLAB and communicates
over TCP. Compilation is trivial (any Julia code works), but the Julia runtime must
be installed on every machine that runs the code.

## Type support

| Julia type | Mexicah | MATFrost |
|---|---|---|
| `Float64` scalar | ✓ | ✓ |
| `Vector{Float64}` | ✓ zero-copy | ✓ |
| `Matrix{Float64}` | ✓ zero-copy | ✓ |
| `Int32` / `Int64` | ✓ | ✓ |
| `Bool` | ✓ | ✓ |
| `UInt64` (opaque handle) | ✓ raw bits | ✗ |
| `SparseMatrixCSC{Float64}` | ✓ | ✓ |
| `Vector{ComplexF64}` | ✓ zero-copy (R2018a+) | ✓ |
| `String` | ✓ `mxGetString` / `mxCreateString` | ✓ |
| Nested structs | via handle registry | ✓ native |
| Cell arrays | ✗ | ✓ |
| `DateTime` | ✗ | ✓ |
| `DataFrame` / table | via handle registry | ✗ |

## Deployment comparison

**Mexicah** — ship the `.mexa64` files:
```
my_project/
  solve_lp.mexa64        ← compiled MEX binary
  setup_paths.m          ← generated once by build_mex
```

The recipient needs only MATLAB. No Julia installation, no network access, no
server management. This is the right choice for distributing toolboxes.

**MATFrost** — ship a Julia environment:
```
my_project/
  julia/                 ← full Julia environment
  src/MyFunctions.jl     ← source (not compiled)
  start_server.m         ← calls matfrost_spawn
```

The recipient needs Julia installed and the correct package environment
resolved. This is the right choice during development or when you need the
full Julia type system.

## Choosing between them

| Situation | Recommendation |
|---|---|
| Distributing a toolbox to colleagues without Julia | **Mexicah** |
| Using packages that don't compile with `juliac --trim` | **MATFrost** |
| Maximum array throughput (no IPC) | **Mexicah** |
| Rich type vocabulary (cell arrays, DateTime, nested structs) | **MATFrost** |
| Calling back from Julia into MATLAB | **MATFrost** |
| Autonomous operation (no persistent process) | **Mexicah** |

The projects are complementary. You can use Mexicah for performance-critical
numerical kernels and MATFrost for exploratory work or where type richness matters.
