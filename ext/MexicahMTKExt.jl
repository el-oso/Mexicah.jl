module MexicahMTKExt

using Mexicah
using ModelingToolkit: ModelingToolkit as MTK

"""
    build_mex_from_mtk(sys; output="./mex/", trim=true, bundle=true)

Given a simplified `ODESystem`, generate and compile MEX files for:
- `<sysname>_rhs`  — the ODE right-hand side  `f(u, p, t) -> du`
- `<sysname>_jac`  — the Jacobian             `J(u, p, t) -> Matrix{Float64}`

The `eval_module=@__MODULE__` kwarg is set automatically so that
MTK-generated Julia closures are compatible with `juliac --trim=safe`.
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
    rhs_wrapper = (u::Vector{Float64}, p::Vector{Float64}, t::Float64)::Vector{Float64} ->
    rhs_f(u, p, t)

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
    jac_wrapper = (u::Vector{Float64}, p::Vector{Float64}, t::Float64)::Matrix{Float64} ->
    jac_f(u, p, t)

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
