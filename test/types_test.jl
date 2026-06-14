@testitem "mex_ext returns platform-appropriate extension" begin
    using Mexicah, Test

    ext = mex_ext()
    @test ext isa String
    if Sys.islinux()
        @test ext == "mexa64"
    elseif Sys.isapple()
        @test ext in ("mexmaci64", "mexmaca64")
    elseif Sys.iswindows()
        @test ext == "mexw64"
    end
end

@testitem "MxArray is a pointer type" begin
    using Mexicah, Test
    @test Mexicah.MxArray === Ptr{Cvoid}
end

@testitem "mxREAL and mxCOMPLEX are distinct Cint values" begin
    using Mexicah, Test
    @test Mexicah.mxREAL isa Cint
    @test Mexicah.mxCOMPLEX isa Cint
    @test Mexicah.mxREAL != Mexicah.mxCOMPLEX
end

@testitem "mxClassID constants are distinct" begin
    using Mexicah, Test
    ids = [
        Mexicah.mxDOUBLE_CLASS,
        Mexicah.mxSINGLE_CLASS,
        Mexicah.mxINT32_CLASS,
        Mexicah.mxINT64_CLASS,
        Mexicah.mxLOGICAL_CLASS,
    ]
    @test allunique(ids)
end
