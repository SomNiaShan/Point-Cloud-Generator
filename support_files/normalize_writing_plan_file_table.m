function planTable = normalize_writing_plan_file_table(rawTable)
%NORMALIZE_WRITING_PLAN_FILE_TABLE Normalize v2 or adapt a legacy file.

actualNames = string(rawTable.Properties.VariableNames);
if all(ismember(["schema_version", "operation"], actualNames))
    planTable = normalize_writing_plan_v2(rawTable);
    return;
end

expectedNames = localLegacyColumnNames();
baseNames = expectedNames(1:11);
missingNames = setdiff(string(baseNames), actualNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan file is missing columns: %s.', strjoin(missingNames, ', '));
end

rowCount = height(rawTable);
mode = localNormalizeModes(rawTable.mode);
x = localNumericColumn(rawTable.x_mm, 'x_mm');
y = localNumericColumn(rawTable.y_mm, 'y_mm');
z = localNumericColumn(rawTable.z_mm, 'z_mm');
x2 = localNumericColumn(rawTable.x2_mm, 'x2_mm');
y2 = localNumericColumn(rawTable.y2_mm, 'y2_mm');
z2 = localNumericColumn(rawTable.z2_mm, 'z2_mm');
power = localNumericColumn(rawTable.power, 'power');
dwell = localNumericColumn(rawTable.dwell_s, 'dwell_s');
scanSpeed = localNumericColumn(rawTable.scan_speed_mm_s, 'scan_speed_mm_s');
pauseSeconds = localNumericColumn(rawTable.pause_s, 'pause_s');
leadX = localOptionalNumericColumn(rawTable, 'lead_x_mm', rowCount);
leadY = localOptionalNumericColumn(rawTable, 'lead_y_mm', rowCount);
leadZ = localOptionalNumericColumn(rawTable, 'lead_z_mm', rowCount);
exitX = localOptionalNumericColumn(rawTable, 'exit_x_mm', rowCount);
exitY = localOptionalNumericColumn(rawTable, 'exit_y_mm', rowCount);
exitZ = localOptionalNumericColumn(rawTable, 'exit_z_mm', rowCount);
leadSpeed = localOptionalNumericColumn(rawTable, 'lead_speed_mm_s', rowCount);
[groupId, groupSegment] = localGroupColumns(rawTable, mode);

if any(~isfinite(x) | ~isfinite(y) | ~isfinite(z))
    error('x_mm, y_mm, and z_mm columns must all be finite numbers.');
end
if any(~isfinite(power))
    error('The power column must contain only finite numbers.');
end

scanMask = mode == "scan";
if any(scanMask)
    if any(~isfinite(x2(scanMask)) | ~isfinite(y2(scanMask)) | ~isfinite(z2(scanMask)))
        error('Legacy scan rows must contain finite end coordinates.');
    end
    if any(~isfinite(scanSpeed(scanMask)) | scanSpeed(scanMask) <= 0)
        error('Legacy scan rows must contain positive speed values.');
    end
end

cutMask = mode == "cut";
if any(cutMask)
    if any(~isfinite(x2(cutMask)) | ~isfinite(y2(cutMask)) | ~isfinite(z2(cutMask)))
        error('Legacy cut rows must contain finite end coordinates.');
    end
    if any(~isfinite(leadX(cutMask)) | ~isfinite(leadY(cutMask)) | ...
            ~isfinite(leadZ(cutMask)) | ~isfinite(exitX(cutMask)) | ...
            ~isfinite(exitY(cutMask)) | ~isfinite(exitZ(cutMask)))
        error('Legacy cut rows must contain finite lead and exit coordinates.');
    end
    if any(~isfinite(scanSpeed(cutMask)) | scanSpeed(cutMask) <= 0)
        error('Legacy cut rows must contain positive exposure speeds.');
    end
    cutIndices = find(cutMask);
    missingLeadSpeed = isnan(leadSpeed(cutMask));
    leadSpeed(cutIndices(missingLeadSpeed)) = scanSpeed(cutIndices(missingLeadSpeed));
    if any(~isfinite(leadSpeed(cutMask)) | leadSpeed(cutMask) <= 0)
        error('Legacy cut rows must contain positive transition speeds.');
    end
end

pointMask = mode == "point";
if any(pointMask) && any(~isfinite(dwell(pointMask)) | dwell(pointMask) < 0)
    error('Legacy point rows must contain nonnegative dwell values.');
end
if any(isfinite(pauseSeconds) & pauseSeconds < 0)
    error('Legacy pause values cannot be negative.');
end

legacyTable = table(mode, x, y, z, x2, y2, z2, power, dwell, scanSpeed, ...
    pauseSeconds, leadX, leadY, leadZ, exitX, exitY, exitZ, leadSpeed, ...
    groupId, groupSegment, 'VariableNames', expectedNames);
planTable = writing_plan_v2_from_legacy( ...
    legacyTable, localSourceRecipes(mode));
end

function names = localLegacyColumnNames()
names = {'mode', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'power', 'dwell_s', 'scan_speed_mm_s', 'pause_s', ...
    'lead_x_mm', 'lead_y_mm', 'lead_z_mm', ...
    'exit_x_mm', 'exit_y_mm', 'exit_z_mm', 'lead_speed_mm_s', ...
    'cut_group_id', 'cut_group_segment'};
end

function recipes = localSourceRecipes(mode)
recipes = repmat("legacy_path", numel(mode), 1);
recipes(mode == "point") = "legacy_point_dwell";
recipes(mode == "scan") = "legacy_axis_scan";
recipes(mode == "cut") = "legacy_cut";
end

function modes = localNormalizeModes(value)
modes = lower(strtrim(string(value)));
modes = regexprep(modes, '[\s-]+', '_');
modes(modes == "axis_scan") = "scan";
modes(modes == "point_dwell") = "point";
modes(modes == "cut_scan" | modes == "hexagon_cut" | ...
    modes == "hexagon_release_cut" | ...
    modes == "hexagon_release_cut_array" | ...
    modes == "circle_release_cut") = "cut";
if any(~ismember(modes, ["point", "scan", "cut"]))
    error('Legacy mode only supports point, scan, or cut.');
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

function values = localOptionalNumericColumn(rawTable, columnName, rowCount)
if any(strcmp(rawTable.Properties.VariableNames, columnName))
    values = localNumericColumn(rawTable.(columnName), columnName);
else
    values = nan(rowCount, 1);
end
end

function [groupId, groupSegment] = localGroupColumns(rawTable, mode)
rowCount = height(rawTable);
cutMask = mode == "cut";
hasGroupId = any(strcmp(rawTable.Properties.VariableNames, 'cut_group_id'));
hasGroupSegment = any(strcmp(rawTable.Properties.VariableNames, 'cut_group_segment'));
if hasGroupSegment && ~hasGroupId
    error('Legacy file has cut_group_segment but is missing cut_group_id.');
end

groupId = nan(rowCount, 1);
groupSegment = nan(rowCount, 1);
if ~hasGroupId
    cutIndices = find(cutMask);
    groupId(cutIndices) = (1:numel(cutIndices)).';
    groupSegment(cutIndices) = 1;
    return;
end

groupId = localOptionalNumericColumn(rawTable, 'cut_group_id', rowCount);
localRequirePositiveIntegers(groupId(cutMask), 'cut_group_id');
groupId(cutMask) = round(groupId(cutMask));
if hasGroupSegment
    groupSegment = localOptionalNumericColumn( ...
        rawTable, 'cut_group_segment', rowCount);
    localRequirePositiveIntegers(groupSegment(cutMask), 'cut_group_segment');
    groupSegment(cutMask) = round(groupSegment(cutMask));
else
    for rowIndex = 1:rowCount
        if cutMask(rowIndex)
            groupSegment(rowIndex) = nnz( ...
                cutMask(1:rowIndex) & groupId(1:rowIndex) == groupId(rowIndex));
        end
    end
end
end

function localRequirePositiveIntegers(values, label)
if any(~isfinite(values) | values < 1 | abs(values - round(values)) > 1e-9)
    error('Legacy %s values must be positive integers.', label);
end
end
