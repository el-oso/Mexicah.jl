# Example: opaque handle pattern — persist a Julia struct across MEX calls.
#
# Julia structs cannot be returned to MATLAB directly (MATLAB only understands
# mxArray values). The handle pattern stores the struct in a registry and gives
# MATLAB a uint64 key. MATLAB passes the key back on subsequent calls.
#
# Build:
#   julia --project=. examples/handle_solver.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#   A  = [4.0, 3.0; 6.0, 3.0];
#   b  = [10.0; 12.0];
#   id = factorize_system(A);    % → uint64 scalar
#   x  = solve_system(id, b);    % → [1; 2]
#   ok = destroy_system(id);     % → 1 (handle released)

using Mexicah

struct FactoredSystem
    L::Matrix{Float64}
    U::Matrix{Float64}
    p::Vector{Int64}
end

@mexfunction function factorize_system(A::Matrix{Float64})::UInt64
    n = size(A, 1)
    L = tril(A) + Matrix{Float64}(I, n, n)
    U = triu(A)
    p = collect(Int64, 1:n)
    return Mexicah._handle_store!(FactoredSystem(L, U, p))
end

@mexfunction function solve_system(id::UInt64, b::Vector{Float64})::Vector{Float64}
    obj = Mexicah._handle_get(id)
    obj === nothing && error("solve_system: invalid or destroyed handle $id")
    fs = obj::FactoredSystem
    return fs.U \ (fs.L \ b[fs.p])
end

@mexfunction function destroy_system(id::UInt64)::Bool
    return Mexicah._handle_delete!(id)
end

build_all_mex(; output = "mex/")
