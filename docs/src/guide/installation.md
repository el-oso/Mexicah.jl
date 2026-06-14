# Installation

## Requirements

| Requirement | Version |
|---|---|
| Julia | 1.12 or later |
| `juliac` | ships with Julia 1.12 (check: `juliac --version`) |
| C linker | `gcc` / `clang` / MSVC (already present on most systems) |
| MATLAB | **not required at build time** |

## Installing Mexicah.jl

```julia
using Pkg
Pkg.add(url="https://github.com/el-oso/Mexicah.jl")
```

## Verifying juliac is available

```bash
juliac --version
```

If `juliac` is not on your PATH, add Julia's `bin` directory:

```bash
export PATH="$(julia -e 'print(Sys.BINDIR)'):$PATH"
```

## Optional dependencies

Load these before using the corresponding features:

```julia
using Enzyme        # for @mexgradient backend=:enzyme
using ModelingToolkit  # for build_mex_from_mtk
```
