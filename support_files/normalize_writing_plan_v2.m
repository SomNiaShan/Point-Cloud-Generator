function planTable = normalize_writing_plan_v2(rawTable)
%NORMALIZE_WRITING_PLAN_V2 Validate and normalize a unified writing plan.

if ~istable(rawTable) || isempty(rawTable) || height(rawTable) == 0
    error('Writing plan v2 must contain at least one row.');
end

expectedNames = writing_plan_v2_column_names();
actualNames = string(rawTable.Properties.VariableNames);
missingNames = setdiff(string(expectedNames), actualNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan v2 is missing columns: %s.', strjoin(missingNames, ', '));
end

rowCount = height(rawTable);
schemaVersion = localNumericColumn(rawTable.schema_version, 'schema_version');
operation = localOptionColumn(rawTable.operation);
groupId = localNumericColumn(rawTable.group_id, 'group_id');
segmentIndex = localNumericColumn(rawTable.segment_index, 'segment_index');
laserState = localOptionColumn(rawTable.laser_state);
x = localNumericColumn(rawTable.x_mm, 'x_mm');
y = localNumericColumn(rawTable.y_mm, 'y_mm');
z = localNumericColumn(rawTable.z_mm, 'z_mm');
x2 = localNumericColumn(rawTable.x2_mm, 'x2_mm');
y2 = localNumericColumn(rawTable.y2_mm, 'y2_mm');
z2 = localNumericColumn(rawTable.z2_mm, 'z2_mm');
speed = localNumericColumn(rawTable.speed_mm_s, 'speed_mm_s');
power = localNumericColumn(rawTable.power, 'power');
dwell = localNumericColumn(rawTable.dwell_s, 'dwell_s');
pauseSeconds = localNumericColumn(rawTable.pause_s, 'pause_s');
sourceRecipe = localOptionColumn(rawTable.source_recipe);

if any(schemaVersion ~= 2)
    error('Writing plan v2 schema_version must equal 2 on every row.');
end
if any(~ismember(operation, ["point", "path"]))
    error('Writing plan v2 operation only supports point or path.');
end
if any(~isfinite(x) | ~isfinite(y) | ~isfinite(z))
    error('Writing plan v2 start coordinates must be finite.');
end
if any(~isfinite(power))
    error('Writing plan v2 power values must be finite.');
end
if any(ismissing(sourceRecipe) | strlength(sourceRecipe) == 0)
    error('Writing plan v2 source_recipe values cannot be blank.');
end

pointMask = operation == "point";
pathMask = operation == "path";
if any(pointMask) && any(pathMask)
    error('Writing plan v2 cannot mix point and path operations in one file.');
end

if any(pointMask)
    localValidatePointRows(pointMask);
else
    localValidatePathRows();
end

planTable = table(schemaVersion, operation, groupId, segmentIndex, laserState, ...
    x, y, z, x2, y2, z2, speed, power, dwell, pauseSeconds, sourceRecipe, ...
    'VariableNames', expectedNames);

if height(planTable) ~= rowCount
    error('Writing plan v2 has an invalid row count.');
end

    function localValidatePointRows(mask)
        if any(laserState(mask) ~= "dwell")
            error('Writing plan v2 point rows must use laser_state=dwell.');
        end
        if any(isfinite(groupId(mask)) | isfinite(segmentIndex(mask)))
            error('Writing plan v2 point rows cannot contain group or segment identifiers.');
        end
        if any(isfinite(x2(mask)) | isfinite(y2(mask)) | isfinite(z2(mask)) | isfinite(speed(mask)))
            error('Writing plan v2 point rows cannot contain path end coordinates or speed.');
        end
        if any(~isfinite(dwell(mask)) | dwell(mask) < 0)
            error('Writing plan v2 point rows must contain nonnegative dwell_s values.');
        end
        if any(~isfinite(pauseSeconds(mask)) | pauseSeconds(mask) < 0)
            error('Writing plan v2 point rows must contain nonnegative pause_s values.');
        end
    end

    function localValidatePathRows()
        if any(~isfinite(groupId) | groupId < 1 | abs(groupId - round(groupId)) > 1e-9)
            error('Writing plan v2 path group_id values must be positive integers.');
        end
        if any(~isfinite(segmentIndex) | segmentIndex < 1 | abs(segmentIndex - round(segmentIndex)) > 1e-9)
            error('Writing plan v2 path segment_index values must be positive integers.');
        end
        if any(~ismember(laserState, ["on", "off"]))
            error('Writing plan v2 path laser_state only supports on or off.');
        end
        if any(~isfinite(x2) | ~isfinite(y2) | ~isfinite(z2))
            error('Writing plan v2 path end coordinates must be finite.');
        end
        segmentLengths = sqrt((x2 - x) .^ 2 + (y2 - y) .^ 2 + (z2 - z) .^ 2);
        if any(segmentLengths <= 1e-12)
            error('Writing plan v2 path segments must have nonzero length.');
        end
        if any(~isfinite(speed) | speed <= 0)
            error('Writing plan v2 path speed_mm_s values must be positive.');
        end
        if any(isfinite(dwell))
            error('Writing plan v2 path rows must leave dwell_s blank.');
        end
        if any(~isfinite(pauseSeconds) | pauseSeconds < 0)
            error('Writing plan v2 path pause_s values must be nonnegative.');
        end

        groupStarts = [1; find(groupId(2:end) ~= groupId(1:end - 1)) + 1];
        groupEnds = [groupStarts(2:end) - 1; rowCount];
        groupIds = groupId(groupStarts);
        if numel(unique(groupIds, 'stable')) ~= numel(groupIds)
            error('Writing plan v2 group_id values must occupy contiguous row blocks.');
        end

        for iGroup = 1:numel(groupStarts)
            rows = groupStarts(iGroup):groupEnds(iGroup);
            expectedSegments = (1:numel(rows)).';
            if any(round(segmentIndex(rows)) ~= expectedSegments)
                error('Writing plan v2 group %g segment_index values must be 1..N.', groupIds(iGroup));
            end

            if numel(rows) > 1
                deltas = abs([ ...
                    x2(rows(1:end - 1)) - x(rows(2:end)), ...
                    y2(rows(1:end - 1)) - y(rows(2:end)), ...
                    z2(rows(1:end - 1)) - z(rows(2:end))]);
                if any(max(deltas, [], 2) > 1e-6)
                    error('writingPlanV2:DiscontinuousGroup', ...
                        'Writing plan v2 group %g contains discontinuous segments.', groupIds(iGroup));
                end
            end

            onPositions = find(laserState(rows) == "on");
            if isempty(onPositions)
                error('Writing plan v2 group %g must contain at least one laser-on segment.', groupIds(iGroup));
            end
            if any(diff(onPositions) ~= 1)
                error('Writing plan v2 group %g laser-on segments must form one continuous block.', groupIds(iGroup));
            end
            if onPositions(1) > 2 || onPositions(end) < numel(rows) - 1
                error(['Writing plan v2 group %g supports at most one laser-off lead segment ', ...
                    'and one laser-off exit segment.'], groupIds(iGroup));
            end

            localRequireConstant(power(rows), 'power', groupIds(iGroup));
            localRequireConstant(pauseSeconds(rows), 'pause_s', groupIds(iGroup));
            if any(sourceRecipe(rows) ~= sourceRecipe(rows(1)))
                error('Writing plan v2 group %g must use one source_recipe.', groupIds(iGroup));
            end

            offRows = rows(laserState(rows) == "off");
            if numel(offRows) == 2 && abs(speed(offRows(1)) - speed(offRows(2))) > 1e-9
                error('Writing plan v2 group %g lead and exit speeds must match.', groupIds(iGroup));
            end
        end
    end
end

function localRequireConstant(values, label, groupId)
if max(abs(values(:) - values(1))) > 1e-9
    error('Writing plan v2 group %g must have constant %s.', groupId, label);
end
end

function values = localNumericColumn(value, columnName)
if isnumeric(value)
    values = double(value(:));
    return;
end

textValue = strtrim(string(value(:)));
values = str2double(textValue);
missingMask = ismissing(textValue) | strlength(textValue) == 0 | ...
    strcmpi(textValue, "NaN") | strcmpi(textValue, "NA");
values(missingMask) = nan;
if any(isnan(values) & ~missingMask)
    error('%s column contains values that cannot be parsed as numbers.', columnName);
end
end

function values = localOptionColumn(value)
values = lower(strtrim(string(value(:))));
values = regexprep(values, '[\s-]+', '_');
end
