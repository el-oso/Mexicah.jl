module MexicahForwardDiffExt

using Mexicah
using ForwardDiff: ForwardDiff

"""
    _forwarddiff_gradient_mex(f, grad_name, output)

Build a MEX that computes the gradient of scalar-valued `f` over its first
`Vector{Float64}` argument using ForwardDiff forward-mode AD.

The generated MEX has signature:
  [g] = f_grad(x)
where `x` is a column vector and `g` is its gradient.

ForwardDiff is recommended for functions with a small number of inputs (fewer
than ~10). For larger inputs, use the Enzyme reverse-mode backend instead.
"""
function _forwarddiff_gradient_mex(f, grad_name::Symbol, output::String)
    input_t = Mexicah._infer_vector_input(f)
    input_t === nothing &&
        error("@mexgradient: $f must accept a single Vector{Float64} argument")

    # Named local function (not anonymous): a return-type annotation on an anonymous
    # function fails to lower on Julia 1.12; named functions accept `::R` fine.
    function grad_f(x::Vector{Float64})::Vector{Float64}
        return ForwardDiff.gradient(f, x)
    end

    return build_mex(
        grad_f;
        input_types = Type[Vector{Float64}],
        output_types = Type[Vector{Float64}],
        name = grad_name,
        output = output,
    )
end

end # module MexicahForwardDiffExt
