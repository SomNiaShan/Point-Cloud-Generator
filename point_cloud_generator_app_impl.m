function fig = point_cloud_generator_app_impl()
%POINT_CLOUD_GENERATOR_APP_IMPL App version of the point cloud generator.

appFolder = fileparts(mfilename('fullpath'));
if exist('generate_point_cloud', 'file') ~= 2
    addpath(appFolder);
end

state = struct();
state.generatedData = [];
state.generatedPrefix = '';
state.generatedSummary = struct([]);
state.lastSaveFolder = appFolder;
state.maxTablePreviewRows = 5000;
state.tablePreviewRowLimit = 200;
state.maxPlotPreviewPoints = 50000;

fig = uifigure( ...
    'Name', 'Point Cloud Generator', ...
    'Position', [60, 20, 1520, 1080], ...
    'Color', [0.97, 0.97, 0.98]);

mainGrid = uigridlayout(fig, [1, 2]);
mainGrid.ColumnWidth = {480, '1x'};
mainGrid.RowHeight = {'1x'};
mainGrid.Padding = [14, 14, 14, 14];
mainGrid.ColumnSpacing = 14;

controlPanel = uipanel(mainGrid, 'Title', 'Generator Settings');
controlPanel.Layout.Row = 1;
controlPanel.Layout.Column = 1;
controlPanel.Scrollable = 'on';

controlGrid = uigridlayout(controlPanel, [4, 1]);
controlGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
controlGrid.RowSpacing = 10;
controlGrid.Padding = [10, 10, 10, 10];
controlGrid.Scrollable = 'on';

ui = struct();

ui.LatticePanel = uipanel(controlGrid, 'Title', 'Lattice');
ui.LatticePanel.Layout.Row = 1;
ui.LatticePanel.Layout.Column = 1;

latticeGrid = uigridlayout(ui.LatticePanel, [12, 1]);
latticeGrid.RowHeight = {'fit', 84, 84, 76, 84, 76, 84, 84, 76, 76, 76, 76};
latticeGrid.RowSpacing = 10;
latticeGrid.Padding = [10, 10, 10, 10];

[ui.LatticeTypeRow, ui.LatticeTypeDropDown] = createDropdownRow( ...
    latticeGrid, 'Lattice Type', {'Cartesian', 'Hex', 'HCP', 'Staircase'}, 'Cartesian', @onLatticeTypeChanged);
ui.LatticeTypeRow.Layout.Row = 1;

[ui.CountsPanel, countFields] = createValuePanel( ...
    latticeGrid, 'Counts', {'Points X', 'Points Y', 'Points Z'}, [20, 20, 5]);
ui.CountsPanel.Layout.Row = 2;
ui.PointsXField = countFields(1);
ui.PointsYField = countFields(2);
ui.PointsZField = countFields(3);

[ui.CartesianPitchPanel, cartesianPitchFields] = createValuePanel( ...
    latticeGrid, 'Pitch (um)', {'Pitch X', 'Pitch Y', 'Pitch Z'}, [2, 2, 10]);
ui.CartesianPitchPanel.Layout.Row = 3;
ui.PitchXField = cartesianPitchFields(1);
ui.PitchYField = cartesianPitchFields(2);
ui.PitchZCartesianField = cartesianPitchFields(3);

[ui.HexPitchPanel, hexPitchFields] = createValuePanel( ...
    latticeGrid, 'Pitch (um)', {'Pitch XY', 'Pitch Z'}, [3, 75]);
ui.HexPitchPanel.Layout.Row = 4;
ui.PitchXYField = hexPitchFields(1);
ui.PitchZHexField = hexPitchFields(2);

[ui.OriginPanel, originFields] = createValuePanel( ...
    latticeGrid, 'Origin (um)', {'Origin X', 'Origin Y', 'Origin Z'}, [0, 0, 0]);
ui.OriginPanel.Layout.Row = 5;
ui.OriginXField = originFields(1);
ui.OriginYField = originFields(2);
ui.OriginZField = originFields(3);

[ui.HcpShiftPanel, hcpShiftFields] = createValuePanel( ...
    latticeGrid, 'AB Shift (um)', {'AB dx', 'AB dy'}, [1.5, (sqrt(3) / 6) * 3]);
ui.HcpShiftPanel.Layout.Row = 6;
ui.AbDxField = hcpShiftFields(1);
ui.AbDyField = hcpShiftFields(2);

[ui.StepConfigPanel, stepConfigFields] = createValuePanel( ...
    latticeGrid, 'Steps', {'nDepths', 'Z Start (um)', 'Z Step (um)'}, [5, 0, 50]);
ui.StepConfigPanel.Layout.Row = 7;
ui.NDepthsField = stepConfigFields(1);
ui.ZStartField = stepConfigFields(2);
ui.ZStepField = stepConfigFields(3);
ui.ZStepField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.PowerColumnsPanel, powerColumnFields] = createValuePanel( ...
    latticeGrid, 'Power Columns', {'nPowers', 'P Start (%)', 'P End (%)'}, [6, 5, 30]);
ui.PowerColumnsPanel.Layout.Row = 8;
ui.NPowersField = powerColumnFields(1);
ui.StaircasePowerStartField = powerColumnFields(2);
ui.StaircasePowerEndField = powerColumnFields(3);

[ui.PatchCountsPanel, patchCountFields] = createValuePanel( ...
    latticeGrid, 'Patch Counts', {'Patch Nx', 'Patch Ny'}, [5, 5]);
ui.PatchCountsPanel.Layout.Row = 9;
ui.PatchNxField = patchCountFields(1);
ui.PatchNyField = patchCountFields(2);

[ui.PatchPitchPanel, patchPitchFields] = createValuePanel( ...
    latticeGrid, 'Patch Pitch (um)', {'Pitch X', 'Pitch Y'}, [10, 10]);
ui.PatchPitchPanel.Layout.Row = 10;
ui.PatchPitchXField = patchPitchFields(1);
ui.PatchPitchYField = patchPitchFields(2);

[ui.GapPanel, gapFields] = createValuePanel( ...
    latticeGrid, 'Gap (um)', {'Gap X', 'Gap Y'}, [20, 20]);
ui.GapPanel.Layout.Row = 11;
ui.GapXField = gapFields(1);
ui.GapYField = gapFields(2);

[ui.StaircaseOriginPanel, stairOriginFields] = createValuePanel( ...
    latticeGrid, 'Origin (um)', {'Origin X', 'Origin Y'}, [0, 0]);
ui.StaircaseOriginPanel.Layout.Row = 12;
ui.StaircaseOriginXField = stairOriginFields(1);
ui.StaircaseOriginYField = stairOriginFields(2);

ui.PowerPanel = uipanel(controlGrid, 'Title', 'Power');
ui.PowerPanel.Layout.Row = 2;
ui.PowerPanel.Layout.Column = 1;

powerGrid = uigridlayout(ui.PowerPanel, [5, 1]);
powerGrid.RowHeight = {'fit', 'fit', 'fit', 100, 'fit'};
powerGrid.RowSpacing = 8;
powerGrid.Padding = [8, 8, 8, 8];

[ui.PowerModeRow, ui.PowerModeDropDown] = createDropdownRow( ...
    powerGrid, 'Power Mode', {'Fixed value', 'Custom formula', 'Linear points'}, 'Linear points', @onPowerModeChanged);
ui.PowerModeRow.Layout.Row = 1;

[ui.FixedPowerRow, ui.FixedPowerField] = createNumericRow(powerGrid, 'Fixed P (%)', 10);
ui.FixedPowerRow.Layout.Row = 2;

[ui.PowerFormulaRow, ui.PowerFormulaField] = createTextRow(powerGrid, 'Formula', '1+0.005*z');
ui.PowerFormulaRow.Layout.Row = 3;

ui.PowerPointsPanel = uipanel(powerGrid, 'Title', 'Linear Points (z_um, power)');
ui.PowerPointsPanel.Layout.Row = 4;
ui.PowerPointsPanel.Layout.Column = 1;

powerPointsGrid = uigridlayout(ui.PowerPointsPanel, [1, 1]);
powerPointsGrid.Padding = [8, 8, 8, 8];

ui.PowerPointsArea = uitextarea(powerPointsGrid, ...
    'Value', {'0, 10'; '30, 20'});
ui.PowerPointsArea.Layout.Row = 1;
ui.PowerPointsArea.Layout.Column = 1;

ui.PowerHintLabel = uilabel(powerGrid, ...
    'Text', 'All points will use the same P value.', ...
    'WordWrap', 'on');
ui.PowerHintLabel.Layout.Row = 5;
ui.PowerHintLabel.Layout.Column = 1;

ui.OrderingPanel = uipanel(controlGrid, 'Title', 'Ordering');
ui.OrderingPanel.Layout.Row = 3;
ui.OrderingPanel.Layout.Column = 1;

orderingGrid = uigridlayout(ui.OrderingPanel, [2, 1]);
orderingGrid.RowHeight = {'fit', 'fit'};
orderingGrid.RowSpacing = 8;
orderingGrid.Padding = [8, 8, 8, 8];

ui.TraversalNoteLabel = uilabel(orderingGrid, ...
    'Text', 'Traversal: layer-by-layer (Z ascending).', ...
    'WordWrap', 'on');
ui.TraversalNoteLabel.Layout.Row = 1;
ui.TraversalNoteLabel.Layout.Column = 1;

[ui.PathModeRow, ui.PathModeDropDown] = createDropdownRow( ...
    orderingGrid, 'In-layer Path', {'Row-major', 'Serpentine'}, 'Row-major', []);
ui.PathModeRow.Layout.Row = 2;

ui.OutputPanel = uipanel(controlGrid, 'Title', 'Output');
ui.OutputPanel.Layout.Row = 4;
ui.OutputPanel.Layout.Column = 1;

outputGrid = uigridlayout(ui.OutputPanel, [5, 1]);
outputGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
outputGrid.RowSpacing = 8;
outputGrid.Padding = [8, 8, 8, 8];

ui.ImportHintLabel = uilabel(outputGrid, ...
    'Text', 'Single file columns for Imported Points: X=1, Y=2, Z=3, P=4', ...
    'WordWrap', 'on');
ui.ImportHintLabel.Layout.Row = 1;
ui.ImportHintLabel.Layout.Column = 1;

[ui.PreviewRowsRow, ui.PreviewRowsField] = createNumericRow(outputGrid, 'Preview rows', state.tablePreviewRowLimit);
ui.PreviewRowsRow.Layout.Row = 2;
ui.PreviewRowsField.ValueChangedFcn = @onPreviewRowsChanged;

buttonRow = uipanel(outputGrid, 'BorderType', 'none');
buttonRow.Layout.Row = 3;
buttonRow.Layout.Column = 1;

buttonGrid = uigridlayout(buttonRow, [1, 2]);
buttonGrid.ColumnWidth = {'1x', '1x'};
buttonGrid.RowHeight = {'fit'};
buttonGrid.ColumnSpacing = 8;
buttonGrid.Padding = [0, 0, 0, 0];

ui.GenerateButton = uibutton(buttonGrid, ...
    'push', ...
    'Text', 'Generate Preview', ...
    'ButtonPushedFcn', @onGenerate);
ui.GenerateButton.Layout.Row = 1;
ui.GenerateButton.Layout.Column = 1;

ui.SaveButton = uibutton(buttonGrid, ...
    'push', ...
    'Text', 'Save Combined File', ...
    'ButtonPushedFcn', @onSave);
ui.SaveButton.Layout.Row = 1;
ui.SaveButton.Layout.Column = 2;

ui.FileHintLabel = uilabel(outputGrid, ...
    'Text', 'Suggested CSV filename will appear after Generate Preview.', ...
    'WordWrap', 'on', ...
    'FontColor', [0.35, 0.35, 0.35]);
ui.FileHintLabel.Layout.Row = 4;
ui.FileHintLabel.Layout.Column = 1;

ui.StatusLabel = uilabel(outputGrid, ...
    'Text', 'Ready.', ...
    'WordWrap', 'on', ...
    'FontWeight', 'bold');
ui.StatusLabel.Layout.Row = 5;
ui.StatusLabel.Layout.Column = 1;

previewPanel = uipanel(mainGrid, 'Title', 'Output / Preview');
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
title(ui.PreviewAxes, 'Point Cloud Preview');
grid(ui.PreviewAxes, 'on');
view(ui.PreviewAxes, 30, 25);
ui.PowerColorbar = colorbar(ui.PreviewAxes);
ui.PowerColorbar.Label.String = 'Power (%)';

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

onLatticeTypeChanged();
onPowerModeChanged();
onGenerate();

    function onLatticeTypeChanged(~, ~)
        latticeType = string(ui.LatticeTypeDropDown.Value);
        isStaircase = latticeType == "Staircase";
        showCartesian = latticeType == "Cartesian";
        showHexPitch = latticeType == "Hex" || latticeType == "HCP";
        showHcpShift = latticeType == "HCP";

        setPanelRow(latticeGrid, 2, ui.CountsPanel, 84, ~isStaircase);
        setPanelRow(latticeGrid, 3, ui.CartesianPitchPanel, 84, showCartesian);
        setPanelRow(latticeGrid, 4, ui.HexPitchPanel, 76, showHexPitch);
        setPanelRow(latticeGrid, 5, ui.OriginPanel, 84, ~isStaircase);
        setPanelRow(latticeGrid, 6, ui.HcpShiftPanel, 76, showHcpShift);
        setPanelRow(latticeGrid, 7, ui.StepConfigPanel, 84, isStaircase);
        setPanelRow(latticeGrid, 8, ui.PowerColumnsPanel, 84, isStaircase);
        setPanelRow(latticeGrid, 9, ui.PatchCountsPanel, 76, isStaircase);
        setPanelRow(latticeGrid, 10, ui.PatchPitchPanel, 76, isStaircase);
        setPanelRow(latticeGrid, 11, ui.GapPanel, 76, isStaircase);
        setPanelRow(latticeGrid, 12, ui.StaircaseOriginPanel, 76, isStaircase);

        setPanelRow(controlGrid, 2, ui.PowerPanel, 'fit', ~isStaircase);
        setPanelRow(orderingGrid, 2, ui.PathModeRow, 'fit', ~isStaircase);
        updateTraversalNote();
    end

    function onPowerModeChanged(~, ~)
        powerMode = string(ui.PowerModeDropDown.Value);

        setPanelRow(powerGrid, 2, ui.FixedPowerRow, 'fit', powerMode == "Fixed value");
        setPanelRow(powerGrid, 3, ui.PowerFormulaRow, 'fit', powerMode == "Custom formula");
        setPanelRow(powerGrid, 4, ui.PowerPointsPanel, 100, powerMode == "Linear points");

        switch powerMode
            case "Fixed value"
                ui.PowerHintLabel.Text = 'All points will use the same P value.';
            case "Custom formula"
                ui.PowerHintLabel.Text = 'Enter a MATLAB expression using x, y, z in um.';
            case "Linear points"
                ui.PowerHintLabel.Text = 'Enter one "z_um, power" pair per line. The app will linearly interpolate between them.';
        end
    end

    function onPreviewRowsChanged(~, ~)
        state.tablePreviewRowLimit = validatePreviewRowLimit(ui.PreviewRowsField.Value);
        ui.PreviewRowsField.Value = state.tablePreviewRowLimit;

        if ~isempty(state.generatedData) && ~isempty(state.generatedSummary)
            updatePreview(state.generatedData, state.generatedPrefix, state.generatedSummary);
        end
    end

    function onStaircaseParamChanged(~, ~)
        updateTraversalNote();
    end

    function onGenerate(~, ~)
        try
            params = collectParams();
            [data, prefix, summary] = generate_point_cloud(params);
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
        state.tablePreviewRowLimit = validatePreviewRowLimit(ui.PreviewRowsField.Value);
        ui.PreviewRowsField.Value = state.tablePreviewRowLimit;

        latticeType = string(ui.LatticeTypeDropDown.Value);
        params = struct();
        params.lattice = struct();
        params.lattice.type = latticeType;

        if latticeType == "Staircase"
            params.lattice.nDepths = round(max(1, ui.NDepthsField.Value));
            params.lattice.zStartUm = ui.ZStartField.Value;
            params.lattice.zStepUm = ui.ZStepField.Value;
            params.lattice.nPowers = round(max(1, ui.NPowersField.Value));
            params.lattice.powerStart = ui.StaircasePowerStartField.Value;
            params.lattice.powerEnd = ui.StaircasePowerEndField.Value;
            params.lattice.patchNx = round(max(1, ui.PatchNxField.Value));
            params.lattice.patchNy = round(max(1, ui.PatchNyField.Value));
            params.lattice.patchPitchXUm = ui.PatchPitchXField.Value;
            params.lattice.patchPitchYUm = ui.PatchPitchYField.Value;
            params.lattice.gapXUm = ui.GapXField.Value;
            params.lattice.gapYUm = ui.GapYField.Value;
            params.lattice.originXUm = ui.StaircaseOriginXField.Value;
            params.lattice.originYUm = ui.StaircaseOriginYField.Value;
        else
            params.lattice.counts = [ui.PointsXField.Value, ui.PointsYField.Value, ui.PointsZField.Value];
            params.lattice.originUm = [ui.OriginXField.Value, ui.OriginYField.Value, ui.OriginZField.Value];
            params.lattice.hcpShift = struct( ...
                'dxUm', ui.AbDxField.Value, ...
                'dyUm', ui.AbDyField.Value);

            if latticeType == "Cartesian"
                params.lattice.pitch = struct( ...
                    'xUm', ui.PitchXField.Value, ...
                    'yUm', ui.PitchYField.Value, ...
                    'zUm', ui.PitchZCartesianField.Value);
            else
                params.lattice.pitch = struct( ...
                    'xyUm', ui.PitchXYField.Value, ...
                    'zUm', ui.PitchZHexField.Value);
            end
        end

        params.region = struct('mode', 'Full Block');

        params.ordering = struct('pathMode', string(ui.PathModeDropDown.Value));

        params.power = struct();
        params.power.mode = string(ui.PowerModeDropDown.Value);
        params.power.fixedValue = ui.FixedPowerField.Value;
        params.power.formula = string(ui.PowerFormulaField.Value);
        params.power.linearPointsText = strjoin(string(ui.PowerPointsArea.Value), newline);
    end

    function updatePreview(data, prefix, summary)
        plotIdx = localPreviewIndices(size(data, 1), state.maxPlotPreviewPoints);
        plotData = data(plotIdx, :);

        cla(ui.PreviewAxes);
        hold(ui.PreviewAxes, 'on');

        if size(plotData, 1) > 1
            plot3(ui.PreviewAxes, ...
                plotData(:, 1), plotData(:, 2), plotData(:, 3), ...
                '-', ...
                'Color', [0.72, 0.72, 0.72], ...
                'LineWidth', 0.35);
        end

        sc = scatter3(ui.PreviewAxes, ...
            plotData(:, 1), plotData(:, 2), plotData(:, 3), ...
            12, plotData(:, 4), 'filled');
        sc.DataTipTemplate.DataTipRows(end).Label = 'Power (%)';

        hold(ui.PreviewAxes, 'off');
        grid(ui.PreviewAxes, 'on');
        colormap(ui.PreviewAxes, turbo);
        title(ui.PreviewAxes, 'Point Cloud Preview');
        applyPreviewLimits3D(ui.PreviewAxes, data(:, 1), data(:, 2), data(:, 3));

        if ~isgraphics(ui.PowerColorbar)
            ui.PowerColorbar = colorbar(ui.PreviewAxes);
        end
        ui.PowerColorbar.Label.String = 'Power (%)';

        previewRows = min(state.tablePreviewRowLimit, size(data, 1));
        ui.DataTable.Data = data(1:previewRows, :);

        if numel(plotIdx) < size(data, 1)
            plotNote = sprintf('3D preview uses %d evenly sampled points to keep the app responsive.', numel(plotIdx));
        else
            plotNote = '3D preview shows all points in write order.';
        end

        ui.FileHintLabel.Text = ['Suggested filename: ', prefix, '.csv'];
        ui.SummaryLabel.Text = sprintf([ ...
            'Points: %d of %d | Lattice: %s\n', ...
            'Traversal: %s | Path: %s | Power: %s\n', ...
            '%s\n', ...
            'X range: %.4f to %.4f mm | Y range: %.4f to %.4f mm\n', ...
            'Z range: %.4f to %.4f mm | Power range: %.2f to %.2f %%\n', ...
            '%s Table shows the first %d rows only.'], ...
            summary.pointCount, summary.sourcePointCount, summary.latticeLabel, ...
            summary.layerTraversalLabel, summary.pathModeLabel, summary.powerModeLabel, ...
            summary.pitchLabel, ...
            summary.xRangeMm(1), summary.xRangeMm(2), ...
            summary.yRangeMm(1), summary.yRangeMm(2), ...
            summary.zRangeMm(1), summary.zRangeMm(2), ...
            summary.powerRange(1), summary.powerRange(2), ...
            plotNote, previewRows);
    end

    function updateTraversalNote()
        if string(ui.LatticeTypeDropDown.Value) ~= "Staircase"
            ui.TraversalNoteLabel.Text = 'Traversal: layer-by-layer (Z ascending).';
            return;
        end

        zStepUm = ui.ZStepField.Value;
        if ~(isscalar(zStepUm) && isnumeric(zStepUm) && isfinite(zStepUm))
            detailText = 'Staircase requires a finite non-zero Z Step.';
        elseif zStepUm > 0
            detailText = 'Deep to shallow (Z ascending).';
        elseif zStepUm < 0
            detailText = 'Shallow to deep (Z descending).';
        else
            detailText = 'Staircase requires a non-zero Z Step.';
        end

        ui.TraversalNoteLabel.Text = ['Traversal: ', detailText, ' Row-major within each patch.'];
    end
end

function [rowPanel, dropdown] = createDropdownRow(parent, labelText, items, defaultValue, callback)
rowPanel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(rowPanel, [1, 2]);
grid.ColumnWidth = {110, '1x'};
grid.RowHeight = {'fit'};
grid.ColumnSpacing = 8;
grid.Padding = [0, 0, 0, 0];

label = uilabel(grid, 'Text', labelText);
label.Layout.Row = 1;
label.Layout.Column = 1;

dropdown = uidropdown(grid, 'Items', items, 'Value', defaultValue);
dropdown.Layout.Row = 1;
dropdown.Layout.Column = 2;

if ~isempty(callback)
    dropdown.ValueChangedFcn = callback;
end
end

function [rowPanel, field] = createNumericRow(parent, labelText, defaultValue)
rowPanel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(rowPanel, [1, 2]);
grid.ColumnWidth = {110, '1x'};
grid.RowHeight = {'fit'};
grid.ColumnSpacing = 8;
grid.Padding = [0, 0, 0, 0];

label = uilabel(grid, 'Text', labelText);
label.Layout.Row = 1;
label.Layout.Column = 1;

field = uieditfield(grid, 'numeric', 'Value', defaultValue);
field.Layout.Row = 1;
field.Layout.Column = 2;
end

function [rowPanel, field] = createTextRow(parent, labelText, defaultValue)
rowPanel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(rowPanel, [1, 2]);
grid.ColumnWidth = {110, '1x'};
grid.RowHeight = {'fit'};
grid.ColumnSpacing = 8;
grid.Padding = [0, 0, 0, 0];

label = uilabel(grid, 'Text', labelText);
label.Layout.Row = 1;
label.Layout.Column = 1;

field = uieditfield(grid, 'text', 'Value', defaultValue);
field.Layout.Row = 1;
field.Layout.Column = 2;
end

function [panel, fields] = createValuePanel(parent, titleText, labelTexts, defaultValues)
panel = uipanel(parent, 'Title', titleText);

labelTexts = cellstr(string(labelTexts));
defaultValues = reshape(defaultValues, 1, []);
count = numel(labelTexts);

grid = uigridlayout(panel, [2, count]);
grid.RowHeight = {'fit', 'fit'};
grid.ColumnWidth = repmat({'1x'}, 1, count);
grid.RowSpacing = 4;
grid.ColumnSpacing = 8;
grid.Padding = [8, 8, 8, 8];

fields = gobjects(1, count);
for i = 1:count
    label = uilabel(grid, 'Text', labelTexts{i}, 'HorizontalAlignment', 'center');
    label.Layout.Row = 1;
    label.Layout.Column = i;

    field = uieditfield(grid, 'numeric', 'Value', defaultValues(i));
    field.Layout.Row = 2;
    field.Layout.Column = i;
    fields(i) = field;
end
end

function setPanelRow(grid, rowIndex, handleValue, rowHeight, isVisible)
if isVisible
    handleValue.Visible = 'on';
    grid.RowHeight{rowIndex} = rowHeight;
else
    handleValue.Visible = 'off';
    grid.RowHeight{rowIndex} = 0;
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
if strcmpi(extension, '.csv') || filterIndex == 1
    delimiter = ',';
else
    delimiter = 'tab';
end
end

function plotIdx = localPreviewIndices(pointCount, pointLimit)
if pointCount <= pointLimit
    plotIdx = (1:pointCount).';
    return;
end

plotIdx = unique(round(linspace(1, pointCount, pointLimit))).';
end

function applyPreviewLimits3D(ax, xValues, yValues, zValues)
mins = [min(xValues), min(yValues), min(zValues)];
maxs = [max(xValues), max(yValues), max(zValues)];
center = (mins + maxs) / 2;
span = max(maxs - mins);

if ~isfinite(span) || span <= 0
    span = 0.001;
end

halfSpan = span * 0.55;
xlim(ax, [center(1) - halfSpan, center(1) + halfSpan]);
ylim(ax, [center(2) - halfSpan, center(2) + halfSpan]);
zlim(ax, [center(3) - halfSpan, center(3) + halfSpan]);
axis(ax, 'equal');
view(ax, 30, 25);
end
