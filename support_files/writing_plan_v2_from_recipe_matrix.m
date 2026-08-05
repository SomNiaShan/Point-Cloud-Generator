function planTable = writing_plan_v2_from_recipe_matrix(recipeMatrix, recipeTable, config)
%WRITING_PLAN_V2_FROM_RECIPE_MATRIX Build point rows from a recipe raster.
%   PLAN = WRITING_PLAN_V2_FROM_RECIPE_MATRIX(MATRIX, RECIPETABLE, CONFIG)
%   maps every nonzero recipe id in MATRIX through RECIPETABLE and creates a
%   normalized Writing Plan v2 table.
%
%   RECIPETABLE must contain:
%     id, name, action, preview_color, power, dwell_s, exposures, pause_s
%   RECIPETABLE may also contain z_shift_mm. When present, each processed
%   point uses CONFIG.originXYZ(3) + z_shift_mm. If omitted, the shift is 0.
%   action is 'process' or 'skip'. Recipe id 0 is always skipped and may be
%   absent from RECIPETABLE. Every nonzero id in MATRIX must have one mapping.
%
%   CONFIG uses the fields documented by RECIPE_MATRIX_TO_POINTS. Repeated
%   exposures for each source pixel are emitted as consecutive plan rows.

if nargin < 3
    error('recipeMatrix:MissingPlanInput', ...
        'Recipe matrix, recipe table, and coordinate configuration are required.');
end

pointConfig = config;
pointConfig.includeZero = false;
points = recipe_matrix_to_points(recipeMatrix, pointConfig);
mapping = localValidateRecipeTable(recipeTable);

matrixRecipeIds = unique(double(recipeMatrix(:)), 'sorted');
requiredIds = matrixRecipeIds(matrixRecipeIds ~= 0);
missingIds = setdiff(requiredIds, mapping.id, 'stable');
if ~isempty(missingIds)
    error('recipeMatrix:MissingRecipeMapping', ...
        'Recipe mappings are missing for nonzero ids: %s.', ...
        strjoin(string(missingIds.'), ', '));
end

if isempty(points)
    error('recipeMatrix:NoProcessPoints', ...
        'Recipe matrix does not contain any nonzero points to process.');
end

[mappingFound, mappingRows] = ismember(points.recipe_id, mapping.id);
if any(~mappingFound)
    error('recipeMatrix:MissingRecipeMapping', ...
        'One or more nonzero recipe ids do not have mappings.');
end

processMask = mapping.action(mappingRows) == "process";
points = points(processMask, :);
mappingRows = mappingRows(processMask);
if isempty(points)
    error('recipeMatrix:NoProcessPoints', ...
        'All recipe points are configured to skip; no writing plan was generated.');
end
points.z_mm = points.z_mm + mapping.z_shift_mm(mappingRows);

exposureCounts = mapping.exposures(mappingRows);
expandedPointRows = repelem((1:height(points)).', exposureCounts);
expandedMappingRows = repelem(mappingRows, exposureCounts);
expandedPointRows = expandedPointRows(:);
expandedMappingRows = expandedMappingRows(:);
rowCount = numel(expandedPointRows);

sourceRecipe = strings(rowCount, 1);
uniqueMappingRows = unique(expandedMappingRows, 'stable');
for index = 1:numel(uniqueMappingRows)
    mappingRow = uniqueMappingRows(index);
    sourceValue = "excel_recipe_" + string(mapping.id(mappingRow)) + ...
        "_" + localRecipeNameToken(mapping.name(mappingRow));
    sourceRecipe(expandedMappingRows == mappingRow) = sourceValue;
end

planTable = table( ...
    repmat(2, rowCount, 1), ...
    repmat("point", rowCount, 1), ...
    nan(rowCount, 1), ...
    nan(rowCount, 1), ...
    repmat("dwell", rowCount, 1), ...
    points.x_mm(expandedPointRows), ...
    points.y_mm(expandedPointRows), ...
    points.z_mm(expandedPointRows), ...
    nan(rowCount, 1), ...
    nan(rowCount, 1), ...
    nan(rowCount, 1), ...
    nan(rowCount, 1), ...
    mapping.power(expandedMappingRows), ...
    mapping.dwell_s(expandedMappingRows), ...
    mapping.pause_s(expandedMappingRows), ...
    sourceRecipe, ...
    'VariableNames', writing_plan_v2_column_names());

planTable = normalize_writing_plan_v2(planTable);
end

function mapping = localValidateRecipeTable(recipeTable)
if ~istable(recipeTable)
    error('recipeMatrix:InvalidRecipeTable', ...
        'Recipe mappings must be provided as a table.');
end

requiredNames = ["id", "name", "action", "preview_color", ...
    "power", "dwell_s", "exposures", "pause_s"];
actualNames = string(recipeTable.Properties.VariableNames);
missingNames = setdiff(requiredNames, actualNames, 'stable');
if ~isempty(missingNames)
    error('recipeMatrix:InvalidRecipeTable', ...
        'Recipe table is missing columns: %s.', strjoin(missingNames, ', '));
end
if height(recipeTable) == 0
    error('recipeMatrix:InvalidRecipeTable', ...
        'Recipe table must contain at least one mapping row.');
end

mapping = struct();
mapping.id = localNumericColumn(recipeTable.id, 'id');
mapping.name = localTextColumn(recipeTable.name, 'name');
mapping.action = lower(strtrim(localTextColumn(recipeTable.action, 'action')));
mapping.action = regexprep(mapping.action, '[\s-]+', '_');
mapping.power = localNumericColumn(recipeTable.power, 'power');
mapping.dwell_s = localNumericColumn(recipeTable.dwell_s, 'dwell_s');
mapping.exposures = localNumericColumn(recipeTable.exposures, 'exposures');
mapping.pause_s = localNumericColumn(recipeTable.pause_s, 'pause_s');
if ismember("z_shift_mm", actualNames)
    mapping.z_shift_mm = localNumericColumn(recipeTable.z_shift_mm, 'z_shift_mm');
else
    mapping.z_shift_mm = zeros(height(recipeTable), 1);
end

mappedLengths = [numel(mapping.id), numel(mapping.name), ...
    numel(mapping.action), numel(mapping.power), numel(mapping.dwell_s), ...
    numel(mapping.exposures), numel(mapping.pause_s), ...
    numel(mapping.z_shift_mm)];
if any(mappedLengths ~= height(recipeTable))
    error('recipeMatrix:InvalidRecipeTable', ...
        'Each recipe table field must contain one value per mapping row.');
end

if any(~isfinite(mapping.id) | mapping.id < 0 | ...
        mapping.id ~= fix(mapping.id) | mapping.id > flintmax)
    error('recipeMatrix:InvalidRecipeTable', ...
        'Recipe table id values must be finite nonnegative integers.');
end
if numel(unique(mapping.id)) ~= numel(mapping.id)
    error('recipeMatrix:DuplicateRecipeId', ...
        'Recipe table id values must be unique.');
end
if any(~ismember(mapping.action, ["process", "skip"]))
    error('recipeMatrix:InvalidRecipeAction', ...
        'Recipe table action values must be process or skip.');
end

zeroRows = mapping.id == 0;
if any(zeroRows & mapping.action ~= "skip")
    error('recipeMatrix:ZeroMustSkip', ...
        'Recipe id 0 is reserved for no processing and must use action=skip.');
end

processRows = mapping.action == "process";
if any(processRows & ...
        (strlength(strtrim(mapping.name)) == 0 | ismissing(mapping.name)))
    error('recipeMatrix:InvalidRecipeTable', ...
        'Process recipe name values cannot be blank.');
end
if any(~isfinite(mapping.power(processRows)))
    error('recipeMatrix:InvalidRecipeParameters', ...
        'Process recipe power values must be finite numbers.');
end
if any(~isfinite(mapping.z_shift_mm(processRows)))
    error('recipeMatrix:InvalidRecipeParameters', ...
        'Process recipe z_shift_mm values must be finite numbers.');
end
if any(~isfinite(mapping.dwell_s(processRows)) | mapping.dwell_s(processRows) < 0)
    error('recipeMatrix:InvalidRecipeParameters', ...
        'Process recipe dwell_s values must be finite nonnegative numbers.');
end
if any(~isfinite(mapping.exposures(processRows)) | ...
        mapping.exposures(processRows) < 1 | ...
        mapping.exposures(processRows) ~= fix(mapping.exposures(processRows)) | ...
        mapping.exposures(processRows) > flintmax)
    error('recipeMatrix:InvalidRecipeParameters', ...
        'Process recipe exposures values must be positive integers.');
end
if any(~isfinite(mapping.pause_s(processRows)) | mapping.pause_s(processRows) < 0)
    error('recipeMatrix:InvalidRecipeParameters', ...
        'Process recipe pause_s values must be finite nonnegative numbers.');
end
mapping.exposures = double(mapping.exposures);
end

function values = localNumericColumn(rawValues, columnName)
if isnumeric(rawValues) || islogical(rawValues)
    if ~isvector(rawValues) || ~isreal(rawValues)
        error('recipeMatrix:InvalidRecipeTable', ...
            'Recipe table %s must be a real numeric column.', columnName);
    end
    values = double(rawValues(:));
    return;
end

if iscell(rawValues)
    validMask = cellfun(@(value) ...
        (isnumeric(value) || islogical(value)) && isscalar(value) && isreal(value), ...
        rawValues);
    if all(validMask)
        values = cellfun(@double, rawValues(:));
        return;
    end
end

error('recipeMatrix:InvalidRecipeTable', ...
    'Recipe table %s must contain numeric values.', columnName);
end

function values = localTextColumn(rawValues, columnName)
try
    values = string(rawValues(:));
catch
    error('recipeMatrix:InvalidRecipeTable', ...
        'Recipe table %s must contain text values.', columnName);
end
end

function token = localRecipeNameToken(name)
token = lower(strtrim(string(name)));
characters = char(token);
keepMask = isstrprop(characters, 'alphanum') | characters == '_';
characters(~keepMask) = '_';
token = string(characters);
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_+|_+$', '');
if strlength(token) == 0
    token = "unnamed";
end
end
