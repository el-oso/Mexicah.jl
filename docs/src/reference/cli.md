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
mexicah compile <source> [options]
```

Compile one or more Julia functions from `<source>` into MEX files.

`<source>` can be:
- A `.jl` file path — loaded with `include`
- A package name — loaded with `using`

#### Options

| Option | Default | Description |
|---|---|---|
| `--function <names>` | — | Comma-separated function names to compile. Required unless `--all-exported`. |
| `--output <dir>` | `./mex/` | Output directory for `.mex*` files and bundle. |
| `--no-trim` | off | Disable `juliac --trim=safe`. Produces larger but more permissive binaries. |
| `--no-bundle` | off | Do not bundle `libjulia.so` alongside the MEX file. |
| `--all-exported` | off | Compile every function registered via `@mexfunction`. |
| `--juliac <path>` | `juliac` | Path to the juliac binary. |

#### Examples

```bash
# Single function from a file
mexicah compile mymodel.jl --function solve --output ./mex/

# Multiple functions
mexicah compile mymodel.jl --function rhs,jac --output ./mex/

# All @mexfunction-annotated exports from a package
mexicah compile MyPkg --all-exported --output ./mex/

# Disable trimming for a debug build
mexicah compile mymodel.jl --function solve --output ./mex-debug/ --no-trim
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
