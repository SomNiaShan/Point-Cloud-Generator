classdef TestRecipeMatrix < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            supportFolder = fullfile(repoRoot, 'support_files');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test)
        function readsSelectedSheetAndReturnsCounts(testCase)
            filePath = localWorkbookPath(testCase);
            writematrix(99, filePath, 'Sheet', 'Ignore');
            writematrix([0, 1, 2; 2, 0, 2], filePath, ...
                'Sheet', 'Pattern', 'Range', 'B2');

            [actual, info] = read_recipe_matrix_xlsx(filePath, "Pattern");

            testCase.verifyEqual(actual, [0, 1, 2; 2, 0, 2]);
            testCase.verifyEqual(info.rowCount, 2);
            testCase.verifyEqual(info.columnCount, 3);
            testCase.verifyEqual(info.recipeIds, [0; 1; 2]);
            testCase.verifyEqual(info.recipeCounts, [2; 1; 3]);
            testCase.verifyEqual(info.totalPixelCount, 6);
            testCase.verifyEqual(info.activePointCount, 4);
            testCase.verifyEqual(info.skippedPointCount, 2);
            testCase.verifyEqual(info.countsTable.recipe_id, [0; 1; 2]);
            testCase.verifyEqual(info.countsTable.pixel_count, [2; 1; 3]);
        end

        function missingWorksheetIsRejected(testCase)
            filePath = localWorkbookPath(testCase);
            writematrix(1, filePath, 'Sheet', 'Pattern');

            testCase.verifyError( ...
                @() read_recipe_matrix_xlsx(filePath, "Missing"), ...
                'recipeMatrix:UnknownSheet');
        end

        function nonXlsxFileIsRejected(testCase)
            filePath = [tempname, '.csv'];
            testCase.addTeardown(@localDeleteIfPresent, filePath);
            writematrix(1, filePath);

            testCase.verifyError( ...
                @() read_recipe_matrix_xlsx(filePath, "Pattern"), ...
                'recipeMatrix:InvalidFileType');
        end

        function internalBlankIsRejected(testCase)
            filePath = localWorkbookPath(testCase);
            writematrix([0, 1; 2, nan], filePath, 'Sheet', 'Pattern');

            testCase.verifyError( ...
                @() read_recipe_matrix_xlsx(filePath, "Pattern"), ...
                'recipeMatrix:InternalBlank');
        end

        function textCellIsRejected(testCase)
            filePath = localWorkbookPath(testCase);
            writecell({0, 1; 2, 'not-a-recipe'}, filePath, 'Sheet', 'Pattern');

            testCase.verifyError( ...
                @() read_recipe_matrix_xlsx(filePath, "Pattern"), ...
                'recipeMatrix:InvalidCellType');
        end

        function negativeAndFractionalIdsAreRejected(testCase)
            negativeFile = localWorkbookPath(testCase);
            writematrix([0, 1; 2, -1], negativeFile, 'Sheet', 'Pattern');
            fractionalFile = localWorkbookPath(testCase);
            writematrix([0, 1; 2, 1.5], fractionalFile, 'Sheet', 'Pattern');

            testCase.verifyError( ...
                @() read_recipe_matrix_xlsx(negativeFile, "Pattern"), ...
                'recipeMatrix:InvalidRecipeId');
            testCase.verifyError( ...
                @() read_recipe_matrix_xlsx(fractionalFile, "Pattern"), ...
                'recipeMatrix:InvalidRecipeId');
        end

        function rowMajorCoordinatesRespectAxisDirections(testCase)
            matrix = [1, 0, 2; 3, 4, 5];
            config = localCoordinateConfig();
            config.originXYZ = [10, 20, 30];
            config.pitchXY = [0.5, 2];
            config.columnDirection = '-X';
            config.rowDirection = '+Y';
            config.order = 'row_major';

            actual = recipe_matrix_to_points(matrix, config);

            testCase.verifyEqual(actual.recipe_id, [1; 2; 3; 4; 5]);
            testCase.verifyEqual(actual.row_index, [1; 1; 2; 2; 2]);
            testCase.verifyEqual(actual.column_index, [1; 3; 1; 2; 3]);
            testCase.verifyEqual(actual.x_mm, [10; 9; 10; 9.5; 9], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.y_mm, [20; 20; 22; 22; 22], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.z_mm, repmat(30, 5, 1));
        end

        function serpentineReversesEverySecondRow(testCase)
            matrix = [1, 2, 3; 4, 5, 6; 7, 0, 8];
            config = localCoordinateConfig();
            config.order = 'serpentine';

            actual = recipe_matrix_to_points(matrix, config);

            testCase.verifyEqual(actual.recipe_id, [1; 2; 3; 6; 5; 4; 7; 8]);
            testCase.verifyEqual(actual.row_index, [1; 1; 1; 2; 2; 2; 3; 3]);
            testCase.verifyEqual(actual.column_index, [1; 2; 3; 3; 2; 1; 1; 3]);
        end

        function topToBottomImageRowsWriteFromLowerLeftWithoutFlipping(testCase)
            matrix = [1, 2; 3, 4];
            config = localCoordinateConfig();
            config.pitchXY = [0.1, 0.2];
            config.order = 'row_major';
            config.matrixRowsTopToBottom = true;

            actual = recipe_matrix_to_points(matrix, config);

            testCase.verifyEqual(actual.recipe_id, [3; 4; 1; 2]);
            testCase.verifyEqual(actual.row_index, [2; 2; 1; 1]);
            testCase.verifyEqual(actual.column_index, [1; 2; 1; 2]);
            testCase.verifyEqual(actual.x_mm, [0; 0.1; 0; 0.1], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.y_mm, [0; 0; 0.2; 0.2], ...
                'AbsTol', 1e-12);
        end

        function recipeByRecipeGroupsAscendingIdsWithSerpentineOrder(testCase)
            matrix = [2, 1, 2, 3; 1, 3, 1, 2; 2, 1, 3, 3];
            config = localCoordinateConfig();
            config.order = 'recipe_by_recipe';

            actual = recipe_matrix_to_points(matrix, config);

            testCase.verifyEqual(actual.recipe_id, ...
                [1; 1; 1; 1; 2; 2; 2; 2; 3; 3; 3; 3]);
            testCase.verifyEqual(actual.row_index, ...
                [1; 2; 2; 3; 1; 1; 2; 3; 1; 2; 3; 3]);
            testCase.verifyEqual(actual.column_index, ...
                [2; 3; 1; 2; 1; 3; 4; 1; 4; 2; 3; 4]);
        end

        function recipeByRecipeAcceptsCustomGroupOrder(testCase)
            matrix = [1, 2, 3; 3, 2, 1];
            config = localCoordinateConfig();
            config.order = 'recipe_by_recipe';
            config.recipeOrder = [3, 2, 1];

            actual = recipe_matrix_to_points(matrix, config);

            testCase.verifyEqual(actual.recipe_id, [3; 3; 2; 2; 1; 1]);
            testCase.verifyEqual(actual.row_index, [1; 2; 1; 2; 1; 2]);
            testCase.verifyEqual(actual.column_index, [3; 1; 2; 2; 1; 3]);
        end

        function invalidCustomRecipeOrderIsRejected(testCase)
            config = localCoordinateConfig();
            config.order = 'recipe_by_recipe';
            config.recipeOrder = [3, 1];

            testCase.verifyError( ...
                @() recipe_matrix_to_points([1, 2, 3], config), ...
                'recipeMatrix:InvalidRecipeOrder');

            config.recipeOrder = [3, 2, 2, 1];
            testCase.verifyError( ...
                @() recipe_matrix_to_points([1, 2, 3], config), ...
                'recipeMatrix:InvalidRecipeOrder');
        end

        function includeZeroSupportsFullRasterPreview(testCase)
            config = localCoordinateConfig();
            config.includeZero = true;

            actual = recipe_matrix_to_points([0, 1; 2, 0], config);

            testCase.verifyEqual(height(actual), 4);
            testCase.verifyEqual(actual.recipe_id, [0; 1; 2; 0]);
        end

        function invalidCoordinateConfigIsRejected(testCase)
            config = localCoordinateConfig();
            config.pitchXY = [0.1, 0];
            testCase.verifyError( ...
                @() recipe_matrix_to_points(1, config), ...
                'recipeMatrix:InvalidPitch');

            config = localCoordinateConfig();
            config.rowDirection = '-X';
            testCase.verifyError( ...
                @() recipe_matrix_to_points(1, config), ...
                'recipeMatrix:InvalidDirection');
        end

        function recipeParametersBuildNormalizedPointPlan(testCase)
            matrix = [1, 2; 0, 1];
            recipes = localRecipeTable();
            config = localCoordinateConfig();
            config.order = 'row_major';

            actual = writing_plan_v2_from_recipe_matrix(matrix, recipes, config);

            testCase.verifyEqual(actual.Properties.VariableNames, ...
                writing_plan_v2_column_names());
            testCase.verifyEqual(height(actual), 5);
            testCase.verifyEqual(actual.operation, repmat("point", 5, 1));
            testCase.verifyEqual(actual.laser_state, repmat("dwell", 5, 1));
            testCase.verifyEqual(actual.x_mm, [0; 0; 0.1; 0.1; 0.1], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.y_mm, [0; 0; 0; 0.2; 0.2], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.z_mm, [0.03; 0.03; -0.04; 0.03; 0.03], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.power, [10; 10; 20; 10; 10]);
            testCase.verifyEqual(actual.dwell_s, [0.1; 0.1; 0.2; 0.1; 0.1]);
            testCase.verifyEqual(actual.pause_s, [0.01; 0.01; 0.02; 0.01; 0.01]);
            testCase.verifyEqual(actual.source_recipe, [ ...
                "excel_recipe_1_yellow"; ...
                "excel_recipe_1_yellow"; ...
                "excel_recipe_2_black"; ...
                "excel_recipe_1_yellow"; ...
                "excel_recipe_1_yellow"]);
            testCase.verifyTrue(all(isnan(actual.group_id)));
        end

        function recipeByRecipePlanKeepsRecipesAndExposuresTogether(testCase)
            recipes = localRecipeTable();
            config = localCoordinateConfig();
            config.order = 'recipe_by_recipe';

            actual = writing_plan_v2_from_recipe_matrix( ...
                [2, 1; 1, 2], recipes, config);

            testCase.verifyEqual(actual.power, [10; 10; 10; 10; 20; 20]);
            testCase.verifyEqual(actual.x_mm, [0.1; 0.1; 0; 0; 0; 0.1], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.y_mm, [0; 0; 0.2; 0.2; 0; 0.2], ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(actual.source_recipe, [ ...
                repmat("excel_recipe_1_yellow", 4, 1); ...
                repmat("excel_recipe_2_black", 2, 1)]);
        end

        function recipeActionSkipOmitsMappedNonzeroPoints(testCase)
            recipes = localRecipeTable();
            recipes.action(recipes.id == 2) = "skip";

            actual = writing_plan_v2_from_recipe_matrix( ...
                [1, 2], recipes, localCoordinateConfig());

            testCase.verifyEqual(height(actual), 2);
            testCase.verifyEqual(actual.power, [10; 10]);
            testCase.verifyEqual(actual.source_recipe, ...
                repmat("excel_recipe_1_yellow", 2, 1));
        end

        function zeroIsSkippedWithoutRecipeMapping(testCase)
            recipes = localRecipeTable();

            actual = writing_plan_v2_from_recipe_matrix( ...
                [0, 2], recipes, localCoordinateConfig());

            testCase.verifyEqual(height(actual), 1);
            testCase.verifyEqual(actual.source_recipe, "excel_recipe_2_black");
        end

        function missingNonzeroMappingIsRejected(testCase)
            recipes = localRecipeTable();

            testCase.verifyError( ...
                @() writing_plan_v2_from_recipe_matrix( ...
                [1, 3], recipes, localCoordinateConfig()), ...
                'recipeMatrix:MissingRecipeMapping');
        end

        function duplicateMappingAndProcessZeroAreRejected(testCase)
            recipes = localRecipeTable();
            duplicate = [recipes; recipes(1, :)];
            testCase.verifyError( ...
                @() writing_plan_v2_from_recipe_matrix( ...
                1, duplicate, localCoordinateConfig()), ...
                'recipeMatrix:DuplicateRecipeId');

            zeroRecipe = localRecipeTable();
            zeroRecipe = [localZeroRecipeRow(); zeroRecipe];
            zeroRecipe.action(zeroRecipe.id == 0) = "process";
            testCase.verifyError( ...
                @() writing_plan_v2_from_recipe_matrix( ...
                1, zeroRecipe, localCoordinateConfig()), ...
                'recipeMatrix:ZeroMustSkip');
        end

        function invalidProcessParametersAreRejected(testCase)
            recipes = localRecipeTable();
            recipes.exposures(1) = 1.5;

            testCase.verifyError( ...
                @() writing_plan_v2_from_recipe_matrix( ...
                1, recipes, localCoordinateConfig()), ...
                'recipeMatrix:InvalidRecipeParameters');
        end

        function invalidRecipeZShiftIsRejected(testCase)
            recipes = localRecipeTable();
            recipes.z_shift_mm(1) = inf;

            testCase.verifyError( ...
                @() writing_plan_v2_from_recipe_matrix( ...
                1, recipes, localCoordinateConfig()), ...
                'recipeMatrix:InvalidRecipeParameters');
        end

        function missingRecipeZShiftDefaultsToZero(testCase)
            recipes = removevars(localRecipeTable(), 'z_shift_mm');
            config = localCoordinateConfig();
            config.originXYZ(3) = 0.25;

            actual = writing_plan_v2_from_recipe_matrix( ...
                [1, 2], recipes, config);

            testCase.verifyEqual(actual.z_mm, repmat(0.25, 3, 1), ...
                'AbsTol', 1e-12);
        end

        function allSkippedRecipesAreRejected(testCase)
            recipes = localRecipeTable();
            recipes.action(:) = "skip";

            testCase.verifyError( ...
                @() writing_plan_v2_from_recipe_matrix( ...
                [1, 2], recipes, localCoordinateConfig()), ...
                'recipeMatrix:NoProcessPoints');
        end

        function unicodeRecipeNameRemainsAuditable(testCase)
            recipes = localRecipeTable();
            recipes.name(1) = "黄色 效果";

            actual = writing_plan_v2_from_recipe_matrix( ...
                1, recipes, localCoordinateConfig());

            testCase.verifyEqual(actual.source_recipe, ...
                repmat("excel_recipe_1_黄色_效果", 2, 1));
        end
    end
end

function config = localCoordinateConfig()
config = struct( ...
    'originXYZ', [0, 0, 0], ...
    'pitchXY', [0.1, 0.2], ...
    'columnDirection', '+X', ...
    'rowDirection', '+Y', ...
    'order', 'row_major');
end

function recipes = localRecipeTable()
id = [1; 2];
name = ["Yellow"; "Black"];
action = ["process"; "process"];
preview_color = ["#FFD700"; "#000000"];
z_shift_mm = [0.03; -0.04];
power = [10; 20];
dwell_s = [0.1; 0.2];
exposures = [2; 1];
pause_s = [0.01; 0.02];
pixel_count = [2; 1];
recipes = table(id, name, action, preview_color, power, dwell_s, ...
    exposures, pause_s, pixel_count);
recipes = addvars(recipes, z_shift_mm, 'After', 'preview_color');
end

function recipe = localZeroRecipeRow()
id = 0;
name = "No processing";
action = "skip";
preview_color = "#FFFFFF";
z_shift_mm = nan;
power = nan;
dwell_s = nan;
exposures = nan;
pause_s = nan;
pixel_count = 0;
recipe = table(id, name, action, preview_color, power, dwell_s, ...
    exposures, pause_s, pixel_count);
recipe = addvars(recipe, z_shift_mm, 'After', 'preview_color');
end

function filePath = localWorkbookPath(testCase)
filePath = [tempname, '.xlsx'];
testCase.addTeardown(@localDeleteIfPresent, filePath);
end

function localDeleteIfPresent(filePath)
if exist(filePath, 'file') == 2
    delete(filePath);
end
end
