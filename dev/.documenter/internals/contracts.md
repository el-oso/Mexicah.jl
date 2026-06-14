
# TypeContracts Interfaces {#TypeContracts-Interfaces}

Mexicah uses [TypeContracts.jl](https://github.com/el-oso/TypeContracts.jl) to verify its internal interfaces at precompile time — before any compilation or MATLAB interaction occurs.

## `AbstractMexMarshaler` {#AbstractMexMarshaler}

Defines bidirectional conversion between a Julia type and an `MxArray`.

```julia
@contract AbstractMexMarshaler "Bidirectional Julia ↔ MxArray conversion." begin
    load(::Self, ::MxArray)::Any        => "Zero-copy wrap or read mxArray data"
    store!(::Self, ::MxArray, ::Any)::Cvoid => "Write Julia value into mxArray buffer"
    create(::Self, ::Dims)::MxArray     => "Allocate a new mxArray of given shape"
    mx_class_id(::Self)::Cint           => "mxClassID for the element type"
end
```


All eight built-in marshalers are verified at Mexicah.jl precompile time with `@verify`. If any method is missing or has an incorrectly inferred return type, the package fails to load with a clear `InterfaceError`.

**Important**: every `@contract` method implementation must carry an explicit return type annotation (`::Cvoid`, `::MxArray`, `::Cint`, …). TypeContracts uses `Base.return_types` for verification, which returns `Any` for functions that call Statistics, LinearAlgebra, or other generic Julia APIs without an annotation — causing `@verify` to fail even if the runtime value is correct.

## `AbstractMexExportable` {#AbstractMexExportable}

Marks a function wrapper as verified for `juliac --trim=safe` export.

```julia
@contract AbstractMexExportable "A trim-safe MEX-exportable function wrapper." begin
    mex_name(::Self)::Symbol
    input_types(::Self)::Tuple
    output_types(::Self)::Tuple
end
```


Future versions will use this to verify user-defined function wrappers at `@mexfunction` expansion time, before `juliac` is invoked.

## Extending with a custom marshaler {#Extending-with-a-custom-marshaler}

```julia
struct MyMarshaler end

using Mexicah, TypeContracts

# Implement all four required methods with explicit return types
Mexicah.load(::MyMarshaler, pa::Mexicah.MxArray)::MyType = ...
Mexicah.store!(::MyMarshaler, pa::Mexicah.MxArray, v::MyType)::Cvoid = (...)
Mexicah.create(::MyMarshaler, dims::Dims)::Mexicah.MxArray = ...
Mexicah.mx_class_id(::MyMarshaler)::Cint = Mexicah.mxDOUBLE_CLASS

@verify MyMarshaler   # fails immediately if anything is wrong
```

