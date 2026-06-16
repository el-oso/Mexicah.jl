# CLI Reference

The `mexicah` command-line tool is a compiled Julia app (`juliac --output-exe`)
for building MEX files without opening a Julia REPL.

## Building the CLI

```bash
juliac --output-exe mexicah --trim=safe app/cli.jl
```

Place the resulting `mexicah` binary on your `PATH`.

## Commands

### `mexicah compile`

```
mexicah compile <package> [options]
```

Compile the selected `@mexfunction`s from `<package>` into one shared library
plus a thin gateway MEX per function — the same as `build_shared_mex`, so the
results share one Julia runtime and can be used together in a MATLAB session.

`<package>` must be a **loadable Julia package** whose functions are annotated
with `@mexfunction`. `juliac` compiles in a separate process and cannot see
functions defined only in a script or the REPL.

#### Options

| Option | Default | Description |
|---|---|---|
| `--function <names>` | — | Comma-separated function names to compile. Required unless `--all-exported`. |
| `--output <dir>` | `./mex/` | Output directory for the gateways, shared library, and bundle. |
| `--all-exported` | off | Compile every function registered via `@mexfunction`. |
| `--no-trim` | off | Disable `juliac --trim=safe`. Produces larger but more permissive binaries. |
| `--juliac <path>` | `juliac` | Path to the juliac binary. |

#### Examples

```bash
# Every @mexfunction-annotated function in the package
mexicah compile MySolvers --all-exported --output ./mex/

# Just a couple of them
mexicah compile MySolvers --function add_doubles,scale_rows --output ./mex/
```

### `mexicah help`

Print usage information.

## Functions must be registered

Only functions annotated with `@mexfunction` (or registered via
`Mexicah._register_mex_export`) carry type signature metadata. The CLI reads
this metadata to know what concrete types to use for argument marshaling.

If you need to compile an existing function without `@mexfunction`, use
`build_mex` from the Julia API and pass `input_types` and `output_types`
explicitly.
