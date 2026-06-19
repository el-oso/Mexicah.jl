module MexicahMTKExt

using Mexicah
using ModelingToolkit: ModelingToolkit as MTK

# generate_rhs/jacobian with eval_module=MexicahMTKExt produce RuntimeGeneratedFunctions
# tagged to this module, which requires RGF to be initialized here first. RGF is reached
# through MTK (it is a transitive dep of ModelingToolkit, not a direct dep of Mexicah).
MTK.RuntimeGeneratedFunctions.init(@__MODULE__)

# Build the `(u, p, t)` callables for `sys`. `u` is in `unknowns(sys)` order and `p`
# (a flat Vector of parameter values) is in `parameters(sys)` order — `structural_simplify`
# reorders both, so the declared order is not the call order. `p` is assembled into the
# structured `MTKParameters` object current MTK's generated code requires (passing a flat
# vector straight through, as before, silently produced wrong results). Returns named
# local functions (anonymous `(x)::R ->` fails to lower on Julia 1.12). Exposed un-exported
# so the numeric behavior can be tested without juliac.
function _mtk_wrappers(sys)
    rhs_f = MTK.generate_rhs(sys; expression = Val{false}, eval_module = MexicahMTKExt)
    jac_f = MTK.generate_jacobian(sys; expression = Val{false}, eval_module = MexicahMTKExt)
    rhs_oop = rhs_f isa Tuple ? rhs_f[1] : rhs_f
    jac_oop = jac_f isa Tuple ? jac_f[1] : jac_f
    psyms = MTK.parameters(sys)
    _mkp(p) = MTK.MTKParameters(sys, psyms .=> p)
    function rhs(u::Vector{Float64}, p::Vector{Float64}, t::Float64)::Vector{Float64}
        return rhs_oop(u, _mkp(p), t)
    end
    function jac(u::Vector{Float64}, p::Vector{Float64}, t::Float64)::Matrix{Float64}
        return jac_oop(u, _mkp(p), t)
    end
    return rhs, jac
end

"""
    build_mex_from_mtk(sys; output="./mex/", trim=false, bundle=true)

**Experimental.** Compile the right-hand side and Jacobian of a simplified `ODESystem`
into MEX files:
- `<sysname>_rhs`  — `f(u, p, t) -> du`
- `<sysname>_jac`  — `J(u, p, t) -> Matrix{Float64}`

`u` is in `unknowns(sys)` order and `p` (a flat vector of parameter values) is in
`parameters(sys)` order — `structural_simplify` reorders both, so use those, not the
declared order. `p` is assembled into the `MTKParameters` structure current MTK requires.

Caveats: the generated functions are `RuntimeGeneratedFunction`s and pull MTK into the
runtime, so the result does **not** `--trim=safe` compile — `trim` defaults to `false`.
A further limitation: the generated closures live in this extension module, which juliac
cannot `import`, so producing a compilable MEX needs them emitted into an importable
on-disk package (tracked as a follow-up). The `(u, p, t)` callables themselves
([`_mtk_wrappers`](@ref)) are correct and usable in-process.
"""
function build_mex_from_mtk(
        sys;
        output::String = "./mex/",
        trim::Bool = false,
        bundle::Bool = true,
    )
    sysname = nameof(sys)
    rhs, jac = _mtk_wrappers(sys)
    build_mex(
        rhs;
        input_types = Type[Vector{Float64}, Vector{Float64}, Float64],
        output_types = Type[Vector{Float64}],
        name = Symbol(sysname, :_rhs), output = output, trim = trim, bundle = bundle,
    )
    build_mex(
        jac;
        input_types = Type[Vector{Float64}, Vector{Float64}, Float64],
        output_types = Type[Matrix{Float64}],
        name = Symbol(sysname, :_jac), output = output, trim = trim, bundle = bundle,
    )
    return @info "Mexicah: MTK MEX files written to $output"
end

end # module MexicahMTKExt
