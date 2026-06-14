@testitem "AbstractMexMarshaler contract is registered" begin
    using Mexicah, TypeContracts, Test
    @test TypeContracts.interface_trait(
        Mexicah.AbstractMexMarshaler,
        Mexicah.Float64Marshaler,
    ) isa TypeContracts.Implemented{Mexicah.AbstractMexMarshaler}
end

@testitem "All built-in marshalers satisfy AbstractMexMarshaler" begin
    using Mexicah, TypeContracts, Test
    I = Mexicah.AbstractMexMarshaler
    for T in [
            Mexicah.Float64Marshaler,
            Mexicah.VectorFloat64Marshaler,
            Mexicah.MatrixFloat64Marshaler,
            Mexicah.Int32Marshaler,
            Mexicah.Int64Marshaler,
            Mexicah.BoolMarshaler,
            Mexicah.SparseFloat64Marshaler,
            Mexicah.ComplexFloat64Marshaler,
        ]
        @test TypeContracts.implements(T, I)
    end
end

@testitem "A struct missing required methods does not satisfy AbstractMexMarshaler" begin
    using Mexicah, TypeContracts, Test
    struct IncompleteMarshaler end
    @test TypeContracts.interface_trait(
        Mexicah.AbstractMexMarshaler,
        IncompleteMarshaler,
    ) isa TypeContracts.NotImplemented{Mexicah.AbstractMexMarshaler}
end

@testitem "AbstractMexExportable contract is registered" begin
    using Mexicah, TypeContracts, Test
    # Verify the contract spec was created (checking by absence of error)
    @test TypeContracts.interface_trait(
        Mexicah.AbstractMexExportable,
        Mexicah.Float64Marshaler,  # deliberately a non-implementer
    ) isa TypeContracts.NotImplemented{Mexicah.AbstractMexExportable}
end
