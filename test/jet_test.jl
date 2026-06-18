# JET static-analysis gate. Complements TypeContracts.check_trim_compat (dynamic-dispatch
# / trim hazards only) by running JET's call analysis — it flags potential MethodErrors,
# undefined references, and type-inference failures *before runtime*, the closest Julia
# gets to a compile-time error check.
#
# Targets the CONCRETE per-marshaler load/store!/create methods (what codegen emits into
# the trimmed mexFunction), NOT the @nospecialize `marshaler_for` boundary (intentionally
# dynamic). Reports are filtered to the Mexicah module via `target_modules`; the
# ccall(libmx)/unsafe surface is trusted (declared return types). No :matlab tag: JET's
# report_call is pure static analysis — it never executes the libmx ccalls — so this runs
# in every environment (incl. CI workers without MATLAB or the stub).
@testitem "JET: marshaller call-analysis gate" begin
    using Mexicah, JET, Test
    using SparseArrays: SparseMatrixCSC
    const MX = Mexicah.MxArray

    reports(f, argtypes) =
        JET.get_reports(JET.report_call(f, argtypes; target_modules = (Mexicah,)))

    # Every supported Julia type → its concrete marshaler (derived via marshaler_for, a
    # build-host call; the dynamic boundary is fine here). Each marshaler's
    # load/store!/create is the type-stable code the trimmed MEX actually runs — including
    # the @generated struct/struct-array/cell composites.
    SP = Mexicah._StructProbe
    types = Any[
        Float64, Float32, Int64, Int32, Int16, Int8,
        UInt64, UInt32, UInt16, UInt8, Bool,
        Vector{Float64}, Matrix{Float64}, Array{Float64, 3}, Vector{Int32},
        Matrix{ComplexF64}, Matrix{ComplexF32}, Matrix{Bool}, Matrix{Char},
        SparseMatrixCSC{Float64, Int}, SparseMatrixCSC{ComplexF64, Int}, SparseMatrixCSC{Bool, Int},
        String, Vector{String}, Matrix{String},
        SP, Vector{SP}, Matrix{SP}, Mexicah._CellProbe,
    ]
    for T in types
        m = Mexicah.marshaler_for(T)
        M = typeof(m)
        @test isempty(reports(Mexicah.store!, (M, MX, T)))
        @test isempty(reports(Mexicah.create, (M, Tuple)))
        @test isempty(reports(Mexicah.load, (M, MX)))
    end
end
