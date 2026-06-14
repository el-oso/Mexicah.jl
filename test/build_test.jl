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
