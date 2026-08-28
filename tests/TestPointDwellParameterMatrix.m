classdef TestPointDwellParameterMatrix < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            supportFolder = fullfile(repoRoot, 'support_files');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test)
        function createsOneRegionPerDwellPowerPair(testCase)
            params = localParams();

            [data, ~, summary] = generate_point_cloud(params);

            testCase.verifySize(data, [12, 5]);
            testCase.verifyEqual(data(:, 4), [ ...
                10; 10; 20; 20; 30; 30; ...
                10; 10; 20; 20; 30; 30]);
            testCase.verifyEqual(data(:, 5), [ ...
                repmat(0.05, 6, 1); repmat(0.25, 6, 1)], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(data(:, 3), repmat(-0.02, 12, 1), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellRange, [0.05, 0.25], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.powerRange, [10, 30], ...
                'AbsTol', 1e-12);
        end

        function regionOriginsFollowPowerColumnsAndDwellRows(testCase)
            data = generate_point_cloud(localParams());
            firstPointOfEachRegion = data(1:2:end, 1:2);

            testCase.verifyEqual(firstPointOfEachRegion, [ ...
                1.0, 2.0; ...
                1.3, 2.0; ...
                1.6, 2.0; ...
                1.0, 2.4; ...
                1.3, 2.4; ...
                1.6, 2.4], 'AbsTol', 1e-12);
        end

        function rejectsNonpositiveDwellTime(testCase)
            params = localParams();
            params.lattice.dwellStartSeconds = 0;

            try
                generate_point_cloud(params);
                testCase.verifyFail('Expected a nonpositive dwell time to be rejected.');
            catch err
                testCase.verifyTrue(contains(err.message, 'Dwell start must be greater than 0'));
            end
        end

        function legacyMissingSpacingModeRemainsLinear(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.nDwells = 3;

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [0.05; 0.15; 0.25];
            testCase.verifyEqual(data(:, 5), expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellValues, expected.', 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellSpacingMode, 'linear');
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 linear dwell-time rows'));
            testCase.verifyFalse(contains(prefix, '_exp_'));
            testCase.verifyFalse(contains(prefix, '_custom_'));
        end

        function createsDescendingExponentiallySpacedDwellRows(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.dwellSpacingMode = 'exponential';
            params.lattice.nDwells = 3;
            params.lattice.dwellStartSeconds = 1;
            params.lattice.dwellEndSeconds = 0.01;

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [1; 0.1; 0.01];
            testCase.verifyEqual(data(:, 5), expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellValues, expected.', 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellRange, [0.01, 1], 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellSpacingMode, 'exponential');
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 exponentially spaced dwell-time rows'));
            testCase.verifyTrue(contains(prefix, 'dwell_matrix_T_exp_1_to_0.01_3_rows_'));

            linearParams = params;
            linearParams.lattice.dwellSpacingMode = 'linear';
            [~, linearPrefix] = generate_point_cloud(linearParams);
            testCase.verifyNotEqual(prefix, linearPrefix);
        end

        function customDwellRowsPreserveOrderAndDeriveCount(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.dwellSpacingMode = 'custom';
            params.lattice.dwellValuesSeconds = [0.5; 0.05; 0.25];
            params.lattice = rmfield(params.lattice, { ...
                'nDwells', 'dwellStartSeconds', 'dwellEndSeconds'});

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [0.5; 0.05; 0.25];
            testCase.verifySize(data, [3, 5]);
            testCase.verifyEqual(data(:, 5), expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellValues, expected.', 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellRange, [0.05, 0.5], 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.dwellSpacingMode, 'custom');
            testCase.verifyTrue(contains(summary.latticeLabel, '3 dwell rows'));
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 custom dwell-time rows'));
            testCase.verifyTrue(contains(prefix, ...
                'dwell_matrix_T_custom_0.5_to_0.25_3_rows_h'));
        end

        function rejectsInvalidCustomDwellRows(testCase)
            invalidValues = { ...
                [0.1, 0], ...
                [0.1, -0.2], ...
                [0.1, NaN], ...
                [0.1, Inf]};

            for iCase = 1:numel(invalidValues)
                params = localSinglePointRegions(localParams());
                params.lattice.dwellSpacingMode = 'custom';
                params.lattice.dwellValuesSeconds = invalidValues{iCase};

                [didThrow, message] = localCaptureError( ...
                    @() generate_point_cloud(params));

                testCase.verifyTrue(didThrow, sprintf( ...
                    'Expected custom dwell-time case %d to be rejected.', iCase));
                testCase.verifyTrue(contains(message, ...
                    'Point-dwell values must contain one or more finite numeric values greater than 0.'));
            end
        end
    end
end

function params = localParams()
params = struct();
params.lattice = struct( ...
    'type', "Point Dwell Parameter Matrix", ...
    'displayDistanceUnit', 'mm', ...
    'nDwells', 2, ...
    'dwellStartSeconds', 0.05, ...
    'dwellEndSeconds', 0.25, ...
    'nPowers', 3, ...
    'powerStart', 10, ...
    'powerEnd', 30, ...
    'patchNx', 2, ...
    'patchNy', 1, ...
    'patchPitchXUm', 100, ...
    'patchPitchYUm', 100, ...
    'gapXUm', 200, ...
    'gapYUm', 400, ...
    'originUm', [1000, 2000, -20]);
end

function params = localSinglePointRegions(params)
params.lattice.nPowers = 1;
params.lattice.powerEnd = params.lattice.powerStart;
params.lattice.patchNx = 1;
params.lattice.patchNy = 1;
end

function [didThrow, message] = localCaptureError(functionHandle)
didThrow = false;
message = '';
try
    functionHandle();
catch err
    didThrow = true;
    message = err.message;
end
end
