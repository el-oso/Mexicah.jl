# Roadmap

Forward-looking work for Mexicah.jl, consolidated from the docs, the GPU
feasibility notes, and a code audit (2026-06-16). Ordered by priority within each
section; **Section 1 (correctness/robustness) should come first** — those are
latent defects, the rest are features and polish.

## Status (v0.18.0)

- End-to-end MATLAB CI is green and blocking on Linux, Windows, and macOS:
  12 marshalers in one session + sparse, per OS.
- Full Julia test suite green (64 test items); docs build clean.
- Marshaler coverage: real-numeric scalars (`Float64/Float32`, `Int8/16/32/64`,
  `UInt8/16/32/64`), `Bool`, dense `Array{T,N}` of any supported numeric element
  type and rank, `SparseMatrixCSC{Float64,Int}`, complex vectors/matrices/N-D,
  flat `struct`/`NamedTuple`, `String`, and `UInt64` handles.

## 1. Correctness & robustness (audit findings — do first)

- **Trap Julia exceptions in the generated `mexFunction`.** `_gen_ccallable`
  (`src/codegen.jl`) emits no `try`/`catch`, so *any* Julia error (a bad input
  value, a user-function throw, an unsupported marshaler) propagates as
  `fatal: error thrown and no exception handler available` and **aborts the whole
  MATLAB process**. Wrap the body and convert to `mex_errorf` (`mexErrMsgIdAndTxt`)
  so MATLAB raises a normal, catchable error instead of crashing. Highest-value
  fix.
- **Respect `nlhs` when storing outputs.** `_gen_store_stmts` (`src/codegen.jl`)
  writes **all** `nret` outputs unconditionally, but MATLAB allocates only
  `max(nlhs,1)` `plhs` slots. Calling a multi-output function with fewer outputs
  (e.g. `U = la_svd(A)` on the 3-output SVD) writes past `plhs` → undefined
  behaviour / crash. Store only the first `max(nlhs,1)` results.
- **Validate array rank on load.** `_load_dims` (`src/marshaling.jl`) does
  `unsafe_load(dptr, i)` for `i in 1:N`; if MATLAB passes an array of lower rank
  than the declared `Array{T,N}`, it reads past `mxGetDimensions`. Check
  `mx_get_number_of_dimensions` and `mex_errorf` on mismatch.
- **Gateway load failure is silent.** `_gateway_c_source` (`src/build.jl`): if
  `dlopen`/`LoadLibrary` fails, `g_impl` stays null and `mexFunction` returns
  having set no output — MATLAB sees no error, only a (often invisible) `stderr`
  line. At minimum document this; ideally surface a clearer failure.

## 2. Marshaler coverage (remainders)

- **Logical (`Bool`) arrays** — scalar `Bool` works, but `Array{Bool,N}` is not
  routed (`_mx_class_for` has no `Bool`, and the array branch excludes it). Either
  support logical arrays or document the asymmetry.
- **`ComplexF32` arrays** (only `ComplexF64` today).
- **Struct *arrays*** (N×1 MATLAB struct) and **struct *inputs*** exercised in the
  MATLAB e2e (current struct support is scalar 1×1 and only output-tested).
- **Cell arrays**, **char/string arrays**.
- **Sparse for non-`Float64`** element types.

## 3. Distribution

- **Register in the General registry.** Blocked: `TypeContracts` is a Git/path
  dependency and must be registered first. This is the gate to `]add Mexicah`.

## 4. Testing & tooling

- **MATLAB-free load/store unit harness** (a mock `mxArray`). The `nlhs` and
  error-trapping defects above slipped through precisely because data movement is
  only validated in CI MATLAB / via fixtures, never in plain `julia` tests.
- **Multi-output and struct-input fixtures** in `.github/workflows/MATLAB.yml`
  (would have caught the `nlhs` bug; current fixtures are single-output + a struct
  *output*).

## 5. Cleanup & polish

- Remove dead `Float64Marshaler.to_mx` (`src/marshaling.jl`), defined for one type
  and used nowhere.
- **Single source of truth for supported types.** `marshaler_for`
  (`src/marshaling.jl`) and `_type_literal` (`src/codegen.jl`) both encode the
  supported set; `_type_literal` now defers to `marshaler_for` as gatekeeper, but
  the two should be unified to prevent future drift (this duplication caused the
  "unsupported type Float32" build error during the v0.18.0 work).
- `mexicah_setup.m` still sets `DYLD_LIBRARY_PATH` on macOS (`_write_setup_m`,
  `src/build.jl`); SIP strips it and the impl now resolves `libjulia` via rpath —
  the branch is stale.
- **Dynamic dispatch in the marshaler hot path** (low priority): `marshaler_for`
  is `@nospecialize` and returns `Any`, so `load`/`store!`/`create` dispatch
  dynamically at runtime (recursively, per struct field). Fine for `ccall`-bound
  work; revisit only if profiling shows it matters.
- `_validate_method` uses `only(Base.return_types(...))`, which throws a confusing
  `only` error for functions with 0 or >1 methods; handle explicitly.
- Add `docs/src/assets/logo.png` + `favicon.ico` (the Vitepress build warns they
  are missing).

## 6. GPU follow-ons (deferred — needs a CUDA + MATLAB host)

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
