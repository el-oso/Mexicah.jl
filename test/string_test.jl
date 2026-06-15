@testitem "marshaler_for(String) returns StringMarshaler" begin
    using Mexicah, Test
    @test Mexicah.marshaler_for(String) isa Mexicah.StringMarshaler
end

@testitem "mx_class_id(StringMarshaler) equals mxCHAR_CLASS" begin
    using Mexicah, Test
    @test Mexicah.mx_class_id(Mexicah.StringMarshaler()) == Mexicah.mxCHAR_CLASS
end

@testitem "_type_literal(String) returns \"String\"" begin
    using Mexicah, Test
    @test Mexicah._type_literal(String) == "String"
end

@testitem "StringMarshaler load from mx_create_string" tags = [:matlab] begin
    using Mexicah, Test
    m = Mexicah.StringMarshaler()
    for s in ("hello", "", "unicode: α β γ", "with spaces and\nnewlines")
        pa = Mexicah.mx_create_string(s)
        @test pa != C_NULL
        @test Mexicah.mx_is_char(pa)
        v = Mexicah.load(m, pa)
        @test v isa String
        @test v == s
        Mexicah.mx_destroy_array(pa)
    end
end

@testitem "store_result(String) writes a char mxArray" tags = [:matlab] begin
    using Mexicah, Test
    slot = Vector{Mexicah.MxArray}(undef, 1)
    slot[1] = C_NULL
    GC.@preserve slot begin
        # plhs is `mxArray *plhs[]` == `mxArray**` == Ptr{MxArray}.
        plhs = pointer(slot)
        Mexicah.store_result(plhs, 1, "hello, Mexicah!")
    end
    pa = slot[1]
    @test pa != C_NULL
    @test Mexicah.mx_is_char(pa)
    @test Mexicah.mx_get_string(pa) == "hello, Mexicah!"
    Mexicah.mx_destroy_array(pa)
end
