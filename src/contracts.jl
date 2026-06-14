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
@verify Float64Marshaler
@verify VectorFloat64Marshaler
@verify MatrixFloat64Marshaler
@verify Int32Marshaler
@verify Int64Marshaler
@verify BoolMarshaler
@verify SparseFloat64Marshaler
@verify ComplexFloat64Marshaler

# TypeContracts._registry is a mutable Dict that is NOT preserved when a package
# is loaded from a precompile cache (dict mutations to external modules are not
# serialized). This function re-populates it so that interface_trait (which uses
# the dict via a @generated function) returns correct results at runtime.
function _reinit_registry!()::Cvoid
    TypeContracts._registry[AbstractMexMarshaler] = TypeContracts.MethodSpecMin[
        TypeContracts.MethodSpecMin(load, (TypeContracts.Self, MxArray), false),
        TypeContracts.MethodSpecMin(store!, (TypeContracts.Self, MxArray, Any), false),
        TypeContracts.MethodSpecMin(create, (TypeContracts.Self, Tuple), false),
        TypeContracts.MethodSpecMin(mx_class_id, (TypeContracts.Self,), false),
    ]
    TypeContracts._registry[AbstractMexExportable] = TypeContracts.MethodSpecMin[
        TypeContracts.MethodSpecMin(mex_name, (TypeContracts.Self,), false),
        TypeContracts.MethodSpecMin(input_types, (TypeContracts.Self,), false),
        TypeContracts.MethodSpecMin(output_types, (TypeContracts.Self,), false),
    ]
    return
end
