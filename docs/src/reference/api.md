# API Reference

## `build_mex`

```@docs
Mexicah.build_mex
```

## `build_all_mex`

```@docs
Mexicah.build_all_mex
```

## `@mexfunction`

```@docs
Mexicah.var"@mexfunction"
```

## `@mexgradient`

```@docs
Mexicah.var"@mexgradient"
```

## `mex_ext`

Returns the platform-appropriate MEX file extension:

| Platform | Extension |
|---|---|
| Linux x86-64 | `.mexa64` |
| macOS x86-64 | `.mexmaci64` |
| macOS ARM64 | `.mexmaca64` |
| Windows x86-64 | `.mexw64` |

## Handle Registry

The handle registry bridges GC-managed Julia objects to MATLAB. MATLAB holds
a `uint64` scalar as an opaque key; Julia retrieves the object via `_handle_get`.
See [Opaque handles](../examples/handles.md) for the full usage pattern.

```@docs
Mexicah._handle_store!
Mexicah._handle_get
Mexicah._handle_delete!
Mexicah._handle_count
```

## LinearAlgebra bridge

All `la_*` functions are exported directly from `Mexicah` (no extension needed —
LinearAlgebra is a Julia stdlib). See [LinearAlgebra](../examples/linalg.md) for
usage patterns.

### Scalar / matrix properties

```@docs
Mexicah.la_det
Mexicah.la_trace
Mexicah.la_norm_frob
Mexicah.la_opnorm
Mexicah.la_cond
Mexicah.la_rank
```

### Dense linear algebra

```@docs
Mexicah.la_inv
Mexicah.la_pinv
Mexicah.la_solve
```

### Decompositions

```@docs
Mexicah.la_svd
Mexicah.la_svdvals
Mexicah.la_eig_sym
Mexicah.la_eig_symvals
Mexicah.la_qr
Mexicah.la_chol
```

### Handle-based LU factorization

```@docs
Mexicah.la_lu_factorize
Mexicah.la_lu_solve
Mexicah.la_lu_det
Mexicah.la_lu_destroy
```

### Handle-based Cholesky factorization

```@docs
Mexicah.la_chol_factorize
Mexicah.la_chol_solve
Mexicah.la_chol_destroy
```
