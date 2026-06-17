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


# Contract verification (structural — marshalers implement AbstractMexMarshaler
# via Holy-Trait dispatch and do NOT subtype it) lives in test/contracts_test.jl,
# which runs `check_contract(T, AbstractMexMarshaler)` + `check_trim_compat(...)`
# for every marshaler POST-LOAD. Two reasons it is not done here at precompile:
#   1. A one-arg `@verify Marshaler` would walk `supertypes(Marshaler)`, find no
#      contract specs (the marshaler doesn't subtype the contract), and pass — and
#      trim-scan — vacuously. The structural two-arg form (TypeContracts ≥ 0.13.1,
#      `for_contract=`) is required to check against the named contract.
#   2. The two-arg check calls `Base.return_types`, which is world-age-fragile on
#      the @generated marshalers (Struct*/Cell*) when run inside this module's own
#      precompilation — it widens `store!`'s return to `Any` and spuriously fails,
#      even though the same check passes once the module is fully loaded. Running it
#      in the test suite (post-load) verifies all marshalers reliably.
