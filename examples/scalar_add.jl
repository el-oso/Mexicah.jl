# Example: scalar addition compiled to a MEX extension.
#
# Build:
#   julia --project=. examples/scalar_add.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   result = add_doubles(3.0, 4.0)   % → 7.0

using Mexicah

@mexfunction function add_doubles(x::Float64, y::Float64)::Float64
    x + y
end

build_mex(add_doubles; output="mex/")
