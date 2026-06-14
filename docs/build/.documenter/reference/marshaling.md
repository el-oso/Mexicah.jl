
# Type Support and Marshaling {#Type-Support-and-Marshaling}

## Supported types {#Supported-types}

|                     Julia type |              MATLAB type |                                   Input strategy |                          Output strategy |
| ------------------------------:| ------------------------:| ------------------------------------------------:| ----------------------------------------:|
|                      `Float64` |          `double` scalar |                     `mxGetScalar` — **by value** |    `mxCreateDoubleScalar` — **by value** |
|              `Vector{Float64}` |            column vector |           `unsafe_wrap(mxGetPr)` — **zero-copy** |       `mxCreateDoubleMatrix` + `copyto!` |
|              `Matrix{Float64}` |            double matrix |           `unsafe_wrap(mxGetPr)` — **zero-copy** |       `mxCreateDoubleMatrix` + `copyto!` |
|                        `Int32` |           `int32` scalar |                `mxGetScalar` cast — **by value** |   `mxCreateNumericMatrix` — **by value** |
|                        `Int64` |           `int64` scalar |                `mxGetScalar` cast — **by value** |   `mxCreateNumericMatrix` — **by value** |
|                         `Bool` |         `logical` scalar |                   `mxGetLogicals` — **by value** |   `mxCreateLogicalScalar` — **by value** |
| `SparseMatrixCSC{Float64,Int}` |            sparse double | `mxGetIr/Jc/Pr`; nzval zero-copy, indices copied |      `mxCreateSparse` + index/value copy |
|           `Vector{ComplexF64}` | complex double (R2018a+) |            `mxGetComplexDoubles` — **zero-copy** | `mxCreateDoubleMatrix(mxCOMPLEX)` + copy |


## Zero-copy guarantee {#Zero-copy-guarantee}

**Inputs are always zero-copy for array types.** Julia receives a view into MATLAB's buffer via `unsafe_wrap(...; own=false)`. No allocation occurs.

**Outputs require one `memcpy`** when the Julia function returns a new array. The MEX wrapper allocates the output `mxArray` first, then `copyto!`s the result into it — exactly one copy from Julia heap to MATLAB heap.

**Scalar types are zero-copy in both directions** — they are passed by value through `mxGetScalar` / `mxCreateDoubleScalar`.

## Column-major layout {#Column-major-layout}

MATLAB and Julia both store matrices in column-major order. No transposition is needed when passing matrices between them.

## MATLAB version notes {#MATLAB-version-notes}
- The interleaved complex API (`mxGetComplexDoubles`) requires MATLAB R2018a or later. Earlier MATLAB releases use the separate real/imaginary API (`mxGetPr` / `mxGetPi`). Mexicah targets R2018a+ by default.
  

## Extending marshaling {#Extending-marshaling}

Implement the `AbstractMexMarshaler` contract for a new type:

```julia
struct MyTypeMarshaler end

Mexicah.load(::MyTypeMarshaler, pa::MxArray)::MyType = ...
Mexicah.store!(::MyTypeMarshaler, pa::MxArray, v::MyType)::Cvoid = ...
Mexicah.create(::MyTypeMarshaler, dims::Dims)::MxArray = ...
Mexicah.mx_class_id(::MyTypeMarshaler)::Cint = Mexicah.mxDOUBLE_CLASS

using TypeContracts
@verify MyTypeMarshaler   # fails at precompile time if anything is missing
```


Then register:

```julia
function Mexicah.marshaler_for(::Type{MyType})
    MyTypeMarshaler()
end
```

