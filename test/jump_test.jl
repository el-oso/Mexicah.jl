@testitem "JuMP extension loads when JuMP is available" tags = [:jump] begin
    if (
            try
                @eval using JuMP; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahJuMPExt)
        @test ext !== nothing
    end
end

@testitem "JuMP: solve_lp_with finds optimal solution" tags = [:jump] begin
    if (
            try
                @eval using JuMP; @eval using HiGHS; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahJuMPExt)
        @test ext !== nothing
        if ext !== nothing
            # minimize  -x1 - 2*x2   s.t.  x1 + x2 <= 4,  x in [0,10]^2
            c = [-1.0, -2.0]
            A_ub = [1.0 1.0]
            b_ub = [4.0]
            lb = [0.0, 0.0]
            ub = [10.0, 10.0]

            x, obj, status = ext.solve_lp_with(HiGHS.Optimizer, c, A_ub, b_ub, lb, ub)
            @test status == ext.STATUS_OPTIMAL
            @test obj ≈ -8.0 atol = 1.0e-6
            @test x ≈ [0.0, 4.0] atol = 1.0e-6
        end
    end
end

@testitem "JuMP: build_lp returns unsolved model" tags = [:jump] begin
    if (
            try
                @eval using JuMP; @eval using HiGHS; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahJuMPExt)
        @test ext !== nothing
        if ext !== nothing
            c = [1.0, 2.0]
            A_ub = Matrix{Float64}(undef, 0, 2)
            b_ub = Float64[]
            lb = [0.0, 0.0]
            ub = [5.0, 5.0]

            model = ext.build_lp(HiGHS.Optimizer, c, A_ub, b_ub, lb, ub)
            @test model isa JuMP.Model
        end
    end
end

@testitem "JuMP: handle-based LP lifecycle" tags = [:jump] begin
    if (
            try
                @eval using JuMP; @eval using HiGHS; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahJuMPExt)
        @test ext !== nothing
        if ext !== nothing
            # minimize  x1 + 3*x2  with x in [0,10]^2  (unconstrained — solution at origin)
            c = [1.0, 3.0]
            A_ub = Matrix{Float64}(undef, 0, 2)
            b_ub = Float64[]
            lb = [0.0, 0.0]
            ub = [10.0, 10.0]

            model = ext.build_lp(HiGHS.Optimizer, c, A_ub, b_ub, lb, ub)
            id = ext.jump_model_to_handle(model)
            @test id isa UInt64

            status = ext.jump_optimize!(id)
            @test status == ext.STATUS_OPTIMAL
            @test ext.jump_get_objective(id) ≈ 0.0 atol = 1.0e-6
            @test ext.jump_get_values(id) ≈ [0.0, 0.0] atol = 1.0e-6

            @test Mexicah._handle_delete!(id) == true
            @test Mexicah._handle_delete!(id) == false
        end
    end
end

@testitem "JuMP: solve_qp_with finds optimal QP solution" tags = [:jump] begin
    using LinearAlgebra: I
    if (
            try
                @eval using JuMP; @eval using HiGHS; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahJuMPExt)
        @test ext !== nothing
        if ext !== nothing
            # minimize  (1/2)||x||^2   s.t.  x >= [1,1]
            n = 2
            Q = Matrix{Float64}(I, n, n)
            c = zeros(n)
            A_ub = Matrix{Float64}(undef, 0, n)
            b_ub = Float64[]
            lb = ones(n)
            ub = fill(10.0, n)

            x, obj, status = ext.solve_qp_with(HiGHS.Optimizer, Q, c, A_ub, b_ub, lb, ub)
            @test status == ext.STATUS_OPTIMAL
            @test x ≈ ones(n) atol = 1.0e-6
            @test obj ≈ 1.0 atol = 1.0e-6   # (1/2) * (1^2 + 1^2) = 1.0
        end
    end
end
