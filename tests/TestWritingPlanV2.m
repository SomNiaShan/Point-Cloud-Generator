classdef TestWritingPlanV2 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            supportFolder = fullfile(repoRoot, 'support_files');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test)
        function scanBecomesSingleLaserOnPathGroup(testCase)
            legacy = localLegacyPlan("scan", 2);
            legacy.x_mm = [0; 1];
            legacy.x2_mm = [0.5; 1.5];

            actual = writing_plan_v2_from_legacy(legacy, "cartesian");

            testCase.verifyEqual(actual.operation, repmat("path", 2, 1));
            testCase.verifyEqual(actual.group_id, [1; 2]);
            testCase.verifyEqual(actual.segment_index, [1; 1]);
            testCase.verifyEqual(actual.laser_state, repmat("on", 2, 1));
            testCase.verifyEqual(actual.speed_mm_s, legacy.scan_speed_mm_s);
        end

        function cutBecomesExplicitOffOnOffSegments(testCase)
            legacy = localLegacyPlan("cut", 2);
            legacy.x_mm = [0; 0.5];
            legacy.x2_mm = [0.5; 1];
            legacy.lead_x_mm = [-0.1; 0.4];
            legacy.exit_x_mm = [0.6; 1.1];
            legacy.cut_group_id = [7; 7];
            legacy.cut_group_segment = [1; 2];

            actual = writing_plan_v2_from_legacy(legacy, "hexagon_cut");

            testCase.verifyEqual(height(actual), 4);
            testCase.verifyEqual(actual.group_id, ones(4, 1));
            testCase.verifyEqual(actual.segment_index, (1:4).');
            testCase.verifyEqual(actual.laser_state, ["off"; "on"; "on"; "off"]);
            testCase.verifyEqual(actual.x_mm, [-0.1; 0; 0.5; 1], 'AbsTol', 1e-12);
            testCase.verifyEqual(actual.x2_mm, [0; 0.5; 1; 1.1], 'AbsTol', 1e-12);
        end

        function discontinuousGroupIsRejected(testCase)
            plan = localPathPlan();
            plan.x_mm(2) = 0.6;

            testCase.verifyError(@() normalize_writing_plan_v2(plan), ...
                'writingPlanV2:DiscontinuousGroup');
        end

        function pointRowsRemainPointOperations(testCase)
            legacy = localLegacyPlan("point", 2);
            legacy.dwell_s = [0.1; 0.2];

            actual = writing_plan_v2_from_legacy(legacy, "cartesian");

            testCase.verifyEqual(actual.operation, repmat("point", 2, 1));
            testCase.verifyEqual(actual.laser_state, repmat("dwell", 2, 1));
            testCase.verifyEqual(actual.dwell_s, [0.1; 0.2]);
            testCase.verifyTrue(all(isnan(actual.group_id)));
        end

        function generatedPointsBuildV2Directly(testCase)
            data = [0, 0, 0, 25; 1, 0, 0.5, 30];
            config = struct( ...
                'profile', "point", ...
                'pauseSeconds', 0.05, ...
                'dwellSeconds', 0.2, ...
                'exposuresPerPoint', 2, ...
                'sourceRecipe', "cartesian_point", ...
                'preserveOrder', false);

            actual = writing_plan_v2_from_generated_data(data, config);

            testCase.verifyEqual(actual.operation, repmat("point", 4, 1));
            testCase.verifyEqual(actual.dwell_s, repmat(0.2, 4, 1));
            testCase.verifyEqual(actual.z_mm, [0; 0; 0.5; 0.5]);
        end

        function generatedPointsAcceptPerRegionDwellTimes(testCase)
            data = [0, 0, 0, 10, 0.05; 1, 0, 0, 20, 0.25];
            config = struct( ...
                'profile', "point", ...
                'pauseSeconds', 0.1, ...
                'dwellSeconds', 0.01, ...
                'dwellColumn', 5, ...
                'exposuresPerPoint', 2, ...
                'sourceRecipe', "dwell_matrix", ...
                'preserveOrder', true);

            actual = writing_plan_v2_from_generated_data(data, config);

            testCase.verifyEqual(actual.dwell_s, [0.05; 0.05; 0.25; 0.25], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.power, [10; 10; 20; 20]);
            testCase.verifyEqual(actual.pause_s, repmat(0.1, 4, 1), ...
                'AbsTol', 1e-12);
        end

        function generatedAxisPathsBuildSingleSegmentGroups(testCase)
            data = [0, 0, 0, 25; 1, 0, 0.5, 30];
            config = struct( ...
                'profile', "axis_path", ...
                'pauseSeconds', 0.05, ...
                'scanAxis', "X", ...
                'scanDirection', "positive", ...
                'scanAnchor', "start_at_point", ...
                'scanLengthUm', 100, ...
                'scanSpeedMmPerSecond', 0.01, ...
                'sourceRecipe', "cartesian_axis_path", ...
                'preserveOrder', false);

            actual = writing_plan_v2_from_generated_data(data, config);

            testCase.verifyEqual(actual.operation, repmat("path", 2, 1));
            testCase.verifyEqual(actual.group_id, [1; 2]);
            testCase.verifyEqual(actual.segment_index, [1; 1]);
            testCase.verifyEqual(actual.laser_state, ["on"; "on"]);
            testCase.verifyEqual(actual.x2_mm - actual.x_mm, [0.1; 0.1], ...
                'AbsTol', 1e-12);
        end

        function generatedAxisPathsAcceptPerRegionScanSpeeds(testCase)
            data = [0, 0, 0, 10, 0.01; 1, 0, 0, 20, 0.03];
            config = localAxisConfig();
            config.scanSpeedColumn = 5;
            config.pauseSeconds = 0.2;
            config.scanLeadInMm = 0.01;
            config.scanLeadOutMm = 0.02;

            actual = writing_plan_v2_from_generated_data(data, config);

            testCase.verifyEqual(actual.speed_mm_s, [ ...
                repmat(0.01, 3, 1); repmat(0.03, 3, 1)], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.power, [ ...
                repmat(10, 3, 1); repmat(20, 3, 1)]);
            testCase.verifyEqual(actual.pause_s, repmat(0.2, 6, 1), ...
                'AbsTol', 1e-12);
        end

        function generatedAxisLeadSupportsEveryAxisDirectionAndAnchor(testCase)
            data = [1, 2, 3, 25];
            axisNames = ["X", "Y", "Z"];
            directionNames = ["positive", "negative"];
            directionSigns = [1, -1];
            anchorNames = ["start_at_point", "center_on_point"];
            scanLengthMm = 0.1;
            leadInMm = 0.02;
            leadOutMm = 0.03;

            for axisIndex = 1:numel(axisNames)
                for directionIndex = 1:numel(directionNames)
                    for anchorIndex = 1:numel(anchorNames)
                        config = localAxisConfig();
                        config.scanAxis = axisNames(axisIndex);
                        config.scanDirection = directionNames(directionIndex);
                        config.scanAnchor = anchorNames(anchorIndex);
                        config.scanLengthUm = scanLengthMm * 1000;
                        config.scanLeadInMm = leadInMm;
                        config.scanLeadOutMm = leadOutMm;

                        actual = writing_plan_v2_from_generated_data(data, config);

                        directionVector = zeros(1, 3);
                        directionVector(axisIndex) = directionSigns(directionIndex);
                        if anchorNames(anchorIndex) == "center_on_point"
                            exposureStart = data(1:3) - directionVector * scanLengthMm / 2;
                            exposureEnd = data(1:3) + directionVector * scanLengthMm / 2;
                        else
                            exposureStart = data(1:3);
                            exposureEnd = data(1:3) + directionVector * scanLengthMm;
                        end
                        expectedStarts = [ ...
                            exposureStart - directionVector * leadInMm; ...
                            exposureStart; ...
                            exposureEnd];
                        expectedEnds = [ ...
                            exposureStart; ...
                            exposureEnd; ...
                            exposureEnd + directionVector * leadOutMm];

                        testCase.verifyEqual(actual.laser_state, ["off"; "on"; "off"]);
                        testCase.verifyEqual(actual.group_id, ones(3, 1));
                        testCase.verifyEqual(actual.segment_index, (1:3).');
                        testCase.verifyEqual(actual.speed_mm_s, repmat(0.01, 3, 1));
                        testCase.verifyEqual(actual{:, {'x_mm', 'y_mm', 'z_mm'}}, ...
                            expectedStarts, 'AbsTol', 1e-12);
                        testCase.verifyEqual(actual{:, {'x2_mm', 'y2_mm', 'z2_mm'}}, ...
                            expectedEnds, 'AbsTol', 1e-12);
                    end
                end
            end
        end

        function zeroAxisLeadKeepsOneSegmentPerGroup(testCase)
            config = localAxisConfig();
            config.scanLeadInMm = 0;
            config.scanLeadOutMm = 0;

            actual = writing_plan_v2_from_generated_data([0, 0, 0, 25], config);

            testCase.verifyEqual(height(actual), 1);
            testCase.verifyEqual(actual.laser_state, "on");
            testCase.verifyEqual(actual.segment_index, 1);
        end

        function singleSidedAxisLeadOmitsZeroLengthSegments(testCase)
            config = localAxisConfig();
            config.scanLeadInMm = 0.02;
            config.scanLeadOutMm = 0;
            leadInOnly = writing_plan_v2_from_generated_data([0, 0, 0, 25], config);

            config.scanLeadInMm = 0;
            config.scanLeadOutMm = 0.03;
            leadOutOnly = writing_plan_v2_from_generated_data([0, 0, 0, 25], config);

            testCase.verifyEqual(leadInOnly.laser_state, ["off"; "on"]);
            testCase.verifyEqual(leadOutOnly.laser_state, ["on"; "off"]);
            testCase.verifyEqual(leadInOnly.segment_index, [1; 2]);
            testCase.verifyEqual(leadOutOnly.segment_index, [1; 2]);
        end

        function axisLeadExpansionKeepsSortedGroupsContiguous(testCase)
            data = [11, 0, 0.5, 25; 22, 0, 0, 30];
            config = localAxisConfig();
            config.scanAxis = "Z";
            config.scanLeadInMm = 0.6;
            config.scanLeadOutMm = 0.4;

            actual = writing_plan_v2_from_generated_data(data, config);

            testCase.verifyEqual(actual.group_id, [1; 1; 1; 2; 2; 2]);
            testCase.verifyEqual(actual.segment_index, [1; 2; 3; 1; 2; 3]);
            onRows = actual(actual.laser_state == "on", :);
            testCase.verifyEqual(onRows.x_mm, [22; 11]);
            testCase.verifyEqual(onRows.z_mm, [0; 0.5], 'AbsTol', 1e-12);
        end

        function negativeAxisLeadIsRejected(testCase)
            config = localAxisConfig();
            config.scanLeadInMm = -0.01;

            testCase.verifyError( ...
                @() writing_plan_v2_from_generated_data([0, 0, 0, 25], config), ...
                'writingPlanV2:InvalidNonnegativeConfig');
        end

        function generatedRecipePathKeepsExplicitLaserStates(testCase)
            first = [0, 0, 0, 50, 0.5, 0, 0, -0.1, 0, 0, 1.1, 0, 0, ...
                0.01, 0.02, 0.1, 7, 1];
            second = [0.5, 0, 0, 50, 1, 0, 0, 0.4, 0, 0, 1.1, 0, 0, ...
                0.01, 0.02, 0.1, 7, 2];
            config = struct( ...
                'profile', "recipe_path", ...
                'sourceRecipe', "hexagon_path", ...
                'preserveOrder', true);

            actual = writing_plan_v2_from_generated_data( ...
                [first; second], config);

            testCase.verifyEqual(actual.laser_state, ...
                ["off"; "on"; "on"; "off"]);
            testCase.verifyEqual(actual.segment_index, (1:4).');
            testCase.verifyEqual(actual.speed_mm_s, ...
                [0.02; 0.01; 0.01; 0.02]);
        end
    end
end

function config = localAxisConfig()
config = struct( ...
    'profile', "axis_path", ...
    'pauseSeconds', 0.05, ...
    'scanAxis', "X", ...
    'scanDirection', "positive", ...
    'scanAnchor', "start_at_point", ...
    'scanLengthUm', 100, ...
    'scanSpeedMmPerSecond', 0.01, ...
    'sourceRecipe', "cartesian_axis_path", ...
    'preserveOrder', false);
end

function plan = localLegacyPlan(modeValue, rowCount)
mode = repmat(string(modeValue), rowCount, 1);
x = zeros(rowCount, 1);
y = zeros(rowCount, 1);
z = zeros(rowCount, 1);
x2 = ones(rowCount, 1);
y2 = zeros(rowCount, 1);
z2 = zeros(rowCount, 1);
power = repmat(50, rowCount, 1);
dwell = nan(rowCount, 1);
scanSpeed = repmat(0.01, rowCount, 1);
pauseSeconds = zeros(rowCount, 1);
leadX = x - 0.1;
leadY = y;
leadZ = z;
exitX = x2 + 0.1;
exitY = y2;
exitZ = z2;
leadSpeed = repmat(0.02, rowCount, 1);
cutGroupId = (1:rowCount).';
cutGroupSegment = ones(rowCount, 1);
plan = table(mode, x, y, z, x2, y2, z2, power, dwell, scanSpeed, pauseSeconds, ...
    leadX, leadY, leadZ, exitX, exitY, exitZ, leadSpeed, cutGroupId, cutGroupSegment, ...
    'VariableNames', {'mode', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'power', 'dwell_s', 'scan_speed_mm_s', 'pause_s', ...
    'lead_x_mm', 'lead_y_mm', 'lead_z_mm', ...
    'exit_x_mm', 'exit_y_mm', 'exit_z_mm', 'lead_speed_mm_s', ...
    'cut_group_id', 'cut_group_segment'});
end

function plan = localPathPlan()
schemaVersion = repmat(2, 2, 1);
operation = repmat("path", 2, 1);
groupId = ones(2, 1);
segmentIndex = (1:2).';
laserState = repmat("on", 2, 1);
x = [0; 0.5];
y = zeros(2, 1);
z = zeros(2, 1);
x2 = [0.5; 1];
y2 = zeros(2, 1);
z2 = zeros(2, 1);
speed = repmat(0.01, 2, 1);
power = repmat(50, 2, 1);
dwell = nan(2, 1);
pauseSeconds = zeros(2, 1);
sourceRecipe = repmat("test", 2, 1);
plan = table(schemaVersion, operation, groupId, segmentIndex, laserState, ...
    x, y, z, x2, y2, z2, speed, power, dwell, pauseSeconds, sourceRecipe, ...
    'VariableNames', writing_plan_v2_column_names());
end
