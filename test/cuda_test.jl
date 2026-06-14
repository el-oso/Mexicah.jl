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

    # state_bytes=16 (KernelState), meta_bytes=16 (CompilerMetadata), 2 inputs.
    src = Mexicah.generate_cuda_mex_source(
        :vector_add, "vadd_entry", ".visible .entry vadd_entry(){ret;}", 2, 256, 16, 16,
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
    # CompilerMetadata is written from the runtime length, not a constant blob.
    @test occursin("Int64(_n)", src)
    @test occursin("Int64(_gx)", src)
    @test !occursin("_META", src)
end

@testitem "generate_cuda_mex_source argbuf layout scales with inputs" begin
    using Mexicah, Test

    # state(16) + meta(16) + output(32) + 1 input(32) = 96 bytes; 4 kernelParams
    # (state, meta, output, input).
    src1 = Mexicah.generate_cuda_mex_source(:f1, "k1", ".entry k1(){ret;}", 1, 128, 16, 16)
    @test occursin("zeros(UInt8, 96)", src1)
    @test occursin("Vector{Ptr{Cvoid}}(undef, 4)", src1)
    @test occursin("Expected 1 input(s)", src1)

    # state(16) + meta(16) + output(32) + 3 inputs(96) = 160 bytes; 6 kernelParams.
    src3 = Mexicah.generate_cuda_mex_source(:f3, "k3", ".entry k3(){ret;}", 3, 256, 16, 16)
    @test occursin("zeros(UInt8, 160)", src3)
    @test occursin("Vector{Ptr{Cvoid}}(undef, 6)", src3)
end

@testitem "generate_cuda_mex_source writes KernelState + CompilerMetadata params" begin
    using Mexicah, Test

    src = Mexicah.generate_cuda_mex_source(:fm, "km", ".entry km(){ret;}", 1, 64, 16, 16)
    ex = Meta.parse("begin\n" * src * "\nend")
    @test ex isa Expr
    # KernelState at offset 0 (zero-filled), CompilerMetadata at offset 16 carrying
    # [n, nblocks]; first kernelParam points at the state buffer (offset 0).
    @test occursin("unsafe_store!(Ptr{Int64}(_bp + 16 + 0), Int64(_n))", src)
    @test occursin("unsafe_store!(Ptr{Int64}(_bp + 16 + 8), Int64(_gx))", src)
    @test occursin("_kparams[1] = Ptr{Cvoid}(_bp + 0)", src)
    @test occursin("_kparams[2] = Ptr{Cvoid}(_bp + 16)", src)
end

@testitem "PTX with newlines and \$ symbols embeds as a valid literal" begin
    using Mexicah, Test
    ptx = ".visible .entry k\$0(\n.reg .f64 %fd<2>;\n ret;\n)\n"
    src = Mexicah.generate_cuda_mex_source(:k, "k\$0", ptx, 1, 32, 16, 16)
    ex = Meta.parse("begin\n" * src * "\nend")
    @test ex isa Expr
    @test !any(a -> a isa Expr && a.head === :error, ex.args)
end

@testitem "_parse_ptx_param_sizes reads the entry param byte sizes" begin
    using Mexicah, Test
    ptx = """
    .visible .entry foo(
    \t.param .align 8 .b8 foo_param_0[16],
    \t.param .align 8 .b8 foo_param_1[16],
    \t.param .align 8 .b8 foo_param_2[32]
    )
    {
    \tret;
    }
    """
    @test Mexicah._parse_ptx_param_sizes(ptx) == [16, 16, 32]
    @test Mexicah._parse_ptx_param_sizes(".entry bar(){ret;}") == Int[]
    @test Mexicah._parse_ptx_param_sizes("no entry here") == Int[]
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

            # Real kernel-launch ABI: [KernelState, CompilerMetadata, 3×CuDeviceArray].
            psz = Mexicah._parse_ptx_param_sizes(ptx)
            @test length(psz) == 5
            @test psz[1] == sizeof(CUDA.KernelState)
            @test psz[(end - 2):end] == [32, 32, 32]
            # CompilerMetadata carries [n, nblocks]; the build path measures and
            # validates this layout.
            @test ext._meta_param_bytes(_vadd_test!, 256) == psz[2]
        end
    end
end
