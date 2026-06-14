# ── @mexfunction ──────────────────────────────────────────────────────────────

"""
    @mexfunction function f(x::T, ...)::R ... end

Define a Julia function and register it in the module's MEX export table.
`build_mex(f; output="./mex/")` then compiles it without requiring any
additional type annotations.

All argument and return types must be concrete and statically knowable.
"""
macro mexfunction(expr)
    expr.head === :function ||
        error("@mexfunction requires a function definition")

    sig = expr.args[1]
    # Collect argument types from the signature
    argtypes = _extract_argtypes(sig)
    rettypes = _extract_rettypes(expr)
    fname = _extract_fname(sig)

    return quote
        $(esc(expr))
        Mexicah._register_mex_export(
            @__MODULE__,
            $(QuoteNode(fname)),
            $(argtypes),
            $(rettypes),
        )
        nothing
    end
end

# ── @mexgradient ──────────────────────────────────────────────────────────────

"""
    @mexgradient f [backend=:enzyme] [output="./mex/"] [name=:f_grad]

Generate and compile a gradient MEX for the scalar-valued function `f`.
Requires Enzyme.jl (loaded as a weak dependency). With `backend=:forwarddiff`
ForwardDiff.jl is used instead.
"""
macro mexgradient(args...)
    fname, kws = _parse_gradient_args(args)
    backend = get(kws, :backend, :enzyme)
    output = get(kws, :output, "./mex/")
    grad_name = get(kws, :name, Symbol(fname, :_grad))

    return quote
        Mexicah._build_gradient_mex(
            $(esc(fname)),
            $(QuoteNode(grad_name)),
            $(QuoteNode(backend)),
            $output,
        )
    end
end

# Called at runtime; the actual implementation lives in MexicahEnzymeExt.
function _build_gradient_mex(f, grad_name::Symbol, backend::Symbol, output::String)
    return if backend === :enzyme
        ext = Base.get_extension(@__MODULE__, :MexicahEnzymeExt)
        ext === nothing &&
            error("Enzyme.jl must be loaded before using @mexgradient with backend=:enzyme")
        ext._enzyme_gradient_mex(f, grad_name, output)
    elseif backend === :forwarddiff
        ext = Base.get_extension(@__MODULE__, :MexicahForwardDiffExt)
        ext === nothing &&
            error("ForwardDiff.jl must be loaded before using @mexgradient with backend=:forwarddiff")
        ext._forwarddiff_gradient_mex(f, grad_name, output)
    else
        error("Unknown @mexgradient backend: $backend. Use :enzyme or :forwarddiff.")
    end
end

# ── MEX export registry ───────────────────────────────────────────────────────

const _MEX_EXPORTS = Dict{Symbol, NamedTuple{(:mod, :argtypes, :rettypes), Tuple{Module, Vector{Type}, Vector{Type}}}}()

function _register_mex_export(
        mod::Module,
        fname::Symbol,
        argtypes::Vector{Type},
        rettypes::Vector{Type},
    )::Cvoid
    _MEX_EXPORTS[fname] = (mod = mod, argtypes = argtypes, rettypes = rettypes)
    return
end

"""
    build_all_mex(; output="./mex/", kw...)

Compile every function registered via `@mexfunction` in all loaded modules.
"""
function build_all_mex(; output::String = "./mex/", kw...)
    for (fname, info) in _MEX_EXPORTS
        f = getfield(info.mod, fname)
        build_mex(
            f;
            input_types = info.argtypes,
            output_types = info.rettypes,
            name = fname,
            output = output,
            kw...,
        )
    end
    return
end

# ── Macro helpers (compile-time) ──────────────────────────────────────────────

function _call_sig(sig::Expr)::Expr
    # Unwrap return-type annotation: `f(...)::R` has head :(::) with args[1] = f(...)
    sig.head === :(::) && return sig.args[1]
    return sig
end

function _extract_fname(sig::Expr)::Symbol
    call = _call_sig(sig)
    call.head === :call && return call.args[1]
    error("@mexfunction: cannot parse function name from $sig")
end

function _extract_argtypes(sig::Expr)::Expr
    call = _call_sig(sig)
    types = Any[]  # can be Symbol (:Float64) or Expr (:(Vector{Float64}))
    for arg in call.args[2:end]
        if arg isa Expr && arg.head === :(::)
            push!(types, arg.args[2])
        else
            error("@mexfunction: argument $arg must have an explicit type annotation")
        end
    end
    return :(Type[$(types...)])
end

function _extract_rettypes(expr::Expr)::Expr
    # function f(...)::R  →  sig has :(::) head wrapping call + type
    sig = expr.args[1]
    if sig.head === :(::)
        rettype = sig.args[2]
        # Handle Tuple return: function f()::Tuple{A,B}
        if rettype isa Expr && rettype.head === :curly && rettype.args[1] === :Tuple
            return :(Type[$(rettype.args[2:end]...)])
        end
        return :(Type[$rettype])
    end
    error(
        "@mexfunction: return type is required. Annotate like: function f(x::T)::R ... end",
    )
end

function _parse_gradient_args(args)
    fname = nothing
    kws = Dict{Symbol, Any}()
    for a in args
        if a isa Symbol
            fname = a
        elseif a isa Expr && a.head === :(=)
            kws[a.args[1]] = a.args[2]
        end
    end
    fname === nothing && error("@mexgradient: function name required")
    return fname, kws
end
