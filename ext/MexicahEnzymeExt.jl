module MexicahEnzymeExt

using Mexicah
using Enzyme: Enzyme

"""
    _enzyme_gradient_mex(f, grad_name, output)

Build a MEX that computes the gradient of scalar-valued `f` over its first
`Vector{Float64}` argument using Enzyme reverse-mode AD.

The generated MEX has signature:
  [g] = f_grad(x)
where `x` is a column vector and `g` is its gradient.
"""
function _enzyme_gradient_mex(f, grad_name::Symbol, output::String, trim::Bool = false)
    input_t = Mexicah._infer_vector_input(f)
    input_t === nothing &&
        error("@mexgradient: $f must accept a single Vector{Float64} argument")

    # Build a wrapper function that calls Enzyme and returns the gradient. A *named*
    # local function (not an anonymous `function (x)::R`) — a return-type annotation
    # on an anonymous function fails to lower on Julia 1.12 ("invalid assignment
    # location"); named functions accept `::R` fine.
    function grad_f(x::Vector{Float64})::Vector{Float64}
        dx = zero(x)
        Enzyme.autodiff(Enzyme.Reverse, f, Enzyme.Active, Enzyme.Duplicated(x, dx))
        return dx
    end

    return build_mex(
        grad_f;
        input_types = Type[Vector{Float64}],
        output_types = Type[Vector{Float64}],
        name = grad_name,
        output = output,
        trim = trim,
    )
end

end # module MexicahEnzymeExt
