classdef tMexicahFixtures < matlab.unittest.TestCase
    % End-to-end checks that juliac-built Mexicah MEX files load and run in real
    % MATLAB. The fixtures are built by test/matlab/build_fixtures.jl into mex/.
    % One method per marshaled type (see the matching @mexfunction definitions).

    methods (TestClassSetup)
        function setupPaths(tc)
            here = fileparts(mfilename('fullpath'));
            mexdir = fullfile(here, '..', '..', 'mex');
            tc.assertTrue(isfolder(mexdir), ...
                sprintf('mex/ not found at %s — run build_fixtures.jl first', mexdir));
            % Generated setup adds the bundled libjulia dirs to the in-session
            % library path (the workflow also exports them to the process env).
            setupfile = fullfile(mexdir, 'mexicah_setup.m');
            if isfile(setupfile)
                run(setupfile);
            end
            addpath(mexdir);
        end
    end

    methods (Test)
        function tAddDoubles(tc)            % Float64 scalar
            verifyEqual(tc, add_doubles(3.0, 4.0), 7.0);
        end

        function tMatrixScale(tc)           % Matrix{Float64}
            verifyEqual(tc, matrix_scale([1 2; 3 4], 2.0), [2 4; 6 8]);
        end

        function tSparseFro(tc)             % SparseMatrixCSC{Float64,Int}
            A = sparse([1 0; 0 2]);
            verifyEqual(tc, sparse_fro(A), sqrt(5), 'AbsTol', 1e-12);
        end

        function tComplexConj(tc)           % Vector{ComplexF64}
            v = [1+2i; 3-1i];
            verifyEqual(tc, complex_conj(v), conj(v), 'AbsTol', 1e-12);
        end

        function tInt64Double(tc)           % Int64 scalar
            verifyEqual(tc, int64_double(int64(21)), int64(42));
        end

        function tInt32Double(tc)           % Int32 scalar
            verifyEqual(tc, int32_double(int32(21)), int32(42));
        end

        function tBoolNot(tc)               % Bool scalar (logical)
            verifyEqual(tc, bool_not(true), false);
            verifyEqual(tc, bool_not(false), true);
        end

        function tFloat32Double(tc)         % Float32 scalar (single)
            r = float32_double(single(2.5));
            verifyEqual(tc, r, single(5.0));
            verifyClass(tc, r, 'single');
        end

        function tInt16Double(tc)           % Int16 scalar
            verifyEqual(tc, int16_double(int16(10)), int16(20));
        end

        function tMatF32Scale(tc)           % Matrix{Float32} (dense non-Float64)
            verifyEqual(tc, mat_f32_scale(single([1 2; 3 4]), single(2)), ...
                single([2 4; 6 8]));
        end

        function tCubeAdd1(tc)              % Array{Float64,3} (rank > 2)
            A = reshape(double(1:24), 2, 3, 4);
            verifyEqual(tc, cube_add1(A), A + 1);
        end

        function tCmatConj(tc)              % Matrix{ComplexF64}
            M = [1+2i 3-1i; 1i 2];
            verifyEqual(tc, cmat_conj(M), conj(M), 'AbsTol', 1e-12);
        end

        function tMakeStats(tc)             % struct output (StructMarshaler)
            s = make_stats([2.0; 4.0; 6.0]);
            verifyEqual(tc, s.mean, 4.0, 'AbsTol', 1e-12);
            verifyEqual(tc, double(s.n), 3.0);
        end

        function tMinmaxTwoOutputs(tc)      % multiple outputs
            [lo, hi] = minmax_vec([3.0; 1.0; 2.0]);
            verifyEqual(tc, lo, 1.0);
            verifyEqual(tc, hi, 3.0);
        end

        function tMinmaxOneOutput(tc)       % nlhs guard: 1-output call must not crash
            lo = minmax_vec([3.0; 1.0; 2.0]);
            verifyEqual(tc, lo, 1.0);
        end

        function tStatsTotal(tc)            % struct input (StructMarshaler load)
            verifyEqual(tc, stats_total(struct('mean', 4.0, 'n', 3)), 12.0, ...
                'AbsTol', 1e-12);
        end

        function tLogicalNotArr(tc)         % Matrix{Bool} (logical array)
            L = [true false; false true];
            verifyEqual(tc, logical_not_arr(L), ~L);
        end

        function tScaleStats(tc)            % Vector{struct} ↔ N×1 struct array
            sa = struct('mean', {2.0, 3.0}, 'n', {1, 2});
            o = scale_stats(sa, 10.0);
            verifyEqual(tc, numel(o), 2);
            verifyEqual(tc, o(1).mean, 20.0, 'AbsTol', 1e-12);
            verifyEqual(tc, o(2).mean, 30.0, 'AbsTol', 1e-12);
            verifyEqual(tc, double(o(1).n), 1.0);
        end

        function tCf32Conj(tc)              % Vector{ComplexF32} (single complex)
            v = single([1+2i; 3-1i]);
            r = cf32_conj(v);
            verifyEqual(tc, r, conj(v), 'AbsTol', 1e-6);
            verifyClass(tc, r, 'single');
        end

        function tSparseComplexFro(tc)      % SparseMatrixCSC{ComplexF64,Int}
            A = sparse([1+1i, 0; 0, 2i]);
            verifyEqual(tc, sparse_complex_fro(A), sqrt(1 + 1 + 4), 'AbsTol', 1e-12);
        end

        function tLogicalSparseIdentity(tc) % SparseMatrixCSC{Bool,Int}
            A = sparse(logical([1 0; 0 1]));
            verifyEqual(tc, logical_sparse_identity(A), A);
        end

        function tTuplePassthrough(tc)      % Tuple{Float64,Int64} → 1×2 cell
            c = tuple_passthrough(3.0, int64(7));
            verifyEqual(tc, c{1}, 3.0);
            verifyEqual(tc, c{2}, int64(7));
        end

        function tStrsUpper(tc)             % Vector{String} → N×1 cell of char
            r = strs_upper({'hello', 'world'});
            verifyEqual(tc, r, {'HELLO', 'WORLD'});
        end

        function tStrArrUpper(tc)           % Matrix{String} → MATLAB string array
            r = str_arr_upper(["a" "bb"; "ccc" "d"]);
            verifyEqual(tc, r, ["A" "BB"; "CCC" "D"]);
        end
    end
end
