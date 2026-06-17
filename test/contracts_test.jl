@testitem "AbstractMexMarshaler contract is registered" begin
    using Mexicah, TypeContracts, Test
    @test TypeContracts.interface_trait(
        Mexicah.AbstractMexMarshaler,
        Mexicah.Float64Marshaler,
    ) isa TypeContracts.Implemented{Mexicah.AbstractMexMarshaler}
end

@testitem "Every marshaler structurally satisfies AbstractMexMarshaler (+ trim scan)" begin
    using Mexicah, TypeContracts, Test
    I = Mexicah.AbstractMexMarshaler
    SP = Mexicah._StructProbe
    CP = Mexicah._CellProbe
    # Structural verification for EVERY marshaler. Marshalers implement the contract
    # via Holy-Trait dispatch and do NOT subtype it, so this uses the two-arg
    # `check_contract(T, I)` (TypeContracts ≥ 0.13.1) — the precompile-time @verify
    # in src/contracts.jl was a vacuous no-op for these (see the note there).
    # check_contract throws InterfaceError on a mismatch (method existence + return
    # types); check_trim_compat scans each impl's IR for juliac --trim=safe hazards.
    marshalers = Any[
        Mexicah.Float64Marshaler,
        Mexicah.VectorFloat64Marshaler,
        Mexicah.MatrixFloat64Marshaler,
        Mexicah.Int32Marshaler,
        Mexicah.Int64Marshaler,
        Mexicah.UInt64Marshaler,
        Mexicah.BoolMarshaler,
        Mexicah.SparseFloat64Marshaler,
        Mexicah.SparseComplexF64Marshaler,
        Mexicah.SparseLogicalMarshaler,
        Mexicah.ComplexFloat64Marshaler,
        Mexicah.StringMarshaler,
        Mexicah.Float32Marshaler,
        Mexicah.Int8Marshaler,
        Mexicah.Int16Marshaler,
        Mexicah.UInt8Marshaler,
        Mexicah.UInt16Marshaler,
        Mexicah.UInt32Marshaler,
        Mexicah.DenseArrayMarshaler{Float64, 2},
        Mexicah.DenseArrayMarshaler{Int32, 1},
        Mexicah.DenseArrayMarshaler{Float32, 3},
        Mexicah.ComplexArrayMarshaler{2},
        Mexicah.ComplexF32ArrayMarshaler{2},
        Mexicah.LogicalArrayMarshaler{2},
        Mexicah.StructMarshaler{SP},
        Mexicah.StructVectorMarshaler{SP},
        Mexicah.StructMatrixMarshaler{SP},
        Mexicah.StructArrayMarshaler{SP, 3},
        Mexicah.CellArrayMarshaler{CP},
        Mexicah.StringVectorMarshaler,
        Mexicah.StringArrayMarshaler,
        Mexicah.CharMatrixMarshaler,
    ]
    for T in marshalers
        @test TypeContracts.check_contract(T, I).passed
        TypeContracts.check_trim_compat(T, I)
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
