# Guard the documented examples: (1) every @mexfunction shown in the Examples docs
# pages must be a real function in the MexicahExamples package, and (2) that package
# must compile under juliac --trim=safe. Together these keep the docs copy-pastable
# and compiling. (The MATLAB usage in the docs can only run in the MATLAB.yml job /
# under the libmx stub — not in plain CI — so it is not asserted here.)

# Always-on: documented example functions exist verbatim in the tested source.
@testitem "docs Examples reference real MexicahExamples functions" begin
    using Mexicah
    root = pkgdir(Mexicah)
    srcmod = read(joinpath(root, "examples", "src", "MexicahExamples.jl"), String)
    docsdir = joinpath(root, "docs", "src", "examples")
    # The framework-free pages whose code lives in MexicahExamples (the Enzyme/JuMP/
    # MTK/DataFrames/CUDA pages use standalone scripts with heavy deps).
    pages = ["scalar.md", "matrix.md", "sparse.md", "linalg.md", "handles.md"]
    checked = 0
    for page in pages
        md = read(joinpath(docsdir, page), String)
        for m in eachmatch(r"@mexfunction function (\w+)", md)
            name = m.captures[1]
            @test occursin("@mexfunction function $name", srcmod)
            checked += 1
        end
    end
    @test checked > 0   # the pages do show @mexfunction definitions
end

# juliac-gated: the framework-free examples compile under --trim=safe. Skips when
# juliac / a C compiler are unavailable (e.g. plain CI); runs locally and in any
# juliac-equipped job. A scalar build is ~10 s.
@testitem "core examples compile under --trim=safe" begin
    using Mexicah
    have = Sys.which("juliac") !== nothing &&
        (Sys.which("cc") !== nothing || Sys.which("gcc") !== nothing)
    if !have
        @info "skipping example trim-build (need juliac + a C compiler)"
        @test_skip true
    else
        root = pkgdir(Mexicah)
        exproj = joinpath(root, "examples")
        driver = joinpath(exproj, "scalar_add.jl")
        jl = Base.julia_cmd()
        tmp = mktempdir()
        # Ensure the examples environment is resolved, then run the documented build
        # command in a clean working directory (the driver writes to ./mex/).
        run(`$jl --project=$exproj -e "using Pkg; Pkg.instantiate()"`)
        run(setenv(`$jl --project=$exproj $driver`, dir = tmp))
        @test isfile(joinpath(tmp, "mex", "add_doubles.$(Mexicah.mex_ext())"))
    end
end
