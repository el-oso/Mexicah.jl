# Example: LinearAlgebra extension — SVD, solve, and handle-based LU from MATLAB.
#
# Build:
#   julia --project=. examples/linalg.jl
#
# MATLAB:
#   run('mex/mexicah_setup.m')
#
#   A = randn(4, 3);
#   [U, s, Vt] = la_svd(A);
#
#   b = randn(4, 1);
#   x = la_solve(A, b);           % least-squares solution
#
#   % Repeated solves: factorize once, solve many times
#   B = rand(100, 100) + 100*eye(100);
#   id = la_lu_factorize(B);
#   for k = 1:50
#     x = la_lu_solve(id, rand(100, 1));
#   end
#   la_lu_destroy(id);

using Mexicah

@mexfunction function la_svd(
        A::Matrix{Float64},
    )::Tuple{Matrix{Float64}, Vector{Float64}, Matrix{Float64}}
    return Mexicah.la_svd(A)
end

@mexfunction function la_svdvals(A::Matrix{Float64})::Vector{Float64}
    return Mexicah.la_svdvals(A)
end

@mexfunction function la_qr(
        A::Matrix{Float64},
    )::Tuple{Matrix{Float64}, Matrix{Float64}}
    return Mexicah.la_qr(A)
end

@mexfunction function la_eig_sym(
        A::Matrix{Float64},
    )::Tuple{Vector{Float64}, Matrix{Float64}}
    return Mexicah.la_eig_sym(A)
end

@mexfunction function la_solve(
        A::Matrix{Float64}, b::Vector{Float64}
    )::Vector{Float64}
    return Mexicah.la_solve(A, b)
end

@mexfunction function la_det(A::Matrix{Float64})::Float64
    return Mexicah.la_det(A)
end

@mexfunction function la_inv(A::Matrix{Float64})::Matrix{Float64}
    return Mexicah.la_inv(A)
end

@mexfunction function la_lu_factorize(A::Matrix{Float64})::UInt64
    return Mexicah.la_lu_factorize(A)
end

@mexfunction function la_lu_solve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    return Mexicah.la_lu_solve(id, b)
end

@mexfunction function la_lu_destroy(id::UInt64)::Bool
    return Mexicah.la_lu_destroy(id)
end

@mexfunction function la_chol_factorize(A::Matrix{Float64})::UInt64
    return Mexicah.la_chol_factorize(A)
end

@mexfunction function la_chol_solve(id::UInt64, b::Vector{Float64})::Vector{Float64}
    return Mexicah.la_chol_solve(id, b)
end

@mexfunction function la_chol_destroy(id::UInt64)::Bool
    return Mexicah.la_chol_destroy(id)
end

build_all_mex(; output = "mex/")
