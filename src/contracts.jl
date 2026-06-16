using TypeContracts

@contract AbstractMexMarshaler "Bidirectional Julia ↔ MxArray conversion for one Julia type." begin
    load(::Self, ::MxArray)::Any => "Wrap or read mxArray data as a Julia value (zero-copy for arrays)"
    store!(::Self, ::MxArray, ::Any)::Cvoid =>
        "Write a Julia value into a pre-allocated mxArray buffer. Third arg typed ::Any so hasmethod passes for any marshaler."
    create(::Self, ::Tuple)::MxArray => "Allocate a new mxArray of the given shape (dims as Tuple)"
    mx_class_id(::Self)::Cint => "mxClassID constant for the element type"
end

@contract AbstractMexExportable "A function wrapper verified as juliac --trim-safe for MEX export." begin
    mex_name(::Self)::Symbol => "MATLAB-visible function name"
    input_types(::Self)::Tuple => "Concrete argument types as a Tuple type"
    output_types(::Self)::Tuple => "Concrete output types as a Tuple type"
end

# Verify all concrete marshalers satisfy the contract at precompile time.
# trim_compat=true additionally scans each implementation method's IR for calls
# that are incompatible with juliac --trim=safe (e.g. Base.return_types).
@verify Float64Marshaler trim_compat = true
@verify VectorFloat64Marshaler trim_compat = true
@verify MatrixFloat64Marshaler trim_compat = true
@verify Int32Marshaler trim_compat = true
@verify Int64Marshaler trim_compat = true
@verify UInt64Marshaler trim_compat = true
@verify BoolMarshaler trim_compat = true
@verify SparseFloat64Marshaler trim_compat = true
@verify SparseComplexF64Marshaler trim_compat = true
@verify SparseLogicalMarshaler trim_compat = true
@verify ComplexFloat64Marshaler trim_compat = true
@verify StringMarshaler trim_compat = true
# Additional real numeric scalars
@verify Float32Marshaler trim_compat = true
@verify Int8Marshaler trim_compat = true
@verify Int16Marshaler trim_compat = true
@verify UInt8Marshaler trim_compat = true
@verify UInt16Marshaler trim_compat = true
@verify UInt32Marshaler trim_compat = true
# Parametric array marshalers — verify representative instantiations (the methods
# are defined for all T/N, so one concrete instance proves the contract).
@verify DenseArrayMarshaler{Float64, 2} trim_compat = true
@verify DenseArrayMarshaler{Int32, 1} trim_compat = true
@verify DenseArrayMarshaler{Float32, 3} trim_compat = true
@verify ComplexArrayMarshaler{2} trim_compat = true
@verify ComplexF32ArrayMarshaler{2} trim_compat = true
@verify LogicalArrayMarshaler{2} trim_compat = true
# Struct marshaler — verified on a concrete fixture struct (its load/store/create
# are @generated, so this instantiates and scans the generated code).
@verify StructMarshaler{_StructProbe} trim_compat = true
@verify StructVectorMarshaler{_StructProbe} trim_compat = true
# Cell array marshaler — @generated over the element types, same trim-safe pattern.
@verify CellArrayMarshaler{_CellProbe} trim_compat = true
@verify StringVectorMarshaler trim_compat = true
