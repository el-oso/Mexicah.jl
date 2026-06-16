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
  mexicah compile <package> [options]
  mexicah help

Compiles every selected function into ONE shared library plus a thin gateway
MEX per function, so they share a single Julia runtime and can be used together
in one MATLAB session. <package> must be a loadable Julia package whose
functions are annotated with @mexfunction (juliac cannot see functions defined
only in a script or the REPL).

Options:
  --function <name(s)>   Comma-separated function names to compile.
                         Required unless --all-exported is given.
  --output <dir>         Output directory (default: ./mex/).
  --all-exported         Compile every function registered via @mexfunction.
  --no-trim              Disable juliac --trim=safe (larger, more permissive).
  --juliac <path>        Path to the juliac binary (default: juliac on PATH).

Examples:
  mexicah compile MySolvers --all-exported --output ./mex/
  mexicah compile MySolvers --function add_doubles,scale_rows --output ./mex/
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
        println(stderr, "mexicah compile: package name required.")
        return 1
    end

    if !all_exported && isempty(functions)
        println(stderr, "mexicah compile: specify --function <name(s)> or --all-exported.")
        return 1
    end

    _load_source(source) === nothing && return 1

    # Collect (function, input types, output types) for every selected function
    # from the @mexfunction registry, then build them into one shared library.
    targets = all_exported ? collect(keys(Mexicah._MEX_EXPORTS)) :
        Symbol[Symbol(strip(f)) for f in functions]

    funcs = Tuple{Any, Vector{Type}, Vector{Type}}[]
    for sym in targets
        info = get(Mexicah._MEX_EXPORTS, sym, nothing)
        if info === nothing
            println(
                stderr,
                "mexicah: '$sym' has no @mexfunction signature registered in $source.",
            )
            return 1
        end
        push!(funcs, (getfield(info.mod, sym), info.argtypes, info.rettypes))
    end

    if isempty(funcs)
        println(stderr, "mexicah: no @mexfunction functions found to compile.")
        return 1
    end

    build_shared_mex(funcs; output = output, trim = trim, juliac_bin = juliac_bin)
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
