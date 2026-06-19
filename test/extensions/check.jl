# Extension smoke checks — loads every Mexicah package extension and exercises a
# representative operation, so load-time and runtime regressions are caught (the
# main CI installs no weakdep packages, so it never loads these). Run with:
#   julia --project=test/extensions test/extensions/check.jl
# Exits non-zero if any check fails.

using Mexicah
using DataFrames: DataFrames, DataFrame
using Enzyme: Enzyme
using ForwardDiff: ForwardDiff
using JuMP: JuMP
using HiGHS: HiGHS
using ModelingToolkit: ModelingToolkit as MTK, @variables, @parameters, @named,
    D_nounits as D, ODESystem, structural_simplify

const FAILURES = String[]

function check(name, cond)
    ok = false
    try
        ok = cond()
    catch e
        push!(FAILURES, "$name — threw: $(sprint(showerror, e))")
        println("  ✗ $name (threw)")
        return
    end
    if ok
        println("  ✓ $name")
    else
        push!(FAILURES, "$name — assertion false")
        println("  ✗ $name")
    end
end

getext(sym) = Base.get_extension(Mexicah, sym)

println("\n== extensions load (guards the anon-fn lowering + DataFrames-UUID bugs) ==")
for sym in (:MexicahDataFramesExt, :MexicahEnzymeExt, :MexicahForwardDiffExt,
        :MexicahJuMPExt, :MexicahMTKExt)
    check(String(sym), () -> getext(sym) !== nothing)
end

println("\n== DataFrames: handle round-trip ==")
let ext = getext(:MexicahDataFramesExt)
    h = ext.df_to_handle(DataFrame(a = [1.0, 2.0, 3.0], b = [4.0, 5.0, 6.0]))
    check("df_nrows == 3", () -> ext.df_nrows(h) == 3)
    check("df_ncols == 2", () -> ext.df_ncols(h) == 2)
    check("df_get_col_f64(1) == [1,2,3]", () -> ext.df_get_col_f64(h, Int64(1)) == [1.0, 2.0, 3.0])
    check("df_destroy_handle", () -> ext.df_destroy_handle(h))
end

println("\n== JuMP: stateless LP solve (guards the JuMP.Min bug) ==")
let ext = getext(:MexicahJuMPExt)
    # min -x1 - 2x2  s.t.  x1 + x2 <= 4,  x in [0,10]^2  → x=[0,4], obj=-8
    x, obj, status = ext.solve_lp_with(HiGHS.Optimizer,
        [-1.0, -2.0], reshape([1.0, 1.0], 1, 2), [4.0], [0.0, 0.0], [10.0, 10.0])
    check("LP optimum x ≈ [0,4]", () -> isapprox(x, [0.0, 4.0]; atol = 1e-6))
    check("LP objective ≈ -8", () -> isapprox(obj, -8.0; atol = 1e-6))
    check("LP status == 1 (OPTIMAL)", () -> status == 1)
end

println("\n== Enzyme: reverse-mode gradient (the path the ext's wrapper compiles) ==")
let
    f(x) = (1.0 - x[1])^2 + 100.0 * (x[2] - x[1]^2)^2
    x = [0.5, 0.6]
    dx = zero(x)
    Enzyme.autodiff(Enzyme.Reverse, f, Enzyme.Active, Enzyme.Duplicated(x, dx))
    # analytic ∇: [-2(1-x1) - 400 x1 (x2-x1^2), 200 (x2-x1^2)]
    g = [-2 * (1 - x[1]) - 400 * x[1] * (x[2] - x[1]^2), 200 * (x[2] - x[1]^2)]
    check("Enzyme gradient matches analytic", () -> isapprox(dx, g; atol = 1e-8))
end

println("\n== ForwardDiff: forward-mode gradient ==")
let
    f(x) = sum(x .^ 2)
    check("ForwardDiff ∇(Σxᵢ²) == 2x", () -> ForwardDiff.gradient(f, [1.0, 2.0, 3.0]) == [2.0, 4.0, 6.0])
end

println("\n== ModelingToolkit: generation via eval_module=ext (guards RGF-init + tuple) ==")
let ext = getext(:MexicahMTKExt)
    @variables t x(t) v(t)
    @parameters k m
    @named spring_mass = ODESystem([D(x) ~ v, D(v) ~ -(k / m) * x], t, [x, v], [k, m])
    sys = structural_simplify(spring_mass)
    rhs = MTK.generate_rhs(sys; expression = Val{false}, eval_module = ext)
    rhs_oop = rhs isa Tuple ? rhs[1] : rhs
    # NOTE: only checks generation + that the RGF is callable. Numeric correctness
    # against a flat p::Vector is a KNOWN-BROKEN issue (current MTK wants structured
    # MTKParameters); the ext needs a port before that can be asserted here.
    check("generate_rhs RGF is callable", () -> rhs_oop([1.0, 0.0], [[1.0], [0.5]], 0.0) isa AbstractVector)
end

println()
if isempty(FAILURES)
    println("ALL EXTENSION CHECKS PASSED ✓")
    exit(0)
else
    println("EXTENSION CHECKS FAILED ($(length(FAILURES))):")
    foreach(f -> println("  - $f"), FAILURES)
    exit(1)
end
