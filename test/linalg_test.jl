@testitem "LinearAlgebra: la_det and la_trace" tags = [:linalg] begin
    A = [4.0 2.0; 1.0 3.0]
    @test Mexicah.la_det(A) ≈ 10.0 atol = 1.0e-12
    @test Mexicah.la_trace(A) ≈ 7.0 atol = 1.0e-12
end

@testitem "LinearAlgebra: la_norm_frob and la_opnorm" tags = [:linalg] begin
    A = [3.0 0.0; 4.0 0.0]
    @test Mexicah.la_norm_frob(A) ≈ 5.0 atol = 1.0e-12
    @test Mexicah.la_opnorm(A) ≈ 5.0 atol = 1.0e-12
end

@testitem "LinearAlgebra: la_rank and la_cond" tags = [:linalg] begin
    using LinearAlgebra: I
    A = [1.0 2.0; 2.0 4.0]   # rank-1 matrix
    @test Mexicah.la_rank(A) == Int64(1)
    @test Mexicah.la_cond(Matrix{Float64}(I, 2, 2)) ≈ 1.0 atol = 1.0e-12
end

@testitem "LinearAlgebra: la_inv and la_pinv" tags = [:linalg] begin
    using LinearAlgebra: I
    A = [2.0 0.0; 0.0 4.0]
    Ainv = Mexicah.la_inv(A)
    @test Ainv * A ≈ I atol = 1.0e-12

    v = reshape([1.0, 2.0, 2.0], 3, 1)
    pv = Mexicah.la_pinv(v)
    @test pv ≈ reshape([1.0, 2.0, 2.0] ./ 9.0, 1, 3) atol = 1.0e-12
end

@testitem "LinearAlgebra: la_solve" tags = [:linalg] begin
    A = [2.0 1.0; 1.0 3.0]
    b = [5.0; 10.0]
    x = Mexicah.la_solve(A, b)
    @test A * x ≈ b atol = 1.0e-12
end

@testitem "LinearAlgebra: la_svd round-trip" tags = [:linalg] begin
    using LinearAlgebra: diagm, I
    A = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    U, s, Vt = Mexicah.la_svd(A)
    @test U * diagm(s) * Vt ≈ A atol = 1.0e-12
    @test U' * U ≈ I atol = 1.0e-12

    s_only = Mexicah.la_svdvals(A)
    @test s_only ≈ s atol = 1.0e-12
end

@testitem "LinearAlgebra: la_eig_sym" tags = [:linalg] begin
    A = [2.0 1.0; 1.0 2.0]   # eigenvalues 1 and 3
    lambda, V = Mexicah.la_eig_sym(A)
    @test lambda ≈ [1.0, 3.0] atol = 1.0e-12
    for i in 1:2
        @test A * V[:, i] ≈ lambda[i] * V[:, i] atol = 1.0e-12
    end

    vals_only = Mexicah.la_eig_symvals(A)
    @test vals_only ≈ lambda atol = 1.0e-12
end

@testitem "LinearAlgebra: la_qr decomposition" tags = [:linalg] begin
    using LinearAlgebra: I
    A = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    Q, R = Mexicah.la_qr(A)
    @test Q * R ≈ A atol = 1.0e-12
    @test Q' * Q ≈ I atol = 1.0e-12
    @test R[2, 1] ≈ 0.0 atol = 1.0e-12   # upper triangular
end

@testitem "LinearAlgebra: la_chol" tags = [:linalg] begin
    A = [4.0 2.0; 2.0 3.0]   # SPD
    R = Mexicah.la_chol(A)
    @test R' * R ≈ A atol = 1.0e-12
    @test R[2, 1] ≈ 0.0 atol = 1.0e-12   # upper triangular
end

@testitem "LinearAlgebra: handle-based LU" tags = [:linalg] begin
    A = [2.0 1.0; 1.0 3.0]
    id = Mexicah.la_lu_factorize(A)
    @test id isa UInt64

    b1 = [3.0; 7.0]
    x1 = Mexicah.la_lu_solve(id, b1)
    @test A * x1 ≈ b1 atol = 1.0e-12

    b2 = [1.0; 0.0]
    x2 = Mexicah.la_lu_solve(id, b2)
    @test A * x2 ≈ b2 atol = 1.0e-12

    using LinearAlgebra: det
    @test Mexicah.la_lu_det(id) ≈ det(A) atol = 1.0e-12

    @test Mexicah.la_lu_destroy(id) == true
    @test Mexicah.la_lu_destroy(id) == false
end

@testitem "LinearAlgebra: handle-based Cholesky" tags = [:linalg] begin
    A = [4.0 2.0; 2.0 3.0]   # SPD
    id = Mexicah.la_chol_factorize(A)
    @test id isa UInt64

    b = [8.0; 7.0]
    x = Mexicah.la_chol_solve(id, b)
    @test A * x ≈ b atol = 1.0e-12

    @test Mexicah.la_chol_destroy(id) == true
    @test Mexicah.la_chol_destroy(id) == false
end

@testitem "LinearAlgebra: stale LU handle throws" tags = [:linalg] begin
    A = [1.0 0.0; 0.0 1.0]
    id = Mexicah.la_lu_factorize(A)
    Mexicah.la_lu_destroy(id)
    @test_throws Exception Mexicah.la_lu_solve(id, [1.0; 1.0])
end
