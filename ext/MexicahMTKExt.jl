module MexicahMTKExt

using Mexicah
using ModelingToolkit: ModelingToolkit as MTK

# generate_rhs/jacobian with eval_module=MexicahMTKExt produce RuntimeGeneratedFunctions
# tagged to this module, which requires RGF to be initialized here first. RGF is reached
# through MTK (it is a transitive dep of ModelingToolkit, not a direct dep of Mexicah).
MTK.RuntimeGeneratedFunctions.init(@__MODULE__)

"""
    build_mex_from_mtk(sys; output="./mex/", trim=true, bundle=true)

**Experimental.** ModelingToolkit is a large, dynamic framework: the generated MEX
does **not** compile under `juliac --trim=safe` (build with `trim=false`). The flat
`p::Vector` parameter interface also needs a port to current MTK's `MTKParameters`.

Given a simplified `ODESystem`, generate and compile MEX files for:
- `<sysname>_rhs`  — the ODE right-hand side  `f(u, p, t) -> du`
- `<sysname>_jac`  — the Jacobian             `J(u, p, t) -> Matrix{Float64}`

The `eval_module=@__MODULE__` kwarg scopes the MTK-generated functions to this
module. Note these use `RuntimeGeneratedFunction`s, which are **not** `--trim=safe`
compatible — build with `trim=false`.
"""
function build_mex_from_mtk(
        sys;
        output::String = "./mex/",
        trim::Bool = true,
        bundle::Bool = true,
    )
    sysname = nameof(sys)

    # RHS  f(u, p, t) → du
    rhs_f = MTK.generate_rhs(sys; expression = Val{false}, eval_module = MexicahMTKExt)
    rhs_name = Symbol(sysname, :_rhs)
    # generate_rhs returns an (out-of-place, in-place) tuple; take the OOP f(u,p,t)→du.
    rhs_oop = rhs_f isa Tuple ? rhs_f[1] : rhs_f
    # Named local function (not an anonymous arrow): a return-type annotation on an
    # anonymous function fails to lower on Julia 1.12; named functions accept `::R`.
    function rhs_wrapper(u::Vector{Float64}, p::Vector{Float64}, t::Float64)::Vector{Float64}
        return rhs_oop(u, p, t)
    end

    build_mex(
        rhs_wrapper;
        input_types = Type[Vector{Float64}, Vector{Float64}, Float64],
        output_types = Type[Vector{Float64}],
        name = rhs_name,
        output = output,
        trim = trim,
        bundle = bundle,
    )

    # Jacobian  J(u, p, t) → Matrix{Float64}
    jac_f = MTK.generate_jacobian(sys; expression = Val{false}, eval_module = MexicahMTKExt)
    jac_name = Symbol(sysname, :_jac)
    jac_oop = jac_f isa Tuple ? jac_f[1] : jac_f
    function jac_wrapper(u::Vector{Float64}, p::Vector{Float64}, t::Float64)::Matrix{Float64}
        return jac_oop(u, p, t)
    end

    build_mex(
        jac_wrapper;
        input_types = Type[Vector{Float64}, Vector{Float64}, Float64],
        output_types = Type[Matrix{Float64}],
        name = jac_name,
        output = output,
        trim = trim,
        bundle = bundle,
    )

    return @info "Mexicah: MTK MEX files written to $output" rhs_name jac_name
end

end # module MexicahMTKExt
