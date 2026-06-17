@testitem "_validate_method passes for correctly typed function" begin
    using Mexicah, Test

    g(x::Vector{Float64}, t::Float64)::Vector{Float64} = x .* t

    @test_nowarn Mexicah._validate_method(g, Type[Vector{Float64}, Float64])
end

@testitem "_validate_method errors when no matching method" begin
    using Mexicah, Test

    f(x::Float64)::Float64 = x + 1.0

    @test_throws ErrorException Mexicah._validate_method(f, Type[Vector{Float64}])
end

@testitem "_write_setup_m creates a .m file with LD_LIBRARY_PATH" begin
    using Mexicah, Test

    dir = mktempdir()
    Mexicah._write_setup_m(dir, :testfunc)

    setup = joinpath(dir, "mexicah_setup.m")
    @test isfile(setup)
    content = read(setup, String)
    @test occursin("LD_LIBRARY_PATH", content)
    @test occursin(abspath(dir), content)
    @test occursin("DYLD_LIBRARY_PATH", content)
end

@testitem "generate_mex_source + _format_file pipeline" begin
    using Mexicah, Test

    module TBuild
    h(x::Float64)::Float64 = sin(x)
    end

    src = Mexicah.generate_mex_source(TBuild, :h, Type[Float64], Type[Float64], :h)
    dir = mktempdir()
    path = joinpath(dir, "h_mexgen.jl")
    write(path, src)
    Mexicah._format_file(path)
    @test isfile(path)
    content = read(path, String)
    @test occursin("mexFunction", content)
    @test occursin("_mexicah_init_once", content)
end

@testitem "_infer_vector_input detects Vector{Float64} functions" begin
    using Mexicah, Test

    takes_vec(x::Vector{Float64})::Float64 = sum(x)
    takes_scalar(x::Float64)::Float64 = x

    @test Mexicah._infer_vector_input(takes_vec) === Vector{Float64}
    @test Mexicah._infer_vector_input(takes_scalar) === nothing
end

@testitem "@mexfunction registers in _MEX_EXPORTS" begin
    using Mexicah, Test

    module RegTest
    using Mexicah
    @mexfunction function myreg(x::Float64)::Float64
        x * 2.0
    end
    end

    @test haskey(Mexicah._MEX_EXPORTS, :myreg)
    info = Mexicah._MEX_EXPORTS[:myreg]
    @test info.argtypes == Type[Float64]
    @test info.rettypes == Type[Float64]
end

@testitem "_gateway_c_source contains platform-appropriate symbols" begin
    using Mexicah, Test

    src = Mexicah._gateway_c_source("add_impl.so", "mexFunction")

    # Platform-independent: entry point is always exported
    @test occursin("mexFunction", src)
    @test occursin("add_impl.so", src)

    # Both branches are always present (compile-time #ifdef); check structural content.
    @test occursin("LoadLibraryA", src)
    @test occursin("GetProcAddress", src)
    @test occursin("__declspec(dllexport)", src)
    @test occursin("dlopen", src)
    @test occursin("dlsym", src)
end

@testitem "_build_mex_gateway compiles a valid shared library" begin
    using Mexicah, Test

    dir = mktempdir()
    ext = Mexicah.mex_ext()
    out_mex = joinpath(dir, "testgw.$ext")

    # Compile the thin C gateway; skip if no C compiler is available.
    cc = something(Sys.which("cc"), Sys.which("gcc"), Sys.which("clang"), nothing)
    if cc === nothing
        @warn "_build_mex_gateway test skipped: no C compiler found"
    else
        Mexicah._build_mex_gateway(dir, out_mex, "testgw_impl.$(Mexicah._impl_ext())", "mexFunction")
        @test isfile(out_mex)
        @test filesize(out_mex) > 0
    end
end
