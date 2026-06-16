# Type Support and Marshaling

## Supported types

| Julia type | MATLAB type | Input strategy | Output strategy |
|---|---|---|---|
| `Float64`, `Float32` | `double` / `single` scalar | `mxGetScalar` — **by value** | `mxCreateDoubleScalar` / numeric matrix |
| `Int8/16/32/64`, `UInt8/16/32/64` | matching integer scalar | `mx_get_data` cast — **by value** | `mxCreateNumericMatrix` — **by value** |
| `Bool` | `logical` scalar | `mxGetLogicals` — **by value** | `mxCreateLogicalScalar` — **by value** |
| `Vector{Float64}`, `Matrix{Float64}` | double vector / matrix | `unsafe_wrap(mxGetPr)` — **zero-copy** | `mxCreateDoubleMatrix` + `copyto!` |
| `Array{T,N}` (any numeric `T`, any rank) | numeric array of class `T` | `unsafe_wrap(mxGetData)` — **zero-copy** | `mxCreateNumericMatrix`/`Array` + `copyto!` |
| `Array{Bool,N}` | `logical` array | `mxGetLogicals` — **zero-copy** | `mxCreateLogicalArray` + `copyto!` |
| `SparseMatrixCSC{Float64,Int}` | sparse double | `mxGetIr/Jc/Pr`; nzval zero-copy, indices copied | `mxCreateSparse` + index/value copy |
| `SparseMatrixCSC{ComplexF64,Int}` | complex sparse double | `mxGetIr/Jc/Pr/Pi` — split real/imag | `mxCreateSparse(mxCOMPLEX)` + split copy |
| `SparseMatrixCSC{Bool,Int}` | sparse logical | `mxGetIr/Jc` + `mxGetData` as `uint8` | `mxCreateSparseLogicalMatrix` |
| `Array{ComplexF64,N}` (vector / matrix / N-D) | complex double | `mxGetPr`/`mxGetPi` (split real/imag) — copy | `mxCreateDoubleMatrix(mxCOMPLEX)` + split copy |
| `Array{ComplexF32,N}` | complex single | `mxGetData`/`mxGetImagData` as `Float32` — copy | `mxCreateNumericMatrix(mxSINGLE,mxCOMPLEX)` |
| `struct` / `NamedTuple` (flat) | 1×1 `struct` | `mxGetField` per field, recursing | `mxCreateStructMatrix` + `mxSetField` per field |
| `Vector{<struct>}` | N×1 `struct` array | `mxGetField` per field per element | `mxCreateStructMatrix(N,1)` + `mxSetField` |
| `Tuple{A,B,…}` | 1×N cell array | `mxGetCell` per element, each by own marshaler | `mxCreateCellMatrix(1,N)` + `mxSetCell` |
| `Vector{String}` | N×1 cell of `char` | `mxGetCell` + `mxGetString` per element | `mxCreateCellMatrix(N,1)` + `mxCreateString` |
| `String` | `char` array | `mxGetString` — **copies to Julia heap** | `mxCreateString` — **one allocation** |

The numeric element types are `Float64`, `Float32`, `Int8/16/32/64`, and
`UInt8/16/32/64`. `Float64` vectors and matrices use dedicated zero-copy
marshalers; every other element type and rank (including 3-D+ arrays) is handled
by a parametric `DenseArrayMarshaler{T,N}`. Struct fields are marshaled by
recursing through `marshaler_for`, so a field may itself be a scalar, array, or
nested struct; the field unrolling happens at compile time (`@generated`), so it
stays `--trim=safe`.

## Zero-copy guarantee

**Inputs are always zero-copy for array types.** Julia receives a view into
MATLAB's buffer via `unsafe_wrap(...; own=false)`. No allocation occurs.

**Outputs require one `memcpy`** when the Julia function returns a new array.
The MEX wrapper allocates the output `mxArray` first, then `copyto!`s the
result into it — exactly one copy from Julia heap to MATLAB heap.

**Scalar types are zero-copy in both directions** — they are passed by value
through `mxGetScalar` / `mxCreateDoubleScalar`.

## Column-major layout

MATLAB and Julia both store matrices in column-major order. No transposition
is needed when passing matrices between them.

## MATLAB version notes

- The interleaved complex API (`mxGetComplexDoubles`) requires MATLAB R2018a
  or later. Earlier MATLAB releases use the separate real/imaginary API
  (`mxGetPr` / `mxGetPi`). Mexicah targets R2018a+ by default.

## Extending marshaling

Implement the `AbstractMexMarshaler` contract for a new type:

```julia
struct MyTypeMarshaler end

Mexicah.load(::MyTypeMarshaler, pa::MxArray)::MyType = ...
Mexicah.store!(::MyTypeMarshaler, pa::MxArray, v)::Cvoid = ...   # third arg ::Any
Mexicah.create(::MyTypeMarshaler, dims::Tuple)::MxArray = ...
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
