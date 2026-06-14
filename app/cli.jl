# Compiled with:
#   juliac --output-exe mexicah --trim=safe app/cli.jl
#
# Usage:
#   mexicah compile path/to/source.jl --function mysolve --output ./mex/
#   mexicah compile MyPackage --all-exported --output ./mex/
#   mexicah compile MyPackage --function f1,f2 --output ./mex/ --no-trim
#   mexicah help

module MexicahCLI

using Mexicah

const USAGE = """
mexicah — compile Julia functions into MATLAB MEX extensions

Usage:
  mexicah compile <source> [options]
  mexicah help

Commands:
  compile   Build one or more MEX files from a Julia source file or package.

Options:
  --function <name(s)>   Comma-separated function names to compile.
                         Required unless --all-exported is given.
  --output <dir>         Output directory (default: ./mex/).
  --no-trim              Disable juliac --trim=safe (larger but more permissive binary).
  --no-bundle            Do not bundle the Julia runtime alongside the MEX file.
  --all-exported         Compile every function registered via @mexfunction.
  --juliac <path>        Path to the juliac binary (default: juliac on PATH).

Examples:
  mexicah compile mymodel.jl --function solve --output ./mex/
  mexicah compile MyPkg --all-exported --output ./mex/
  mexicah compile mymodel.jl --function rhs,jac --output ./mex/ --no-trim
"""

function (@main)(args::Vector{String})::Cint
    isempty(args) && (print(USAGE); return 0)
    cmd = args[1]
    rest = args[2:end]

    if cmd == "help" || cmd == "--help" || cmd == "-h"
        print(USAGE)
        return 0
    elseif cmd == "compile"
        return compile_cmd(rest)
    else
        println(stderr, "mexicah: unknown command '$cmd'. Run 'mexicah help'.")
        return 1
    end
end

function compile_cmd(args::Vector{String})::Cint
    source = ""
    functions = String[]
    output = "./mex/"
    trim = true
    bundle = true
    all_exported = false
    juliac_bin = "juliac"

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--function" && i < length(args)
            i += 1
            functions = split(args[i], ",")
        elseif a == "--output" && i < length(args)
            i += 1
            output = args[i]
        elseif a == "--no-trim"
            trim = false
        elseif a == "--no-bundle"
            bundle = false
        elseif a == "--all-exported"
            all_exported = true
        elseif a == "--juliac" && i < length(args)
            i += 1
            juliac_bin = args[i]
        elseif !startswith(a, "-")
            source = a
        else
            println(stderr, "mexicah: unknown option '$a'")
            return 1
        end
        i += 1
    end

    if isempty(source)
        println(stderr, "mexicah compile: source file or package name required.")
        return 1
    end

    if !all_exported && isempty(functions)
        println(stderr, "mexicah compile: specify --function <name(s)> or --all-exported.")
        return 1
    end

    mod = _load_source(source)
    mod === nothing && return 1

    if all_exported
        build_all_mex(; output = output, trim = trim, bundle = bundle, juliac_bin = juliac_bin)
    else
        for fname in functions
            sym = Symbol(strip(fname))
            if !isdefined(mod, sym)
                println(stderr, "mexicah: '$sym' not found in $source")
                return 1
            end
            f = getfield(mod, sym)
            info = get(Mexicah._MEX_EXPORTS, sym, nothing)
            if info === nothing
                println(
                    stderr,
                    "mexicah: '$sym' has no registered type signature. " *
                        "Annotate it with @mexfunction or register manually.",
                )
                return 1
            end
            build_mex(
                f;
                input_types = info.argtypes,
                output_types = info.rettypes,
                name = sym,
                output = output,
                trim = trim,
                bundle = bundle,
                juliac_bin = juliac_bin,
            )
        end
    end
    return 0
end

function _load_source(source::String)::Union{Module, Nothing}
    return if isfile(source)
        try
            return Base.include(Main, abspath(source))
        catch e
            println(stderr, "mexicah: failed to load $source: $e")
            return nothing
        end
    else
        # Treat as a package name
        try
            mod_sym = Symbol(source)
            Base.require(Main, mod_sym)
            return getfield(Main, mod_sym)
        catch e
            println(stderr, "mexicah: failed to load package $source: $e")
            return nothing
        end
    end
end

end # module MexicahCLI
