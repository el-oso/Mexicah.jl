# Example: scalar addition compiled to a MEX extension.
#
# The function lives in the MexicahExamples package (examples/src/) so juliac can
# import and compile it — functions defined in a script's Main cannot be built.
#
# Build (from the repo root):
#   julia --project=examples examples/scalar_add.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   result = add_doubles(3.0, 4.0)   % → 7.0

using Mexicah, MexicahExamples

build_shared_mex(
    [(MexicahExamples.add_doubles, Type[Float64, Float64], Type[Float64])];
    output = "mex/",
)
