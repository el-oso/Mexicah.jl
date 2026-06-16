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

## TypeContracts dependency

Developed locally at `/home/el_oso/Documents/claude/TypeContracts`, added as a path source in `Project.toml` and `test/Project.toml`.
