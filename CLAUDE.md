# CLAUDE.md

## Commands

```julia
# Run all tests
julia --project=test test/runtests.jl

# Run a single test item by name pattern
julia --project=test -e 'using Mexicah, ReTestItems; runtests(Mexicah; name=r"marshaler")'

# Build docs
julia --project=docs docs/make.jl

# Format all source files (run before every commit)
runic -i src/ ext/ test/ docs/make.jl

# Instantiate test environment (first time)
julia --project=test -e 'using Pkg; Pkg.instantiate()'

# The `mexicah` CLI is a Julia 1.12 app (Project.toml [apps]); run it directly:
julia -m Mexicah help
# or install the launcher: julia -e 'using Pkg; Pkg.Apps.develop(path=".")'
```

### libmx stub (MATLAB-less :matlab tests on Linux)

Build before running tests locally when MATLAB is not installed:

```bash
cc -O2 -shared -fPIC -o test/matlab/libmx_stub/libmx_stub.so \
   test/matlab/libmx_stub/libmx_stub.c
```

Or use the helper: `julia test/matlab/libmx_stub/build.jl`

`test/runtests.jl` preloads the stub with `RTLD_GLOBAL` on Linux if the `.so`
exists, making `cglobal(:mxGetScalar)` succeed and enabling all `:matlab`-tagged
tests. The `.so` is gitignored. CI builds it automatically (Linux only; macOS and
Windows use real MATLAB via `MATLAB.yml`).

## Architecture

`src/Mexicah.jl` is the module root (exports + `include` calls only).

| File | Contents |
|---|---|
| `types.jl` | `MxArray = Ptr{Cvoid}`, mxClassID constants, `mex_ext()` |
| `api.jl` | `ccall` wrappers for all MATLAB C API functions (no headers required) |
| `marshaling.jl` | Zero-copy loaders and writers per Julia type; `marshaler_for`, `load_arg`, `store_result` |
| `contracts.jl` | `AbstractMexMarshaler` and `AbstractMexExportable` TypeContracts interfaces; `@verify` for all marshalers; `_reinit_registry!` |
| `runtime.jl` | `_mexicah_init_once()` — atomic init guard for each MEX file |
| `codegen.jl` | `generate_mex_source(...)` — generates the Julia file passed to juliac |
| `cuda_driver.jl` | Raw `libcuda` ccall wrappers (`_cu_*`, `_cuda_init_once!`) for the GPU MEX runtime — no CUDA.jl dependency |
| `cuda_codegen.jl` | `generate_cuda_mex_source(...)` — GPU MEX wrapper embedding PTX; `_parse_ptx_entry` |
| `build.jl` | `build_mex(...)` + `_compile_generated_source(...)` — juliac subprocess pipeline; `_write_setup_m` |
| `macros.jl` | `@mexfunction`, `@mexgradient`, `@mexgpukernel`, `_MEX_EXPORTS` registry, `build_all_mex` |
| `cli.jl` | `mexicah` CLI app — `Base.@main` + `_cli_run`; `[apps.mexicah]` in Project.toml |

Extensions in `ext/`:
- `MexicahDataFramesExt.jl` — handle-based DataFrame lifecycle + value conversion via MATLAB struct arrays
- `MexicahEnzymeExt.jl` — `_enzyme_gradient_mex` via `Enzyme.autodiff`
- `MexicahForwardDiffExt.jl` — `_forwarddiff_gradient_mex` via `ForwardDiff.gradient`
- `MexicahJuMPExt.jl` — stateless LP/QP solvers + handle-based JuMP model lifecycle
- `MexicahMTKExt.jl` — `build_mex_from_mtk` via `MTK.generate_rhs/jacobian`
- `MexicahCUDAExt.jl` — build-time only; extracts PTX from a KernelAbstractions `@kernel` (via CUDA's `@device_code_ptx`) for `@mexgpukernel`. Requires both CUDA and KernelAbstractions (dual trigger). Never compiled into the MEX.

Core src additions:
- `handles.jl` — thread-safe `_handle_store!` / `_handle_get` / `_handle_delete!` / `_handle_count`; opaque UInt64 IDs bridge Julia heap objects to MATLAB
- `linalg.jl` — `la_*` functions: stateless helpers (det, svd, qr, eig_sym, …) + handle-based LU/Cholesky; LinearAlgebra is a stdlib, so it is a hard dep in `[deps]`, not an extension

## Requirements

- Format with `runic -i` before every commit.
- Tests use `@testitem` (ReTestItems.jl). No bare `@testset`. Test files are named `*_test.jl`.
- Run tests via `julia --project=test test/runtests.jl`, NOT `runtests("test/")`.
- MATLAB-dependent tests carry `tags = [:matlab]` and are skipped automatically when MATLAB is not loaded.
- TypeContracts: `_reinit_registry!()` must be called from `__init__()` — the `_registry` dict is not preserved across precompile cache loading.
- All `store!` methods in `marshaling.jl` use `::Any` as the third argument so `hasmethod` in TypeContracts contracts returns `true` for any marshaler value type.
- All `create` methods use `::Tuple` (not `::Dims{N}`) for the same reason.
- `@mexfunction` macro: `_extract_argtypes` uses `Any[]` (not `Expr[]`) because Julia type names in function signatures are `Symbol`s, not `Expr`s.
- All `@verify` calls in `contracts.jl` use `trim_compat=true` to scan implementation IR for juliac --trim=safe incompatibilities.
- **`return` in `@testitem` does NOT work**: ReTestItems evaluates each top-level statement in the testitem body as a SEPARATE `eval` call, so `&&return` exits only the current statement's eval, not the entire test. Use `if (...) ... end` blocks to skip optional-package tests instead.

## Marshaling internals

### ccall macros (`src/api.jl`)

Two platform-dispatch macros wrap every MATLAB C API call:

- **`@mxccall`** — bare symbol on Linux, library-qualified on Windows, `_mxsym`
  resolver on macOS. Use for functions that exist in both the 32-bit and 64-bit APIs.
- **`@mxccall730`** — same as `@mxccall` but appends `_730` on Windows to select
  the 64-bit large-array API (indexes as `mwSize`/`mwIndex`). **Required** for any
  function that takes or returns array dimensions or element counts:
  `mxCreateCellMatrix`, `mxGetCell`, `mxSetCell`, `mxCreateSparse`,
  `mxCreateSparseLogicalMatrix`, `mxCreateStructMatrix`, etc.

### `marshaler_for` dispatch order (`src/marshaling.jl`)

Order matters — later branches are not reached if an earlier one matches:

1. Exact-type sparse matches (`SparseMatrixCSC{Float64,Int}`, `{ComplexF64,Int}`,
   `{Bool,Int}`) — before the generic `T <: AbstractSparseMatrix` fallback.
2. `T <: Array` block — catches `Vector{String}` (→ `StringVectorMarshaler`) before
   the struct-vector branch; `ET`, `ND` pulled from type params inside the block.
3. `T <: Tuple` — comes **after** the Array block and **before** `_is_user_struct`.
   Critical: `isstructtype(Tuple{...})` returns `true`, so if the user-struct branch
   ran first it would swallow all Tuple types.
4. `_is_user_struct(T)` — plain `struct` and `NamedTuple`.

### `_render_type` dispatch order (`src/codegen.jl`)

Same ordering constraint: the `T <: Tuple` branch must appear **before** the
`isstructtype(T)` / user-struct branch, for the same reason.

### `CellArrayMarshaler{T}` (`src/marshaling.jl`)

`@generated` over `Tuple` element types — same trim-safe pattern as
`StructMarshaler`. `fieldtype(T, i)` and `fieldcount(T)` are evaluated at codegen
time (compile-time constants), so no runtime reflection reaches `juliac --trim=safe`.
A concrete probe type is used for `@verify`:

```julia
const _CellProbe = Tuple{Float64, Int64}
@verify CellArrayMarshaler{_CellProbe} trim_compat = true
```

`CellArrayMarshaler` defers element-type validation to instantiation time: calling
`marshaler_for(Tuple{ComplexF64})` succeeds; the error (if `ComplexF64` is
unsupported as a cell element) surfaces only when the `@generated` body runs.

### libmx stub (`test/matlab/libmx_stub/libmx_stub.c`)

~400-line C file. Key struct:

```c
typedef struct _mx {
    int classid, is_complex, is_sparse, is_cell;
    size_t m, n, ndim, nelems; size_t *dims;
    void *pr, *pi;
    size_t nzmax, *ir, *jc;
    int nfields; char **fieldnames; struct _mx **fields; /* nfields × nelems */
    struct _mx **cells;
} mx_stub_t;
```

All function names are bare (no `_730` suffix) because on Linux `@mxccall730`
expands to bare names. `mxDestroyArray` recurses into struct fields and cell
children. `mxDuplicateArray` performs a deep copy. `mexErrMsgIdAndTxt` calls
`abort()` — marshaler errors surface as Julia exceptions in unit tests, so this
path is never reached.

## TypeContracts dependency

Developed locally at `/home/el_oso/Documents/claude/TypeContracts`, added as a path source in `Project.toml` and `test/Project.toml`.
