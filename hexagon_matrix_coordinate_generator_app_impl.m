function fig = hexagon_matrix_coordinate_generator_app_impl()
%HEXAGON_MATRIX_COORDINATE_GENERATOR_APP_IMPL App version of the hexagon generator.

appFolder = fileparts(mfilename('fullpath'));
if exist('generate_hexagon_point_cloud', 'file') ~= 2
    addpath(appFolder);
end

state = struct();
state.generatedData = [];
state.generatedPrefix = '';
state.generatedSummary = struct([]);
state.lastSaveFolder = appFolder;
state.maxTablePreviewRows = 5000;
state.tablePreviewRowLimit = 200;

fig = uifigure( ...
    'Name', 'Hexagon Point Cloud Generator', ...
    'Position', [100, 40, 1220, 980], ...
    'Color', [0.97, 0.97, 0.98]);

mainGrid = uigridlayout(fig, [1, 2]);
mainGrid.ColumnWidth = {340, '1x'};
mainGrid.RowHeight = {'1x'};
mainGrid.Padding = [14, 14, 14, 14];
mainGrid.ColumnSpacing = 14;

controlPanel = uipanel(mainGrid, 'Title', 'Parameters');
controlPanel.Layout.Row = 1;
controlPanel.Layout.Column = 1;

controlRow = 0;
controlGrid = uigridlayout(controlPanel, [34, 2]);
controlGrid.RowHeight = repmat({'fit'}, 1, 34);
controlGrid.ColumnWidth = {'1x', '1x'};
controlGrid.RowSpacing = 8;
controlGrid.ColumnSpacing = 10;
controlGrid.Padding = [10, 10, 10, 10];

ui = struct();

headerLabel(controlGrid, 'Grid');
ui.PointsXField = addNumericField(controlGrid, 'Points X', 66);
ui.PointsYField = addNumericField(controlGrid, 'Points Y', round(66 * 1.155));
ui.PointsZField = addNumericField(controlGrid, 'Points Z', 1);

headerLabel(controlGrid, 'Pitch (um)');
ui.PitchXYField = addNumericField(controlGrid, 'Pitch XY', 3);
ui.PitchZField = addNumericField(controlGrid, 'Pitch Z', 75);

headerLabel(controlGrid, 'Origin (um)');
ui.OriginXField = addNumericField(controlGrid, 'Origin X', 0);
ui.OriginYField = addNumericField(controlGrid, 'Origin Y', 0);
ui.OriginZField = addNumericField(controlGrid, 'Origin Z', 0);

headerLabel(controlGrid, 'Layer Shift');
ui.UseHcpCheckBox = uicheckbox(controlGrid, ...
    'Text', 'Use HCP AB shift on even layers', ...
    'Value', false, ...
    'ValueChangedFcn', @onHcpToggled);
ui.UseHcpCheckBox.Layout.Row = nextRow(controlGrid);
ui.UseHcpCheckBox.Layout.Column = [1, 2];

ui.AbDxField = addNumericField(controlGrid, 'AB dx', 1.5);
ui.AbDyField = addNumericField(controlGrid, 'AB dy', (sqrt(3) / 6) * 3);

headerLabel(controlGrid, 'Power');
ui.PowerModeDropDownLabel = uilabel(controlGrid, 'Text', 'Power Mode');
ui.PowerModeDropDownLabel.Layout.Row = nextRow(controlGrid);
ui.PowerModeDropDownLabel.Layout.Column = 1;

ui.PowerModeDropDown = uidropdown(controlGrid, ...
    'Items', {'Fixed value', 'Custom formula', 'Linear points'}, ...
    'Value', 'Fixed value', ...
    'ValueChangedFcn', @onPowerModeChanged);
ui.PowerModeDropDown.Layout.Row = ui.PowerModeDropDownLabel.Layout.Row;
ui.PowerModeDropDown.Layout.Column = 2;

ui.FixedPowerField = addNumericField(controlGrid, 'Fixed P (%)', 10);

powerConfigRow = nextRow(controlGrid);
controlGrid.RowHeight{powerConfigRow} = 170;
ui.PowerConfigPanel = uipanel(controlGrid, 'Title', 'Power Model Settings');
ui.PowerConfigPanel.Layout.Row = powerConfigRow;
ui.PowerConfigPanel.Layout.Column = [1, 2];

powerGrid = uigridlayout(ui.PowerConfigPanel, [4, 2]);
powerGrid.ColumnWidth = {90, '1x'};
powerGrid.RowHeight = {'fit', 'fit', 78, 'fit'};
powerGrid.RowSpacing = 6;
powerGrid.ColumnSpacing = 8;
powerGrid.Padding = [8, 8, 8, 8];

ui.PowerHintLabel = uilabel(powerGrid, ...
    'Text', 'All points will use the same P value.', ...
    'WordWrap', 'on');
ui.PowerHintLabel.Layout.Row = 1;
ui.PowerHintLabel.Layout.Column = [1, 2];

ui.PowerFormulaLabel = uilabel(powerGrid, 'Text', 'Formula');
ui.PowerFormulaLabel.Layout.Row = 2;
ui.PowerFormulaLabel.Layout.Column = 1;

ui.PowerFormulaField = uieditfield(powerGrid, 'text', ...
    'Value', '1+0.005*z');
ui.PowerFormulaField.Layout.Row = 2;
ui.PowerFormulaField.Layout.Column = 2;

ui.PowerPointsLabel = uilabel(powerGrid, 'Text', 'Z/P');
ui.PowerPointsLabel.Layout.Row = 3;
ui.PowerPointsLabel.Layout.Column = 1;

ui.PowerPointsArea = uitextarea(powerGrid, ...
    'Value', { ...
        '0, 33'; ...
        '100, 28'; ...
        '200, 28'; ...
        '300, 12'; ...
        '400, 10'; ...
        '500, 12'; ...
        '600, 30'; ...
        '700, 35'; ...
        '800, 35'; ...
        '900, 15'});
ui.PowerPointsArea.Layout.Row = 3;
ui.PowerPointsArea.Layout.Column = 2;

ui.PowerConfigNoteLabel = uilabel(powerGrid, ...
    'Text', 'Formula variables: x, y, z in um. Linear points format: one "z_um, power" pair per line.', ...
    'WordWrap', 'on');
ui.PowerConfigNoteLabel.Layout.Row = 4;
ui.PowerConfigNoteLabel.Layout.Column = [1, 2];

headerLabel(controlGrid, 'Output');
ui.ImportHintLabel = uilabel(controlGrid, ...
    'Text', 'Single file columns for Imported Points: X=1, Y=2, Z=3, P=4', ...
    'WordWrap', 'on');
ui.ImportHintLabel.Layout.Row = nextRow(controlGrid);
ui.ImportHintLabel.Layout.Column = [1, 2];

ui.FileHintLabel = uilabel(controlGrid, ...
    'Text', 'Suggested CSV filename will appear after Generate Preview.', ...
    'WordWrap', 'on', ...
    'FontColor', [0.35, 0.35, 0.35]);
ui.FileHintLabel.Layout.Row = nextRow(controlGrid);
ui.FileHintLabel.Layout.Column = [1, 2];

ui.PreviewRowsField = addNumericField(controlGrid, 'Preview rows', state.tablePreviewRowLimit);
ui.PreviewRowsField.ValueChangedFcn = @onPreviewRowsChanged;

ui.GenerateButton = uibutton(controlGrid, ...
    'push', ...
    'Text', 'Generate Preview', ...
    'ButtonPushedFcn', @onGenerate);
ui.GenerateButton.Layout.Row = nextRow(controlGrid);
ui.GenerateButton.Layout.Column = 1;

ui.SaveButton = uibutton(controlGrid, ...
    'push', ...
    'Text', 'Save Combined File', ...
    'ButtonPushedFcn', @onSave);
ui.SaveButton.Layout.Row = ui.GenerateButton.Layout.Row;
ui.SaveButton.Layout.Column = 2;

ui.StatusLabel = uilabel(controlGrid, ...
    'Text', 'Ready.', ...
    'WordWrap', 'on', ...
    'FontWeight', 'bold');
ui.StatusLabel.Layout.Row = nextRow(controlGrid);
ui.StatusLabel.Layout.Column = [1, 2];

previewPanel = uipanel(mainGrid, 'Title', 'Preview');
previewPanel.Layout.Row = 1;
previewPanel.Layout.Column = 2;

previewGrid = uigridlayout(previewPanel, [3, 1]);
previewGrid.RowHeight = {'2.3x', 'fit', '1x'};
previewGrid.RowSpacing = 10;
previewGrid.Padding = [10, 10, 10, 10];

ui.PreviewAxes = uiaxes(previewGrid);
ui.PreviewAxes.Layout.Row = 1;
ui.PreviewAxes.Layout.Column = 1;
ui.PreviewAxes.Box = 'on';
ui.PreviewAxes.XLabel.String = 'X (mm)';
ui.PreviewAxes.YLabel.String = 'Y (mm)';
ui.PreviewAxes.ZLabel.String = 'Z (mm)';
title(ui.PreviewAxes, 'Hexagon Point Cloud');
grid(ui.PreviewAxes, 'on');
view(ui.PreviewAxes, 30, 25);

ui.SummaryLabel = uilabel(previewGrid, ...
    'Text', 'No preview generated yet.', ...
    'WordWrap', 'on');
ui.SummaryLabel.Layout.Row = 2;
ui.SummaryLabel.Layout.Column = 1;

ui.DataTable = uitable(previewGrid, ...
    'ColumnName', {'X_mm', 'Y_mm', 'Z_mm', 'P'}, ...
    'ColumnEditable', [false, false, false, false], ...
    'ColumnWidth', {110, 110, 110, 90}, ...
    'RowName', []);
ui.DataTable.Layout.Row = 3;
ui.DataTable.Layout.Column = 1;

onHcpToggled();
onPowerModeChanged();
onGenerate();

    function field = addNumericField(parentGrid, labelText, defaultValue)
        row = nextRow(parentGrid);
        label = uilabel(parentGrid, 'Text', labelText);
        label.Layout.Row = row;
        label.Layout.Column = 1;

        field = uieditfield(parentGrid, 'numeric', 'Value', defaultValue);
        field.Layout.Row = row;
        field.Layout.Column = 2;
    end

    function headerLabel(parentGrid, textValue)
        row = nextRow(parentGrid);
        label = uilabel(parentGrid, ...
            'Text', textValue, ...
            'FontWeight', 'bold', ...
            'FontSize', 14);
        label.Layout.Row = row;
        label.Layout.Column = [1, 2];
    end

    function row = nextRow(~)
        controlRow = controlRow + 1;
        row = controlRow;
    end

    function onHcpToggled(~, ~)
        if ui.UseHcpCheckBox.Value
            enabled = 'on';
        else
            enabled = 'off';
        end

        ui.AbDxField.Enable = enabled;
        ui.AbDyField.Enable = enabled;
    end

    function onPowerModeChanged(~, ~)
        mode = string(ui.PowerModeDropDown.Value);

        ui.FixedPowerField.Enable = onOff(mode == "Fixed value");
        ui.PowerFormulaField.Enable = onOff(mode == "Custom formula");
        ui.PowerPointsArea.Enable = onOff(mode == "Linear points");

        switch mode
            case "Fixed value"
                ui.PowerHintLabel.Text = 'All points will use the same P value.';
            case "Custom formula"
                ui.PowerHintLabel.Text = 'Enter a MATLAB expression using x, y, z in um.';
            case "Linear points"
                ui.PowerHintLabel.Text = 'Enter z-power pairs in um/% and the app will linearly interpolate between them.';
            otherwise
                ui.PowerHintLabel.Text = 'Depth model uses depth2powerMgF2(1070 - (z_mm + 0.1) * 1000).';
        end
    end

    function onPreviewRowsChanged(~, ~)
        state.tablePreviewRowLimit = validatePreviewRowLimit(ui.PreviewRowsField.Value);
        ui.PreviewRowsField.Value = state.tablePreviewRowLimit;

        if ~isempty(state.generatedData) && ~isempty(state.generatedSummary)
            updatePreview(state.generatedData, state.generatedPrefix, state.generatedSummary);
        end
    end

    function onGenerate(~, ~)
        try
            params = collectParams();
            [data, prefix, summary] = generate_hexagon_point_cloud(params);
            state.generatedData = data;
            state.generatedPrefix = prefix;
            state.generatedSummary = summary;
            updatePreview(data, prefix, summary);
            ui.StatusLabel.Text = sprintf('Generated %d points.', summary.pointCount);
        catch err
            uialert(fig, err.message, 'Generate Failed');
            ui.StatusLabel.Text = 'Generate failed.';
        end
    end

    function onSave(~, ~)
        try
            if isempty(state.generatedData)
                onGenerate();
                if isempty(state.generatedData)
                    return;
                end
            end

            defaultName = [state.generatedPrefix, '.csv'];
            [fileName, folderName, filterIndex] = uiputfile( ...
                {'*.csv', 'Comma-separated values (*.csv)'; '*.txt', 'Tab-delimited text (*.txt)'}, ...
                'Save Combined Point Cloud', ...
                fullfile(state.lastSaveFolder, defaultName));

            if isequal(fileName, 0) || isequal(folderName, 0)
                return;
            end

            fullPath = fullfile(folderName, fileName);
            delimiter = localDelimiter(filterIndex, fileName);
            writematrix(state.generatedData, fullPath, 'Delimiter', delimiter);

            state.lastSaveFolder = folderName;
            ui.StatusLabel.Text = ['Saved: ', fullPath];
        catch err
            uialert(fig, err.message, 'Save Failed');
            ui.StatusLabel.Text = 'Save failed.';
        end
    end

    function params = collectParams()
        params = struct();
        params.pointsX = ui.PointsXField.Value;
        params.pointsY = ui.PointsYField.Value;
        params.pointsZ = ui.PointsZField.Value;
        params.pitchXYUm = ui.PitchXYField.Value;
        params.pitchZUm = ui.PitchZField.Value;
        params.originXUm = ui.OriginXField.Value;
        params.originYUm = ui.OriginYField.Value;
        params.originZUm = ui.OriginZField.Value;
        params.useHcpABShift = logical(ui.UseHcpCheckBox.Value);
        params.abDxUm = ui.AbDxField.Value;
        params.abDyUm = ui.AbDyField.Value;
        params.powerMode = lower(strrep(string(ui.PowerModeDropDown.Value), ' ', '_'));
        params.fixedPower = ui.FixedPowerField.Value;
        params.customFormula = string(ui.PowerFormulaField.Value);
        params.linearPointsText = strjoin(string(ui.PowerPointsArea.Value), newline);
        state.tablePreviewRowLimit = validatePreviewRowLimit(ui.PreviewRowsField.Value);
        ui.PreviewRowsField.Value = state.tablePreviewRowLimit;
    end

    function updatePreview(data, prefix, summary)
        cla(ui.PreviewAxes);
        hold(ui.PreviewAxes, 'on');
        if size(data, 1) > 1
            plot3(ui.PreviewAxes, ...
                data(:, 1), data(:, 2), data(:, 3), ...
                '-', ...
                'Color', [0.72, 0.72, 0.72], ...
                'LineWidth', 0.35);
        end

        scatter3(ui.PreviewAxes, data(:, 1), data(:, 2), data(:, 3), 12, data(:, 4), 'filled');
        hold(ui.PreviewAxes, 'off');
        axis(ui.PreviewAxes, 'equal');
        grid(ui.PreviewAxes, 'on');
        colormap(ui.PreviewAxes, turbo);
        colorbar(ui.PreviewAxes);
        title(ui.PreviewAxes, 'Hexagon Point Cloud');
        view(ui.PreviewAxes, 30, 25);

        previewRows = min(state.tablePreviewRowLimit, size(data, 1));
        ui.DataTable.Data = data(1:previewRows, :);

        ui.FileHintLabel.Text = ['Suggested filename: ', prefix, '.csv'];
        ui.SummaryLabel.Text = sprintf([ ...
            'Points: %d | Row spacing: %.4f um | Power mode: %s\n', ...
            'X range: %.4f to %.4f mm | Y range: %.4f to %.4f mm\n', ...
            'Z range: %.4f to %.4f mm | Power range: %.2f to %.2f %%\n', ...
            'Preview line shows write order. Table shows the first %d rows only to keep the app responsive.'], ...
            summary.pointCount, summary.rowSpacingUm, summary.powerModeLabel, ...
            summary.xRangeMm(1), summary.xRangeMm(2), ...
            summary.yRangeMm(1), summary.yRangeMm(2), ...
            summary.zRangeMm(1), summary.zRangeMm(2), ...
            summary.powerRange(1), summary.powerRange(2), ...
            previewRows);
    end
end

function stateValue = onOff(tf)
if tf
    stateValue = 'on';
else
    stateValue = 'off';
end
end

function previewRows = validatePreviewRowLimit(value)
if ~(isscalar(value) && isnumeric(value) && isfinite(value))
    previewRows = 200;
    return;
end

previewRows = max(1, round(value));
previewRows = min(previewRows, 5000);
end

function delimiter = localDelimiter(filterIndex, fileName)
[~, ~, extension] = fileparts(fileName);
if strcmpi(extension, '.csv') || filterIndex == 2
    delimiter = ',';
else
    delimiter = 'tab';
end
end
