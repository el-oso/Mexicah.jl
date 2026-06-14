
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

