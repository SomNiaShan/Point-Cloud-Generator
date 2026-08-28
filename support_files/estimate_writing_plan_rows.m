function rowCount = estimate_writing_plan_rows(generated, config)
%ESTIMATE_WRITING_PLAN_ROWS Estimate expansion before constructing plan rows.

profile = string(config.profile);
sourceCount = size(generated, 1);
if sourceCount == 0
    rowCount = 0;
    return;
end
switch profile
    case "point"
        if istable(generated) && ismember('exposure_count', generated.Properties.VariableNames)
            counts = generated.exposure_count;
        elseif isfield(config, 'exposuresPerPoint')
            counts = repmat(config.exposuresPerPoint, sourceCount, 1);
        else
            counts = ones(sourceCount, 1);
        end
        if any(~isfinite(counts) | counts < 1 | counts ~= round(counts))
            error('Generated exposure counts must be positive integers.');
        end
        rowCount = sum(double(counts));
    case "axis_path"
        segmentCount = 1 + double(config.scanLeadInMm > 0) + ...
            double(config.scanLeadOutMm > 0);
        rowCount = sourceCount * segmentCount;
    case "recipe_path"
        rowCount = localRecipePathRows(generated);
    otherwise
        error('Unsupported writing-plan profile: "%s".', profile);
end
if ~isscalar(rowCount) || ~isfinite(rowCount) || rowCount < 0 || rowCount > flintmax
    error('Estimated Writing Plan row count is outside the supported numeric range.');
end
rowCount = round(rowCount);
end

function rowCount = localRecipePathRows(generated)
if ~istable(generated)
    rowCount = size(generated, 1) * 3;
    return;
end
required = {'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'approach_x_mm', 'approach_y_mm', 'approach_z_mm', ...
    'departure_x_mm', 'departure_y_mm', 'departure_z_mm'};
if ~all(ismember(required, generated.Properties.VariableNames))
    error('Named recipe-path data is missing required coordinate columns.');
end
if ismember('source_group_id', generated.Properties.VariableNames)
    groupIds = generated.source_group_id;
else
    groupIds = (1:height(generated)).';
end
groupStarts = [1; find(groupIds(2:end) ~= groupIds(1:end - 1)) + 1];
groupEnds = [groupStarts(2:end) - 1; height(generated)];
rowCount = 0;
for iGroup = 1:numel(groupStarts)
    first = groupStarts(iGroup);
    last = groupEnds(iGroup);
    exposureStart = [generated.x_mm(first), generated.y_mm(first), generated.z_mm(first)];
    exposureEnd = [generated.x2_mm(last), generated.y2_mm(last), generated.z2_mm(last)];
    approachStart = [generated.approach_x_mm(first), generated.approach_y_mm(first), generated.approach_z_mm(first)];
    departureEnd = [generated.departure_x_mm(last), generated.departure_y_mm(last), generated.departure_z_mm(last)];
    rowCount = rowCount + (last - first + 1) + ...
        double(norm(approachStart - exposureStart) > 1e-12) + ...
        double(norm(departureEnd - exposureEnd) > 1e-12);
end
end
