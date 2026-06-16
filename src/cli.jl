# `mexicah` command-line app.
#
# Declared in Project.toml under `[apps]`, so `julia -e 'using Pkg; Pkg.Apps.add("Mexicah")'`
# (or `Pkg.Apps.develop` for a local checkout) installs a `mexicah` launcher into
# ~/.julia/bin. Equivalent to running `julia -m Mexicah`. It compiles a package's
# @mexfunctions into MATLAB MEX files with `build_shared_mex`.

const _CLI_USAGE = """
mexicah — compile a package's @mexfunctions into MATLAB MEX files

Usage:
  mexicah compile <Package> [options]
  mexicah help

Compiles the selected functions into ONE shared library plus a thin gateway MEX
per function (build_shared_mex), so they share a single Julia runtime and can be
used together in one MATLAB session.

<Package> must be a loadable Julia package whose functions are annotated with
@mexfunction. The project used for compilation must depend on both Mexicah and
<Package>; by default that is the current directory.

Options:
  --all-exported        Compile every @mexfunction registered by the package.
  --function <f1,f2>    Comma-separated function names (instead of --all-exported).
  --output <dir>        Output directory (default: ./mex/).
  --project <dir>       Project with Mexicah and <Package> (default: current dir).
  --juliac <path>       juliac binary (default: juliac on PATH).

Examples:
  mexicah compile MySolvers --all-exported
  mexicah compile MySolvers --function add_doubles,scale_rows --output build/mex
"""

# App entry point. `julia -m Mexicah <args>` (and the installed `mexicah`
# launcher) call this with the command-line arguments.
function (@main)(args::Vector{String})::Cint
    return _cli_run(args)
end

function _cli_run(args::Vector{String})::Cint
    if isempty(args) || args[1] in ("help", "-h", "--help")
        print(_CLI_USAGE)
        return Cint(0)
    end
    if args[1] != "compile"
        println(stderr, "mexicah: unknown command '$(args[1])'. Try `mexicah help`.")
        return Cint(1)
    end
    return _cli_compile(args[2:end])
end

function _cli_compile(args::Vector{String})::Cint
    pkg = ""
    functions = String[]
    all_exported = false
    output = "./mex/"
    projectdir = "."
    juliac_bin = "juliac"

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--all-exported"
            all_exported = true
        elseif a == "--function" && i < length(args)
            i += 1
            functions = String.(split(args[i], ","))
        elseif a == "--output" && i < length(args)
            i += 1
            output = args[i]
        elseif a == "--project" && i < length(args)
            i += 1
            projectdir = args[i]
        elseif a == "--juliac" && i < length(args)
            i += 1
            juliac_bin = args[i]
        elseif !startswith(a, "-")
            pkg = a
        else
            println(stderr, "mexicah: unknown option '$a'")
            return Cint(1)
        end
        i += 1
    end

    if isempty(pkg)
        println(stderr, "mexicah compile: a package name is required.")
        return Cint(1)
    end
    if !all_exported && isempty(functions)
        println(stderr, "mexicah compile: pass --all-exported or --function <names>.")
        return Cint(1)
    end

    # Compile against the user's project (which has Mexicah and the package), then
    # load the package there so its @mexfunctions register in this Mexicah.
    Pkg = Base.require(Base.PkgId(Base.UUID("44cfe95a-1eb2-52ea-b672-e2afdf69b78f"), "Pkg"))
    Base.invokelatest(Pkg.activate, abspath(projectdir))
    Base.invokelatest(Pkg.instantiate)
    try
        Base.require(Main, Symbol(pkg))
    catch err
        println(stderr, "mexicah: could not load package '$pkg' from $(abspath(projectdir)): $err")
        return Cint(1)
    end

    targets = all_exported ? collect(keys(_MEX_EXPORTS)) :
        Symbol[Symbol(strip(f)) for f in functions]
    funcs = Tuple{Any, Vector{Type}, Vector{Type}}[]
    for sym in targets
        info = get(_MEX_EXPORTS, sym, nothing)
        if info === nothing
            println(stderr, "mexicah: '$sym' is not a registered @mexfunction in $pkg.")
            return Cint(1)
        end
        push!(funcs, (getfield(info.mod, sym), info.argtypes, info.rettypes))
    end
    if isempty(funcs)
        println(stderr, "mexicah: no @mexfunction functions found to compile in $pkg.")
        return Cint(1)
    end

    build_shared_mex(funcs; output = output, juliac_bin = juliac_bin, project = abspath(projectdir))
    return Cint(0)
end
