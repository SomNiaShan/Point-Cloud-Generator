classdef TestSingleExposureCountParameterMatrix < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            supportFolder = fullfile(repoRoot, 'support_files');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test)
        function linearIntegerRowsFollowCountRowsAndPowerColumns(testCase)
            [data, ~, summary] = generate_point_cloud(localParams());

            testCase.verifySize(data, [18, 5]);
            testCase.verifyEqual(data(:, 4), repmat([ ...
                10; 10; 20; 20; 30; 30], 3, 1));
            testCase.verifyEqual(data(:, 5), [ ...
                ones(6, 1); repmat(3, 6, 1); repmat(5, 6, 1)]);

            firstPointOfEachRegion = data(1:2:end, 1:2);
            testCase.verifyEqual(firstPointOfEachRegion, [ ...
                1.0, 2.0; ...
                1.3, 2.0; ...
                1.6, 2.0; ...
                1.0, 2.4; ...
                1.3, 2.4; ...
                1.6, 2.4; ...
                1.0, 2.8; ...
                1.3, 2.8; ...
                1.6, 2.8], 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.exposureCountValues, [1, 3, 5]);
            testCase.verifyEqual(summary.exposureCountSpacingMode, 'linear');
            testCase.verifyEqual(summary.powerRange, [10, 30]);
            testCase.verifyEqual(summary.plannedExposureCount, 54);
        end

        function createsExponentiallySpacedIntegerLevels(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.exposureCountSpacingMode = 'exponential';
            params.lattice.nExposureCounts = 3;
            params.lattice.exposureCountStart = 1;
            params.lattice.exposureCountEnd = 100;

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [1; 10; 100];
            testCase.verifyEqual(data(:, 5), expected);
            testCase.verifyEqual(summary.exposureCountValues, expected.');
            testCase.verifyEqual(summary.exposureCountSpacingMode, 'exponential');
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 exponentially spaced exposure-count rows'));
            testCase.verifyTrue(contains(prefix, ...
                'single_exposure_matrix_N_exp_1_to_100_3_rows_'));
        end

        function customRowsPreserveNonmonotonicOrderAndDeriveCount(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.exposureCountSpacingMode = 'custom';
            params.lattice.exposureCountValues = [5; 1; 3];
            params.lattice = rmfield(params.lattice, { ...
                'nExposureCounts', 'exposureCountStart', 'exposureCountEnd'});

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [5; 1; 3];
            testCase.verifySize(data, [3, 5]);
            testCase.verifyEqual(data(:, 5), expected);
            testCase.verifyEqual(data(:, 2), [2.0; 2.4; 2.8], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.exposureCountValues, expected.');
            testCase.verifyEqual(summary.exposureCountRange, [1, 5]);
            testCase.verifyEqual(summary.exposureCountSpacingMode, 'custom');
            testCase.verifyTrue(contains(summary.latticeLabel, '3 count rows'));
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 custom exposure-count rows in entered order'));
            testCase.verifyTrue(contains(prefix, ...
                'single_exposure_matrix_N_custom_5_to_3_3_rows_h'));
        end

        function rejectsInvalidCustomExposureCounts(testCase)
            invalidValues = { ...
                [1, 0], ...
                [1, -2], ...
                [1, 1.5], ...
                [1, NaN], ...
                [1, Inf]};

            for iCase = 1:numel(invalidValues)
                params = localSinglePointRegions(localParams());
                params.lattice.exposureCountSpacingMode = 'custom';
                params.lattice.exposureCountValues = invalidValues{iCase};

                [didThrow, message] = localCaptureError( ...
                    @() generate_point_cloud(params));

                testCase.verifyTrue(didThrow, sprintf( ...
                    'Expected custom exposure-count case %d to be rejected.', iCase));
                testCase.verifyTrue(contains(message, ...
                    'Exposure-count values must contain only positive integers.'));
            end
        end

        function rejectsNonintegerGeneratedLevels(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.nExposureCounts = 3;
            params.lattice.exposureCountStart = 1;
            params.lattice.exposureCountEnd = 4;

            [didThrow, message] = localCaptureError( ...
                @() generate_point_cloud(params));

            testCase.verifyTrue(didThrow);
            testCase.verifyTrue(contains(message, ...
                'spacing produces noninteger exposure-count levels'));
        end

        function rejectsDuplicateGeneratedLevels(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.nExposureCounts = 3;
            params.lattice.exposureCountStart = 2;
            params.lattice.exposureCountEnd = 2;

            [didThrow, message] = localCaptureError( ...
                @() generate_point_cloud(params));

            testCase.verifyTrue(didThrow);
            testCase.verifyTrue(contains(message, ...
                'range and row count produce duplicate integer levels'));
        end

        function rejectsNonintegerRowConfiguration(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.nExposureCounts = 2.5;

            [didThrow, message] = localCaptureError( ...
                @() generate_point_cloud(params));

            testCase.verifyTrue(didThrow);
            testCase.verifyTrue(contains(message, ...
                'Exposure-count Row Count must be a positive integer.'));
        end

        function reportsFixedTwoHundredMicrosecondExposure(testCase)
            [~, prefix, summary] = generate_point_cloud(localParams());

            fixedDwell = 200e-6;
            testCase.verifyEqual(summary.singleExposureDwellSeconds, fixedDwell, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(summary.dwellRange, [fixedDwell, fixedDwell], ...
                'AbsTol', 1e-15);
            testCase.verifyTrue(contains(summary.latticeLabel, '200 us each'));
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                'each exposure uses 200 us shutter dwell'));
            testCase.verifyTrue(contains(prefix, '_T_200us_'));
        end
    end
end

function params = localParams()
params = struct();
params.lattice = struct( ...
    'type', "Single Exposure Count Parameter Matrix", ...
    'displayDistanceUnit', 'mm', ...
    'exposureCountSpacingMode', 'linear', ...
    'nExposureCounts', 3, ...
    'exposureCountStart', 1, ...
    'exposureCountEnd', 5, ...
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
