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

### libmx host (MATLAB-less :matlab tests on Linux)

The libmx host C source now lives in **LibMx** (`LibMx/cruntime/libmxhost.c`) — one
canonical source shared by Mexicah's tests, LibMx's tests, and Unmex's runtime.
`test/runtests.jl` builds it on Linux via `LibMx.build_libmxhost(...)` and preloads the
`.so` with `RTLD_GLOBAL`, making `cglobal(:mxGetScalar)` succeed and enabling all
`:matlab`-tagged tests. No separate build step is needed (the built `.so` is gitignored).
The real-MATLAB CI (`MATLAB.yml`) runs `build_fixtures.jl`, not `runtests.jl`, so the host
never shadows real MATLAB there.

## Architecture

`src/Mexicah.jl` is the module root (exports + `include` calls only).

| File | Contents |
|---|---|
| `types.jl` | `MxArray = Ptr{Cvoid}`, mxClassID constants, `mex_ext()` |
| `api.jl` | `ccall` wrappers for all MATLAB C API functions (no headers required) |
| `marshaling.jl` | Zero-copy loaders and writers per Julia type; `marshaler_for`, `load_arg`, `store_result` |
| `contracts.jl` | `AbstractMexMarshaler` and `AbstractMexExportable` TypeContracts interfaces; `@verify` for all marshalers |
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
- TypeContracts 0.13+: `@contract` emits method definitions serialized into the precompile cache — no `__init__` / re-registration step needed. Do not reference `TypeContracts._registry` or `TypeContracts.MethodSpecMin` (both removed in 0.13).
- All `store!` methods in `marshaling.jl` use `::Any` as the third argument so `hasmethod` in TypeContracts contracts returns `true` for any marshaler value type.
- All `create` methods use `::Tuple` (not `::Dims{N}`) for the same reason.
- `@mexfunction` macro: `_extract_argtypes` uses `Any[]` (not `Expr[]`) because Julia type names in function signatures are `Symbol`s, not `Expr`s.
- **Contract verification is structural and lives in `test/contracts_test.jl`, not `contracts.jl`.** Marshalers implement `AbstractMexMarshaler` via Holy-Trait dispatch and do NOT subtype it, so a one-arg `@verify Marshaler` is a vacuous no-op (it scans `supertypes`, finds no specs, passes). The test suite uses the two-arg `check_contract(T, AbstractMexMarshaler)` + `check_trim_compat(T, AbstractMexMarshaler)` (TypeContracts ≥ 0.13.1's `for_contract` path) for every marshaler, post-load — `Base.return_types` on the `@generated` marshalers is world-age-fragile during the defining module's own precompile, so it must run after load. When adding a marshaler, add it to that testitem's list.
- **`return` in `@testitem` does NOT work**: ReTestItems evaluates each top-level statement in the testitem body as a SEPARATE `eval` call, so `&&return` exits only the current statement's eval, not the entire test. Use `if (...) ... end` blocks to skip optional-package tests instead.
- **JET static-analysis gate (`test/jet_test.jl`).** `JET` (test-only dep) runs `report_call` over every concrete marshaler's `load`/`store!`/`create` (derived via `marshaler_for(T)` for each supported `T`), scoped with `target_modules=(Mexicah,)`. This catches potential `MethodError`s / inference failures *before runtime* — the complement to `check_trim_compat` (which only flags dynamic dispatch). It is **untagged** (not `:matlab`): `report_call` is pure static analysis and never executes the libmx `ccall`s, so it runs in every environment. When adding a marshaler, add its `T` to that testitem's list. JET 0.11.x on Julia 1.12.

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
  `mxCreateCharArray` also takes `mwSize` dims — use `@mxccall730` if Windows
  char-matrix tests fail (currently uses `@mxccall`; no Windows CI coverage yet).

### `marshaler_for` dispatch order (`src/marshaling.jl`)

Order matters — later branches are not reached if an earlier one matches:

1. Exact-type sparse matches (`SparseMatrixCSC{Float64,Int}`, `{ComplexF64,Int}`,
   `{Bool,Int}`) — before the generic `T <: AbstractSparseMatrix` fallback.
2. `T <: Array` block — in order within the block:
   - Bool/Complex/DenseNumeric element types
   - `ET === String && ND == 1` → `StringVectorMarshaler` (cell of char)
   - `ET === String && ND == 2` → `StringArrayMarshaler` (MATLAB string array)
   - `ET === Char && ND == 2` → `CharMatrixMarshaler`
   - `_is_user_struct(ET)` → `StructArrayMarshaler{ET, ND}` (any rank; `StructVectorMarshaler`/`StructMatrixMarshaler` are aliases for N=1/N=2)
3. `T <: Tuple` — comes **after** the Array block and **before** `_is_user_struct`.
   Critical: `isstructtype(Tuple{...})` returns `true`, so if the user-struct branch
   ran first it would swallow all Tuple types.
4. `_is_user_struct(T)` — plain `struct` and `NamedTuple` (→ `StructMarshaler{T}`).

### `_render_type` dispatch order (`src/codegen.jl`)

Same ordering constraint: the `T <: Tuple` branch must appear **before** the
`isstructtype(T)` / user-struct branch, for the same reason.

### Static dispatch in `@generated` bodies (`src/marshaling.jl`)

All `@generated` marshalers (`StructMarshaler`, `StructArrayMarshaler{T,N}`,
`CellArrayMarshaler`) resolve field marshalers at **code-generation time**, not at
runtime. The pattern:

```julia
# Code-gen phase (before `return`):
let m = marshaler_for(fieldtype(T, k)), MT = typeof(m)
    :(load($MT(), mx_get_field(pa, Csize_t(i - 1), $(string(fieldname(T, k))))))
end
```

`marshaler_for` is called once during `@generated` body evaluation; `typeof(m)`
is interpolated as a literal concrete type into the generated AST. The emitted code
has no runtime `marshaler_for` calls — every `load`/`store!` resolves to a
concrete monomorphic method. **Do not revert to emitting `marshaler_for($(FT))`
as a runtime call** — that returns `Any`-typed and breaks type stability.

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

### `StringArrayMarshaler` — `Matrix{String}` ↔ MATLAB string array (`src/marshaling.jl`)

MATLAB's `string` array (R2016b+) is **opaque** in the legacy C Matrix API — there
is no `mxSTRING_CLASS` (the enum stops at `mxOBJECT_CLASS = 18`) and no create/get
for it. The marshaler bridges through a cell-of-char using MATLAB's own builtins via
`mex_call_matlab_1` (a 1-in/1-out `mexCallMATLAB` wrapper, `src/api.jl`):

- **load**: `mexCallMATLAB("cellstr", strArr)` → cell of char, then `mx_get_string`
  per element.
- **output**: build a cell of char, then `mexCallMATLAB("string", cell)` → string
  array. Asymmetric like `String` — `store!` is a no-op and `create` is a placeholder;
  the real output is a `store_result(::Matrix{String})` override (concrete
  `Matrix{String}`, so it does not capture `Vector{String}` → cell).

Mapping is **Option B**: `Matrix{String}` → string array, `Vector{String}` → cell.
A "1-D" MATLAB string array is really `1×N`, so it round-trips as a `1×N Matrix{String}`.
If this split becomes awkward, switch to a wrapper type (Option A) — the bridge is
reused, only the dispatch type changes.

### libmx host (`LibMx/cruntime/libmxhost.c`, built via `LibMx.build_libmxhost`)

~470-line C file. Key struct:

```c
typedef struct _mx_stub {
    int classid, is_complex, is_sparse;
    size_t m, n, ndim, nelems; size_t *dims;
    void *pr, *pi;                        /* pr = char data (uint16_t) for MX_CHAR_CLASS */
    size_t nzmax, *ir, *jc;
    int nfields; char **fieldnames;
    struct _mx_stub **fields;             /* [nfields × nelems] column-major */
    struct _mx_stub **cells;
} mx_stub_t;
```

All function names are bare (no `_730` suffix) because on Linux `@mxccall730`
expands to bare names. **Char data is `uint16_t` (mxChar) everywhere** —
`mxCreateString`, `mxCreateCharArray`, `mxGetString`, `mxGetChars` all agree, and
`element_size(MX_CHAR_CLASS)` returns 2, so `deep_copy` is byte-correct for char
arrays. `mxCreateStructArray(ndim, dims, …)` is the N-D struct array (field storage
`[nfields × nelems]`, same as the 2-D `mxCreateStructMatrix`). `mxGetScalar` converts
the first element **per its mxClassID** (int/logical/char are not double-encoded) — a
raw `double` reinterpret would corrupt non-double scalar/struct fields.
`mexCallMATLAB` is faked for only the two builtins the string-array marshaler uses:
`"string"` (cell → opaque `MX_STRING_CLASS` wrapping the same cells) and `"cellstr"`
(string array → cell); both copy shape and deep-copy elements. `mxDestroyArray`
recurses into struct fields and cell children. `mxDuplicateArray` performs a deep copy.
`mexErrMsgIdAndTxt` calls `abort()` — marshaler errors surface as Julia exceptions
in unit tests, so this path is never reached. The stub also tracks a live-array count
(`g_mx_live`, incremented in `alloc_stub`/`deep_copy`, decremented in `mxDestroyArray`)
exposed via the non-`mx`-prefixed `mx_stub_live_count()` / `mx_stub_reset_count()`;
the regression test (`test/marshaling_test.jl`) samples it across success and throwing
paths. Note the stub **does not** emulate MATLAB's return-time auto-free of temporary
`mxArray`s, so it is intentionally *stricter* than real MATLAB — the counter is a
**temporary-cleanup-discipline guard** (catches a marshaler that orphans a temporary),
not a real-MATLAB leak detector (see the Memory-safety section). Each child counted
individually, so a fully-destroyed parent nets back to baseline.

## TypeContracts dependency

Registered in the Julia General registry; Mexicah requires `0.13.1` (for the
structural two-arg `check_contract(T, I)` / `@verify ... for_contract=` used to
verify the marshalers, which don't subtype the contract). Both `Project.toml` and
`test/Project.toml` resolve it from General — no `[sources]` entries needed.

## Memory-safety: explicit temporary cleanup (best-practice hygiene, not a leak fix)

**Crucial context first — Mexicah has no cross-call `mxArray` leaks, by construction.**
MATLAB's MEX memory manager **automatically destroys every temporary `mxArray`** (one
created with `mxCreate*` and *not* returned in `plhs`) when the MEX-function returns —
**including when it errors out** (`mexErrMsgIdAndTxt` longjmps and MATLAB frees
temporaries during the unwind). A full audit confirmed nothing escapes that net:

- **No `mexMakeArrayPersistent`, `mxMalloc`, `mxCalloc`, `mxRealloc`** anywhere in
  `src/`/`ext/` → no persistent `mxArray` or raw buffer survives a call.
- The **handle registry** (`handles.jl`) stores **Julia objects** (`Dict{UInt64,Any}`),
  **not** `mxArray`s. (Those Julia objects live until the MATLAB user calls
  `destroy_*` → `_handle_delete!` — that is the *one* place memory grows across calls,
  by design, and is unrelated to `mxArray` lifetime.)
- Every `mxCreate*` site (`marshaling.jl`, DataFrames ext) yields a call-scoped
  temporary or an array handed to `plhs` / attached to a returned parent.

So the `try/finally` guards added to the marshalers are **explicit best-practice
cleanup**, *not* fixes for real leaks: MathWorks recommends destroying temporaries you
no longer need (especially inside loops) to cap **peak memory**, and being explicit on
error paths is defensive and forward-proofs any future persistent/caching path (where
MATLAB's auto-free would *not* save you). They are the Julia-idiomatic, trim-safe
analogue of ParselTongue's `__attribute__((cleanup))` (a `Bool` flag + concrete
`mx_destroy_array` call — no dynamic dispatch, passes `check_trim_compat`). ParselTongue
*needed* its guards because CPython does **not** auto-free extension-owned allocations;
MATLAB does, so here the benefit is peak-memory + robustness, not leak prevention.

**Ownership model (confirmed against the libmx stub, matches MATLAB):**
`mxSetField`/`mxSetCell` *transfer* ownership of the child to the parent (and destroy
any previous occupant); `mxDestroyArray` recurses into fields/cells; MATLAB owns
`plhs[i]` only *after* `unsafe_store!` hands it over; `mexCallMATLAB` does **not** take
ownership of its inputs — the caller owns them (MATLAB still auto-frees them at return).

**What each guard does (per allocation in `src/marshaling.jl`):**
- `store_result` (generic): `owned` flag + `try/finally`; frees `pa` if `store!` throws
  before `unsafe_store!`, then `owned=false` "disarms" once MATLAB takes ownership.
- `store_result(::Matrix{String})` / `load(::StringArrayMarshaler)`: the `cell`
  `mexCallMATLAB` input/output is destroyed promptly in `finally` instead of waiting for
  MATLAB's return-time sweep (peak memory; still freed without the guard).
- Composite `store!` (`StructMarshaler`/`StructArrayMarshaler`/`CellArrayMarshaler`):
  `attached` flag + `try/finally` per child `fpa`, freed promptly if the nested `store!`
  throws before `mxSetField`/`mxSetCell` transfers ownership. String-field fast paths
  (`mx_set_field!(pa, …, mx_create_string(…))`) have no intermediate to guard.
- Leaf scalar/array marshalers can't throw after allocating an owned intermediate, so
  the generic `store_result` guard already covers them.

**Regression check (discipline guard, *not* a MATLAB-leak detector):**
`test/marshaling_test.jl` testitem `"leak-regression: store_result frees intermediates
on success + error"` (tagged `:matlab`). The libmx stub exports
`mx_stub_live_count()`/`mx_stub_reset_count()` (a live-array counter). **The stub
deliberately does *not* model MATLAB's return-time auto-free, so it is stricter than
real MATLAB** — that makes it a useful guard that catches a future marshaler which
orphans a temporary without destroying it (under the stub it shows as a non-zero net;
in real MATLAB it would merely raise peak memory). The test samples the count across
clean round trips and throwing paths (a `String` field with an embedded NUL forces
`mxCreateString`'s `Cstring` conversion to throw mid-`store!`) and asserts it nets to
baseline. Teeth-checked: nulling a guard makes it fail; restoring it passes. Do **not**
read a failure as "MATLAB leaked" — read it as "a temporary wasn't explicitly freed."
