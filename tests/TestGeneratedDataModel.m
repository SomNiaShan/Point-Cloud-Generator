classdef TestGeneratedDataModel < matlab.unittest.TestCase
    methods (Test)
        function pointColumnsReceiveNames(testCase)
            data = [0, 1, 2, 10, 0.25; 3, 4, 5, 20, 0.5];
            config = struct('profile', "point", 'dwellColumn', 5);
            actual = generated_data_to_table(data, config);

            testCase.verifyEqual(actual.Properties.VariableNames, ...
                {'x_mm', 'y_mm', 'z_mm', 'power', 'dwell_s'});
            testCase.verifyEqual(actual.dwell_s, [0.25; 0.5]);
        end

        function zPushPauseReceivesName(testCase)
            data = [0, 0, -0.1, 10, 0.2; 0, 0, -0.2, 10, 0.2];
            config = struct('profile', "point", 'pauseColumn', 5);
            actual = generated_data_to_table(data, config);
            testCase.verifyEqual(actual.pause_s, [0.2; 0.2]);
            testCase.verifyFalse(ismember('dwell_s', actual.Properties.VariableNames));
        end

        function namedPointDataBuildsCanonicalPlan(testCase)
            data = [0, 0, 0, 10, 0.1; 1, 0, 0, 20, 0.2];
            config = struct( ...
                'profile', "point", ...
                'dwellSeconds', 1, ...
                'dwellColumn', 5, ...
                'exposuresPerPoint', 2, ...
                'pauseSeconds', 0.05, ...
                'preserveOrder', true, ...
                'sourceRecipe', "named_point");
            named = generated_data_to_table(data, config);
            actual = writing_plan_v2_from_generated_data(named, config);

            testCase.verifyEqual(height(actual), 4);
            testCase.verifyEqual(actual.dwell_s, [0.1; 0.1; 0.2; 0.2]);
            testCase.verifyEqual(actual.power, [10; 10; 20; 20]);
        end

        function recipePathColumnsAndEstimateAreNamed(testCase)
            data = zeros(2, 18);
            data(:, 1:3) = [0, 0, 0; 1, 0, 0];
            data(:, 4) = 50;
            data(:, 5:7) = [1, 0, 0; 2, 0, 0];
            data(:, 8:10) = [-1, 0, 0; 1, 0, 0];
            data(:, 11:13) = [1, 0, 0; 3, 0, 0];
            data(:, 14:16) = [1, 1, 0; 1, 1, 0];
            data(:, 17:18) = [1, 1; 1, 2];
            config = struct('profile', "recipe_path", 'pauseSeconds', 0, ...
                'preserveOrder', true, 'sourceRecipe', "named_cut");
            named = generated_data_to_table(data, config);

            testCase.verifyTrue(all(ismember( ...
                {'segment_speed_mm_s', 'source_group_id', 'source_segment_index'}, ...
                named.Properties.VariableNames)));
            testCase.verifyEqual(estimate_writing_plan_rows(named, config), 4);
            actual = writing_plan_v2_from_generated_data(named, config);
            testCase.verifyEqual(height(actual), 4);
            testCase.verifyEqual(actual.laser_state, ["off"; "on"; "on"; "off"]);
        end

        function expansionEstimateCoversPointAndAxis(testCase)
            point = table([0; 1], [0; 0], [0; 0], [10; 10], [2; 3], ...
                'VariableNames', {'x_mm', 'y_mm', 'z_mm', 'power', 'exposure_count'});
            pointConfig = struct('profile', "point", 'exposuresPerPoint', 1);
            testCase.verifyEqual(estimate_writing_plan_rows(point, pointConfig), 5);

            axisConfig = struct('profile', "axis_path", ...
                'scanLeadInMm', 0.005, 'scanLeadOutMm', 0.005);
            testCase.verifyEqual(estimate_writing_plan_rows(point(:, 1:4), axisConfig), 6);
        end

        function emptyGeneratedDataHasNoOperations(testCase)
            emptyPoint = table([], [], [], [], ...
                'VariableNames', {'x_mm', 'y_mm', 'z_mm', 'power'});
            config = struct('profile', "point", 'exposuresPerPoint', 1);
            testCase.verifyEqual(estimate_writing_plan_rows(emptyPoint, config), 0);
        end
    end
end
