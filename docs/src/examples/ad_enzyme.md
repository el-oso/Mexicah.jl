# Automatic Differentiation with Enzyme

Export the gradient of any scalar-valued Julia function as a MEX extension
using Enzyme.jl's reverse-mode AD.

## Julia source (`examples/enzyme_gradient.jl`)

```julia
using Mexicah, Enzyme

function rosenbrock(x::Vector{Float64})::Float64
    n = length(x)
    s = 0.0
    for i in 1:(n - 1)
        s += 100.0 * (x[i + 1] - x[i]^2)^2 + (1.0 - x[i])^2
    end
    s
end

@mexgradient rosenbrock backend=:enzyme output="mex/" name=:rosenbrock_grad
```

## Build

```bash
julia --project=. examples/enzyme_gradient.jl
```

This produces `mex/rosenbrock_grad.mexa64` with signature `g = rosenbrock_grad(x)`.

## MATLAB

```matlab
run('mex/mexicah_setup.m')

x = [1.5; 0.5];
g = rosenbrock_grad(x)
% g ≈ [-401.5; 200.0]   (gradient at (1.5, 0.5))

% Verify against finite differences
h = 1e-6;
g_fd = zeros(size(x));
for i = 1:numel(x)
    xp = x; xp(i) = xp(i) + h;
    xm = x; xm(i) = xm(i) - h;
    f = @(v) 100*(v(2)-v(1)^2)^2 + (1-v(1))^2;  % 2D only
    g_fd(i) = (f(xp) - f(xm)) / (2*h);
end
disp(norm(g - g_fd))   % should be < 1e-5
```

## Why Enzyme?

Enzyme operates at the LLVM IR level, producing adjoints that are trim-safe
(no abstract dispatch, no runtime type queries). For large-input functions it
avoids the dual-number memory explosion of forward-mode AD. It is the
recommended backend for MEX gradient generation.

Use `backend=:forwarddiff` for small-input functions (fewer than ~10 inputs)
where forward-mode is more efficient.
