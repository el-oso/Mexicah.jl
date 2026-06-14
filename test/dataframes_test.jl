@testitem "DataFrames extension: handle round-trip" tags = [:dataframes] begin
    if (
            try
                @eval using DataFrames; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
        @test ext !== nothing
        if ext !== nothing
            df = DataFrames.DataFrame(a = [1.0, 2.0, 3.0], b = [4.0, 5.0, 6.0])
            id = ext.df_to_handle(df)
            @test id isa UInt64 && id > 0

            recovered = ext.df_from_handle(id)
            @test recovered === df

            @test ext.df_destroy_handle(id) == true
            @test ext.df_destroy_handle(id) == false
        end
    end
end

@testitem "DataFrames extension: nrows / ncols" tags = [:dataframes] begin
    if (
            try
                @eval using DataFrames; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
        @test ext !== nothing
        if ext !== nothing
            df = DataFrames.DataFrame(x = 1.0:5.0, y = 6.0:10.0, z = Bool[1, 0, 1, 0, 1])
            id = ext.df_to_handle(df)

            @test ext.df_nrows(id) == 5
            @test ext.df_ncols(id) == 3

            ext.df_destroy_handle(id)
        end
    end
end

@testitem "DataFrames extension: df_get_col_f64" tags = [:dataframes] begin
    if (
            try
                @eval using DataFrames; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
        @test ext !== nothing
        if ext !== nothing
            df = DataFrames.DataFrame(a = [10.0, 20.0], b = [30.0, 40.0])
            id = ext.df_to_handle(df)

            @test ext.df_get_col_f64(id, Int64(1)) ≈ [10.0, 20.0]
            @test ext.df_get_col_f64(id, Int64(2)) ≈ [30.0, 40.0]
            @test_throws Exception ext.df_get_col_f64(id, Int64(3))

            ext.df_destroy_handle(id)
        end
    end
end

@testitem "DataFrames extension: missing handle throws" tags = [:dataframes] begin
    if (
            try
                @eval using DataFrames; true
            catch
                false
            end
        )
        ext = Base.get_extension(Mexicah, :MexicahDataFramesExt)
        @test ext !== nothing
        if ext !== nothing
            @test_throws Exception ext.df_from_handle(UInt64(999999999))
        end
    end
end
