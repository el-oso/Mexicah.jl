# Installation

This page gets your machine ready to **build** MEX files. Your MATLAB users
need none of this — they only need MATLAB.

## What you need

| Tool | Why | How to check |
|---|---|---|
| **Julia 1.12+** | Mexicah and `juliac` require it | `julia --version` |
| **`juliac`** | the Julia → binary compiler | `juliac --version` |
| **A C compiler** | builds the tiny MEX loader (`gcc`/`clang`) | `cc --version` |
| MATLAB | **not needed to build** — only to run | — |

> 🐧 **Linux is the supported platform today.** Windows and macOS builds are in
> progress.

## 1. Install Julia

If you don't have Julia, the easiest way is [juliaup](https://github.com/JuliaLang/juliaup):

```bash
curl -fsSL https://install.julialang.org | sh
```

Then make sure you're on 1.12 or newer:

```bash
juliaup add 1.12
julia --version      # should print 1.12.x or later
```

## 2. Install `juliac`

`juliac` is distributed as a Julia "app". Install it once:

```bash
julia -e 'using Pkg; Pkg.Apps.add("JuliaC")'
```

This drops a `juliac` launcher in `~/.julia/bin`. Add that to your `PATH` (put
this in your `~/.bashrc` / `~/.zshrc` so it sticks):

```bash
export PATH="$HOME/.julia/bin:$PATH"
```

Check it works:

```bash
juliac --version
```

> **If that fails to find `JuliaC` in the registry** (it can lag on fresh
> machines), install it straight from source instead:
> ```bash
> julia -e 'using Pkg; Pkg.Apps.add(url="https://github.com/JuliaLang/JuliaC.jl.git")'
> ```

## 3. Make sure a C compiler is present

Mexicah compiles a tiny C gateway loader alongside your MEX. It auto-detects
whichever of these is on your `PATH`:

| Platform | Probe order | Notes |
|---|---|---|
| **Linux / macOS** | `cc` → `gcc` → `clang` | `cc` is almost always present |
| **Windows** | `gcc` → `clang` → `cc` | install one of the options below |

**Linux / macOS** — you almost certainly already have one:

```bash
cc --version        # or: gcc --version / clang --version
```

On Ubuntu/Debian, if it's missing: `sudo apt-get install build-essential`.

**Windows** — install either option:

- **MinGW-w64 / MSYS2** (provides `gcc`):
  ```powershell
  winget install MSYS2.MSYS2
  # then from the MSYS2 shell:
  pacman -S mingw-w64-ucrt-x86_64-gcc
  ```
  Add `C:\msys64\ucrt64\bin` to your `PATH`.

- **LLVM/Clang** (provides `clang`):
  ```powershell
  winget install LLVM.LLVM
  ```
  The installer offers to add LLVM to `PATH`; accept it.

Verify whichever you chose:

```powershell
gcc --version   # MinGW path
clang --version # LLVM path
```

## 4. Install Mexicah.jl

```julia
using Pkg
Pkg.add(url = "https://github.com/el-oso/Mexicah.jl")
```

That's it — head to the [Quickstart](quickstart.md).

## Optional add-ons

Mexicah grows extra build features when you load these packages (each is
optional — install only what you use):

| Package | Unlocks |
|---|---|
| `Enzyme` / `ForwardDiff` | `@mexgradient` (compile a gradient) |
| `ModelingToolkit` | compile an ODE right-hand side / Jacobian |
| `DataFrames`, `JuMP` | DataFrame and optimization bridges |
| `CUDA` + `KernelAbstractions` | GPU kernels via `@mexgpukernel` |
