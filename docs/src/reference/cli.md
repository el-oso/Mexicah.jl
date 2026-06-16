# The `mexicah` CLI

`mexicah` is a Julia 1.12 **app** — a small command-line tool that compiles a
package's `@mexfunction`s into MATLAB MEX files without opening a Julia REPL. It
calls [`build_shared_mex`](../guide/quickstart.md) under the hood.

## Install

```bash
julia -e 'using Pkg; Pkg.Apps.add("Mexicah")'
```

This installs a `mexicah` launcher into `~/.julia/bin`. Add that to your `PATH`
(the same directory `juliac` lives in):

```bash
export PATH="$HOME/.julia/bin:$PATH"
mexicah help
```

> Developing Mexicah from a local checkout? Use
> `julia -e 'using Pkg; Pkg.Apps.develop(path=".")'` instead.

## Usage

```
mexicah compile <Package> [options]
mexicah help
```

Compiles the selected functions into **one** shared library plus a thin gateway
MEX per function, so they share a single Julia runtime and can be used together
in one MATLAB session.

`<Package>` must be a loadable Julia package whose functions are annotated with
`@mexfunction`. The compilation project must depend on both Mexicah and
`<Package>`; by default that is the current directory (override with
`--project`).

### Options

| Option | Default | Description |
|---|---|---|
| `--all-exported` | off | Compile every `@mexfunction` the package registers. |
| `--function <f1,f2>` | — | Comma-separated function names (instead of `--all-exported`). |
| `--output <dir>` | `./mex/` | Output directory for the gateways, shared library, and bundle. |
| `--project <dir>` | `.` | Project containing Mexicah and `<Package>`. |
| `--juliac <path>` | `juliac` | Path to the juliac binary. |

### Examples

```bash
# From inside your project (it depends on Mexicah and MySolvers):
mexicah compile MySolvers --all-exported

# Just two functions, to a custom directory:
mexicah compile MySolvers --function add_doubles,scale_rows --output build/mex
```

The result is the same `mex/` bundle as the [Quickstart](../guide/quickstart.md):
copy it to your MATLAB machine, `run('mex/mexicah_setup.m')`, and call the
functions.
