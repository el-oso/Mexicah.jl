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
    @mexgradient f [backend=:enzyme] [output="./mex/"] [name=:f_grad] [trim=true]

Generate and compile a gradient MEX for the scalar-valued function `f`.
Requires Enzyme.jl (loaded as a weak dependency). With `backend=:forwarddiff`
ForwardDiff.jl is used instead.

!!! warning "Experimental"
    Enzyme is a heavy, dynamic framework: an Enzyme gradient MEX does **not** compile
    under `juliac --trim=safe`, so pass `trim=false` for `backend=:enzyme`
    (e.g. `@mexgradient myloss trim=false`). ForwardDiff can build trim-safe.
"""
macro mexgradient(args...)
    fname, kws = _parse_gradient_args(args)
    backend = get(kws, :backend, :enzyme)
    output = get(kws, :output, "./mex/")
    grad_name = get(kws, :name, Symbol(fname, :_grad))
    # Enzyme is not --trim=safe compatible, so an Enzyme gradient MEX must be built with
    # `trim=false`; ForwardDiff can trim. Default true; override with `trim=false`.
    trim = get(kws, :trim, true)

    return quote
        Mexicah._build_gradient_mex(
            $(esc(fname)),
            $(QuoteNode(grad_name)),
            $(QuoteNode(backend)),
            $output,
            $trim,
        )
    end
end

# Called at runtime; the actual implementation lives in MexicahEnzymeExt.
function _build_gradient_mex(
        f, grad_name::Symbol, backend::Symbol, output::String, trim::Bool = true,
    )
    return if backend === :enzyme
        ext = Base.get_extension(@__MODULE__, :MexicahEnzymeExt)
        ext === nothing &&
            error("Enzyme.jl must be loaded before using @mexgradient with backend=:enzyme")
        ext._enzyme_gradient_mex(f, grad_name, output, trim)
    elseif backend === :forwarddiff
        ext = Base.get_extension(@__MODULE__, :MexicahForwardDiffExt)
        ext === nothing &&
            error("ForwardDiff.jl must be loaded before using @mexgradient with backend=:forwarddiff")
        ext._forwarddiff_gradient_mex(f, grad_name, output, trim)
    else
        error("Unknown @mexgradient backend: $backend. Use :enzyme or :forwarddiff.")
    end
end

# ── @mexgpukernel ─────────────────────────────────────────────────────────────

"""
    @mexgpukernel kernel=k [block=256] [output="./mex/"] function name(args...)::R end

Compile a KernelAbstractions `@kernel` `k` into a GPU MEX named `name`. Requires
CUDA.jl and KernelAbstractions.jl to be loaded (they trigger `MexicahCUDAExt`).

!!! warning "Experimental"
    The GPU extension requires an NVIDIA GPU to build and is not part of the
    CI-verified example set.

The trailing `function` gives only the MATLAB-visible signature — its body is
ignored. The kernel itself must take `(output, inputs...)` in the same order, all
`Vector{Float64}` of equal length, with 1-D `@index(Global)` indexing (MVP).

```julia
@kernel function vadd!(c, a, b)
    i = @index(Global)
    @inbounds c[i] = a[i] + b[i]
end

@mexgpukernel kernel=vadd! block=256 function
    vector_add(a::Vector{Float64}, b::Vector{Float64})::Vector{Float64}
end
```
"""
macro mexgpukernel(args...)
    isempty(args) && error("@mexgpukernel: a function signature is required")
    fexpr = args[end]
    (fexpr isa Expr && fexpr.head === :function) ||
        error("@mexgpukernel: the last argument must be a `function name(...)::R end` signature")

    kws = Dict{Symbol, Any}()
    for a in args[1:(end - 1)]
        (a isa Expr && a.head === :(=)) ||
            error("@mexgpukernel: expected `key=value` options, got $a")
        kws[a.args[1]] = a.args[2]
    end
    haskey(kws, :kernel) ||
        error("@mexgpukernel: `kernel=<@kernel function>` is required")
    kernel = kws[:kernel]
    block = get(kws, :block, 256)
    output = get(kws, :output, "./mex/")

    sig = fexpr.args[1]
    argtypes = _extract_argtypes(sig)
    rettypes = _extract_rettypes(fexpr)
    fname = _extract_fname(sig)

    return quote
        Mexicah._build_gpu_mex(
            $(esc(kernel)),
            $(QuoteNode(fname)),
            $(argtypes),
            $(rettypes),
            Int($(esc(block))),
            $(esc(output)),
        )
    end
end

# Called at runtime; the actual implementation lives in MexicahCUDAExt.
function _build_gpu_mex(
        kernelobj,
        mex_name::Symbol,
        argtypes::Vector{Type},
        rettypes::Vector{Type},
        block_dim::Int,
        output::String,
    )
    ext = Base.get_extension(@__MODULE__, :MexicahCUDAExt)
    ext === nothing && error(
        "@mexgpukernel: CUDA.jl and KernelAbstractions.jl must be loaded before building " *
            "a GPU MEX (they trigger MexicahCUDAExt).",
    )
    return ext._ka_cuda_build_mex(kernelobj, mex_name, argtypes, rettypes, block_dim, output)
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
