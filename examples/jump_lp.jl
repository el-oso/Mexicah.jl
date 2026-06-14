# Example: stateless LP solve via JuMP + HiGHS, called from MATLAB.
#
# Requires JuMP and HiGHS to be installed:
#   julia --project=. -e 'using Pkg; Pkg.add(["JuMP", "HiGHS"])'
#
# Build:
#   julia --project=. examples/jump_lp.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#
#   % minimize -x1 - 2*x2  s.t.  x1 + x2 <= 4,  x in [0,10]^2
#   c    = [-1.0; -2.0];
#   A_ub = [1.0, 1.0];
#   b_ub = [4.0];
#   lb   = [0.0; 0.0];
#   ub   = [10.0; 10.0];
#
#   [x, obj, status] = solve_lp(c, A_ub, b_ub, lb, ub);
#   % status == 1  (1 = OPTIMAL, 2 = INFEASIBLE, 3 = UNBOUNDED, 99 = OTHER)
#   % obj ≈ -8.0
#   % x   ≈ [0; 4]

using Mexicah

@mexfunction function solve_lp(
        c::Vector{Float64},
        A_ub::Matrix{Float64},
        b_ub::Vector{Float64},
        lb::Vector{Float64},
        ub::Vector{Float64},
    )::Tuple{Vector{Float64}, Float64, Int64}
    ext = Base.get_extension(Mexicah, :MexicahJuMPExt)
    ext === nothing && error("MexicahJuMPExt not loaded — add JuMP to your Julia environment")
    optimizer = isdefined(Main, :HiGHS) ? Main.HiGHS.Optimizer :
        error("HiGHS is not loaded — add it to your Julia environment")
    return ext.solve_lp_with(optimizer, c, A_ub, b_ub, lb, ub)
end

build_mex(solve_lp; output = "mex/")
