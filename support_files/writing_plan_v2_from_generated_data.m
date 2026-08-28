function planTable = writing_plan_v2_from_generated_data(data, config)
%WRITING_PLAN_V2_FROM_GENERATED_DATA Build the canonical plan directly.

if isempty(data)
    planTable = table();
    return;
end
if size(data, 2) < 4
    error('Generated data must include X, Y, Z, and power columns.');
end

switch string(config.profile)
    case "point"
        planTable = localPointPlan(data, config);
    case "axis_path"
        planTable = localAxisPathPlan(data, config);
    case "recipe_path"
        planTable = localRecipePathPlan(data, config);
    otherwise
        error('Unsupported writing-plan profile: "%s".', config.profile);
end

planTable = normalize_writing_plan_v2(planTable);
end

function planTable = localPointPlan(data, config)
rowCount = size(data, 1);
pauseSeconds = localPauseValues(data, config);
dwellSeconds = localDwellValues(data, config);
planTable = localPlanTable( ...
    repmat("point", rowCount, 1), nan(rowCount, 1), nan(rowCount, 1), ...
    repmat("dwell", rowCount, 1), data(:, 1), data(:, 2), data(:, 3), ...
    nan(rowCount, 1), nan(rowCount, 1), nan(rowCount, 1), nan(rowCount, 1), ...
    data(:, 4), dwellSeconds, pauseSeconds, ...
    repmat(string(config.sourceRecipe), rowCount, 1));
planTable = localSortOperations(planTable, config);
if config.exposuresPerPoint > 1
    rows = repelem((1:height(planTable)).', config.exposuresPerPoint);
    planTable = planTable(rows, :);
end
end

function planTable = localAxisPathPlan(data, config)
rowCount = size(data, 1);
scanSpeed = localScanSpeedValues(data, config);
startCoordinates = data(:, 1:3);
endCoordinates = startCoordinates;
axisIndex = find(["X", "Y", "Z"] == upper(string(config.scanAxis)), 1);
if isempty(axisIndex)
    error('Unsupported path axis: "%s".', config.scanAxis);
end

directionSign = 1;
if string(config.scanDirection) == "negative"
    directionSign = -1;
end
lengthMm = config.scanLengthUm / 1000;
startShift = 0;
if string(config.scanAnchor) == "center_on_point"
    startShift = -directionSign * lengthMm / 2;
    endShift = directionSign * lengthMm / 2;
else
    endShift = directionSign * lengthMm;
end
startCoordinates(:, axisIndex) = startCoordinates(:, axisIndex) + startShift;
endCoordinates(:, axisIndex) = endCoordinates(:, axisIndex) + endShift;

exposurePlan = localPlanTable( ...
    repmat("path", rowCount, 1), (1:rowCount).', ones(rowCount, 1), ...
    repmat("on", rowCount, 1), ...
    startCoordinates(:, 1), startCoordinates(:, 2), startCoordinates(:, 3), ...
    endCoordinates(:, 1), endCoordinates(:, 2), endCoordinates(:, 3), ...
    scanSpeed, data(:, 4), ...
    nan(rowCount, 1), localPauseValues(data, config), ...
    repmat(string(config.sourceRecipe), rowCount, 1));
exposurePlan = localSortOperations(exposurePlan, config);

leadInMm = localNonnegativeConfigValue(config, 'scanLeadInMm', 0, 'Scan lead-in');
leadOutMm = localNonnegativeConfigValue(config, 'scanLeadOutMm', 0, 'Scan lead-out');
directionVector = zeros(1, 3);
directionVector(axisIndex) = directionSign;

exposureStarts = [exposurePlan.x_mm, exposurePlan.y_mm, exposurePlan.z_mm];
exposureEnds = [exposurePlan.x2_mm, exposurePlan.y2_mm, exposurePlan.z2_mm];
segmentCount = 1 + double(leadInMm > 0) + double(leadOutMm > 0);
expandedCount = rowCount * segmentCount;
segmentStarts = zeros(expandedCount, 3);
segmentEnds = zeros(expandedCount, 3);
laserState = strings(expandedCount, 1);

segmentPosition = 1;
if leadInMm > 0
    outputRows = segmentPosition:segmentCount:expandedCount;
    segmentStarts(outputRows, :) = exposureStarts - directionVector * leadInMm;
    segmentEnds(outputRows, :) = exposureStarts;
    laserState(outputRows) = "off";
    segmentPosition = segmentPosition + 1;
end

outputRows = segmentPosition:segmentCount:expandedCount;
segmentStarts(outputRows, :) = exposureStarts;
segmentEnds(outputRows, :) = exposureEnds;
laserState(outputRows) = "on";
segmentPosition = segmentPosition + 1;

if leadOutMm > 0
    outputRows = segmentPosition:segmentCount:expandedCount;
    segmentStarts(outputRows, :) = exposureEnds;
    segmentEnds(outputRows, :) = exposureEnds + directionVector * leadOutMm;
    laserState(outputRows) = "off";
end

planTable = localPlanTable( ...
    repmat("path", expandedCount, 1), ...
    repelem((1:rowCount).', segmentCount), ...
    repmat((1:segmentCount).', rowCount, 1), laserState, ...
    segmentStarts(:, 1), segmentStarts(:, 2), segmentStarts(:, 3), ...
    segmentEnds(:, 1), segmentEnds(:, 2), segmentEnds(:, 3), ...
    repelem(exposurePlan.speed_mm_s, segmentCount), ...
    repelem(exposurePlan.power, segmentCount), nan(expandedCount, 1), ...
    repelem(exposurePlan.pause_s, segmentCount), ...
    repelem(exposurePlan.source_recipe, segmentCount));
end

function planTable = localRecipePathPlan(data, config)
if size(data, 2) < 14
    error('Recipe path data must include end, approach, departure, and speed columns.');
end

rowCount = size(data, 1);
segmentSpeed = data(:, 14);
if size(data, 2) >= 15
    transitionSpeed = data(:, 15);
else
    transitionSpeed = segmentSpeed;
end
if size(data, 2) >= 16
    pauseSeconds = data(:, 16);
else
    pauseSeconds = zeros(rowCount, 1);
end
if size(data, 2) >= 18
    sourceGroupId = data(:, 17);
    sourceSegmentIndex = data(:, 18);
elseif size(data, 2) == 17
    error('Recipe path data must include both group id and segment index, or neither.');
else
    sourceGroupId = (1:rowCount).';
    sourceSegmentIndex = ones(rowCount, 1);
end

coordinates = data(:, [1:3, 5:13]);
if any(~isfinite(coordinates), 'all')
    error('Recipe path coordinates must all be finite.');
end
if any(~isfinite(segmentSpeed) | segmentSpeed <= 0 | ...
        ~isfinite(transitionSpeed) | transitionSpeed <= 0)
    error('Recipe path speeds must be finite positive values.');
end
if any(~isfinite(pauseSeconds) | pauseSeconds < 0)
    error('Recipe path pause values must be finite nonnegative values.');
end
localRequirePositiveIntegers(sourceGroupId, 'Recipe path group id');
localRequirePositiveIntegers(sourceSegmentIndex, 'Recipe path segment index');
sourceGroupId = round(sourceGroupId);
sourceSegmentIndex = round(sourceSegmentIndex);

groupStarts = [1; find(sourceGroupId(2:end) ~= sourceGroupId(1:end - 1)) + 1];
groupEnds = [groupStarts(2:end) - 1; rowCount];
orderedIds = sourceGroupId(groupStarts);
if numel(unique(orderedIds, 'stable')) ~= numel(orderedIds)
    error('Recipe path group ids must occupy contiguous row blocks.');
end

blocks = cell(numel(groupStarts), 1);
for groupIndex = 1:numel(groupStarts)
    rows = groupStarts(groupIndex):groupEnds(groupIndex);
    expectedSegments = (1:numel(rows)).';
    if any(sourceSegmentIndex(rows) ~= expectedSegments)
        error('Recipe path group %g segment indexes must be 1..N.', orderedIds(groupIndex));
    end
    blocks{groupIndex} = localRecipeGroup(data(rows, :), segmentSpeed(rows), ...
        transitionSpeed(rows), pauseSeconds(rows), groupIndex, config.sourceRecipe);
end
planTable = vertcat(blocks{:});
end

function block = localRecipeGroup(data, segmentSpeed, transitionSpeed, pauseSeconds, groupId, sourceRecipe)
rowCount = size(data, 1);
localRequireConstant(data(:, 4), 'power', groupId);
localRequireConstant(transitionSpeed, 'transition speed', groupId);
localRequireConstant(pauseSeconds, 'pause', groupId);

if rowCount > 1
    deltas = abs(data(1:end - 1, 5:7) - data(2:end, 1:3));
    if any(max(deltas, [], 2) > 1e-6)
        error('Recipe path group %g contains discontinuous exposure segments.', groupId);
    end
end

approachStart = data(1, 8:10);
exposureStart = data(1, 1:3);
exposureEnd = data(end, 5:7);
departureEnd = data(end, 11:13);
hasApproach = norm(approachStart - exposureStart) > 1e-12;
hasDeparture = norm(departureEnd - exposureEnd) > 1e-12;
outputCount = double(hasApproach) + rowCount + double(hasDeparture);

laserState = repmat("on", outputCount, 1);
startCoordinates = zeros(outputCount, 3);
endCoordinates = zeros(outputCount, 3);
speed = zeros(outputCount, 1);
offset = 0;
if hasApproach
    offset = 1;
    laserState(1) = "off";
    startCoordinates(1, :) = approachStart;
    endCoordinates(1, :) = exposureStart;
    speed(1) = transitionSpeed(1);
end
exposureRows = offset + (1:rowCount);
startCoordinates(exposureRows, :) = data(:, 1:3);
endCoordinates(exposureRows, :) = data(:, 5:7);
speed(exposureRows) = segmentSpeed;
if hasDeparture
    laserState(end) = "off";
    startCoordinates(end, :) = exposureEnd;
    endCoordinates(end, :) = departureEnd;
    speed(end) = transitionSpeed(1);
end

block = localPlanTable( ...
    repmat("path", outputCount, 1), repmat(groupId, outputCount, 1), ...
    (1:outputCount).', laserState, ...
    startCoordinates(:, 1), startCoordinates(:, 2), startCoordinates(:, 3), ...
    endCoordinates(:, 1), endCoordinates(:, 2), endCoordinates(:, 3), speed, ...
    repmat(data(1, 4), outputCount, 1), nan(outputCount, 1), ...
    repmat(pauseSeconds(1), outputCount, 1), repmat(string(sourceRecipe), outputCount, 1));
end

function pauseSeconds = localPauseValues(data, config)
pauseSeconds = repmat(config.pauseSeconds, size(data, 1), 1);
scanSpeedColumn = localOptionalColumn(config, 'scanSpeedColumn');
dwellColumn = localOptionalColumn(config, 'dwellColumn');
if size(data, 2) >= 5 && scanSpeedColumn ~= 5 && dwellColumn ~= 5
    pauseSeconds = data(:, 5);
end
if any(~isfinite(pauseSeconds) | pauseSeconds < 0)
    error('Generated pause values must be finite nonnegative numbers.');
end
end

function dwellValues = localDwellValues(data, config)
dwellColumn = localOptionalColumn(config, 'dwellColumn');
if isnan(dwellColumn)
    dwellValues = repmat(config.dwellSeconds, size(data, 1), 1);
elseif dwellColumn > size(data, 2)
    error('writingPlanV2:MissingDwellColumn', ...
        'Generated data does not contain configured dwell-time column %d.', dwellColumn);
else
    dwellValues = data(:, dwellColumn);
end
if any(~isfinite(dwellValues) | dwellValues < 0)
    error('writingPlanV2:InvalidDwellTime', ...
        'Generated dwell-time values must be finite nonnegative numbers.');
end
end

function speedValues = localScanSpeedValues(data, config)
scanSpeedColumn = localOptionalColumn(config, 'scanSpeedColumn');
if isnan(scanSpeedColumn)
    speedValues = repmat(config.scanSpeedMmPerSecond, size(data, 1), 1);
elseif scanSpeedColumn > size(data, 2)
    error('writingPlanV2:MissingScanSpeedColumn', ...
        'Generated data does not contain configured scan-speed column %d.', scanSpeedColumn);
else
    speedValues = data(:, scanSpeedColumn);
end
if any(~isfinite(speedValues) | speedValues <= 0)
    error('writingPlanV2:InvalidScanSpeed', ...
        'Generated scan-speed values must be finite positive numbers.');
end
end

function columnIndex = localOptionalColumn(config, fieldName)
columnIndex = nan;
if ~isfield(config, fieldName) || isempty(config.(fieldName))
    return;
end
columnIndex = config.(fieldName);
if ~(isscalar(columnIndex) && isnumeric(columnIndex) && isfinite(columnIndex) && ...
        columnIndex >= 1 && columnIndex == round(columnIndex))
    error('writingPlanV2:InvalidDataColumn', ...
        '%s must be a positive integer column index.', fieldName);
end
columnIndex = double(columnIndex);
end

function planTable = localSortOperations(planTable, config)
if isfield(config, 'preserveOrder') && config.preserveOrder || height(planTable) < 2
    return;
end
operationDepth = planTable.z_mm;
hasEnd = isfinite(planTable.z2_mm);
operationDepth(hasEnd) = min(operationDepth(hasEnd), planTable.z2_mm(hasEnd));
[~, order] = sortrows([operationDepth, (1:height(planTable)).'], [1, 2]);
planTable = planTable(order, :);
end

function planTable = localPlanTable(operation, groupId, segmentIndex, laserState, ...
        x, y, z, x2, y2, z2, speed, power, dwell, pauseSeconds, sourceRecipe)
rowCount = numel(operation);
planTable = table( ...
    repmat(2, rowCount, 1), string(operation(:)), groupId(:), segmentIndex(:), ...
    string(laserState(:)), x(:), y(:), z(:), x2(:), y2(:), z2(:), ...
    speed(:), power(:), dwell(:), pauseSeconds(:), string(sourceRecipe(:)), ...
    'VariableNames', writing_plan_v2_column_names());
end

function localRequirePositiveIntegers(values, label)
if any(~isfinite(values) | values < 1 | abs(values - round(values)) > 1e-9)
    error('%s values must be positive integers.', label);
end
end

function localRequireConstant(values, label, groupId)
if max(abs(values(:) - values(1))) > 1e-9
    error('Recipe path group %g must have constant %s.', groupId, label);
end
end

function value = localNonnegativeConfigValue(config, fieldName, defaultValue, label)
if isfield(config, fieldName)
    value = config.(fieldName);
else
    value = defaultValue;
end
if ~(isscalar(value) && isnumeric(value) && isfinite(value) && value >= 0)
    error('writingPlanV2:InvalidNonnegativeConfig', ...
        '%s must be a finite nonnegative number.', label);
end
value = double(value);
end
