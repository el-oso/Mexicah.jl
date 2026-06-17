# Roadmap

Forward-looking work for Mexicah.jl, consolidated from the docs, the GPU
feasibility notes, and a code audit (2026-06-16). Ordered by priority within each
section; **Section 1 (correctness/robustness) should come first** — those are
latent defects, the rest are features and polish.

## Status (v0.22.0)

- End-to-end MATLAB CI is green and blocking on Linux, Windows, and macOS:
  19 asserted fixtures in one session + sparse (including complex and logical), per OS.
- Full Julia test suite green (81 tests, 253 assertions); docs build clean.
- `:matlab`-tagged marshaler round-trips now run in regular CI (without MATLAB) via
  the `libmx_stub.so` preloaded on Linux runners.
- Marshaler coverage: real-numeric scalars (`Float64/Float32`, `Int8/16/32/64`,
  `UInt8/16/32/64`), `Bool`, dense `Array{T,N}` of any supported numeric element
  type and rank, logical `Array{Bool,N}`, `SparseMatrixCSC{Float64,Int}`,
  `SparseMatrixCSC{ComplexF64,Int}`, `SparseMatrixCSC{Bool,Int}`,
  complex `Array{ComplexF64,N}` **and `Array{ComplexF32,N}`**, flat
  `struct`/`NamedTuple` (in & out), **`Vector{<struct>}` ↔ N×1 struct array**,
  **`Matrix{<struct>}` ↔ M×N struct array**, `Tuple{A,B,…}` ↔ 1×N cell array,
  `Vector{String}` ↔ N×1 cell of char, **`Matrix{Char}` ↔ M×N char array**,
  `String`, `UInt64` handles, and multiple outputs.

## Recently completed (v0.22.0)

- **§1 coverage:** `Matrix{S}` ↔ M×N MATLAB struct array (`StructMatrixMarshaler{T}`);
  `Matrix{Char}` ↔ M×N MATLAB char array (`CharMatrixMarshaler`). Both tested via
  the libmx stub with round-trip `:matlab`-tagged tests.
- **§4 dispatch:** All `@generated` marshaler bodies (`StructMarshaler`,
  `StructVectorMarshaler`, `StructMatrixMarshaler`, `CellArrayMarshaler`) now
  resolve field marshalers at **code-generation time** (interpolating the concrete
  marshaler type into the generated AST) rather than as runtime `marshaler_for`
  calls. All `load`/`store!` call sites in generated MEX code are now fully
  type-stable — no `Any`-typed dynamic dispatch in the hot field-iteration paths.

## Recently completed (v0.21.0)

- **§1 coverage:** `SparseMatrixCSC{ComplexF64,Int}` ↔ complex sparse double
  (split Pr/Pi over shared Ir/Jc); `SparseMatrixCSC{Bool,Int}` ↔ sparse logical
  (`mxCreateSparseLogicalMatrix`, values via `mxGetData` as `Cuchar`).
- **§1 coverage:** `Tuple{A,B,…}` ↔ 1×N MATLAB cell (heterogeneous, @generated
  element unrolling at compile time); `Vector{String}` ↔ N×1 cell of char.
- **§3 MATLAB-less stub:** `test/matlab/libmx_stub/libmx_stub.c` — a ~400-line C
  shared library implementing ~45 `libmx` entry points over a minimal `mx_stub_t`
  heap struct. Preloaded with `RTLD_GLOBAL` on Linux CI runners so that all
  `:matlab`-tagged tests (marshaler round-trips) run without a MATLAB license.
  7 previously-skipped `:matlab` tests now run in the regular `CI.yml` workflow.

## Recently completed (v0.20.0)

- **§1 coverage:** `Vector{<struct>}` ↔ N×1 MATLAB struct array; `ComplexF32`
  arrays.
- **§4 cleanup:** unified the type registries — `codegen._type_literal` is now a
  recursive renderer with `marshaler_for` as the sole support gatekeeper; Linux
  self-contained loading via a `patchelf` `$ORIGIN` RUNPATH (falls back to
  `LD_LIBRARY_PATH` if `patchelf` is absent).

## Recently completed (v0.19.0)

- **§1 correctness — all four audit defects fixed:** exceptions are trapped in the
  generated `mexFunction` (→ `mex_errorf`, no more process abort); outputs are
  stored only up to `max(nlhs,1)` (no past-`plhs` write for multi-output calls);
  `_load_dims` errors on rank mismatch instead of reading past `mxGetDimensions`;
  the gateway raises a MATLAB error on impl load failure.
- **§2:** logical (`Bool`) arrays.
- **§4:** multi-output + struct-input MATLAB fixtures (would have caught the
  `nlhs` defect).
- **§5:** removed dead `to_mx`; `mexicah_setup.m` no longer sets the stale
  macOS `DYLD_LIBRARY_PATH`; `_validate_method` uses `first`, not `only`.
- **§3:** added the missing `[compat]` bounds (`LinearAlgebra`, `ModelingToolkit`).

## 1. Marshaler coverage

### Later

- **MATLAB `string` arrays** (R2016b+ `string` type, `mxSTRING_CLASS`) — distinct
  from char arrays; requires a different C API and a new stub classid. Deferred.
- **N-D struct arrays** (`Array{S,N}` for N≥3) — `Vector{S}` (N=1) and `Matrix{S}`
  (N=2) are done; higher ranks need `mxCreateStructArray` (not just
  `mxCreateStructMatrix`).

## 2. Distribution

- **Register in the General registry.** All AutoMerge criteria are now met:
  - `TypeContracts 0.13` merged into General (2026-06-17).
  - `[sources]` blocks removed from `Project.toml` and `test/Project.toml`; both
    Manifests resolve `TypeContracts` from General (git-tree-sha1 `58f93c70`).
  - MIT license, upper-bounded `[compat]` for all deps, tests + CI, Documenter,
    TagBot, CompatHelper, and LLM disclosure in README are all in place.

  **Next step:** Trigger [Registrator](https://github.com/JuliaRegistries/Registrator.jl)
  — comment `@JuliaRegistrator register` on a commit in this repo, or use the web UI.
  The PR will auto-merge after the 3-day new-package cooloff.

## 3. Cleanup & polish

- Add `docs/src/assets/logo.png` + `favicon.ico` (the Vitepress build warns they
  are missing). **In progress** — a designer is producing the assets; drop them in
  and DocumenterVitepress picks them up automatically.

## 4. GPU follow-ons (deferred — needs a CUDA + MATLAB host)

Scheduled last: unlike everything above, this work cannot be developed or
validated on the current machine or on hosted CI. It needs a single host with
**both** an NVIDIA GPU/CUDA (to extract PTX and run the kernel) **and** MATLAB (to
exercise the MEX end to end), which will take time to provision. Hosted runners
have neither together. Until that host exists, treat this section as blocked.

The CUDA MVP is the narrowest surface (`docs/src/examples/cuda.md`); the CPU-side
Float32/N-D work in v0.18.0 makes the generalization tractable once a host is
available.

- **Multiple outputs** (currently exactly one).
- **Float32 / integer element types** (currently `Float64`-only).
- **2-D `Matrix` kernels** (currently 1-D `Vector{Float64}`, `@index(Global)`).
- Infrastructure: self-hosted GPU CI (hosted runners have no NVIDIA GPU);
  AMDGPU/Metal/oneAPI are blocked upstream by missing runtime kernel loaders.

---

## Notes for future sessions

- **Test count:** 81 tests, 253 assertions (v0.22.0). Baseline for regression checks.
- **libmx stub** (`test/matlab/libmx_stub/libmx_stub.c`, ~430 lines) must be rebuilt
  locally before running tests without MATLAB:
  `cc -O2 -shared -fPIC -o test/matlab/libmx_stub/libmx_stub.so test/matlab/libmx_stub/libmx_stub.c`
- **General registry registration**: all AutoMerge criteria met. Trigger with
  `@JuliaRegistrator register` comment on any commit in the GitHub repo.
- **`@mxccall730` rule**: any MATLAB C API function whose parameters include
  `mwSize`/`mwIndex` (dimensions, element counts, sparse indices) must use
  `@mxccall730` on Windows — bare names resolve to the obsolete 32-bit API.
  Functions that are pure type/metadata queries use `@mxccall`.
- **`marshaler_for` dispatch order** (invariant — do not reorder):
  exact sparse → `T <: Array` block (Vector/Matrix{String}, Matrix{Char},
  Vector{S}/Matrix{S} struct) → `T <: Tuple` → `_is_user_struct`.
  Tuples must come before `_is_user_struct` because `isstructtype(Tuple{…})` is `true`.
- **Static dispatch in `@generated` bodies**: call `marshaler_for(fieldtype(T,k))`
  in the *code-generation phase* (before `return`), interpolate `typeof(m)` into the
  generated AST — never emit `marshaler_for($(SomeType))` as a runtime call.
- **TypeContracts 0.13**: no `__init__` or `_reinit_registry!` needed. `@contract`
  emits method definitions that survive precompile cache loading.
