
# API Reference {#API-Reference}

## `build_mex` {#build_mex}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.build_mex' href='#Mexicah.build_mex'><span class="jlbinding">Mexicah.build_mex</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
build_mex(f;
    input_types,
    output_types,
    name        = nothing,
    output      = ".",
    trim        = true,
    bundle      = true,
    juliac_bin  = "juliac",
)
```


Compile Julia function `f` into a MATLAB MEX extension in `output/`.

**Arguments**
- `f` — any Julia function. Must have a single method matching `input_types`.
  
- `input_types` — `Vector{Type}` of concrete argument types.
  
- `output_types` — `Vector{Type}` of concrete return types.
  
- `name` — MATLAB-visible name (default: `nameof(f)`).
  
- `output` — directory where the `.mex*` file and bundle land.
  
- `trim` — pass `--trim=safe` to juliac (recommended; much smaller binaries).
  
- `bundle` — pass `--bundle output` to juliac so `libjulia.so` is co-located.
  
- `juliac_bin` — path or name of the juliac executable.
  

**Output**

Writes `output/<name>.<mex_ext>` and, when `bundle=true`, `libjulia.so` and friends into `output/`. Also writes `output/mexicah_setup.m` which the MATLAB user runs once per session to put the bundle directory on `LD_LIBRARY_PATH`.

</details>


## `build_all_mex` {#build_all_mex}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.build_all_mex' href='#Mexicah.build_all_mex'><span class="jlbinding">Mexicah.build_all_mex</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
build_all_mex(; output="./mex/", kw...)
```


Compile every function registered via `@mexfunction` in all loaded modules.

</details>


## `@mexfunction` {#@mexfunction}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.@mexfunction' href='#Mexicah.@mexfunction'><span class="jlbinding">Mexicah.@mexfunction</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@mexfunction function f(x::T, ...)::R ... end
```


Define a Julia function and register it in the module's MEX export table. `build_mex(f; output="./mex/")` then compiles it without requiring any additional type annotations.

All argument and return types must be concrete and statically knowable.

</details>


## `@mexgradient` {#@mexgradient}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.@mexgradient' href='#Mexicah.@mexgradient'><span class="jlbinding">Mexicah.@mexgradient</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@mexgradient f [backend=:enzyme] [output="./mex/"] [name=:f_grad]
```


Generate and compile a gradient MEX for the scalar-valued function `f`. Requires Enzyme.jl (loaded as a weak dependency). With `backend=:forwarddiff` ForwardDiff.jl is used instead.

</details>


## `mex_ext` {#mex_ext}

Returns the platform-appropriate MEX file extension:

|       Platform |    Extension |
| --------------:| ------------:|
|   Linux x86-64 |    `.mexa64` |
|   macOS x86-64 | `.mexmaci64` |
|    macOS ARM64 | `.mexmaca64` |
| Windows x86-64 |    `.mexw64` |


## Handle Registry {#Handle-Registry}

The handle registry bridges GC-managed Julia objects to MATLAB. MATLAB holds a `uint64` scalar as an opaque key; Julia retrieves the object via `_handle_get`. See [Opaque handles](../examples/handles.md) for the full usage pattern.
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah._handle_store!' href='#Mexicah._handle_store!'><span class="jlbinding">Mexicah._handle_store!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
_handle_store!(obj) → UInt64
```


Store `obj` in the handle registry and return a unique opaque identifier. The object is GC-rooted until `_handle_delete!` is called with the same id.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah._handle_get' href='#Mexicah._handle_get'><span class="jlbinding">Mexicah._handle_get</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
_handle_get(id) → Any
```


Retrieve the object stored under `id`, or `nothing` if the handle does not exist.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah._handle_delete!' href='#Mexicah._handle_delete!'><span class="jlbinding">Mexicah._handle_delete!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
_handle_delete!(id) → Bool
```


Remove the handle `id` from the registry, allowing the associated object to be garbage-collected. Returns `true` if the handle existed and was removed, `false` if it was not found (already deleted or never created).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah._handle_count' href='#Mexicah._handle_count'><span class="jlbinding">Mexicah._handle_count</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
_handle_count() → Int
```


Return the number of live (not yet deleted) handles. Useful for leak detection.

</details>


## LinearAlgebra bridge {#LinearAlgebra-bridge}

All `la_*` functions are exported directly from `Mexicah` (no extension needed — LinearAlgebra is a Julia stdlib). See [LinearAlgebra](../examples/linalg.md) for usage patterns.

### Scalar / matrix properties {#Scalar-/-matrix-properties}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_det' href='#Mexicah.la_det'><span class="jlbinding">Mexicah.la_det</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_det(A) → Float64
```


Determinant of `A` (via LU factorization).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_trace' href='#Mexicah.la_trace'><span class="jlbinding">Mexicah.la_trace</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_trace(A) → Float64
```


Sum of diagonal elements of `A`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_norm_frob' href='#Mexicah.la_norm_frob'><span class="jlbinding">Mexicah.la_norm_frob</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_norm_frob(A) → Float64
```


Frobenius norm of `A`: `sqrt(sum(A.^2))`.

Note: MATLAB's `norm(A)` returns the 2-norm (largest singular value). Use `la_opnorm` for that. Use `la_norm_frob` for the Frobenius norm.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_opnorm' href='#Mexicah.la_opnorm'><span class="jlbinding">Mexicah.la_opnorm</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_opnorm(A) → Float64
```


Operator 2-norm of `A` (largest singular value). Equivalent to MATLAB's `norm(A)`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_cond' href='#Mexicah.la_cond'><span class="jlbinding">Mexicah.la_cond</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_cond(A) → Float64
```


2-norm condition number of `A` (ratio of largest to smallest singular value). Returns `Inf` if `A` is singular.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_rank' href='#Mexicah.la_rank'><span class="jlbinding">Mexicah.la_rank</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_rank(A) → Int64
```


Numerical rank of `A` estimated via SVD with default tolerance.

</details>


### Dense linear algebra {#Dense-linear-algebra}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_inv' href='#Mexicah.la_inv'><span class="jlbinding">Mexicah.la_inv</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_inv(A) → Matrix{Float64}
```


Matrix inverse of `A`. Prefer `la_solve` or the handle-based LU API for solving linear systems — `la_inv` is provided for cases where the inverse itself is needed.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_pinv' href='#Mexicah.la_pinv'><span class="jlbinding">Mexicah.la_pinv</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_pinv(A) → Matrix{Float64}
```


Moore-Penrose pseudoinverse of `A`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_solve' href='#Mexicah.la_solve'><span class="jlbinding">Mexicah.la_solve</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_solve(A, b) → Vector{Float64}
```


Solve the linear system `A * x = b` using Julia's backslash operator. For repeated solves with the same `A`, use `la_lu_factorize` / `la_lu_solve` instead to amortize the factorization cost.

</details>


### Decompositions {#Decompositions}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_svd' href='#Mexicah.la_svd'><span class="jlbinding">Mexicah.la_svd</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_svd(A) → (U, s, Vt)
```


Full SVD: `A = U * diagm(s) * Vt`. Returns three outputs:
- `U` — left singular vectors (m × k matrix)
  
- `s` — singular values in descending order (vector of length k = min(m,n))
  
- `Vt` — transposed right singular vectors (k × n matrix, i.e. `V'`)
  

MATLAB call: `[U, s, Vt] = la_svd(A)`

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_svdvals' href='#Mexicah.la_svdvals'><span class="jlbinding">Mexicah.la_svdvals</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_svdvals(A) → Vector{Float64}
```


Singular values of `A` in descending order. Faster than `la_svd` when only the values are needed.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_eig_sym' href='#Mexicah.la_eig_sym'><span class="jlbinding">Mexicah.la_eig_sym</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_eig_sym(A) → (lambda, V)
```


Eigendecomposition of a real symmetric matrix `A`. Returns:
- `lambda` — eigenvalues in ascending order (real-valued)
  
- `V`      — columns are the corresponding eigenvectors
  

`A` must be symmetric; only the lower triangle is read. For non-symmetric matrices the result is undefined.

MATLAB call: `[lambda, V] = la_eig_sym(A)`

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_eig_symvals' href='#Mexicah.la_eig_symvals'><span class="jlbinding">Mexicah.la_eig_symvals</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_eig_symvals(A) → Vector{Float64}
```


Eigenvalues of the real symmetric matrix `A` in ascending order. Faster than `la_eig_sym` when only eigenvalues are needed.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_qr' href='#Mexicah.la_qr'><span class="jlbinding">Mexicah.la_qr</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_qr(A) → (Q, R)
```


Thin QR factorization of `A` (m × n, m ≥ n).
- `Q` — orthonormal columns (m × n)
  
- `R` — upper triangular (n × n)
  

MATLAB call: `[Q, R] = la_qr(A)`

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_chol' href='#Mexicah.la_chol'><span class="jlbinding">Mexicah.la_chol</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_chol(A) → R
```


Upper Cholesky factor of the symmetric positive-definite matrix `A`. Returns `R` such that `A = R' * R`.

</details>


### Handle-based LU factorization {#Handle-based-LU-factorization}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_lu_factorize' href='#Mexicah.la_lu_factorize'><span class="jlbinding">Mexicah.la_lu_factorize</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_lu_factorize(A) → UInt64
```


Compute the LU factorization of `A` and store it in the Mexicah handle registry. Returns an opaque handle that MATLAB passes to `la_lu_solve` and `la_lu_det`. Call `la_lu_destroy` when finished to allow garbage collection.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_lu_solve' href='#Mexicah.la_lu_solve'><span class="jlbinding">Mexicah.la_lu_solve</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_lu_solve(id, b) → Vector{Float64}
```


Solve `A * x = b` using the LU factorization stored at `id`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_lu_det' href='#Mexicah.la_lu_det'><span class="jlbinding">Mexicah.la_lu_det</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_lu_det(id) → Float64
```


Determinant of the matrix whose LU factorization is stored at `id`. Cheaper than `la_det` for an already-factored matrix.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_lu_destroy' href='#Mexicah.la_lu_destroy'><span class="jlbinding">Mexicah.la_lu_destroy</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_lu_destroy(id) → Bool
```


Remove the LU factorization at `id` from the registry. Returns `true` if the handle existed, `false` if already deleted.

</details>


### Handle-based Cholesky factorization {#Handle-based-Cholesky-factorization}
<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_chol_factorize' href='#Mexicah.la_chol_factorize'><span class="jlbinding">Mexicah.la_chol_factorize</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_chol_factorize(A) → UInt64
```


Compute the Cholesky factorization of the symmetric positive-definite matrix `A` and store it in the handle registry. Only the lower triangle of `A` is read.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_chol_solve' href='#Mexicah.la_chol_solve'><span class="jlbinding">Mexicah.la_chol_solve</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_chol_solve(id, b) → Vector{Float64}
```


Solve `A * x = b` using the Cholesky factorization stored at `id`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Mexicah.la_chol_destroy' href='#Mexicah.la_chol_destroy'><span class="jlbinding">Mexicah.la_chol_destroy</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
la_chol_destroy(id) → Bool
```


Remove the Cholesky factorization at `id` from the registry.

</details>

