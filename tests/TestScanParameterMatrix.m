classdef TestScanParameterMatrix < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            supportFolder = fullfile(repoRoot, 'support_files');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test)
        function createsOneRegionPerSpeedPowerPair(testCase)
            params = localParams();

            [data, ~, summary] = generate_point_cloud(params);

            testCase.verifySize(data, [12, 5]);
            testCase.verifyEqual(data(:, 4), [ ...
                10; 10; 20; 20; 30; 30; ...
                10; 10; 20; 20; 30; 30]);
            testCase.verifyEqual(data(:, 5), [ ...
                repmat(0.01, 6, 1); repmat(0.03, 6, 1)], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(data(:, 3), repmat(-0.02, 12, 1), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedRange, [0.01, 0.03], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.powerRange, [10, 30], ...
                'AbsTol', 1e-12);
        end

        function regionOriginsFollowPowerColumnsAndSpeedRows(testCase)
            params = localParams();

            data = generate_point_cloud(params);
            firstAnchorOfEachRegion = data(1:2:end, 1:2);

            testCase.verifyEqual(firstAnchorOfEachRegion, [ ...
                1.0, 2.0; ...
                1.3, 2.0; ...
                1.6, 2.0; ...
                1.0, 2.4; ...
                1.3, 2.4; ...
                1.6, 2.4], 'AbsTol', 1e-12);
        end

        function rejectsNonpositiveScanSpeed(testCase)
            params = localParams();
            params.lattice.speedStartMmPerSecond = 0;

            try
                generate_point_cloud(params);
                testCase.verifyFail('Expected a nonpositive scan speed to be rejected.');
            catch err
                testCase.verifyTrue(contains(err.message, 'Speed start must be greater than 0'));
            end
        end

        function legacyMissingSpacingModeRemainsLinear(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.nSpeeds = 3;

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [0.01; 0.02; 0.03];
            testCase.verifyEqual(data(:, 5), expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedValues, expected.', 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedSpacingMode, 'linear');
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 linear scan-speed rows'));
            testCase.verifyFalse(contains(prefix, '_exp_'));
            testCase.verifyFalse(contains(prefix, '_custom_'));
        end

        function createsExponentiallySpacedSpeedRows(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.speedSpacingMode = 'exponential';
            params.lattice.nSpeeds = 3;
            params.lattice.speedStartMmPerSecond = 0.01;
            params.lattice.speedEndMmPerSecond = 1;

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [0.01; 0.1; 1];
            testCase.verifyEqual(data(:, 5), expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedValues, expected.', 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedSpacingMode, 'exponential');
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 exponentially spaced scan-speed rows'));
            testCase.verifyTrue(contains(prefix, 'scan_matrix_S_exp_0.01_to_1_3_rows_'));

            linearParams = params;
            linearParams.lattice.speedSpacingMode = 'linear';
            [~, linearPrefix] = generate_point_cloud(linearParams);
            testCase.verifyNotEqual(prefix, linearPrefix);
        end

        function customSpeedRowsPreserveOrderAndDeriveCount(testCase)
            params = localSinglePointRegions(localParams());
            params.lattice.speedSpacingMode = 'custom';
            params.lattice.speedValuesMmPerSecond = [0.5; 0.1; 1];
            params.lattice = rmfield(params.lattice, { ...
                'nSpeeds', 'speedStartMmPerSecond', 'speedEndMmPerSecond'});

            [data, prefix, summary] = generate_point_cloud(params);

            expected = [0.5; 0.1; 1];
            testCase.verifySize(data, [3, 5]);
            testCase.verifyEqual(data(:, 5), expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedValues, expected.', 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedRange, [0.1, 1], 'AbsTol', 1e-12);
            testCase.verifyEqual(summary.scanSpeedSpacingMode, 'custom');
            testCase.verifyTrue(contains(summary.latticeLabel, '3 speed rows'));
            testCase.verifyTrue(contains(summary.layerTraversalLabel, ...
                '3 custom scan-speed rows'));
            testCase.verifyTrue(contains(prefix, ...
                'scan_matrix_S_custom_0.5_to_1_3_rows_h'));
        end

        function rejectsInvalidCustomSpeedRows(testCase)
            invalidValues = { ...
                [0.1, 0], ...
                [0.1, -0.2], ...
                [0.1, NaN], ...
                [0.1, Inf]};

            for iCase = 1:numel(invalidValues)
                params = localSinglePointRegions(localParams());
                params.lattice.speedSpacingMode = 'custom';
                params.lattice.speedValuesMmPerSecond = invalidValues{iCase};

                [didThrow, message] = localCaptureError( ...
                    @() generate_point_cloud(params));

                testCase.verifyTrue(didThrow, sprintf( ...
                    'Expected custom scan-speed case %d to be rejected.', iCase));
                testCase.verifyTrue(contains(message, ...
                    'Scan-speed values must contain one or more finite numeric values greater than 0.'));
            end
        end
    end
end

function params = localParams()
params = struct();
params.lattice = struct( ...
    'type', "Scan Parameter Matrix", ...
    'displayDistanceUnit', 'mm', ...
    'nSpeeds', 2, ...
    'speedStartMmPerSecond', 0.01, ...
    'speedEndMmPerSecond', 0.03, ...
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
