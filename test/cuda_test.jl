# ── PTX entry parsing (pure string work — no GPU/CUDA needed) ──────────────────

@testitem "_parse_ptx_entry extracts entry symbol" begin
    using Mexicah, Test
    @test Mexicah._parse_ptx_entry(".visible .entry vadd_42(\n") == "vadd_42"
    @test Mexicah._parse_ptx_entry("//c\n.entry _Z4vaddPdS_(.param ...)") == "_Z4vaddPdS_"
    # PTX symbols may contain `$`
    @test Mexicah._parse_ptx_entry(".entry foo\$bar(") == "foo\$bar"
    @test Mexicah._parse_ptx_entry("no entry here") === nothing
end

# ── GPU codegen (no GPU needed — checks the emitted Julia source) ──────────────

@testitem "generate_cuda_mex_source produces valid, correct wrapper" begin
    using Mexicah, Test

    src = Mexicah.generate_cuda_mex_source(
        :vector_add, "vadd_entry", ".visible .entry vadd_entry(){ret;}", 2, UInt8[], 256,
    )
    ex = Meta.parse("begin\n" * src * "\nend")
    @test ex isa Expr
    @test !any(a -> a isa Expr && a.head === :error, ex.args)

    @test occursin("@ccallable function mexFunction", src)
    @test occursin("_ENTRY = \"vadd_entry\"", src)
    @test occursin("Expected 2 input(s)", src)
    @test occursin("cld(_n, 256)", src)
    @test occursin("_cuda_init_once!", src)
    @test occursin("_cu_launch", src)
    @test occursin("store_result(plhs, 1, _out)", src)
end

@testitem "generate_cuda_mex_source argbuf layout scales with inputs" begin
    using Mexicah, Test

    # 1 input → output + 1 input = 2 CuDeviceArrays = 64 bytes, 2 kernelParams
    src1 = Mexicah.generate_cuda_mex_source(:f1, "k1", ".entry k1(){ret;}", 1, UInt8[], 128)
    @test occursin("zeros(UInt8, 64)", src1)
    @test occursin("Vector{Ptr{Cvoid}}(undef, 2)", src1)
    @test occursin("Expected 1 input(s)", src1)

    # 3 inputs → output + 3 inputs = 4 CuDeviceArrays = 128 bytes, 4 kernelParams
    src3 = Mexicah.generate_cuda_mex_source(:f3, "k3", ".entry k3(){ret;}", 3, UInt8[], 256)
    @test occursin("zeros(UInt8, 128)", src3)
    @test occursin("Vector{Ptr{Cvoid}}(undef, 4)", src3)
end

@testitem "generate_cuda_mex_source embeds metadata blob when present" begin
    using Mexicah, Test

    meta = UInt8[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
    src = Mexicah.generate_cuda_mex_source(:fm, "km", ".entry km(){ret;}", 1, meta, 64)
    ex = Meta.parse("begin\n" * src * "\nend")
    @test ex isa Expr
    @test occursin("const _META = UInt8[", src)
    @test occursin("unsafe_copyto!", src)
    # meta(8 bytes) aligned, then output(32) + input(32) → 72 total, 3 kernelParams
    @test occursin("zeros(UInt8, 72)", src)
    @test occursin("Vector{Ptr{Cvoid}}(undef, 3)", src)
end

@testitem "PTX with newlines and \$ symbols embeds as a valid literal" begin
    using Mexicah, Test
    ptx = ".visible .entry k\$0(\n.reg .f64 %fd<2>;\n ret;\n)\n"
    src = Mexicah.generate_cuda_mex_source(:k, "k\$0", ptx, 1, UInt8[], 32)
    ex = Meta.parse("begin\n" * src * "\nend")
    @test ex isa Expr
    @test !any(a -> a isa Expr && a.head === :error, ex.args)
end

# ── GPU integration (requires NVIDIA GPU + CUDA.jl + KernelAbstractions) ───────
# Self-guards like the JuMP/DataFrames tests: skips cleanly when the GPU stack is
# absent. The full MATLAB round-trip is validated manually via examples/cuda_vector_add.jl.

@testitem "CUDA build path: PTX extraction from a KA kernel" tags = [:cuda] begin
    using Mexicah, Test
    if (
            try
                @eval using CUDA
                @eval using KernelAbstractions
                CUDA.functional()
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahCUDAExt)
        @test ext !== nothing
        if ext !== nothing
            @eval KernelAbstractions.@kernel function _vadd_test!(c, a, b)
                i = KernelAbstractions.@index(Global)
                @inbounds c[i] = a[i] + b[i]
            end

            out = CUDA.CuArray{Float64}(undef, 1024)
            a = CUDA.CuArray{Float64}(undef, 1024)
            b = CUDA.CuArray{Float64}(undef, 1024)
            ptx, entry = ext._extract_ptx(_vadd_test!, (out, a, b), 256)
            @test ptx isa String
            @test !isempty(ptx)
            @test occursin(".entry", ptx)
            @test entry == Mexicah._parse_ptx_entry(ptx)
        end
    end
end
