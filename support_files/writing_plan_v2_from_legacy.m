function planTable = writing_plan_v2_from_legacy(legacyTable, sourceRecipe)
%WRITING_PLAN_V2_FROM_LEGACY Convert point/scan/cut rows to unified segments.

if ~istable(legacyTable) || isempty(legacyTable) || height(legacyTable) == 0
    error('Legacy writing plan must contain at least one row.');
end

requiredNames = {'mode', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'power', 'dwell_s', 'scan_speed_mm_s', 'pause_s', ...
    'lead_x_mm', 'lead_y_mm', 'lead_z_mm', ...
    'exit_x_mm', 'exit_y_mm', 'exit_z_mm', 'lead_speed_mm_s', ...
    'cut_group_id', 'cut_group_segment'};
missingNames = setdiff(requiredNames, legacyTable.Properties.VariableNames, 'stable');
if ~isempty(missingNames)
    error('Legacy writing plan is missing columns: %s.', strjoin(missingNames, ', '));
end

rowCount = height(legacyTable);
modes = lower(strtrim(string(legacyTable.mode(:))));
modes = regexprep(modes, '[\s-]+', '_');
modes(modes == "point_dwell") = "point";
modes(modes == "axis_scan") = "scan";
modes(modes == "cut_scan") = "cut";
if any(~ismember(modes, ["point", "scan", "cut"]))
    error('Legacy writing plan only supports point, scan, or cut modes.');
end

sourceRecipe = localRecipeVector(sourceRecipe, rowCount);
pointMask = modes == "point";
pathMask = modes ~= "point";
if any(pointMask) && any(pathMask)
    error('Writing plans cannot mix point and path operations in one file.');
end

if all(pointMask)
    planTable = localPointPlan(legacyTable, sourceRecipe);
elseif all(modes == "scan")
    planTable = localScanPlan(legacyTable, sourceRecipe);
else
    planTable = localPathPlan(legacyTable, modes, sourceRecipe);
end

planTable = normalize_writing_plan_v2(planTable);
end

function planTable = localPointPlan(legacyTable, sourceRecipe)
rowCount = height(legacyTable);
planTable = localPlanTable( ...
    repmat(2, rowCount, 1), repmat("point", rowCount, 1), ...
    nan(rowCount, 1), nan(rowCount, 1), repmat("dwell", rowCount, 1), ...
    legacyTable.x_mm, legacyTable.y_mm, legacyTable.z_mm, ...
    nan(rowCount, 1), nan(rowCount, 1), nan(rowCount, 1), nan(rowCount, 1), ...
    legacyTable.power, legacyTable.dwell_s, legacyTable.pause_s, sourceRecipe);
end

function planTable = localScanPlan(legacyTable, sourceRecipe)
rowCount = height(legacyTable);
planTable = localPlanTable( ...
    repmat(2, rowCount, 1), repmat("path", rowCount, 1), ...
    (1:rowCount).', ones(rowCount, 1), repmat("on", rowCount, 1), ...
    legacyTable.x_mm, legacyTable.y_mm, legacyTable.z_mm, ...
    legacyTable.x2_mm, legacyTable.y2_mm, legacyTable.z2_mm, ...
    legacyTable.scan_speed_mm_s, legacyTable.power, nan(rowCount, 1), ...
    legacyTable.pause_s, sourceRecipe);
end

function planTable = localPathPlan(legacyTable, modes, sourceRecipe)
rowCount = height(legacyTable);
blocks = cell(rowCount, 1);
blockCount = 0;
nextGroupId = 1;
seenLegacyCutIds = zeros(0, 1);
iRow = 1;

while iRow <= rowCount
    if modes(iRow) == "scan"
        rows = iRow;
        block = localPlanTable( ...
            2, "path", nextGroupId, 1, "on", ...
            legacyTable.x_mm(rows), legacyTable.y_mm(rows), legacyTable.z_mm(rows), ...
            legacyTable.x2_mm(rows), legacyTable.y2_mm(rows), legacyTable.z2_mm(rows), ...
            legacyTable.scan_speed_mm_s(rows), legacyTable.power(rows), nan, ...
            legacyTable.pause_s(rows), sourceRecipe(rows));
        iRow = iRow + 1;
    else
        legacyGroupId = legacyTable.cut_group_id(iRow);
        if ~isfinite(legacyGroupId)
            legacyGroupId = iRow;
        end
        if any(seenLegacyCutIds == legacyGroupId)
            error('Legacy cut group %g reappears after another operation.', legacyGroupId);
        end
        seenLegacyCutIds(end + 1, 1) = legacyGroupId; %#ok<AGROW>

        groupEnd = iRow;
        while groupEnd < rowCount && modes(groupEnd + 1) == "cut" && ...
                legacyTable.cut_group_id(groupEnd + 1) == legacyGroupId
            groupEnd = groupEnd + 1;
        end
        rows = iRow:groupEnd;
        block = localCutGroupBlock(legacyTable(rows, :), sourceRecipe(rows), nextGroupId);
        iRow = groupEnd + 1;
    end

    blockCount = blockCount + 1;
    blocks{blockCount} = block;
    nextGroupId = nextGroupId + 1;
end

planTable = vertcat(blocks{1:blockCount});
end

function block = localCutGroupBlock(groupTable, sourceRecipe, groupId)
rowCount = height(groupTable);
if any(abs(groupTable.power - groupTable.power(1)) > 1e-9)
    error('Legacy cut group %g must have constant power.', groupId);
end
if any(abs(groupTable.pause_s - groupTable.pause_s(1)) > 1e-9)
    error('Legacy cut group %g must have constant pause_s.', groupId);
end
if any(abs(groupTable.lead_speed_mm_s - groupTable.lead_speed_mm_s(1)) > 1e-9)
    error('Legacy cut group %g must have constant lead speed.', groupId);
end
if any(sourceRecipe ~= sourceRecipe(1))
    error('Legacy cut group %g must use one source recipe.', groupId);
end

leadStart = [groupTable.lead_x_mm(1), groupTable.lead_y_mm(1), groupTable.lead_z_mm(1)];
cutStart = [groupTable.x_mm(1), groupTable.y_mm(1), groupTable.z_mm(1)];
cutEnd = [groupTable.x2_mm(end), groupTable.y2_mm(end), groupTable.z2_mm(end)];
exitEnd = [groupTable.exit_x_mm(end), groupTable.exit_y_mm(end), groupTable.exit_z_mm(end)];
hasLead = norm(leadStart - cutStart) > 1e-12;
hasExit = norm(exitEnd - cutEnd) > 1e-12;
newRowCount = double(hasLead) + rowCount + double(hasExit);

laserState = repmat("on", newRowCount, 1);
x = zeros(newRowCount, 1);
y = zeros(newRowCount, 1);
z = zeros(newRowCount, 1);
x2 = zeros(newRowCount, 1);
y2 = zeros(newRowCount, 1);
z2 = zeros(newRowCount, 1);
speed = zeros(newRowCount, 1);

offset = 0;
if hasLead
    offset = 1;
    laserState(1) = "off";
    x(1) = leadStart(1);
    y(1) = leadStart(2);
    z(1) = leadStart(3);
    x2(1) = cutStart(1);
    y2(1) = cutStart(2);
    z2(1) = cutStart(3);
    speed(1) = groupTable.lead_speed_mm_s(1);
end

exposureRows = offset + (1:rowCount);
x(exposureRows) = groupTable.x_mm;
y(exposureRows) = groupTable.y_mm;
z(exposureRows) = groupTable.z_mm;
x2(exposureRows) = groupTable.x2_mm;
y2(exposureRows) = groupTable.y2_mm;
z2(exposureRows) = groupTable.z2_mm;
speed(exposureRows) = groupTable.scan_speed_mm_s;

if hasExit
    exitRow = newRowCount;
    laserState(exitRow) = "off";
    x(exitRow) = cutEnd(1);
    y(exitRow) = cutEnd(2);
    z(exitRow) = cutEnd(3);
    x2(exitRow) = exitEnd(1);
    y2(exitRow) = exitEnd(2);
    z2(exitRow) = exitEnd(3);
    speed(exitRow) = groupTable.lead_speed_mm_s(1);
end

block = localPlanTable( ...
    repmat(2, newRowCount, 1), repmat("path", newRowCount, 1), ...
    repmat(groupId, newRowCount, 1), (1:newRowCount).', laserState, ...
    x, y, z, x2, y2, z2, speed, ...
    repmat(groupTable.power(1), newRowCount, 1), nan(newRowCount, 1), ...
    repmat(groupTable.pause_s(1), newRowCount, 1), repmat(sourceRecipe(1), newRowCount, 1));
end

function planTable = localPlanTable(schemaVersion, operation, groupId, segmentIndex, ...
        laserState, x, y, z, x2, y2, z2, speed, power, dwell, pauseSeconds, sourceRecipe)
planTable = table( ...
    schemaVersion(:), string(operation(:)), groupId(:), segmentIndex(:), string(laserState(:)), ...
    x(:), y(:), z(:), x2(:), y2(:), z2(:), speed(:), power(:), dwell(:), ...
    pauseSeconds(:), string(sourceRecipe(:)), ...
    'VariableNames', writing_plan_v2_column_names());
end

function recipes = localRecipeVector(value, rowCount)
recipes = lower(strtrim(string(value(:))));
recipes = regexprep(recipes, '[\s-]+', '_');
if isscalar(recipes)
    recipes = repmat(recipes, rowCount, 1);
end
if numel(recipes) ~= rowCount
    error('sourceRecipe must be scalar or match the legacy writing plan row count.');
end
if any(ismissing(recipes) | strlength(recipes) == 0)
    error('sourceRecipe cannot be blank.');
end
end
