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
    end
end
