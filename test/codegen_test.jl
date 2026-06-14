@testitem "generate_mex_source produces mexFunction and ccallable" begin
    using Mexicah, Test

    module TestFuncs1
    f(x::Float64)::Float64 = x * 2.0
    end

    src = Mexicah.generate_mex_source(TestFuncs1, :f, Type[Float64], Type[Float64], :f)

    @test src isa String
    @test occursin("mexFunction", src)
    @test occursin("@ccallable", src)
    @test occursin("_mexicah_init_once", src)
    @test occursin("Float64", src)
    @test occursin("AUTO-GENERATED", src)
end

@testitem "generate_mex_source argument count check is correct" begin
    using Mexicah, Test

    module TestFuncs2
    g(x::Vector{Float64}, t::Float64)::Vector{Float64} = x .* t
    end

    src = Mexicah.generate_mex_source(
        TestFuncs2,
        :g,
        Type[Vector{Float64}, Float64],
        Type[Vector{Float64}],
        :g,
    )
    @test occursin("nrhs != 2", src)
    @test occursin("nlhs > 1", src)
end

@testitem "generate_mex_source single-arg single-return" begin
    using Mexicah, Test

    module TestFuncs3
    h(x::Matrix{Float64})::Matrix{Float64} = x'
    end

    src = Mexicah.generate_mex_source(
        TestFuncs3,
        :h,
        Type[Matrix{Float64}],
        Type[Matrix{Float64}],
        :h,
    )
    @test occursin("nrhs != 1", src)
    @test occursin("nlhs > 1", src)
    @test occursin("Matrix{Float64}", src)
end

@testitem "generate_mex_source errors on unsupported types" begin
    using Mexicah, Test

    module TestFuncs4
    bad(x::Complex{Int32})::Complex{Int32} = x
    end

    @test_throws ErrorException Mexicah.generate_mex_source(
        TestFuncs4,
        :bad,
        Type[Complex{Int32}],
        Type[Complex{Int32}],
        :bad,
    )
end

@testitem "generate_mex_source supports String input and output" begin
    using Mexicah, Test

    module TestFuncs4b
    greet(s::String)::String = "Hello, " * s
    end

    src = Mexicah.generate_mex_source(
        TestFuncs4b, :greet, Type[String], Type[String], :greet
    )
    @test occursin("String", src)
    @test occursin("load_arg", src)
    @test occursin("store_result", src)
end

@testitem "_format_file runs runic without error on valid Julia" begin
    using Mexicah, Test

    module TestFuncs5
    simple(x::Float64)::Float64 = x + 1.0
    end

    src = Mexicah.generate_mex_source(
        TestFuncs5,
        :simple,
        Type[Float64],
        Type[Float64],
        :simple,
    )
    dir = mktempdir()
    path = joinpath(dir, "simple_mexgen.jl")
    write(path, src)
    Mexicah._format_file(path)
    @test isfile(path)
    content = read(path, String)
    @test !isempty(content)
    @test occursin("mexFunction", content)
end
