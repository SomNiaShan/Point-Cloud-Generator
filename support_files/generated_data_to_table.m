function generated = generated_data_to_table(data, planConfig)
%GENERATED_DATA_TO_TABLE Give generated columns one unambiguous internal name.

if istable(data)
    generated = data;
    return;
end
if ~(isnumeric(data) && isreal(data) && ismatrix(data) && size(data, 2) >= 4)
    error('Generated data must be a real numeric matrix with X, Y, Z, and power columns.');
end

generated = array2table(double(data(:, 1:4)), ...
    'VariableNames', {'x_mm', 'y_mm', 'z_mm', 'power'});
profile = string(planConfig.profile);

switch profile
    case "point"
        generated = localAddOptionalColumn(generated, data, planConfig, ...
            'dwellColumn', 'dwell_s');
        generated = localAddOptionalColumn(generated, data, planConfig, ...
            'exposureCountColumn', 'exposure_count');
        generated = localAddOptionalColumn(generated, data, planConfig, ...
            'pauseColumn', 'pause_s');
    case "axis_path"
        generated = localAddOptionalColumn(generated, data, planConfig, ...
            'scanSpeedColumn', 'speed_mm_s');
        generated = localAddOptionalColumn(generated, data, planConfig, ...
            'pauseColumn', 'pause_s');
    case "recipe_path"
        generated = localRecipePathTable(data);
    otherwise
        error('Unsupported writing-plan profile: "%s".', profile);
end
end

function output = localAddOptionalColumn(output, data, config, fieldName, variableName)
if ~isfield(config, fieldName) || isempty(config.(fieldName))
    return;
end
columnIndex = config.(fieldName);
if ~(isscalar(columnIndex) && isnumeric(columnIndex) && isfinite(columnIndex) && ...
        columnIndex == round(columnIndex) && columnIndex >= 1 && columnIndex <= size(data, 2))
    error('%s must identify an existing generated-data column.', fieldName);
end
output.(variableName) = double(data(:, columnIndex));
end

function generated = localRecipePathTable(data)
if ~any(size(data, 2) == [14, 15, 16, 18])
    error('Recipe path data must contain 14, 15, 16, or 18 columns.');
end
names = { ...
    'x_mm', 'y_mm', 'z_mm', 'power', ...
    'x2_mm', 'y2_mm', 'z2_mm', ...
    'approach_x_mm', 'approach_y_mm', 'approach_z_mm', ...
    'departure_x_mm', 'departure_y_mm', 'departure_z_mm', ...
    'segment_speed_mm_s'};
if size(data, 2) >= 15
    names{15} = 'transition_speed_mm_s';
end
if size(data, 2) >= 16
    names{16} = 'pause_s';
end
if size(data, 2) == 18
    names{17} = 'source_group_id';
    names{18} = 'source_segment_index';
end
generated = array2table(double(data), 'VariableNames', names);
end
