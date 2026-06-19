@testitem "_type_literal(String) returns \"String\"" begin
    using Mexicah, Test
    @test Mexicah._type_literal(String) == "String"
end
