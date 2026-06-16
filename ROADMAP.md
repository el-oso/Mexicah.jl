# Roadmap

Forward-looking work for Mexicah.jl, consolidated from the docs, the GPU
feasibility notes, and a code audit (2026-06-16). Ordered by priority within each
section; **Section 1 (correctness/robustness) should come first** — those are
latent defects, the rest are features and polish.

## Status (v0.20.0)

- End-to-end MATLAB CI is green and blocking on Linux, Windows, and macOS:
  17 asserted fixtures in one session + sparse, per OS.
- Full Julia test suite green; docs build clean.
- Marshaler coverage: real-numeric scalars (`Float64/Float32`, `Int8/16/32/64`,
  `UInt8/16/32/64`), `Bool`, dense `Array{T,N}` of any supported numeric element
  type and rank, logical `Array{Bool,N}`, `SparseMatrixCSC{Float64,Int}`,
  complex `Array{ComplexF64,N}` **and `Array{ComplexF32,N}`**, flat
  `struct`/`NamedTuple` (in & out) **and `Vector{<struct>}` ↔ N×1 struct array**,
  `String`, `UInt64` handles, and multiple outputs.

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

## 1. Marshaler coverage (remainders)

- **Cell arrays** (heterogeneous; e.g. `Vector{Any}`/tuple → MATLAB cell — needs a
  design for how Julia heterogeneity maps).
- **Char/string arrays** (`Vector{String}` → cell of char, or MATLAB `string`).
- **Sparse for non-`Float64`** element types (logical/complex sparse).
- **N-D / matrix struct arrays** (`Matrix{<struct>}`; today only `Vector{<struct>}`
  → N×1).

## 2. Distribution

- **Register in the General registry.** Blocked: `TypeContracts` is a Git
  dependency (`[sources]` in `Project.toml`), which the General registry forbids —
  `TypeContracts` must be registered first and the `[sources]` entry removed.
  `[compat]` bounds are now in place.

## 3. Testing & tooling

- **MATLAB-free load/store unit harness.** Investigated and deferred: the
  marshalers `ccall` real `libmx` entry points (`mxGetData`, `mxCreateNumericMatrix`,
  …), so a pure-Julia mock would have to reimplement enough of `libmx` to be
  meaningful. Data movement stays validated via the CI MATLAB fixtures; the
  `@verify trim_compat` checks cover trim-safety without MATLAB.

## 4. Cleanup & polish

- **Dynamic dispatch in the marshaler hot path** (low priority): `marshaler_for`
  is `@nospecialize` and returns `Any`, so `load`/`store!`/`create` dispatch
  dynamically at runtime (recursively, per struct field). Fine for `ccall`-bound
  work; revisit only if profiling shows it matters.
- Add `docs/src/assets/logo.png` + `favicon.ico` (the Vitepress build warns they
  are missing; needs design assets).

## 5. GPU follow-ons (deferred — needs a CUDA + MATLAB host)

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
