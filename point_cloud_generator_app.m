function fig = point_cloud_generator_app()
%POINT_CLOUD_GENERATOR_APP App version of the point cloud generator.

appFolder = fileparts(mfilename('fullpath'));
supportFolder = fullfile(appFolder, 'support_files');
if exist(supportFolder, 'dir') == 7
    addpath(supportFolder, '-begin');
end

state = struct();
state.generatedData = [];
state.generatedPlanTable = table();
state.generatedPrefix = '';
state.generatedSummary = struct([]);
state.previewFromLoadedPlan = false;
state.lastSaveFolder = appFolder;
state.maxTablePreviewRows = 5000;
state.tablePreviewRowLimit = 200;
state.maxPlotPreviewPoints = 50000;
tips = parameterTooltips();

figurePosition = compactFigurePosition();

fig = uifigure( ...
    'Name', 'Point Cloud Generator', ...
    'Position', figurePosition, ...
    'Color', [0.97, 0.97, 0.98]);

mainGrid = uigridlayout(fig, [1, 2]);
mainGrid.ColumnWidth = {560, '1x'};
mainGrid.RowHeight = {'1x'};
mainGrid.Padding = [10, 10, 10, 10];
mainGrid.ColumnSpacing = 10;

controlPanel = uipanel(mainGrid, 'Title', 'Generator Settings');
controlPanel.Layout.Row = 1;
controlPanel.Layout.Column = 1;
controlPanel.Scrollable = 'on';

controlPanelGrid = uigridlayout(controlPanel, [2, 1]);
controlPanelGrid.RowHeight = {'1x', 'fit'};
controlPanelGrid.ColumnWidth = {'1x'};
controlPanelGrid.Padding = [6, 6, 6, 6];
controlPanelGrid.RowSpacing = 6;

controlTabs = uitabgroup(controlPanelGrid);
controlTabs.Layout.Row = 1;
controlTabs.Layout.Column = 1;
latticeTab = uitab(controlTabs, 'Title', 'Lattice');
latticeTab.Scrollable = 'on';
powerOrderTab = uitab(controlTabs, 'Title', 'Writing Settings');

latticeTabGrid = uigridlayout(latticeTab, [34, 1]);
latticeTabGrid.RowHeight = repmat({'fit'}, 1, 34);
latticeTabGrid.ColumnWidth = {'1x'};
latticeTabGrid.Padding = [6, 6, 6, 6];
latticeTabGrid.RowSpacing = 4;
latticeTabGrid.Scrollable = 'on';

powerOrderGrid = uigridlayout(powerOrderTab, [3, 1]);
powerOrderGrid.RowHeight = {'fit', 'fit', 'fit'};
powerOrderGrid.ColumnWidth = {'1x'};
powerOrderGrid.RowSpacing = 6;
powerOrderGrid.Padding = [6, 6, 6, 6];

ui = struct();

latticeGrid = latticeTabGrid;

latticeTypeItems = {'Cartesian', 'Hex', 'HCP', 'Staircase', 'Segmented Grating', 'Z Push', ...
    'Hexagon Cut', 'Hexagon Release Cut', 'Hexagon Release Cut Array', 'Circle Release Cut'};
[ui.LatticeTypeRow, ui.LatticeTypeDropDown] = createDropdownRow( ...
    latticeGrid, 'Lattice Type', latticeTypeItems, 'Hexagon Release Cut', @onLatticeTypeChanged, ...
    latticeTypeItems, tips.latticeType);
ui.LatticeTypeRow.Layout.Row = 1;

[ui.CountsPanel, countFields] = createValuePanel( ...
    latticeGrid, 'Counts', {'Points X', 'Points Y', 'Points Z'}, [20, 20, 5], tips.counts);
ui.CountsPanel.Layout.Row = 2;
ui.PointsXField = countFields(1);
ui.PointsYField = countFields(2);
ui.PointsZField = countFields(3);

[ui.CartesianPitchPanel, cartesianPitchFields] = createValuePanel( ...
    latticeGrid, 'Pitch (mm)', {'Pitch X', 'Pitch Y', 'Pitch Z'}, [0.002, 0.002, 0.01], tips.cartesianPitch);
ui.CartesianPitchPanel.Layout.Row = 3;
ui.PitchXField = cartesianPitchFields(1);
ui.PitchYField = cartesianPitchFields(2);
ui.PitchZCartesianField = cartesianPitchFields(3);

[ui.HexPitchPanel, hexPitchFields] = createValuePanel( ...
    latticeGrid, 'Pitch (mm)', {'Pitch XY', 'Pitch Z'}, [0.003, 0.075], tips.hexPitch);
ui.HexPitchPanel.Layout.Row = 4;
ui.PitchXYField = hexPitchFields(1);
ui.PitchZHexField = hexPitchFields(2);

[ui.OriginPanel, originFields] = createValuePanel( ...
    latticeGrid, 'Origin (mm)', {'Origin X', 'Origin Y', 'Origin Z'}, [0, 0, -0.0175], tips.origin);
ui.OriginPanel.Layout.Row = 5;
ui.OriginXField = originFields(1);
ui.OriginYField = originFields(2);
ui.OriginZField = originFields(3);

[ui.HcpShiftPanel, hcpShiftFields] = createValuePanel( ...
    latticeGrid, 'AB Shift (mm)', {'AB dx', 'AB dy'}, [0.0015, (sqrt(3) / 6) * 0.003], tips.hcpShift);
ui.HcpShiftPanel.Layout.Row = 6;
ui.AbDxField = hcpShiftFields(1);
ui.AbDyField = hcpShiftFields(2);

[ui.StepConfigPanel, stepConfigFields] = createValuePanel( ...
    latticeGrid, 'Depth Steps', {'Depth Count', 'Z Start (mm)', 'Z Step (mm)'}, [5, 0, 0.05], tips.stepConfig);
ui.StepConfigPanel.Layout.Row = 7;
ui.NDepthsField = stepConfigFields(1);
ui.ZStartField = stepConfigFields(2);
ui.ZStepField = stepConfigFields(3);
ui.ZStepField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.PowerColumnsPanel, powerColumnFields] = createValuePanel( ...
    latticeGrid, 'Power Columns', {'Power Count', 'P Start', 'P End'}, [6, 5, 30], tips.powerColumns);
ui.PowerColumnsPanel.Layout.Row = 8;
ui.NPowersField = powerColumnFields(1);
ui.StaircasePowerStartField = powerColumnFields(2);
ui.StaircasePowerEndField = powerColumnFields(3);

[ui.PatchCountsPanel, patchCountFields] = createValuePanel( ...
    latticeGrid, 'Patch Counts', {'Nx', 'Ny'}, [5, 5], tips.patchCounts);
ui.PatchCountsPanel.Layout.Row = 9;
ui.PatchNxField = patchCountFields(1);
ui.PatchNyField = patchCountFields(2);

[ui.PatchPitchPanel, patchPitchFields] = createValuePanel( ...
    latticeGrid, 'Patch Pitch (mm)', {'Pitch X', 'Pitch Y'}, [0.01, 0.01], tips.patchPitch);
ui.PatchPitchPanel.Layout.Row = 10;
ui.PatchPitchXField = patchPitchFields(1);
ui.PatchPitchYField = patchPitchFields(2);

[ui.GapPanel, gapFields] = createValuePanel( ...
    latticeGrid, 'Gap (mm)', {'Gap X', 'Gap Y'}, [0.02, 0.02], tips.gap);
ui.GapPanel.Layout.Row = 11;
ui.GapXField = gapFields(1);
ui.GapYField = gapFields(2);

[ui.StaircaseOriginPanel, stairOriginFields] = createValuePanel( ...
    latticeGrid, 'Origin (mm)', {'Origin X', 'Origin Y'}, [0, 0], tips.staircaseOrigin);
ui.StaircaseOriginPanel.Layout.Row = 12;
ui.StaircaseOriginXField = stairOriginFields(1);
ui.StaircaseOriginYField = stairOriginFields(2);

[ui.GratingAxesPanel, gratingAxisDropdowns] = createDropdownPanel( ...
    latticeGrid, 'Grating Axes', {'Depth Axis', 'Period Axis'}, {'X', 'Y', 'Z'}, {'Z', 'X'}, ...
    @onGratingAxisChanged, tips.gratingAxes);
ui.GratingAxesPanel.Layout.Row = 13;
ui.GratingDepthAxisDropDown = gratingAxisDropdowns(1);
ui.GratingPeriodAxisDropDown = gratingAxisDropdowns(2);

[ui.GratingDepthPanel, gratingDepthFields] = createValuePanel( ...
    latticeGrid, 'Grating Depth', {'Layer Count', 'Start (mm)', 'Step (mm)'}, [1, 0, 0.01], tips.gratingDepth);
ui.GratingDepthPanel.Layout.Row = 14;
ui.GratingDepthCountField = gratingDepthFields(1);
ui.GratingDepthStartField = gratingDepthFields(2);
ui.GratingDepthStepField = gratingDepthFields(3);
ui.GratingDepthStepField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.GratingSegmentOnePanel, gratingSegmentOneFields] = createValuePanelWithSlots( ...
    latticeGrid, 'Grating Segment 1', {'Period (mm)', 'Period Count'}, [0.01753, 6], 3, tips.gratingSegmentOne);
ui.GratingSegmentOnePanel.Layout.Row = 15;
ui.GratingPeriod1Field = gratingSegmentOneFields(1);
ui.GratingPeriodCount1Field = gratingSegmentOneFields(2);

[ui.GratingSegmentTwoPanel, gratingSegmentTwoFields] = createValuePanelWithSlots( ...
    latticeGrid, 'Grating Segment 2', {'Period (mm)', 'Period Count', 'Segment Gap (mm)'}, [0.00965, 20, 0.004], 3, tips.gratingSegmentTwo);
ui.GratingSegmentTwoPanel.Layout.Row = 16;
ui.GratingPeriod2Field = gratingSegmentTwoFields(1);
ui.GratingPeriodCount2Field = gratingSegmentTwoFields(2);
ui.GratingSegmentGapField = gratingSegmentTwoFields(3);

[ui.GratingSlabOnePanel, gratingSlabOneFields] = createValuePanel( ...
    latticeGrid, 'Slab Segment 1', {'Line Count', 'Line Pitch (mm)'}, [8, 0.001], tips.gratingSlabOne);
ui.GratingSlabOnePanel.Layout.Row = 17;
ui.GratingSlabCopies1Field = gratingSlabOneFields(1);
ui.GratingSlabPitch1Field = gratingSlabOneFields(2);

[ui.GratingSlabTwoPanel, gratingSlabTwoFields] = createValuePanel( ...
    latticeGrid, 'Slab Segment 2', {'Line Count', 'Line Pitch (mm)'}, [4, 0.001], tips.gratingSlabTwo);
ui.GratingSlabTwoPanel.Layout.Row = 18;
ui.GratingSlabCopies2Field = gratingSlabTwoFields(1);
ui.GratingSlabPitch2Field = gratingSlabTwoFields(2);

[ui.GratingChannelPanel, gratingChannelFields] = createValuePanelWithSlots( ...
    latticeGrid, 'Channel Matrix', {'Rows', 'Columns', 'Row Pitch (mm)', 'Column Pitch (mm)'}, [5, 5, 0.0087, 0.02], 4, tips.gratingChannel);
ui.GratingChannelPanel.Layout.Row = 19;
ui.GratingChannelRowsField = gratingChannelFields(1);
ui.GratingChannelColsField = gratingChannelFields(2);
ui.GratingChannelRowPitchField = gratingChannelFields(3);
ui.GratingChannelColPitchField = gratingChannelFields(4);
ui.GratingChannelRowsField.ValueChangedFcn = @onGratingChannelMatrixChanged;
ui.GratingChannelColsField.ValueChangedFcn = @onGratingChannelMatrixChanged;

ui.GratingChannelStartsPanel = uipanel(latticeGrid, 'BorderType', 'none');
ui.GratingChannelStartsPanel.Layout.Row = 20;
gratingStartsGrid = uigridlayout(ui.GratingChannelStartsPanel, [4, 1]);
gratingStartsGrid.RowHeight = {'fit', gratingStartTableHeight(5), 'fit', gratingStartTableHeight(5)};
gratingStartsGrid.ColumnWidth = {'1x'};
gratingStartsGrid.Padding = [0, 0, 0, 0];
gratingStartsGrid.RowSpacing = 4;

ui.GratingSegmentOneStartsLabel = uilabel(gratingStartsGrid, 'Text', 'First Grating Start Positions');
ui.GratingSegmentOneStartsLabel.Layout.Row = 1;
ui.GratingSegmentOneStartsLabel.Layout.Column = 1;
ui.GratingSegmentOneStartsTable = uitable(gratingStartsGrid, ...
    'Data', { ...
    '0.0087655', '0.0087655', '', '0', '0'; ...
    '0.0087655', '0', '', '0.0087655', '0'; ...
    '', '', '', '', ''; ...
    '0', '0.0087655', '', '0', '0.0087655'; ...
    '0', '0', '', '0.0087655', '0.0087655'}, ...
    'ColumnName', {'C1', 'C2', 'C3', 'C4', 'C5'}, ...
    'RowName', {'R1', 'R2', 'R3', 'R4', 'R5'}, ...
    'ColumnEditable', true(1, 5), ...
    'ColumnWidth', repmat({54}, 1, 5));
ui.GratingSegmentOneStartsTable.Layout.Row = 2;
ui.GratingSegmentOneStartsTable.Layout.Column = 1;

ui.GratingSegmentTwoStartsLabel = uilabel(gratingStartsGrid, 'Text', 'Second Grating Start Positions');
ui.GratingSegmentTwoStartsLabel.Layout.Row = 3;
ui.GratingSegmentTwoStartsLabel.Layout.Column = 1;
ui.GratingSegmentTwoStartsTable = uitable(gratingStartsGrid, ...
    'Data', { ...
    '', '0.114825', '0.114825', '0.114825', ''; ...
    '0.11', '0.11', '0.11', '0.11', '0.11'; ...
    '0.11', '0.114825', '', '0.114825', '0.11'; ...
    '0.11', '0.11', '0.11', '0.11', '0.11'; ...
    '', '0.114825', '0.114825', '0.114825', ''}, ...
    'ColumnName', {'C1', 'C2', 'C3', 'C4', 'C5'}, ...
    'RowName', {'R1', 'R2', 'R3', 'R4', 'R5'}, ...
    'ColumnEditable', true(1, 5), ...
    'ColumnWidth', repmat({54}, 1, 5));
ui.GratingSegmentTwoStartsTable.Layout.Row = 4;
ui.GratingSegmentTwoStartsTable.Layout.Column = 1;
applyTooltip({ui.GratingChannelStartsPanel, ui.GratingSegmentOneStartsLabel, ui.GratingSegmentOneStartsTable, ...
    ui.GratingSegmentTwoStartsLabel, ui.GratingSegmentTwoStartsTable}, tips.gratingChannelStarts);

[ui.GratingScanPanel, gratingScanFields] = createValuePanel( ...
    latticeGrid, 'Scan Line', {'Length (mm)'}, 0.02, tips.gratingScan);
ui.GratingScanPanel.Layout.Row = 21;
ui.GratingScanLengthField = gratingScanFields(1);
ui.GratingScanLengthField.ValueChangedFcn = @onPlanParamChanged;

[ui.ZPushOriginPanel, zPushOriginFields] = createValuePanel( ...
    latticeGrid, 'Initial Position (mm)', {'X0', 'Y0', 'Z0'}, [0, 0, 0], tips.zPushOrigin);
ui.ZPushOriginPanel.Layout.Row = 22;
ui.ZPushOriginXField = zPushOriginFields(1);
ui.ZPushOriginYField = zPushOriginFields(2);
ui.ZPushOriginZField = zPushOriginFields(3);
ui.ZPushOriginXField.ValueChangedFcn = @onStaircaseParamChanged;
ui.ZPushOriginYField.ValueChangedFcn = @onStaircaseParamChanged;
ui.ZPushOriginZField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.ZPushMovePanel, zPushMoveFields] = createValuePanel( ...
    latticeGrid, 'XY Move (mm)', {'dX', 'dY'}, [0, 0], tips.zPushMove);
ui.ZPushMovePanel.Layout.Row = 23;
ui.ZPushMoveXField = zPushMoveFields(1);
ui.ZPushMoveYField = zPushMoveFields(2);
ui.ZPushMoveXField.ValueChangedFcn = @onStaircaseParamChanged;
ui.ZPushMoveYField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.ZPushConfigPanel, zPushConfigFields] = createValuePanel( ...
    latticeGrid, 'Z Push', {'Count', 'Step (mm)', 'Interval s'}, [5, 0.01, 1], tips.zPushConfig);
ui.ZPushConfigPanel.Layout.Row = 24;
ui.ZPushCountField = zPushConfigFields(1);
ui.ZPushStepField = zPushConfigFields(2);
ui.ZPushIntervalField = zPushConfigFields(3);
ui.ZPushCountField.ValueChangedFcn = @onStaircaseParamChanged;
ui.ZPushStepField.ValueChangedFcn = @onStaircaseParamChanged;
ui.ZPushIntervalField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.HexCutCenterPanel, hexCutCenterFields] = createValuePanel( ...
    latticeGrid, 'Cut Center (mm)', {'Center X', 'Center Y', 'Center Z'}, [0, 0, 0], tips.hexCutCenter);
ui.HexCutCenterPanel.Layout.Row = 25;
ui.HexCutCenterXField = hexCutCenterFields(1);
ui.HexCutCenterYField = hexCutCenterFields(2);
ui.HexCutCenterZField = hexCutCenterFields(3);

[ui.HexCutGeometryPanel, hexCutGeometryFields] = createValuePanel( ...
    latticeGrid, 'Hexagon Geometry', {'Side (mm)', 'Rotation (deg)'}, [0.5, 0], tips.hexCutGeometry);
ui.HexCutGeometryPanel.Layout.Row = 26;
ui.HexCutSideLengthField = hexCutGeometryFields(1);
ui.HexCutRotationField = hexCutGeometryFields(2);

[ui.CircleCutGeometryPanel, circleCutGeometryFields] = createValuePanel( ...
    latticeGrid, 'Circle Geometry', {'Radius (mm)', 'Start Angle (deg)', 'Segments'}, [0.5, 0, 128], tips.circleCutGeometry);
ui.CircleCutGeometryPanel.Layout.Row = 26;
ui.CircleCutRadiusField = circleCutGeometryFields(1);
ui.CircleCutStartAngleField = circleCutGeometryFields(2);
ui.CircleCutSegmentCountField = circleCutGeometryFields(3);

[ui.HexCutDirectionRow, ui.HexCutDirectionDropDown] = createDropdownRow( ...
    latticeGrid, 'Cut Direction', {'Counter-clockwise', 'Clockwise'}, 'Counter-clockwise', @onStaircaseParamChanged, ...
    {'Counter-clockwise', 'Clockwise'}, tips.hexCutDirection);
ui.HexCutDirectionRow.Layout.Row = 27;

[ui.HexCutMotionPanel, hexCutMotionFields] = createValuePanelWithSlots( ...
    latticeGrid, 'Cut Motion', {'Power (%)', 'Speed (mm/s)', 'Accel (mm/s^2)', 'Lead Safety', 'Exit Safety'}, ...
    [100, 0.01, 1, 1.5, 1], 5, tips.hexCutMotion);
ui.HexCutMotionPanel.Layout.Row = 28;
ui.HexCutPowerField = hexCutMotionFields(1);
ui.HexCutSpeedField = hexCutMotionFields(2);
ui.HexCutAccelerationField = hexCutMotionFields(3);
ui.HexCutLeadSafetyField = hexCutMotionFields(4);
ui.HexCutExitSafetyField = hexCutMotionFields(5);

[ui.HexReleasePatternPanel, hexReleasePatternFields] = createValuePanelWithSlots( ...
    latticeGrid, 'Release Pattern', {'Wall Margin (mm)', 'Rings', 'Ring Pitch (mm)', 'Hatch Pitch (mm)'}, ...
    [0.015, 10, 0.005, 0], 4, tips.hexReleasePattern);
ui.HexReleasePatternPanel.Layout.Row = 29;
ui.HexReleaseWallMarginField = hexReleasePatternFields(1);
ui.HexReleaseRingCountField = hexReleasePatternFields(2);
ui.HexReleaseRingPitchField = hexReleasePatternFields(3);
ui.HexReleaseHatchPitchField = hexReleasePatternFields(4);

[ui.HexReleaseZPanel, hexReleaseZFields] = createValuePanel( ...
    latticeGrid, 'Release Z Stack', {'Layers', 'Z Step (mm)', 'Repeats'}, [1, 0, 1], tips.hexReleaseZ);
ui.HexReleaseZPanel.Layout.Row = 30;
ui.HexReleaseLayerCountField = hexReleaseZFields(1);
ui.HexReleaseZStepField = hexReleaseZFields(2);
ui.HexReleaseRepeatCountField = hexReleaseZFields(3);
ui.HexReleaseRepeatCountField.ValueChangedFcn = @onStaircaseParamChanged;

[ui.HexReleaseMotionPanel, hexReleaseMotionFields] = createValuePanelWithSlots( ...
    latticeGrid, 'Release Motion', {'Ring P (%)', 'Ring Speed', 'Hatch P (%)', 'Hatch Speed'}, ...
    [100, 0.01, 10, 0.01], 4, tips.hexReleaseMotion);
ui.HexReleaseMotionPanel.Layout.Row = 31;
ui.HexReleaseRingPowerField = hexReleaseMotionFields(1);
ui.HexReleaseRingSpeedField = hexReleaseMotionFields(2);
ui.HexReleaseHatchPowerField = hexReleaseMotionFields(3);
ui.HexReleaseHatchSpeedField = hexReleaseMotionFields(4);

[ui.HexReleaseOrderRow, ui.HexReleaseOrderDropDown] = createDropdownRow( ...
    latticeGrid, 'Release Order', {'Inside-out', 'Outside-in'}, 'Inside-out', @onStaircaseParamChanged, ...
    {'Inside-out', 'Outside-in'}, tips.hexReleaseOrder);
ui.HexReleaseOrderRow.Layout.Row = 32;

[ui.HexArraySizePanel, hexArraySizeFields] = createValuePanel( ...
    latticeGrid, 'Honeycomb Array', {'Rows', 'Columns'}, [3, 3], tips.hexArraySize);
ui.HexArraySizePanel.Layout.Row = 33;
ui.HexArrayRowsField = hexArraySizeFields(1);
ui.HexArrayColsField = hexArraySizeFields(2);
ui.HexArrayRowsField.ValueChangedFcn = @onHexArraySizeChanged;
ui.HexArrayColsField.ValueChangedFcn = @onHexArraySizeChanged;

ui.HexArraySelectionPanel = uipanel(latticeGrid, 'Title', 'Selected Honeycomb Cells');
ui.HexArraySelectionPanel.Layout.Row = 34;
hexArraySelectionGrid = uigridlayout(ui.HexArraySelectionPanel, [1, 1]);
hexArraySelectionGrid.RowHeight = {hexArraySelectionTableHeight(3)};
hexArraySelectionGrid.ColumnWidth = {'1x'};
hexArraySelectionGrid.Padding = [5, 5, 5, 5];

hexArrayDefaultMask = false(3, 3);
hexArrayDefaultMask(sub2ind([3, 3], [1, 1, 2, 3], [2, 3, 2, 1])) = true;
ui.HexArraySelectionTable = uitable(hexArraySelectionGrid, ...
    'Data', hexArrayDefaultMask, ...
    'ColumnName', {'C1', 'C2', 'C3'}, ...
    'RowName', {'R1', 'R2', 'R3'}, ...
    'ColumnFormat', repmat({'logical'}, 1, 3), ...
    'ColumnEditable', true(1, 3), ...
    'ColumnWidth', repmat({54}, 1, 3), ...
    'CellEditCallback', @onHexArraySelectionChanged);
ui.HexArraySelectionTable.Layout.Row = 1;
ui.HexArraySelectionTable.Layout.Column = 1;
applyTooltip({ui.HexArraySelectionPanel, ui.HexArraySelectionTable}, tips.hexArraySelection);

ui.PowerPanel = uipanel(powerOrderGrid, 'Title', 'Power');
ui.PowerPanel.Layout.Row = 1;
ui.PowerPanel.Layout.Column = 1;

powerGrid = uigridlayout(ui.PowerPanel, [5, 1]);
powerGrid.RowHeight = {'fit', 'fit', 'fit', 78, 'fit'};
powerGrid.RowSpacing = 5;
powerGrid.Padding = [6, 6, 6, 6];

[ui.PowerModeRow, ui.PowerModeDropDown] = createDropdownRow( ...
    powerGrid, 'Power Mode', {'Fixed Value', 'Custom Formula', 'Linear Points'}, 'Linear points', @onPowerModeChanged, ...
    {'Fixed value', 'Custom formula', 'Linear points'}, tips.powerMode);
ui.PowerModeRow.Layout.Row = 1;

[ui.FixedPowerRow, ui.FixedPowerField] = createNumericRow(powerGrid, 'Fixed Power', 10, tips.fixedPower);
ui.FixedPowerRow.Layout.Row = 2;

[ui.PowerFormulaRow, ui.PowerFormulaField] = createTextRow(powerGrid, 'Formula', '1+5*z', tips.powerFormula);
ui.PowerFormulaRow.Layout.Row = 3;

ui.PowerPointsPanel = uipanel(powerGrid, 'Title', 'Linear Points (z_mm, power)');
ui.PowerPointsPanel.Layout.Row = 4;
ui.PowerPointsPanel.Layout.Column = 1;

powerPointsGrid = uigridlayout(ui.PowerPointsPanel, [1, 1]);
powerPointsGrid.Padding = [5, 5, 5, 5];

ui.PowerPointsArea = uitextarea(powerPointsGrid, ...
    'Value', {'0, 10'; '0.03, 20'});
ui.PowerPointsArea.Layout.Row = 1;
ui.PowerPointsArea.Layout.Column = 1;
applyTooltip({ui.PowerPointsPanel, ui.PowerPointsArea}, tips.powerPointsArea);

ui.PowerHintLabel = uilabel(powerGrid, ...
    'Text', 'All points will use the same P value.', ...
    'WordWrap', 'on');
ui.PowerHintLabel.Layout.Row = 5;
ui.PowerHintLabel.Layout.Column = 1;

ui.OrderingPanel = uipanel(powerOrderGrid, 'Title', 'Writing Order');
ui.OrderingPanel.Layout.Row = 2;
ui.OrderingPanel.Layout.Column = 1;

orderingGrid = uigridlayout(ui.OrderingPanel, [2, 1]);
orderingGrid.RowHeight = {'fit', 'fit'};
orderingGrid.RowSpacing = 5;
orderingGrid.Padding = [6, 6, 6, 6];

ui.TraversalNoteLabel = uilabel(orderingGrid, ...
    'Text', 'Traversal: layer-by-layer (deep to shallow, ascending Z; smaller Z is deeper).', ...
    'WordWrap', 'on');
ui.TraversalNoteLabel.Layout.Row = 1;
ui.TraversalNoteLabel.Layout.Column = 1;

[ui.PathModeRow, ui.PathModeDropDown] = createDropdownRow( ...
    orderingGrid, 'In-layer Path', {'Row-major', 'Serpentine'}, 'Row-major', [], ...
    {'Row-major', 'Serpentine'}, tips.pathMode);
ui.PathModeRow.Layout.Row = 2;

ui.PlanPanel = uipanel(powerOrderGrid, 'Title', 'Exposure / Scan');
ui.PlanPanel.Layout.Row = 3;
ui.PlanPanel.Layout.Column = 1;

planGrid = uigridlayout(ui.PlanPanel, [8, 1]);
planGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
planGrid.RowSpacing = 5;
planGrid.Padding = [6, 6, 6, 6];

[ui.ExposureModeRow, ui.ExposureModeDropDown] = createDropdownRow( ...
    planGrid, 'Exposure Mode', {'Point dwell', 'Axis scan'}, 'Axis scan', @onPlanParamChanged, ...
    {'Point dwell', 'Axis scan'}, tips.exposureMode);
ui.ExposureModeRow.Layout.Row = 1;

[ui.DwellSecondsRow, ui.DwellSecondsField] = createNumericRow(planGrid, 'Dwell (s)', 1, tips.dwellSeconds);
ui.DwellSecondsRow.Layout.Row = 2;
ui.DwellSecondsField.ValueChangedFcn = @onPlanParamChanged;

[ui.ScanAxisRow, ui.ScanAxisDropDown] = createDropdownRow( ...
    planGrid, 'Scan Axis', {'X', 'Y', 'Z'}, 'Z', @onPlanParamChanged, [], tips.scanAxis);
ui.ScanAxisRow.Layout.Row = 3;

[ui.ScanDirectionRow, ui.ScanDirectionDropDown] = createDropdownRow( ...
    planGrid, 'Direction', {'Positive', 'Negative'}, 'Positive', @onPlanParamChanged, ...
    {'Positive', 'Negative'}, tips.scanDirection);
ui.ScanDirectionRow.Layout.Row = 4;

[ui.ScanAnchorRow, ui.ScanAnchorDropDown] = createDropdownRow( ...
    planGrid, 'Anchor', {'Centered on point', 'Start at point'}, 'Start at point', @onPlanParamChanged, ...
    {'Center on point', 'Start at point'}, tips.scanAnchor);
ui.ScanAnchorRow.Layout.Row = 5;

[ui.ScanLengthRow, ui.ScanLengthField] = createNumericRow(planGrid, 'Length (mm)', 0.01, tips.scanLength);
ui.ScanLengthRow.Layout.Row = 6;
ui.ScanLengthField.ValueChangedFcn = @onPlanParamChanged;

[ui.ScanSpeedRow, ui.ScanSpeedField] = createNumericRow(planGrid, 'Speed (mm/s)', 0.01, tips.scanSpeed);
ui.ScanSpeedRow.Layout.Row = 7;
ui.ScanSpeedField.ValueChangedFcn = @onPlanParamChanged;

[ui.PauseSecondsRow, ui.PauseSecondsField] = createNumericRow(planGrid, 'Pre-write pause (s)', 0.1, tips.pauseSeconds);
ui.PauseSecondsRow.Layout.Row = 8;
ui.PauseSecondsField.ValueChangedFcn = @onPlanParamChanged;

ui.ActionPanel = uipanel(controlPanelGrid, 'BorderType', 'none');
ui.ActionPanel.Layout.Row = 2;
ui.ActionPanel.Layout.Column = 1;

actionGrid = uigridlayout(ui.ActionPanel, [5, 1]);
actionGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
actionGrid.RowSpacing = 5;
actionGrid.Padding = [0, 0, 0, 0];

ui.ImportHintLabel = uilabel(actionGrid, ...
    'Text', 'Saved files include headers: mode, start/end XYZ, power, dwell, speed, pause, lead/exit, and cut group columns.', ...
    'WordWrap', 'on');
ui.ImportHintLabel.Layout.Row = 1;
ui.ImportHintLabel.Layout.Column = 1;

[ui.PreviewRowsRow, ui.PreviewRowsField] = createNumericRow(actionGrid, 'Preview rows', state.tablePreviewRowLimit, tips.previewRows);
ui.PreviewRowsRow.Layout.Row = 2;
ui.PreviewRowsField.ValueChangedFcn = @onPreviewRowsChanged;

buttonRow = uipanel(actionGrid, 'BorderType', 'none');
buttonRow.Layout.Row = 3;
buttonRow.Layout.Column = 1;

buttonGrid = uigridlayout(buttonRow, [1, 3]);
buttonGrid.ColumnWidth = {'1x', '1x', '1x'};
buttonGrid.RowHeight = {'fit'};
buttonGrid.ColumnSpacing = 6;
buttonGrid.Padding = [0, 0, 0, 0];

ui.GenerateButton = uibutton(buttonGrid, ...
    'push', ...
    'Text', 'Generate Preview', ...
    'ButtonPushedFcn', @onGenerate);
ui.GenerateButton.Layout.Row = 1;
ui.GenerateButton.Layout.Column = 1;

ui.LoadPlanButton = uibutton(buttonGrid, ...
    'push', ...
    'Text', 'Load Plan', ...
    'ButtonPushedFcn', @onLoadPlan);
ui.LoadPlanButton.Layout.Row = 1;
ui.LoadPlanButton.Layout.Column = 2;

ui.SaveButton = uibutton(buttonGrid, ...
    'push', ...
    'Text', 'Save Plan', ...
    'ButtonPushedFcn', @onSave);
ui.SaveButton.Layout.Row = 1;
ui.SaveButton.Layout.Column = 3;

ui.FileHintLabel = uilabel(actionGrid, ...
    'Text', 'Suggested CSV filename will appear after Generate Preview.', ...
    'WordWrap', 'on', ...
    'FontColor', [0.35, 0.35, 0.35]);
ui.FileHintLabel.Layout.Row = 4;
ui.FileHintLabel.Layout.Column = 1;

ui.StatusLabel = uilabel(actionGrid, ...
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
previewGrid.RowSpacing = 6;
previewGrid.Padding = [6, 6, 6, 6];

ui.PreviewAxes = uiaxes(previewGrid);
ui.PreviewAxes.Layout.Row = 1;
ui.PreviewAxes.Layout.Column = 1;
ui.PreviewAxes.Box = 'on';
ui.PreviewAxes.XLabel.String = 'X (mm)';
ui.PreviewAxes.YLabel.String = 'Y (mm)';
ui.PreviewAxes.ZLabel.String = 'Z (mm, smaller = deeper)';
title(ui.PreviewAxes, 'Point Cloud Preview');
grid(ui.PreviewAxes, 'on');
view(ui.PreviewAxes, 30, 25);
applyPreviewAxisOrientation(ui.PreviewAxes);
ui.PowerColorbar = colorbar(ui.PreviewAxes);
ui.PowerColorbar.Label.String = 'Power';

ui.SummaryLabel = uilabel(previewGrid, ...
    'Text', 'No preview generated yet.', ...
    'WordWrap', 'on');
ui.SummaryLabel.Layout.Row = 2;
ui.SummaryLabel.Layout.Column = 1;

ui.DataTable = uitable(previewGrid, ...
    'ColumnName', writingPlanColumnNames(), ...
    'ColumnEditable', false(1, numel(writingPlanColumnNames())), ...
    'ColumnWidth', repmat({90}, 1, numel(writingPlanColumnNames())), ...
    'RowName', []);
ui.DataTable.Layout.Row = 3;
ui.DataTable.Layout.Column = 1;

onLatticeTypeChanged();
onPowerModeChanged();
onPlanParamChanged();
onGenerate();
applyCompactFonts(fig);

    function onLatticeTypeChanged(~, ~)
        latticeType = string(ui.LatticeTypeDropDown.Value);
        isStaircase = latticeType == "Staircase";
        isGrating = latticeType == "Segmented Grating";
        isZPush = latticeType == "Z Push";
        isHexCut = latticeType == "Hexagon Cut";
        isHexReleaseCut = latticeType == "Hexagon Release Cut";
        isHexReleaseArray = latticeType == "Hexagon Release Cut Array";
        isCircleReleaseCut = latticeType == "Circle Release Cut";
        isHexReleaseMode = isHexReleaseCut || isHexReleaseArray;
        isReleaseMode = isHexReleaseMode || isCircleReleaseCut;
        isCutMode = isHexCut || isReleaseMode;
        showHexGeometry = isHexCut || isHexReleaseMode;
        isFixedOrder = isStaircase || isGrating || isZPush || isCutMode;
        showCartesian = latticeType == "Cartesian";
        showHexPitch = latticeType == "Hex" || latticeType == "HCP";
        showHcpShift = latticeType == "HCP";

        setPanelRow(latticeGrid, 2, ui.CountsPanel, 'fit', ~isFixedOrder);
        setPanelRow(latticeGrid, 3, ui.CartesianPitchPanel, 'fit', showCartesian);
        setPanelRow(latticeGrid, 4, ui.HexPitchPanel, 'fit', showHexPitch);
        setPanelRow(latticeGrid, 5, ui.OriginPanel, 'fit', ~isStaircase && ~isZPush && ~isCutMode);
        setPanelRow(latticeGrid, 6, ui.HcpShiftPanel, 'fit', showHcpShift);
        setPanelRow(latticeGrid, 7, ui.StepConfigPanel, 'fit', isStaircase);
        setPanelRow(latticeGrid, 8, ui.PowerColumnsPanel, 'fit', isStaircase);
        setPanelRow(latticeGrid, 9, ui.PatchCountsPanel, 'fit', isStaircase);
        setPanelRow(latticeGrid, 10, ui.PatchPitchPanel, 'fit', isStaircase);
        setPanelRow(latticeGrid, 11, ui.GapPanel, 'fit', isStaircase);
        setPanelRow(latticeGrid, 12, ui.StaircaseOriginPanel, 'fit', isStaircase);
        setPanelRow(latticeGrid, 13, ui.GratingAxesPanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 14, ui.GratingDepthPanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 15, ui.GratingSegmentOnePanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 16, ui.GratingSegmentTwoPanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 17, ui.GratingSlabOnePanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 18, ui.GratingSlabTwoPanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 19, ui.GratingChannelPanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 20, ui.GratingChannelStartsPanel, gratingChannelTablePanelHeight(), isGrating);
        setPanelRow(latticeGrid, 21, ui.GratingScanPanel, 'fit', isGrating);
        setPanelRow(latticeGrid, 22, ui.ZPushOriginPanel, 'fit', isZPush);
        setPanelRow(latticeGrid, 23, ui.ZPushMovePanel, 'fit', isZPush);
        setPanelRow(latticeGrid, 24, ui.ZPushConfigPanel, 'fit', isZPush);
        setPanelRow(latticeGrid, 25, ui.HexCutCenterPanel, 'fit', isCutMode);
        if showHexGeometry
            ui.HexCutGeometryPanel.Visible = 'on';
        else
            ui.HexCutGeometryPanel.Visible = 'off';
        end
        if isCircleReleaseCut
            ui.CircleCutGeometryPanel.Visible = 'on';
        else
            ui.CircleCutGeometryPanel.Visible = 'off';
        end
        if showHexGeometry || isCircleReleaseCut
            latticeGrid.RowHeight{26} = 'fit';
        else
            latticeGrid.RowHeight{26} = 0;
        end
        setPanelRow(latticeGrid, 27, ui.HexCutDirectionRow, 'fit', isCutMode);
        setPanelRow(latticeGrid, 28, ui.HexCutMotionPanel, 'fit', isCutMode);
        if isHexReleaseArray
            ui.HexCutCenterPanel.Title = 'Array Center (mm)';
            syncHexArraySelectionTable();
        elseif isCircleReleaseCut
            ui.HexCutCenterPanel.Title = 'Circle Center (mm)';
        else
            ui.HexCutCenterPanel.Title = 'Cut Center (mm)';
        end
        setPanelRow(latticeGrid, 29, ui.HexReleasePatternPanel, 'fit', isReleaseMode);
        setPanelRow(latticeGrid, 30, ui.HexReleaseZPanel, 'fit', isReleaseMode);
        setPanelRow(latticeGrid, 31, ui.HexReleaseMotionPanel, 'fit', isReleaseMode);
        setPanelRow(latticeGrid, 32, ui.HexReleaseOrderRow, 'fit', isReleaseMode);
        setPanelRow(latticeGrid, 33, ui.HexArraySizePanel, 'fit', isHexReleaseArray);
        setPanelRow(latticeGrid, 34, ui.HexArraySelectionPanel, hexArraySelectionPanelHeight(validateHexArrayDimension(ui.HexArrayRowsField.Value)), isHexReleaseArray);

        setPanelRow(powerOrderGrid, 1, ui.PowerPanel, 'fit', ~isStaircase && ~isCutMode);
        setPanelRow(orderingGrid, 2, ui.PathModeRow, 'fit', ~isFixedOrder);
        setPanelRow(powerOrderGrid, 3, ui.PlanPanel, 'fit', ~isCutMode);
        if isGrating
            ui.ExposureModeDropDown.Value = 'Axis scan';
            syncGratingScanAxis();
            onPlanParamChanged();
        elseif isZPush
            ui.ExposureModeDropDown.Value = 'Point dwell';
            onPlanParamChanged();
        elseif isCutMode
            onPlanParamChanged();
        end
        updateTraversalNote();
    end

    function onPowerModeChanged(~, ~)
        powerMode = string(ui.PowerModeDropDown.Value);

        setPanelRow(powerGrid, 2, ui.FixedPowerRow, 'fit', powerMode == "Fixed value");
        setPanelRow(powerGrid, 3, ui.PowerFormulaRow, 'fit', powerMode == "Custom formula");
        setPanelRow(powerGrid, 4, ui.PowerPointsPanel, 78, powerMode == "Linear points");

        switch powerMode
            case "Fixed value"
                ui.PowerHintLabel.Text = 'All points will use the same P value.';
            case "Custom formula"
                ui.PowerHintLabel.Text = 'Enter a MATLAB expression using x, y, z in mm.';
            case "Linear points"
                ui.PowerHintLabel.Text = 'Enter one "z_mm, power" pair per line. The app will linearly interpolate between them.';
        end
    end

    function onPreviewRowsChanged(~, ~)
        state.tablePreviewRowLimit = validatePreviewRowLimit(ui.PreviewRowsField.Value);
        ui.PreviewRowsField.Value = state.tablePreviewRowLimit;

        if ~isempty(state.generatedData) && ~isempty(state.generatedSummary)
            if ~state.previewFromLoadedPlan
                refreshPlanFromCurrentSettings();
            end
            updatePreview(state.generatedData, state.generatedPrefix, state.generatedSummary, state.generatedPlanTable);
        end
    end

    function onPlanParamChanged(~, ~)
        isGrating = string(ui.LatticeTypeDropDown.Value) == "Segmented Grating";
        isZPush = string(ui.LatticeTypeDropDown.Value) == "Z Push";
        if isGrating
            ui.ExposureModeDropDown.Value = 'Axis scan';
            syncGratingScanAxis();
        elseif isZPush
            ui.ExposureModeDropDown.Value = 'Point dwell';
        end

        isScan = string(ui.ExposureModeDropDown.Value) == "Axis scan";
        setPanelRow(planGrid, 2, ui.DwellSecondsRow, 'fit', ~isScan);
        setPanelRow(planGrid, 3, ui.ScanAxisRow, 'fit', isScan && ~isGrating);
        setPanelRow(planGrid, 4, ui.ScanDirectionRow, 'fit', isScan);
        setPanelRow(planGrid, 5, ui.ScanAnchorRow, 'fit', isScan);
        setPanelRow(planGrid, 6, ui.ScanLengthRow, 'fit', isScan && ~isGrating);
        setPanelRow(planGrid, 7, ui.ScanSpeedRow, 'fit', isScan);
        setPanelRow(planGrid, 8, ui.PauseSecondsRow, 'fit', ~isZPush);

        if ~isempty(state.generatedData) && ~isempty(state.generatedSummary) && ~state.previewFromLoadedPlan
            try
                refreshPlanFromCurrentSettings();
                updatePreview(state.generatedData, state.generatedPrefix, state.generatedSummary, state.generatedPlanTable);
                ui.StatusLabel.Text = sprintf('Updated %s plan.', exposureModeDisplayName(ui.ExposureModeDropDown.Value));
            catch err
                ui.StatusLabel.Text = ['Invalid plan parameters: ', err.message];
            end
        end
    end

    function onStaircaseParamChanged(~, ~)
        updateTraversalNote();
    end

    function onGratingAxisChanged(~, ~)
        if string(ui.LatticeTypeDropDown.Value) == "Segmented Grating"
            syncGratingScanAxis();
        end
        updateTraversalNote();
    end

    function onGratingChannelMatrixChanged(~, ~)
        syncGratingChannelStartsTable();
    end

    function onHexArraySizeChanged(~, ~)
        syncHexArraySelectionTable();
        updateTraversalNote();
    end

    function onHexArraySelectionChanged(~, ~)
        updateTraversalNote();
    end

    function syncGratingChannelStartsTable()
        channelRows = round(max(1, ui.GratingChannelRowsField.Value));
        channelCols = round(max(1, ui.GratingChannelColsField.Value));
        ui.GratingChannelRowsField.Value = channelRows;
        ui.GratingChannelColsField.Value = channelCols;

        resizeGratingStartTable(ui.GratingSegmentOneStartsTable, channelRows, channelCols);
        resizeGratingStartTable(ui.GratingSegmentTwoStartsTable, channelRows, channelCols);
        tableHeight = gratingStartTableHeight(channelRows);
        gratingStartsGrid.RowHeight = {'fit', tableHeight, 'fit', tableHeight};
        if string(ui.LatticeTypeDropDown.Value) == "Segmented Grating"
            latticeGrid.RowHeight{20} = gratingChannelTablePanelHeight(channelRows);
        end
    end

    function syncHexArraySelectionTable()
        arrayRows = validateHexArrayDimension(ui.HexArrayRowsField.Value);
        arrayCols = validateHexArrayDimension(ui.HexArrayColsField.Value);
        ui.HexArrayRowsField.Value = arrayRows;
        ui.HexArrayColsField.Value = arrayCols;

        oldMask = hexArraySelectionTableMask();
        newMask = false(arrayRows, arrayCols);
        copyRows = min(arrayRows, size(oldMask, 1));
        copyCols = min(arrayCols, size(oldMask, 2));
        if copyRows > 0 && copyCols > 0
            newMask(1:copyRows, 1:copyCols) = oldMask(1:copyRows, 1:copyCols);
        end

        ui.HexArraySelectionTable.Data = newMask;
        ui.HexArraySelectionTable.RowName = cellstr(compose('R%d', 1:arrayRows));
        ui.HexArraySelectionTable.ColumnName = cellstr(compose('C%d', 1:arrayCols));
        ui.HexArraySelectionTable.ColumnFormat = repmat({'logical'}, 1, arrayCols);
        ui.HexArraySelectionTable.ColumnEditable = true(1, arrayCols);
        ui.HexArraySelectionTable.ColumnWidth = repmat({54}, 1, arrayCols);

        tableHeight = hexArraySelectionTableHeight(arrayRows);
        hexArraySelectionGrid.RowHeight = {tableHeight};
        if string(ui.LatticeTypeDropDown.Value) == "Hexagon Release Cut Array"
            latticeGrid.RowHeight{34} = hexArraySelectionPanelHeight(arrayRows);
        end
    end

    function mask = hexArraySelectionTableMask()
        data = ui.HexArraySelectionTable.Data;
        if istable(data)
            data = table2array(data);
        end

        if iscell(data)
            mask = false(size(data));
            for iCell = 1:numel(data)
                mask(iCell) = parseHexArraySelectionValue(data{iCell});
            end
        elseif islogical(data)
            mask = data;
        elseif isnumeric(data)
            mask = data ~= 0;
        else
            textValues = string(data);
            mask = strcmpi(textValues, "true") | strcmpi(textValues, "1") | ...
                strcmpi(textValues, "yes") | strcmpi(textValues, "y");
        end

        mask = logical(mask);
    end

    function value = parseHexArraySelectionValue(cellValue)
        if isempty(cellValue) || ismissingValue(cellValue)
            value = false;
        elseif islogical(cellValue)
            value = cellValue;
        elseif isnumeric(cellValue)
            value = isscalar(cellValue) && isfinite(cellValue) && cellValue ~= 0;
        else
            textValue = strtrim(string(cellValue));
            value = strcmpi(textValue, "true") || strcmpi(textValue, "1") || ...
                strcmpi(textValue, "yes") || strcmpi(textValue, "y");
        end
    end

    function dimension = validateHexArrayDimension(value)
        if ~(isscalar(value) && isnumeric(value) && isfinite(value))
            dimension = 3;
            return;
        end

        dimension = round(value);
        dimension = max(1, dimension);
        dimension = min(25, dimension);
    end

    function resizeGratingStartTable(tableHandle, channelRows, channelCols)
        oldData = tableHandle.Data;
        if ~iscell(oldData)
            oldData = cellstr(string(oldData));
        end

        newData = repmat({''}, channelRows, channelCols);
        copyRows = min(channelRows, size(oldData, 1));
        copyCols = min(channelCols, size(oldData, 2));
        if copyRows > 0 && copyCols > 0
            newData(1:copyRows, 1:copyCols) = oldData(1:copyRows, 1:copyCols);
        end

        tableHandle.Data = newData;
        tableHandle.RowName = cellstr(compose('R%d', 1:channelRows));
        tableHandle.ColumnName = cellstr(compose('C%d', 1:channelCols));
        tableHandle.ColumnEditable = true(1, channelCols);
        tableHandle.ColumnWidth = repmat({54}, 1, channelCols);
    end

    function panelHeight = gratingChannelTablePanelHeight(channelRows)
        if nargin < 1
            channelRows = round(max(1, ui.GratingChannelRowsField.Value));
        end

        panelHeight = gratingChannelStartsContentHeight(channelRows);
    end

    function tableHeight = gratingStartTableHeight(channelRows)
        tableHeight = 58 + 32 * channelRows;
        tableHeight = max(150, tableHeight);
    end

    function tableHeight = hexArraySelectionTableHeight(arrayRows)
        tableHeight = 58 + 28 * arrayRows;
        tableHeight = max(140, min(420, tableHeight));
    end

    function panelHeight = hexArraySelectionPanelHeight(arrayRows)
        panelHeight = hexArraySelectionTableHeight(arrayRows) + 38;
    end

    function contentHeight = gratingChannelStartsContentHeight(channelRows)
        contentHeight = 2 * gratingStartTableHeight(channelRows) + 56;
    end

    function syncGratingScanAxis()
        try
            scanAxis = inferredGratingScanAxis();
            ui.ScanAxisDropDown.Value = char(scanAxis);
        catch
            % Invalid axis combinations are reported during generation.
        end
    end

    function scanAxis = inferredGratingScanAxis()
        depthAxis = string(ui.GratingDepthAxisDropDown.Value);
        periodAxis = string(ui.GratingPeriodAxisDropDown.Value);
        axisNames = ["X", "Y", "Z"];
        if depthAxis == periodAxis
            error('Grating depth axis and period axis cannot be the same.');
        end

        scanAxis = axisNames(~ismember(axisNames, [depthAxis, periodAxis]));
        if numel(scanAxis) ~= 1
            error('Unable to infer the grating scan axis.');
        end
    end

    function onGenerate(~, ~)
        try
            params = collectParams();
            [data, prefix, summary] = generate_point_cloud(params);
            state.generatedData = data;
            state.generatedPrefix = prefix;
            state.generatedSummary = summary;
            state.previewFromLoadedPlan = false;
            refreshPlanFromCurrentSettings();
            updatePreview(data, prefix, summary, state.generatedPlanTable);
            ui.StatusLabel.Text = sprintf('Generated %d operations.', summary.pointCount);
        catch err
            uialert(fig, err.message, 'Generate Failed');
            ui.StatusLabel.Text = 'Generate failed.';
        end
    end

    function onLoadPlan(~, ~)
        try
            [fileName, folderName] = uigetfile( ...
                {'*.csv;*.txt;*.tsv', 'Writing plan files (*.csv, *.txt, *.tsv)'; ...
                 '*.*', 'All files (*.*)'}, ...
                'Load Writing Plan', ...
                state.lastSaveFolder);

            if isequal(fileName, 0) || isequal(folderName, 0)
                return;
            end

            fullPath = fullfile(folderName, fileName);
            planTable = readWritingPlanTable(fullPath);
            data = writingPlanTableToPointData(planTable);
            [~, prefix] = fileparts(fileName);
            summary = importedPlanSummary(planTable, fileName);
            summary.fileHint = ['Loaded: ', fullPath];

            state.generatedData = data;
            state.generatedPlanTable = planTable;
            state.generatedPrefix = prefix;
            state.generatedSummary = summary;
            state.previewFromLoadedPlan = true;
            state.lastSaveFolder = folderName;

            updatePreview(data, prefix, summary, planTable);
            ui.FileHintLabel.Text = ['Loaded: ', fullPath];
            ui.StatusLabel.Text = sprintf('Loaded %d operations.', height(planTable));
        catch err
            uialert(fig, err.message, 'Load Failed');
            ui.StatusLabel.Text = 'Load failed.';
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

            if ~state.previewFromLoadedPlan
                refreshPlanFromCurrentSettings();
            end

            defaultName = [state.generatedPrefix, '_writing_plan.csv'];
            [fileName, folderName, filterIndex] = uiputfile( ...
                {'*.csv', 'Comma-separated values (*.csv)'; '*.txt', 'Tab-delimited text (*.txt)'}, ...
                'Save Writing Plan', ...
                fullfile(state.lastSaveFolder, defaultName));

            if isequal(fileName, 0) || isequal(folderName, 0)
                return;
            end

            fullPath = fullfile(folderName, fileName);
            delimiter = localDelimiter(filterIndex, fileName);
            writetable(state.generatedPlanTable, fullPath, 'Delimiter', delimiter);

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
        params.lattice.displayDistanceUnit = 'mm';

        if latticeType == "Staircase"
            params.lattice.nDepths = round(max(1, ui.NDepthsField.Value));
            params.lattice.zStartUm = mmToUm(ui.ZStartField.Value);
            params.lattice.zStepUm = mmToUm(ui.ZStepField.Value);
            params.lattice.nPowers = round(max(1, ui.NPowersField.Value));
            params.lattice.powerStart = ui.StaircasePowerStartField.Value;
            params.lattice.powerEnd = ui.StaircasePowerEndField.Value;
            params.lattice.patchNx = round(max(1, ui.PatchNxField.Value));
            params.lattice.patchNy = round(max(1, ui.PatchNyField.Value));
            params.lattice.patchPitchXUm = mmToUm(ui.PatchPitchXField.Value);
            params.lattice.patchPitchYUm = mmToUm(ui.PatchPitchYField.Value);
            params.lattice.gapXUm = mmToUm(ui.GapXField.Value);
            params.lattice.gapYUm = mmToUm(ui.GapYField.Value);
            params.lattice.originXUm = mmToUm(ui.StaircaseOriginXField.Value);
            params.lattice.originYUm = mmToUm(ui.StaircaseOriginYField.Value);
        elseif latticeType == "Segmented Grating"
            params.lattice.originUm = mmToUm([ui.OriginXField.Value, ui.OriginYField.Value, ui.OriginZField.Value]);
            params.lattice.depthAxis = string(ui.GratingDepthAxisDropDown.Value);
            params.lattice.periodAxis = string(ui.GratingPeriodAxisDropDown.Value);
            params.lattice.nDepths = round(max(1, ui.GratingDepthCountField.Value));
            params.lattice.depthStartUm = mmToUm(ui.GratingDepthStartField.Value);
            params.lattice.depthStepUm = mmToUm(ui.GratingDepthStepField.Value);
            params.lattice.period1Um = mmToUm(ui.GratingPeriod1Field.Value);
            params.lattice.nPeriods1 = round(max(1, ui.GratingPeriodCount1Field.Value));
            params.lattice.period2Um = mmToUm(ui.GratingPeriod2Field.Value);
            params.lattice.nPeriods2 = round(max(1, ui.GratingPeriodCount2Field.Value));
            params.lattice.segmentGapUm = mmToUm(ui.GratingSegmentGapField.Value);
            params.lattice.slabCopies1 = round(max(1, ui.GratingSlabCopies1Field.Value));
            params.lattice.slabPitch1Um = mmToUm(ui.GratingSlabPitch1Field.Value);
            params.lattice.slabCopies2 = round(max(1, ui.GratingSlabCopies2Field.Value));
            params.lattice.slabPitch2Um = mmToUm(ui.GratingSlabPitch2Field.Value);
            syncGratingChannelStartsTable();
            params.lattice.channelRows = round(max(1, ui.GratingChannelRowsField.Value));
            params.lattice.channelCols = round(max(1, ui.GratingChannelColsField.Value));
            params.lattice.channelRowPitchUm = mmToUm(ui.GratingChannelRowPitchField.Value);
            params.lattice.channelColPitchUm = mmToUm(ui.GratingChannelColPitchField.Value);
            params.lattice.channelStartsExplicit = true;
            params.lattice.channelStartsUm = gratingChannelStartTablesToRows( ...
                ui.GratingSegmentOneStartsTable.Data, ui.GratingSegmentTwoStartsTable.Data, ...
                params.lattice.channelRows, params.lattice.channelCols);
        elseif latticeType == "Z Push"
            params.lattice.originUm = mmToUm([ ...
                ui.ZPushOriginXField.Value, ...
                ui.ZPushOriginYField.Value, ...
                ui.ZPushOriginZField.Value]);
            params.lattice.moveXYUm = mmToUm([ui.ZPushMoveXField.Value, ui.ZPushMoveYField.Value]);
            params.lattice.pushCount = round(max(1, ui.ZPushCountField.Value));
            params.lattice.pushStepUm = mmToUm(ui.ZPushStepField.Value);
            params.lattice.intervalSeconds = ui.ZPushIntervalField.Value;
        elseif latticeType == "Hexagon Cut" || latticeType == "Hexagon Release Cut" || ...
                latticeType == "Hexagon Release Cut Array" || latticeType == "Circle Release Cut"
            params.lattice.centerUm = mmToUm([ ...
                ui.HexCutCenterXField.Value, ...
                ui.HexCutCenterYField.Value, ...
                ui.HexCutCenterZField.Value]);
            if latticeType == "Circle Release Cut"
                params.lattice.radiusUm = mmToUm(ui.CircleCutRadiusField.Value);
                params.lattice.startAngleDeg = ui.CircleCutStartAngleField.Value;
                params.lattice.segmentCount = round(max(8, ui.CircleCutSegmentCountField.Value));
            else
                params.lattice.sideLengthUm = mmToUm(ui.HexCutSideLengthField.Value);
                params.lattice.rotationDeg = ui.HexCutRotationField.Value;
            end
            params.lattice.direction = string(ui.HexCutDirectionDropDown.Value);
            params.lattice.powerPercent = ui.HexCutPowerField.Value;
            params.lattice.cutSpeedMmPerSecond = ui.HexCutSpeedField.Value;
            params.lattice.accelerationMmPerSecondSquared = ui.HexCutAccelerationField.Value;
            params.lattice.leadSafetyFactor = ui.HexCutLeadSafetyField.Value;
            params.lattice.exitSafetyFactor = ui.HexCutExitSafetyField.Value;
            if latticeType == "Hexagon Release Cut" || latticeType == "Hexagon Release Cut Array" || ...
                    latticeType == "Circle Release Cut"
                params.lattice.releaseWallMarginUm = mmToUm(ui.HexReleaseWallMarginField.Value);
                params.lattice.releaseRingCount = round(max(1, ui.HexReleaseRingCountField.Value));
                params.lattice.releaseRingPitchUm = mmToUm(ui.HexReleaseRingPitchField.Value);
                params.lattice.releaseHatchPitchUm = mmToUm(ui.HexReleaseHatchPitchField.Value);
                params.lattice.releaseLayerCount = round(max(1, ui.HexReleaseLayerCountField.Value));
                params.lattice.releaseZStepUm = mmToUm(ui.HexReleaseZStepField.Value);
                params.lattice.releaseRepeatCount = round(max(1, ui.HexReleaseRepeatCountField.Value));
                params.lattice.releaseRingPowerPercent = ui.HexReleaseRingPowerField.Value;
                params.lattice.releaseRingSpeedMmPerSecond = ui.HexReleaseRingSpeedField.Value;
                params.lattice.releaseHatchPowerPercent = ui.HexReleaseHatchPowerField.Value;
                params.lattice.releaseHatchSpeedMmPerSecond = ui.HexReleaseHatchSpeedField.Value;
                params.lattice.releaseOrder = string(ui.HexReleaseOrderDropDown.Value);
                if latticeType == "Hexagon Release Cut Array"
                    syncHexArraySelectionTable();
                    params.lattice.arrayRows = validateHexArrayDimension(ui.HexArrayRowsField.Value);
                    params.lattice.arrayCols = validateHexArrayDimension(ui.HexArrayColsField.Value);
                    params.lattice.arraySelectionMask = hexArraySelectionTableMask();
                end
            end
        else
            params.lattice.counts = [ui.PointsXField.Value, ui.PointsYField.Value, ui.PointsZField.Value];
            params.lattice.originUm = mmToUm([ui.OriginXField.Value, ui.OriginYField.Value, ui.OriginZField.Value]);
            params.lattice.hcpShift = struct( ...
                'dxUm', mmToUm(ui.AbDxField.Value), ...
                'dyUm', mmToUm(ui.AbDyField.Value));

            if latticeType == "Cartesian"
                params.lattice.pitch = struct( ...
                    'xUm', mmToUm(ui.PitchXField.Value), ...
                    'yUm', mmToUm(ui.PitchYField.Value), ...
                    'zUm', mmToUm(ui.PitchZCartesianField.Value));
            else
                params.lattice.pitch = struct( ...
                    'xyUm', mmToUm(ui.PitchXYField.Value), ...
                    'zUm', mmToUm(ui.PitchZHexField.Value));
            end
        end

        params.region = struct('mode', 'Full Block');

        params.ordering = struct('pathMode', string(ui.PathModeDropDown.Value));

        params.power = struct();
        params.power.mode = string(ui.PowerModeDropDown.Value);
        params.power.fixedValue = ui.FixedPowerField.Value;
        params.power.formula = string(ui.PowerFormulaField.Value);
        params.power.linearPointsText = strjoin(string(ui.PowerPointsArea.Value), newline);
        params.power.distanceUnit = 'mm';
    end

    function rows = gratingChannelStartTablesToRows(segmentOneData, segmentTwoData, channelRows, channelCols)
        rows = zeros(0, 4);

        for iRow = 1:channelRows
            for iCol = 1:channelCols
                segmentOneStart = gratingStartTableValue(segmentOneData, iRow, iCol, 'First Grating');
                segmentTwoStart = gratingStartTableValue(segmentTwoData, iRow, iCol, 'Second Grating');
                rows(end + 1, :) = [iRow, iCol, mmToUm(segmentOneStart), mmToUm(segmentTwoStart)]; %#ok<AGROW>
            end
        end
    end

    function value = gratingStartTableValue(tableData, iRow, iCol, tableName)
        if isempty(tableData) || iRow > size(tableData, 1) || iCol > size(tableData, 2)
            value = nan;
            return;
        end

        if iscell(tableData)
            cellValue = tableData{iRow, iCol};
        else
            cellValue = tableData(iRow, iCol);
        end

        value = parseSingleGratingStartCell(cellValue, iRow, iCol, tableName);
    end

    function value = parseSingleGratingStartCell(cellValue, iRow, iCol, tableName)
        if isempty(cellValue) || ismissingValue(cellValue)
            value = nan;
            return;
        end

        if isnumeric(cellValue)
            if ~isscalar(cellValue)
                error('%s start-position table R%d/C%d must contain only one number per cell.', tableName, iRow, iCol);
            end
            value = double(cellValue);
            if isnan(value)
                return;
            end
            if ~isfinite(value)
                error('%s start-position table R%d/C%d must be a finite distance in mm, or blank to skip writing.', tableName, iRow, iCol);
            end
            return;
        end

        textValue = strtrim(string(cellValue));
        if strlength(textValue) == 0 || any(strcmpi(textValue, ["N", "NaN"]))
            value = nan;
            return;
        end
        if contains(textValue, ",") || contains(textValue, ";")
            error('%s start-position table R%d/C%d must contain only one number per cell.', tableName, iRow, iCol);
        end

        parts = regexp(char(textValue), '\s+', 'split');
        parts = parts(~cellfun('isempty', parts));
        if numel(parts) ~= 1
            error('%s start-position table R%d/C%d must contain only one number per cell.', tableName, iRow, iCol);
        end

        value = str2double(parts{1});
        if isnan(value)
            if strcmpi(parts{1}, 'N') || strcmpi(parts{1}, 'NaN')
                return;
            end
            error('%s start-position table R%d/C%d must be numeric, blank, or N to skip writing.', tableName, iRow, iCol);
        elseif ~isfinite(value)
                error('%s start-position table R%d/C%d must be a finite distance in mm, or blank to skip writing.', tableName, iRow, iCol);
        end
    end

    function tf = ismissingValue(value)
        try
            tf = ismissing(value);
            if ~isscalar(tf)
                tf = all(tf(:));
            end
        catch
            tf = false;
        end
    end

    function refreshPlanFromCurrentSettings()
        planConfig = collectPlanConfig();
        state.generatedPlanTable = buildWritingPlanTable(state.generatedData, planConfig);
    end

    function planConfig = collectPlanConfig()
        isGrating = string(ui.LatticeTypeDropDown.Value) == "Segmented Grating";
        isZPush = string(ui.LatticeTypeDropDown.Value) == "Z Push";
        isHexCut = string(ui.LatticeTypeDropDown.Value) == "Hexagon Cut";
        isHexReleaseCut = string(ui.LatticeTypeDropDown.Value) == "Hexagon Release Cut";
        isHexReleaseArray = string(ui.LatticeTypeDropDown.Value) == "Hexagon Release Cut Array";
        isCircleReleaseCut = string(ui.LatticeTypeDropDown.Value) == "Circle Release Cut";
        isCutMode = isHexCut || isHexReleaseCut || isHexReleaseArray || isCircleReleaseCut;
        planConfig = struct();
        planConfig.mode = normalizePlanOption(ui.ExposureModeDropDown.Value);
        planConfig.dwellSeconds = validateNonnegativeScalar(ui.DwellSecondsField.Value, 'Dwell time');
        planConfig.scanAxis = string(ui.ScanAxisDropDown.Value);
        planConfig.scanDirection = normalizePlanOption(ui.ScanDirectionDropDown.Value);
        planConfig.scanAnchor = normalizePlanOption(ui.ScanAnchorDropDown.Value);
        if isGrating
            planConfig.scanLengthUm = mmToUm(validatePositiveScalar(ui.GratingScanLengthField.Value, 'Grating scan length'));
        else
            planConfig.scanLengthUm = mmToUm(validatePositiveScalar(ui.ScanLengthField.Value, 'Scan length'));
        end
        planConfig.scanSpeedMmPerSecond = validatePositiveScalar(ui.ScanSpeedField.Value, 'Scan speed');
        planConfig.pauseSeconds = validateNonnegativeScalar(ui.PauseSecondsField.Value, 'Pause time');
        planConfig.preserveOrder = isGrating || isZPush;

        if isGrating
            planConfig.mode = "axis_scan";
            planConfig.scanAxis = inferredGratingScanAxis();
        elseif isZPush
            planConfig.mode = "point_dwell";
        elseif isCutMode
            planConfig.mode = "cut_scan";
            planConfig.preserveOrder = true;
        end
    end

    function updatePreview(data, prefix, summary, planTable)
        if nargin < 4 || isempty(planTable)
            refreshPlanFromCurrentSettings();
            planTable = state.generatedPlanTable;
        end

        plotIdx = localPreviewIndices(size(data, 1), state.maxPlotPreviewPoints);
        plotTable = planTable(plotIdx, :);

        cla(ui.PreviewAxes);
        hold(ui.PreviewAxes, 'on');

        if height(plotTable) > 1
            plot3(ui.PreviewAxes, ...
                plotTable.x_mm, plotTable.y_mm, plotTable.z_mm, ...
                '-', ...
                'Color', [0.72, 0.72, 0.72], ...
                'LineWidth', 0.35);
        end

        scanMask = string(plotTable.mode) == "scan";
        if any(scanMask)
            scanTable = plotTable(scanMask, :);
            drawScanPreviewLines(ui.PreviewAxes, scanTable, [0.95, 0.45, 0.12]);
        end

        cutMask = string(plotTable.mode) == "cut";
        if any(cutMask)
            cutTable = plotTable(cutMask, :);
            drawCutPreviewLines(ui.PreviewAxes, cutTable);
        end

        sc = scatter3(ui.PreviewAxes, ...
            plotTable.x_mm, plotTable.y_mm, plotTable.z_mm, ...
            12, plotTable.power, 'filled');
        sc.DataTipTemplate.DataTipRows(end).Label = 'Power';

        hold(ui.PreviewAxes, 'off');
        grid(ui.PreviewAxes, 'on');
        colormap(ui.PreviewAxes, turbo);
        title(ui.PreviewAxes, 'Writing Plan Preview');
        [boundsX, boundsY, boundsZ] = planPreviewBounds(planTable);
        applyPreviewLimits3D(ui.PreviewAxes, boundsX, boundsY, boundsZ);

        if ~isgraphics(ui.PowerColorbar)
            ui.PowerColorbar = colorbar(ui.PreviewAxes);
        end
        ui.PowerColorbar.Label.String = 'Power';

        previewRows = min(state.tablePreviewRowLimit, height(planTable));
        ui.DataTable.Data = planTable(1:previewRows, :);
        ui.DataTable.ColumnName = planTable.Properties.VariableNames;
        ui.DataTable.ColumnEditable = false(1, width(planTable));

        if numel(plotIdx) < size(data, 1)
            plotNote = sprintf('3D preview shows a sample of %d operations to keep the UI responsive.', numel(plotIdx));
        else
            plotNote = '3D preview shows all operations in writing order.';
        end

        if isfield(summary, 'fileHint') && strlength(string(summary.fileHint)) > 0
            ui.FileHintLabel.Text = char(summary.fileHint);
        else
            ui.FileHintLabel.Text = ['Suggested filename: ', prefix, '_writing_plan.csv'];
        end
        [pointCount, scanCount, cutCount] = planOperationCounts(planTable);
        ui.SummaryLabel.Text = sprintf([ ...
            'Operations: %d point dwells, %d axis scans, %d cuts | Source points: %d / %d | Lattice: %s\n', ...
            'Traversal: %s | Path: %s | Power: %s\n', ...
            '%s\n', ...
            'X range: %.4f to %.4f mm | Y range: %.4f to %.4f mm\n', ...
            'Z range: %.4f to %.4f mm | Power range: %.2f to %.2f\n', ...
            '%s table shows only the first %d rows.'], ...
            pointCount, scanCount, cutCount, summary.pointCount, summary.sourcePointCount, summary.latticeLabel, ...
            summary.layerTraversalLabel, summary.pathModeLabel, summary.powerModeLabel, ...
            summary.pitchLabel, ...
            min(boundsX), max(boundsX), min(boundsY), max(boundsY), min(boundsZ), max(boundsZ), ...
            summary.powerRange(1), summary.powerRange(2), ...
            plotNote, previewRows);
    end

    function updateTraversalNote()
        latticeType = string(ui.LatticeTypeDropDown.Value);
        if latticeType == "Z Push"
            nPush = round(max(1, ui.ZPushCountField.Value));
            zStepMm = ui.ZPushStepField.Value;
            intervalSeconds = ui.ZPushIntervalField.Value;
            finalDepthMm = nPush * zStepMm;
            if ~(isscalar(zStepMm) && isnumeric(zStepMm) && isfinite(zStepMm) && zStepMm > 0)
                detailText = 'Z Push requires a push step greater than 0.';
            elseif ~(isscalar(intervalSeconds) && isnumeric(intervalSeconds) && isfinite(intervalSeconds) && intervalSeconds >= 0)
                detailText = 'Z Push requires a nonnegative interval time.';
            else
                detailText = sprintf('Apply the XY offset first, then push toward -Z (deeper) starting at Z0 - %.4g mm for %d steps, reaching Z0 - %.4g mm, waiting %.4g s each time.', ...
                    zStepMm, nPush, finalDepthMm, intervalSeconds);
            end
            ui.TraversalNoteLabel.Text = ['Traversal: ', detailText];
            return;
        end

        if latticeType == "Hexagon Cut" || latticeType == "Hexagon Release Cut" || ...
                latticeType == "Hexagon Release Cut Array" || latticeType == "Circle Release Cut"
            speed = ui.HexCutSpeedField.Value;
            acceleration = ui.HexCutAccelerationField.Value;
            leadSafety = ui.HexCutLeadSafetyField.Value;
            exitSafety = ui.HexCutExitSafetyField.Value;
            isCircleReleaseCut = latticeType == "Circle Release Cut";
            isReleaseCut = latticeType == "Hexagon Release Cut" || latticeType == "Hexagon Release Cut Array" || isCircleReleaseCut;
            isReleaseArray = latticeType == "Hexagon Release Cut Array";
            if isReleaseCut
                ringSpeed = ui.HexReleaseRingSpeedField.Value;
                hatchSpeed = ui.HexReleaseHatchSpeedField.Value;
            else
                ringSpeed = speed;
                hatchSpeed = speed;
            end
            if ~(isscalar(speed) && isnumeric(speed) && isfinite(speed) && speed > 0)
                detailText = 'Cut mode requires a finite positive cut speed.';
            elseif isReleaseCut && ~(isscalar(ringSpeed) && isnumeric(ringSpeed) && isfinite(ringSpeed) && ringSpeed > 0)
                detailText = 'Release cut requires a finite positive ring speed.';
            elseif isReleaseCut && ~(isscalar(hatchSpeed) && isnumeric(hatchSpeed) && isfinite(hatchSpeed) && hatchSpeed > 0)
                detailText = 'Release cut requires a finite positive hatch speed.';
            elseif ~(isscalar(acceleration) && isnumeric(acceleration) && isfinite(acceleration) && acceleration > 0)
                detailText = 'Cut mode requires a finite positive acceleration.';
            elseif ~(isscalar(leadSafety) && isnumeric(leadSafety) && isfinite(leadSafety) && leadSafety > 0)
                detailText = 'Cut mode requires a finite positive lead safety factor.';
            elseif ~(isscalar(exitSafety) && isnumeric(exitSafety) && isfinite(exitSafety) && exitSafety >= 0)
                detailText = 'Cut mode requires a finite nonnegative exit safety factor.';
            else
                if isReleaseCut
                    ringCount = round(max(1, ui.HexReleaseRingCountField.Value));
                    layerCount = round(max(1, ui.HexReleaseLayerCountField.Value));
                    repeatCount = round(max(1, ui.HexReleaseRepeatCountField.Value));
                    releaseOrder = string(ui.HexReleaseOrderDropDown.Value);
                    speeds = [speed, ringSpeed, hatchSpeed];
                    baseLeadMm = speeds .^ 2 ./ (2 * acceleration);
                    leadInMm = baseLeadMm * leadSafety;
                    leadOutMm = baseLeadMm * exitSafety;
                    ringText = 'outline ring(s)';
                    hatchText = 'internal 3-direction hatch lines';
                    if isCircleReleaseCut
                        ringText = 'circular ring group(s)';
                        hatchText = 'internal 3-direction hatch chords';
                    end
                    if releaseOrder == "Outside-in"
                        orderText = sprintf('starts with the final outer wall, then %d %s inward, then %s', ringCount, ringText, hatchText);
                    else
                        orderText = sprintf('starts with %s, then %d %s from inside to the final outer wall', hatchText, ringCount, ringText);
                    end
                    detailText = sprintf(['Each Z layer %s; %d layer(s), plan repeated %d time(s). ', ...
                        'Lead-in range %.4g-%.4g mm, lead-out range %.4g-%.4g mm.'], ...
                        orderText, layerCount, repeatCount, min(leadInMm), max(leadInMm), min(leadOutMm), max(leadOutMm));
                else
                    baseLeadMm = speed ^ 2 / (2 * acceleration);
                    detailText = sprintf('Each edge starts %.4g mm before the cut start, exposes during the edge, then exits %.4g mm after the cut end.', ...
                        baseLeadMm * leadSafety, baseLeadMm * exitSafety);
                end
            end
            if isReleaseArray
                selectedCount = nnz(hexArraySelectionTableMask());
                totalCount = validateHexArrayDimension(ui.HexArrayRowsField.Value) * validateHexArrayDimension(ui.HexArrayColsField.Value);
                detailText = sprintf('Selected %d/%d honeycomb cell(s). %s', selectedCount, totalCount, detailText);
            end
            ui.TraversalNoteLabel.Text = ['Traversal: ', detailText];
            return;
        end

        if latticeType ~= "Staircase" && latticeType ~= "Segmented Grating"
            ui.TraversalNoteLabel.Text = 'Traversal: layer-by-layer (deep to shallow, ascending Z; smaller Z is deeper).';
            return;
        end

        if latticeType == "Staircase"
            zStepMm = ui.ZStepField.Value;
            if ~(isscalar(zStepMm) && isnumeric(zStepMm) && isfinite(zStepMm))
                detailText = 'Staircase mode requires a finite non-zero Z Step.';
            elseif zStepMm ~= 0
                detailText = 'Deep to shallow (ascending Z; smaller Z is deeper).';
            else
                detailText = 'Staircase mode requires a non-zero Z Step.';
            end

            ui.TraversalNoteLabel.Text = ['Traversal: ', detailText, ' Row-major within each patch.'];
            return;
        end

        depthStepMm = ui.GratingDepthStepField.Value;
        depthAxis = string(ui.GratingDepthAxisDropDown.Value);
        periodAxis = string(ui.GratingPeriodAxisDropDown.Value);
        if depthAxis == periodAxis
            detailText = 'Grating depth axis and period axis cannot be the same.';
        elseif ~(isscalar(depthStepMm) && isnumeric(depthStepMm) && isfinite(depthStepMm))
            detailText = 'Grating requires a finite non-zero depth step.';
        elseif depthStepMm == 0
            detailText = 'Grating requires a non-zero depth step.';
        elseif depthAxis == "Z"
            detailText = 'Deep to shallow (ascending Z; smaller Z is deeper).';
        elseif depthStepMm > 0
            detailText = sprintf('Increasing along %s.', depthAxis);
        elseif depthStepMm < 0
            detailText = sprintf('Decreasing along %s.', depthAxis);
        else
            detailText = 'Grating requires a non-zero depth step.';
        end

        ui.TraversalNoteLabel.Text = ['Traversal: ', detailText, ' Within each layer, write the channel matrix row by row and column by column; each channel writes segment 1 before segment 2, and the scan axis is inferred from the remaining coordinate axis.'];
    end
end

function valueUm = mmToUm(valueMm)
valueUm = valueMm .* 1000;
end

function names = writingPlanColumnNames()
names = {'mode', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'power', 'dwell_s', 'scan_speed_mm_s', 'pause_s', ...
    'lead_x_mm', 'lead_y_mm', 'lead_z_mm', ...
    'exit_x_mm', 'exit_y_mm', 'exit_z_mm', 'lead_speed_mm_s', ...
    'cut_group_id', 'cut_group_segment'};
end

function names = writingPlanBaseColumnNames()
names = {'mode', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'power', 'dwell_s', 'scan_speed_mm_s', 'pause_s'};
end

function planTable = readWritingPlanTable(filePath)
delimiters = delimiterCandidates(filePath);
messages = strings(0, 1);

for iDelimiter = 1:numel(delimiters)
    try
        options = detectImportOptions(filePath, 'FileType', 'text', 'VariableNamingRule', 'preserve');
        if strlength(delimiters(iDelimiter)) > 0 && isprop(options, 'Delimiter')
            options.Delimiter = char(delimiters(iDelimiter));
        end
        rawTable = readtable(filePath, options);
        if isempty(rawTable) || height(rawTable) == 0
            error('The loaded writing plan file is empty.');
        end
        planTable = normalizeWritingPlanTable(rawTable);
        return;
    catch err
        messages(end + 1) = string(err.message); %#ok<AGROW>
    end
end

error('Unable to read writing plan file: %s', messages(end));
end

function delimiters = delimiterCandidates(filePath)
[~, ~, extension] = fileparts(filePath);
tabDelimiter = string(sprintf('\t'));
switch lower(extension)
    case '.csv'
        delimiters = ["", ",", tabDelimiter, ";"];
    case {'.txt', '.tsv'}
        delimiters = ["", tabDelimiter, ",", ";"];
    otherwise
        delimiters = ["", ",", tabDelimiter, ";"];
end
end

function planTable = normalizeWritingPlanTable(rawTable)
expectedNames = writingPlanColumnNames();
baseNames = writingPlanBaseColumnNames();
actualNames = string(rawTable.Properties.VariableNames);
missingNames = setdiff(string(baseNames), actualNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan file is missing columns: %s.', strjoin(missingNames, ', '));
end

n = height(rawTable);
mode = normalizeLoadedPlanModes(rawTable.mode);
x = numericColumn(rawTable.x_mm, 'x_mm');
y = numericColumn(rawTable.y_mm, 'y_mm');
z = numericColumn(rawTable.z_mm, 'z_mm');
x2 = numericColumn(rawTable.x2_mm, 'x2_mm');
y2 = numericColumn(rawTable.y2_mm, 'y2_mm');
z2 = numericColumn(rawTable.z2_mm, 'z2_mm');
power = numericColumn(rawTable.power, 'power');
dwell = numericColumn(rawTable.dwell_s, 'dwell_s');
scanSpeed = numericColumn(rawTable.scan_speed_mm_s, 'scan_speed_mm_s');
pauseSeconds = numericColumn(rawTable.pause_s, 'pause_s');
leadX = numericOptionalColumn(rawTable, 'lead_x_mm', n);
leadY = numericOptionalColumn(rawTable, 'lead_y_mm', n);
leadZ = numericOptionalColumn(rawTable, 'lead_z_mm', n);
exitX = numericOptionalColumn(rawTable, 'exit_x_mm', n);
exitY = numericOptionalColumn(rawTable, 'exit_y_mm', n);
exitZ = numericOptionalColumn(rawTable, 'exit_z_mm', n);
leadSpeed = numericOptionalColumn(rawTable, 'lead_speed_mm_s', n);
[cutGroupId, cutGroupSegment] = optionalCutGroupColumns(rawTable, mode);

if any(~isfinite(x) | ~isfinite(y) | ~isfinite(z))
    error('x_mm, y_mm, and z_mm columns must all be finite numbers.');
end
if any(~isfinite(power))
    error('The power column must contain only finite numbers.');
end

scanMask = mode == "scan";
if any(scanMask)
    if any(~isfinite(x2(scanMask)) | ~isfinite(y2(scanMask)) | ~isfinite(z2(scanMask)))
        error('Rows with mode=scan must contain finite x2_mm, y2_mm, and z2_mm values.');
    end
    if any(~isfinite(scanSpeed(scanMask)) | scanSpeed(scanMask) <= 0)
        error('Rows with mode=scan must contain positive scan_speed_mm_s values.');
    end
end

cutMask = mode == "cut";
if any(cutMask)
    if any(~isfinite(x2(cutMask)) | ~isfinite(y2(cutMask)) | ~isfinite(z2(cutMask)))
        error('Rows with mode=cut must contain finite x2_mm, y2_mm, and z2_mm values.');
    end
    if any(~isfinite(leadX(cutMask)) | ~isfinite(leadY(cutMask)) | ~isfinite(leadZ(cutMask)) | ...
            ~isfinite(exitX(cutMask)) | ~isfinite(exitY(cutMask)) | ~isfinite(exitZ(cutMask)))
        error('Rows with mode=cut must contain finite lead_* and exit_* coordinates.');
    end
    if any(~isfinite(scanSpeed(cutMask)) | scanSpeed(cutMask) <= 0)
        error('Rows with mode=cut must contain positive scan_speed_mm_s values.');
    end
    missingLeadSpeed = isnan(leadSpeed(cutMask));
    cutIndices = find(cutMask);
    leadSpeed(cutIndices(missingLeadSpeed)) = scanSpeed(cutIndices(missingLeadSpeed));
    if any(~isfinite(leadSpeed(cutMask)) | leadSpeed(cutMask) <= 0)
        error('Rows with mode=cut must contain positive lead_speed_mm_s values.');
    end
end

pointMask = mode == "point";
if any(pointMask) && any(~isfinite(dwell(pointMask)) | dwell(pointMask) < 0)
    error('Rows with mode=point must contain nonnegative dwell_s values.');
end
if any(isfinite(pauseSeconds) & pauseSeconds < 0)
    error('pause_s cannot be negative.');
end

planTable = table(mode, x, y, z, x2, y2, z2, power, dwell, scanSpeed, pauseSeconds, ...
    leadX, leadY, leadZ, exitX, exitY, exitZ, leadSpeed, cutGroupId, cutGroupSegment, ...
    'VariableNames', expectedNames);

if height(planTable) ~= n
    error('The loaded writing plan has an invalid row count.');
end
end

function modes = normalizeLoadedPlanModes(value)
modes = lower(strtrim(string(value)));
modes = regexprep(modes, '[\s-]+', '_');
modes(modes == "axis_scan") = "scan";
modes(modes == "point_dwell") = "point";
modes(modes == "cut_scan" | modes == "hexagon_cut" | modes == "hexagon_release_cut" | ...
    modes == "hexagon_release_cut_array" | modes == "circle_release_cut") = "cut";
if any(~ismember(modes, ["point", "scan", "cut"]))
    error('The mode column only supports point, scan, or cut.');
end
end

function values = numericColumn(value, columnName)
if isnumeric(value)
    values = double(value);
    values = values(:);
    return;
end

textValue = strtrim(string(value(:)));
values = str2double(textValue);
values = values(:);
missingMask = ismissing(textValue) | strlength(textValue) == 0 | strcmpi(textValue, "NaN") | strcmpi(textValue, "NA");
values(missingMask) = nan;
badText = isnan(values) & ~missingMask;
if any(badText)
    error('%s column contains values that cannot be parsed as numbers.', columnName);
end
end

function values = numericOptionalColumn(rawTable, columnName, rowCount)
if any(strcmp(rawTable.Properties.VariableNames, columnName))
    values = numericColumn(rawTable.(columnName), columnName);
else
    values = nan(rowCount, 1);
end
end

function [groupId, groupSegment] = optionalCutGroupColumns(rawTable, mode)
rowCount = height(rawTable);
cutMask = mode == "cut";
hasGroupId = any(strcmp(rawTable.Properties.VariableNames, 'cut_group_id'));
hasGroupSegment = any(strcmp(rawTable.Properties.VariableNames, 'cut_group_segment'));
if hasGroupSegment && ~hasGroupId
    error('Writing plan file has cut_group_segment but is missing cut_group_id.');
end

groupId = nan(rowCount, 1);
groupSegment = nan(rowCount, 1);
if ~hasGroupId
    cutIndices = find(cutMask);
    groupId(cutIndices) = (1:numel(cutIndices)).';
    groupSegment(cutIndices) = 1;
    return;
end

groupId = numericOptionalColumn(rawTable, 'cut_group_id', rowCount);
if any(cutMask & (~isfinite(groupId) | groupId < 1 | abs(groupId - round(groupId)) > 1e-9))
    error('cut_group_id values must be positive integers on cut rows.');
end
groupId(cutMask) = round(groupId(cutMask));

if hasGroupSegment
    groupSegment = numericOptionalColumn(rawTable, 'cut_group_segment', rowCount);
    if any(cutMask & (~isfinite(groupSegment) | groupSegment < 1 | abs(groupSegment - round(groupSegment)) > 1e-9))
        error('cut_group_segment values must be positive integers on cut rows.');
    end
    groupSegment(cutMask) = round(groupSegment(cutMask));
else
    groupSegment = autoCutGroupSegments(groupId, cutMask);
end
end

function segments = autoCutGroupSegments(groupId, cutMask)
segments = nan(numel(groupId), 1);
for iRow = 1:numel(groupId)
    if ~cutMask(iRow)
        continue;
    end
    segments(iRow) = nnz(cutMask(1:iRow) & (groupId(1:iRow) == groupId(iRow)));
end
end

function data = writingPlanTableToPointData(planTable)
data = [planTable.x_mm, planTable.y_mm, planTable.z_mm, planTable.power];
end

function summary = importedPlanSummary(planTable, fileName)
[pointCount, scanCount, cutCount] = planOperationCounts(planTable);
summary = struct();
summary.pointCount = height(planTable);
summary.sourcePointCount = height(planTable);
summary.latticeLabel = 'Loaded Writing Plan';
summary.layerTraversalLabel = 'File row order';
summary.pathModeLabel = sprintf('File order (%d point dwells / %d axis scans / %d cuts)', pointCount, scanCount, cutCount);
summary.powerModeLabel = 'File power column';
summary.pitchLabel = ['Source file: ', fileName];
summary.powerRange = [min(planTable.power), max(planTable.power)];
summary.fileHint = ['Loaded: ', fileName];
end

function planTable = buildWritingPlanTable(data, planConfig)
if isempty(data)
    planTable = table();
    return;
end

if size(data, 2) < 4
    error('Generated data must include X, Y, Z, and power columns.');
end

n = size(data, 1);
x = data(:, 1);
y = data(:, 2);
z = data(:, 3);
power = data(:, 4);
x2 = nan(n, 1);
y2 = nan(n, 1);
z2 = nan(n, 1);
dwell = nan(n, 1);
scanSpeed = nan(n, 1);
pauseSeconds = repmat(planConfig.pauseSeconds, n, 1);
leadX = nan(n, 1);
leadY = nan(n, 1);
leadZ = nan(n, 1);
exitX = nan(n, 1);
exitY = nan(n, 1);
exitZ = nan(n, 1);
leadSpeed = nan(n, 1);
cutGroupId = nan(n, 1);
cutGroupSegment = nan(n, 1);

switch planConfig.mode
    case "point_dwell"
        mode = repmat("point", n, 1);
        dwell(:) = planConfig.dwellSeconds;

    case "axis_scan"
        mode = repmat("scan", n, 1);
        x2 = x;
        y2 = y;
        z2 = z;

        axisIndex = find(["X", "Y", "Z"] == upper(planConfig.scanAxis), 1);
        if isempty(axisIndex)
            error('Unsupported scan axis: "%s".', planConfig.scanAxis);
        end

        directionSign = 1;
        if planConfig.scanDirection == "negative"
            directionSign = -1;
        end

        lengthMm = planConfig.scanLengthUm / 1000;
        startShift = 0;
        if planConfig.scanAnchor == "center_on_point"
            startShift = -directionSign * lengthMm / 2;
            endShift = directionSign * lengthMm / 2;
        else
            endShift = directionSign * lengthMm;
        end

        switch axisIndex
            case 1
                x = x + startShift;
                x2 = data(:, 1) + endShift;
            case 2
                y = y + startShift;
                y2 = data(:, 2) + endShift;
            case 3
                z = z + startShift;
                z2 = data(:, 3) + endShift;
        end

        scanSpeed(:) = planConfig.scanSpeedMmPerSecond;

    case "cut_scan"
        if size(data, 2) < 14
            error('Cut-scan data must include cut end, lead-in, lead-out, and speed columns.');
        end
        mode = repmat("cut", n, 1);
        x2 = data(:, 5);
        y2 = data(:, 6);
        z2 = data(:, 7);
        leadX = data(:, 8);
        leadY = data(:, 9);
        leadZ = data(:, 10);
        exitX = data(:, 11);
        exitY = data(:, 12);
        exitZ = data(:, 13);
        scanSpeed = data(:, 14);
        if size(data, 2) >= 15
            leadSpeed = data(:, 15);
        else
            leadSpeed = scanSpeed;
        end
        if size(data, 2) >= 16
            pauseSeconds = data(:, 16);
        else
            pauseSeconds = zeros(n, 1);
        end
        if size(data, 2) >= 18
            cutGroupId = data(:, 17);
            cutGroupSegment = data(:, 18);
        elseif size(data, 2) == 17
            error('Cut-scan data must include both cut group id and cut group segment columns, or neither.');
        else
            cutGroupId = (1:n).';
            cutGroupSegment = ones(n, 1);
        end
        if any(~isfinite([x2; y2; z2; leadX; leadY; leadZ; exitX; exitY; exitZ]))
            error('Cut-scan coordinates must all be finite.');
        end
        if any(~isfinite(scanSpeed) | scanSpeed <= 0 | ~isfinite(leadSpeed) | leadSpeed <= 0)
            error('Cut-scan speeds must be finite positive values.');
        end
        if any(~isfinite(pauseSeconds) | pauseSeconds < 0)
            error('Cut-scan pause values must be finite nonnegative values.');
        end
        if any(~isfinite(cutGroupId) | cutGroupId < 1 | abs(cutGroupId - round(cutGroupId)) > 1e-9 | ...
                ~isfinite(cutGroupSegment) | cutGroupSegment < 1 | abs(cutGroupSegment - round(cutGroupSegment)) > 1e-9)
            error('Cut group columns must contain positive integers.');
        end
        cutGroupId = round(cutGroupId);
        cutGroupSegment = round(cutGroupSegment);

    otherwise
        error('Unsupported exposure mode: "%s".', planConfig.mode);
end

if planConfig.mode ~= "cut_scan" && size(data, 2) >= 5
    customPauseSeconds = data(:, 5);
    if any(~isfinite(customPauseSeconds) | customPauseSeconds < 0)
        error('Generated data column 5 pause_s must contain only finite nonnegative numbers.');
    end
    pauseSeconds = customPauseSeconds;
end

planTable = table(mode, x, y, z, x2, y2, z2, power, dwell, scanSpeed, pauseSeconds, ...
    leadX, leadY, leadZ, exitX, exitY, exitZ, leadSpeed, cutGroupId, cutGroupSegment, ...
    'VariableNames', writingPlanColumnNames());

if ~isfield(planConfig, 'preserveOrder') || ~planConfig.preserveOrder
    planTable = sortWritingPlanDeepToShallow(planTable);
end
end

function planTable = sortWritingPlanDeepToShallow(planTable)
if isempty(planTable) || height(planTable) < 2
    return;
end

operationDepth = planTable.z_mm;
scanMask = isfinite(planTable.z2_mm);
operationDepth(scanMask) = min(operationDepth(scanMask), planTable.z2_mm(scanMask));
leadMask = isfinite(planTable.lead_z_mm);
operationDepth(leadMask) = min(operationDepth(leadMask), planTable.lead_z_mm(leadMask));
exitMask = isfinite(planTable.exit_z_mm);
operationDepth(exitMask) = min(operationDepth(exitMask), planTable.exit_z_mm(exitMask));
rowIndex = (1:height(planTable)).';
sortKeys = [operationDepth(:), rowIndex];
[~, order] = sortrows(sortKeys, [1, 2]);
planTable = planTable(order, :);
end

function value = validatePositiveScalar(value, label)
if ~(isscalar(value) && isnumeric(value) && isfinite(value) && value > 0)
    error('%s must be a finite positive number.', label);
end
end

function value = validateNonnegativeScalar(value, label)
if ~(isscalar(value) && isnumeric(value) && isfinite(value) && value >= 0)
    error('%s must be a finite nonnegative number.', label);
end
end

function value = normalizePlanOption(value)
value = lower(string(value));
value = regexprep(value, '[\s-]+', '_');
end

function [pointCount, scanCount, cutCount] = planOperationCounts(planTable)
modes = string(planTable.mode);
pointCount = nnz(modes == "point");
scanCount = nnz(modes == "scan");
cutCount = nnz(modes == "cut");
end

function [xValues, yValues, zValues] = planPreviewBounds(planTable)
xValues = planTable.x_mm;
yValues = planTable.y_mm;
zValues = planTable.z_mm;

scanMask = string(planTable.mode) == "scan";
if any(scanMask)
    xValues = [xValues; planTable.x2_mm(scanMask)];
    yValues = [yValues; planTable.y2_mm(scanMask)];
    zValues = [zValues; planTable.z2_mm(scanMask)];
end

cutMask = string(planTable.mode) == "cut";
if any(cutMask)
    cutTable = planTable(cutMask, :);
    groups = cutTableGroups(cutTable);
    leadRows = groups(:, 1);
    exitRows = groups(:, 2);
    xValues = [xValues; cutTable.x2_mm; cutTable.lead_x_mm(leadRows); cutTable.exit_x_mm(exitRows)];
    yValues = [yValues; cutTable.y2_mm; cutTable.lead_y_mm(leadRows); cutTable.exit_y_mm(exitRows)];
    zValues = [zValues; cutTable.z2_mm; cutTable.lead_z_mm(leadRows); cutTable.exit_z_mm(exitRows)];
end

xValues = xValues(isfinite(xValues));
yValues = yValues(isfinite(yValues));
zValues = zValues(isfinite(zValues));
end

function drawScanPreviewLines(ax, scanTable, colorValue)
xLines = [scanTable.x_mm.'; scanTable.x2_mm.'; nan(1, height(scanTable))];
yLines = [scanTable.y_mm.'; scanTable.y2_mm.'; nan(1, height(scanTable))];
zLines = [scanTable.z_mm.'; scanTable.z2_mm.'; nan(1, height(scanTable))];
plot3(ax, xLines(:), yLines(:), zLines(:), '-', 'Color', colorValue, 'LineWidth', 1.2);

arrowLimit = min(height(scanTable), 2000);
if arrowLimit == 0
    return;
end
arrowIdx = unique(round(linspace(1, height(scanTable), arrowLimit)));
u = scanTable.x2_mm(arrowIdx) - scanTable.x_mm(arrowIdx);
v = scanTable.y2_mm(arrowIdx) - scanTable.y_mm(arrowIdx);
w = scanTable.z2_mm(arrowIdx) - scanTable.z_mm(arrowIdx);
quiver3(ax, scanTable.x_mm(arrowIdx), scanTable.y_mm(arrowIdx), scanTable.z_mm(arrowIdx), ...
    u, v, w, 0, 'Color', colorValue, 'LineWidth', 0.9, 'MaxHeadSize', 0.8);
end

function drawCutPreviewLines(ax, cutTable)
leadColor = [0.45, 0.45, 0.45];
cutColor = [0.9, 0.12, 0.08];
groups = cutTableGroups(cutTable);
leadX = [];
leadY = [];
leadZ = [];
cutX = [];
cutY = [];
cutZ = [];
exitX = [];
exitY = [];
exitZ = [];
for iGroup = 1:size(groups, 1)
    firstRow = groups(iGroup, 1);
    lastRow = groups(iGroup, 2);
    rows = firstRow:lastRow;
    leadX = [leadX; cutTable.lead_x_mm(firstRow); cutTable.x_mm(firstRow); nan]; %#ok<AGROW>
    leadY = [leadY; cutTable.lead_y_mm(firstRow); cutTable.y_mm(firstRow); nan]; %#ok<AGROW>
    leadZ = [leadZ; cutTable.lead_z_mm(firstRow); cutTable.z_mm(firstRow); nan]; %#ok<AGROW>
    cutX = [cutX; cutTable.x_mm(firstRow); cutTable.x2_mm(rows); nan]; %#ok<AGROW>
    cutY = [cutY; cutTable.y_mm(firstRow); cutTable.y2_mm(rows); nan]; %#ok<AGROW>
    cutZ = [cutZ; cutTable.z_mm(firstRow); cutTable.z2_mm(rows); nan]; %#ok<AGROW>
    exitX = [exitX; cutTable.x2_mm(lastRow); cutTable.exit_x_mm(lastRow); nan]; %#ok<AGROW>
    exitY = [exitY; cutTable.y2_mm(lastRow); cutTable.exit_y_mm(lastRow); nan]; %#ok<AGROW>
    exitZ = [exitZ; cutTable.z2_mm(lastRow); cutTable.exit_z_mm(lastRow); nan]; %#ok<AGROW>
end
plot3(ax, leadX, leadY, leadZ, '--', 'Color', leadColor, 'LineWidth', 0.9);
plot3(ax, cutX, cutY, cutZ, '-', 'Color', cutColor, 'LineWidth', 1.5);
plot3(ax, exitX, exitY, exitZ, ':', 'Color', leadColor, 'LineWidth', 1.0);

arrowLimit = min(height(cutTable), 2000);
if arrowLimit == 0
    return;
end
arrowIdx = unique(round(linspace(1, height(cutTable), arrowLimit)));
u = cutTable.x2_mm(arrowIdx) - cutTable.x_mm(arrowIdx);
v = cutTable.y2_mm(arrowIdx) - cutTable.y_mm(arrowIdx);
w = cutTable.z2_mm(arrowIdx) - cutTable.z_mm(arrowIdx);
quiver3(ax, cutTable.x_mm(arrowIdx), cutTable.y_mm(arrowIdx), cutTable.z_mm(arrowIdx), ...
    u, v, w, 0, 'Color', cutColor, 'LineWidth', 0.9, 'MaxHeadSize', 0.8);
end

function groups = cutTableGroups(cutTable)
if isempty(cutTable) || height(cutTable) == 0
    groups = zeros(0, 2);
    return;
end

if any(strcmp(cutTable.Properties.VariableNames, 'cut_group_id')) && all(isfinite(cutTable.cut_group_id))
    groupIds = cutTable.cut_group_id(:);
else
    groupIds = (1:height(cutTable)).';
end

groupStarts = [1; find(groupIds(2:end) ~= groupIds(1:end - 1)) + 1];
groupEnds = [groupStarts(2:end) - 1; height(cutTable)];
groups = [groupStarts, groupEnds];
end

function tips = parameterTooltips()
tips = struct();
tips.latticeType = 'Choose the lattice generator: Cartesian is a regular grid; Hex/HCP use staggered layers; Staircase builds a depth/power matrix; Segmented Grating builds a two-period 1D QPM pattern; Z Push steps one point toward -Z; Hexagon Cut creates six continuous cutting edges; Hexagon Release Cut adds hatch and concentric release rings; Hexagon Release Cut Array repeats that cut on selected honeycomb cells; Circle Release Cut creates grouped continuous circular rings.';
tips.counts = { ...
    'Number of generated points along X; must be a positive integer.', ...
    'Number of generated points along Y; must be a positive integer.', ...
    'Number of generated layers or points along Z; must be a positive integer.'};
tips.cartesianPitch = { ...
    'Spacing between adjacent points along X, in mm.', ...
    'Spacing between adjacent points along Y, in mm.', ...
    'Spacing between adjacent Z layers, in mm.'};
tips.hexPitch = { ...
    'Neighbor spacing for Hex/HCP lattices in the XY plane, in mm.', ...
    'Spacing between adjacent Z layers for Hex/HCP lattices, in mm.'};
tips.origin = { ...
    'Overall lattice X origin or offset, in mm.', ...
    'Overall lattice Y origin or offset, in mm.', ...
    'Overall lattice Z origin or offset, in mm.'};
tips.hcpShift = { ...
    'X offset of HCP B layers relative to A layers, in mm.', ...
    'Y offset of HCP B layers relative to A layers, in mm.'};
tips.stepConfig = { ...
    'Number of depth layers in Staircase mode.', ...
    'Z coordinate of the first Staircase layer, in mm.', ...
    'Z step between adjacent depth layers, in mm; smaller Z is deeper.'};
tips.powerColumns = { ...
    'Number of power columns in Staircase mode.', ...
    'Power value used by the first Staircase column.', ...
    'Power value used by the last Staircase column; intermediate columns are interpolated linearly.'};
tips.patchCounts = { ...
    'Number of points along X in each Staircase patch.', ...
    'Number of points along Y in each Staircase patch.'};
tips.patchPitch = { ...
    'X spacing inside each Staircase patch, in mm.', ...
    'Y spacing inside each Staircase patch, in mm.'};
tips.gap = { ...
    'Blank X gap between adjacent Staircase patches, in mm.', ...
    'Blank Y gap between adjacent Staircase patches, in mm.'};
tips.staircaseOrigin = { ...
    'Overall Staircase array X origin or offset, in mm.', ...
    'Overall Staircase array Y origin or offset, in mm.'};
tips.gratingAxes = { ...
    'Depth direction for the segmented grating; depth layers are emitted from start and step.', ...
    'Period direction for the 1D QPM pattern; the scan direction automatically uses the remaining coordinate axis.'};
tips.gratingDepth = { ...
    'Number of depth layers in the segmented grating.', ...
    'Depth-axis coordinate of the first layer relative to the origin, in mm.', ...
    'Depth-axis step between adjacent layers, in mm; for Z depth, smaller Z is deeper.'};
tips.gratingSegmentOne = { ...
    'Period of segment 1 in the 1D QPM pattern, in mm.', ...
    'Number of periods in segment 1.'};
tips.gratingSegmentTwo = { ...
    'Period of segment 2 in the 1D QPM pattern, in mm.', ...
    'Number of periods in segment 2.', ...
    'Gap from the last segment 1 period position to the start of segment 2 along the period axis, in mm; defaults to the segment 1 period.'};
tips.gratingSlabOne = { ...
    'Number of adjacent scan lines written at each segment 1 period position to form a thicker slab.', ...
    'Spacing along the period axis between adjacent scan lines in the same segment 1 slab, in mm.'};
tips.gratingSlabTwo = { ...
    'Number of adjacent scan lines written at each segment 2 period position to form a thicker slab.', ...
    'Spacing along the period axis between adjacent scan lines in the same segment 2 slab, in mm.'};
tips.gratingChannel = { ...
    'Rows in the segmented grating channel matrix; channels are written row by row and column by column for each depth layer.', ...
    'Columns in the segmented grating channel matrix; channels are written row by row and column by column for each depth layer.', ...
    'Origin offset between adjacent channel rows, defaulting to the depth axis, in mm; sign controls direction.', ...
    'Origin offset between adjacent channel columns, defaulting to the scan axis, in mm; sign controls direction.'};
tips.gratingChannelStarts = [ ...
    'Table cells map to channel positions: R1/C1 is row 1 column 1, R2/C1 is row 2 column 1;', ...
    'The first table gives segment 1 grating start positions, and the second table gives segment 2 start positions, in mm;', ...
    'Enter only one number per cell; blank or N skips that segment for that channel.'];
tips.gratingScan = { ...
    'Length of each segmented grating slab scan line, in mm.'};
tips.zPushOrigin = { ...
    'Reference X coordinate before push starts, in mm.', ...
    'Reference Y coordinate before push starts, in mm.', ...
    'Surface or initial Z coordinate, in mm; the first step writes at Z0 - step.'};
tips.zPushMove = { ...
    'X offset from the initial X coordinate, in mm.', ...
    'Y offset from the initial Y coordinate, in mm.'};
tips.zPushConfig = { ...
    'Number of pushes along -Z; must be a positive integer.', ...
    'Distance for each -Z push, in mm; for example, 0.01 means 0.01 mm per step.', ...
    'Wait time after each push reaches position; written to pause_s, in seconds.'};
tips.hexCutCenter = { ...
    'Center X coordinate of the hexagon, in mm.', ...
    'Center Y coordinate of the hexagon, in mm.', ...
    'Fixed Z coordinate of the hexagon cut plane, in mm.'};
tips.hexCutGeometry = { ...
    'Side length of the regular hexagon, in mm.', ...
    'Rotation angle of the first vertex around the center, in degrees.'};
tips.circleCutGeometry = { ...
    'Radius of the final circular wall, in mm.', ...
    'Angle of the first polygon vertex around the center, in degrees.', ...
    'Number of straight segments used to approximate each circular ring; larger values are smoother but create more rows.'};
tips.hexCutDirection = 'Order used to cut the six hexagon edges.';
tips.hexCutMotion = { ...
    'Laser power used during each exposed edge; in Hexagon Release Cut this is the final outer wall power.', ...
    'Target stage speed during the exposed cut, in mm/s; in Hexagon Release Cut this is the final outer wall speed.', ...
    'Stage acceleration used to estimate the laser-off lead-in distance, in mm/s^2.', ...
    'Multiplier applied to v^2/(2a) for the lead-in distance before each cut start.', ...
    'Multiplier applied to v^2/(2a) for the laser-off lead-out distance after each cut end.'};
tips.hexReleasePattern = { ...
    'Distance from internal hatch endpoints to the final wall, in mm.', ...
    'Number of concentric release outline rings; the final ring is the requested hole boundary.', ...
    'Inward offset spacing between concentric outline rings, in mm.', ...
    'Spacing between internal 3-direction hatch lines, in mm; set to 0 to disable hatch.'};
tips.hexReleaseZ = { ...
    'Number of repeated release-cut Z layers.', ...
    'Z offset between release layers, in mm; sign controls whether layers move deeper or shallower.', ...
    'Number of times to repeat the complete generated release plan; 1 keeps the original plan.'};
tips.hexReleaseMotion = { ...
    'Laser power used for concentric release rings inside the final hexagon wall.', ...
    'Stage speed used for concentric release rings, in mm/s.', ...
    'Laser power used for internal 3-direction hatch destruction lines.', ...
    'Stage speed used for internal 3-direction hatch destruction lines, in mm/s.'};
tips.hexReleaseOrder = ['Inside-out writes hatch first, then inward release rings, and the final wall last; ', ...
    'Outside-in writes the final wall first, then release rings inward, and hatch last.'];
tips.hexArraySize = { ...
    'Number of selectable honeycomb rows in the cut mask table.', ...
    'Number of selectable honeycomb columns in the cut mask table.'};
tips.hexArraySelection = ['Checked cells are cut with the same Hexagon Release Cut recipe. ', ...
    'The array is centered on the Center X/Y/Z values; columns are staggered to form a close-packed honeycomb.'];
tips.powerMode = 'Choose how the power column is generated for each point: fixed value, formula, or linear interpolation by Z depth.';
tips.fixedPower = 'Single power value used for all points in fixed-power mode.';
tips.powerFormula = 'Custom power formula; x, y, and z variables are in mm.';
tips.powerPointsArea = 'Enter one "z_mm, power" pair per line. The app linearly interpolates power by Z depth.';
tips.pathMode = 'Controls writing order within the same Z layer: row-major uses the same direction per row; serpentine reverses adjacent rows to reduce travel.';
tips.exposureMode = 'Choose the exposure mode for the writing plan: point dwell opens the shutter at each point; axis scan moves from a start point to an end point.';
tips.dwellSeconds = 'Exposure time for each point in point-dwell mode, in seconds.';
tips.scanAxis = 'Coordinate axis used for axis scans.';
tips.scanDirection = 'Axis scans move from the start point in the positive or negative coordinate direction; positive Z corresponds to deep-to-shallow.';
tips.scanAnchor = 'Centered on point means the scan segment is centered on the source point; start at point means the source point is the scan start.';
tips.scanLength = 'Length of each axis scan, in mm.';
tips.scanSpeed = 'Stage speed during axis scans, in mm/s.';
tips.pauseSeconds = 'Settling time after the stage reaches a point or scan start before exposure or scanning, in seconds.';
tips.previewRows = 'Maximum number of plan rows shown in the table; saving still writes every row.';
end
function [rowPanel, dropdown] = createDropdownRow(parent, labelText, items, defaultValue, callback, itemData, tooltipText)
if nargin < 7
    tooltipText = '';
end

rowPanel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(rowPanel, [1, 2]);
grid.ColumnWidth = {142, '1x'};
grid.RowHeight = {'fit'};
grid.ColumnSpacing = 5;
grid.Padding = [0, 0, 0, 0];

label = uilabel(grid, 'Text', labelText, 'WordWrap', 'on');
label.Layout.Row = 1;
label.Layout.Column = 1;

if nargin < 6 || isempty(itemData)
    dropdown = uidropdown(grid, 'Items', items, 'Value', defaultValue);
else
    dropdown = uidropdown(grid, 'Items', items, 'ItemsData', itemData, 'Value', defaultValue);
end
dropdown.Layout.Row = 1;
dropdown.Layout.Column = 2;
applyTooltip({rowPanel, label, dropdown}, tooltipText);

if ~isempty(callback)
    dropdown.ValueChangedFcn = callback;
end
end

function [panel, dropdowns] = createDropdownPanel(parent, titleText, labelTexts, items, defaultValues, callback, tooltipTexts)
if nargin < 7
    tooltipTexts = '';
end

labelTexts = cellstr(string(labelTexts));
defaultValues = cellstr(string(defaultValues));
count = numel(labelTexts);
if ischar(items) || isstring(items)
    items = cellstr(string(items));
end

if isempty(tooltipTexts)
    tooltipTexts = repmat({''}, 1, count);
else
    tooltipTexts = cellstr(string(tooltipTexts));
    if isscalar(tooltipTexts) && count > 1
        tooltipTexts = repmat(tooltipTexts, 1, count);
    elseif numel(tooltipTexts) < count
        tooltipTexts(end + 1:count) = {''};
    elseif numel(tooltipTexts) > count
        tooltipTexts = tooltipTexts(1:count);
    end
end

panel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(panel, [2, 1 + count]);
grid.RowHeight = {'fit', 'fit'};
grid.ColumnWidth = [{128}, repmat({'1x'}, 1, count)];
grid.RowSpacing = 0;
grid.ColumnSpacing = 6;
grid.Padding = [0, 0, 0, 0];

titleLabel = uilabel(grid, 'Text', titleText, 'WordWrap', 'on');
titleLabel.Layout.Row = [1, 2];
titleLabel.Layout.Column = 1;
nonemptyTips = string(tooltipTexts);
nonemptyTips = nonemptyTips(strlength(nonemptyTips) > 0);
applyTooltip({panel, titleLabel}, strjoin(nonemptyTips, newline));

dropdowns = gobjects(1, count);
for i = 1:count
    fieldColumn = 1 + i;

    label = uilabel(grid, 'Text', labelTexts{i}, 'HorizontalAlignment', 'center', 'WordWrap', 'on');
    label.Layout.Row = 1;
    label.Layout.Column = fieldColumn;

    dropdown = uidropdown(grid, 'Items', items, 'Value', defaultValues{i});
    dropdown.Layout.Row = 2;
    dropdown.Layout.Column = fieldColumn;
    if ~isempty(callback)
        dropdown.ValueChangedFcn = callback;
    end
    applyTooltip({label, dropdown}, tooltipTexts{i});
    dropdowns(i) = dropdown;
end
end

function [rowPanel, field] = createNumericRow(parent, labelText, defaultValue, tooltipText)
if nargin < 4
    tooltipText = '';
end

rowPanel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(rowPanel, [1, 2]);
grid.ColumnWidth = {142, '1x'};
grid.RowHeight = {'fit'};
grid.ColumnSpacing = 5;
grid.Padding = [0, 0, 0, 0];

label = uilabel(grid, 'Text', labelText, 'WordWrap', 'on');
label.Layout.Row = 1;
label.Layout.Column = 1;

field = uieditfield(grid, 'numeric', 'Value', defaultValue);
field.Layout.Row = 1;
field.Layout.Column = 2;
applyTooltip({rowPanel, label, field}, tooltipText);
end

function [rowPanel, field] = createTextRow(parent, labelText, defaultValue, tooltipText)
if nargin < 4
    tooltipText = '';
end

rowPanel = uipanel(parent, 'BorderType', 'none');

grid = uigridlayout(rowPanel, [1, 2]);
grid.ColumnWidth = {142, '1x'};
grid.RowHeight = {'fit'};
grid.ColumnSpacing = 5;
grid.Padding = [0, 0, 0, 0];

label = uilabel(grid, 'Text', labelText, 'WordWrap', 'on');
label.Layout.Row = 1;
label.Layout.Column = 1;

field = uieditfield(grid, 'text', 'Value', defaultValue);
field.Layout.Row = 1;
field.Layout.Column = 2;
applyTooltip({rowPanel, label, field}, tooltipText);
end

function [panel, fields] = createValuePanel(parent, titleText, labelTexts, defaultValues, tooltipTexts)
if nargin < 5
    tooltipTexts = '';
end

[panel, fields] = createValuePanelWithSlots(parent, titleText, labelTexts, defaultValues, numel(labelTexts), tooltipTexts);
end

function [panel, fields] = createValuePanelWithSlots(parent, titleText, labelTexts, defaultValues, slotCount, tooltipTexts)
if nargin < 6
    tooltipTexts = '';
end

panel = uipanel(parent, 'BorderType', 'none');

labelTexts = cellstr(string(labelTexts));
defaultValues = reshape(defaultValues, 1, []);
count = numel(labelTexts);
if nargin < 5 || isempty(tooltipTexts)
    tooltipTexts = repmat({''}, 1, count);
else
    tooltipTexts = cellstr(string(tooltipTexts));
    if isscalar(tooltipTexts) && count > 1
        tooltipTexts = repmat(tooltipTexts, 1, count);
    elseif numel(tooltipTexts) < count
        tooltipTexts(end + 1:count) = {''};
    elseif numel(tooltipTexts) > count
        tooltipTexts = tooltipTexts(1:count);
    end
end

slotCount = max(slotCount, count);

grid = uigridlayout(panel, [2, 1 + slotCount]);
grid.RowHeight = {'fit', 'fit'};
grid.ColumnWidth = [{128}, repmat({'1x'}, 1, slotCount)];
grid.RowSpacing = 0;
grid.ColumnSpacing = 6;
grid.Padding = [0, 0, 0, 0];

titleLabel = uilabel(grid, 'Text', titleText, 'WordWrap', 'on');
titleLabel.Layout.Row = [1, 2];
titleLabel.Layout.Column = 1;
nonemptyTips = string(tooltipTexts);
nonemptyTips = nonemptyTips(strlength(nonemptyTips) > 0);
applyTooltip({panel, titleLabel}, strjoin(nonemptyTips, newline));

fields = gobjects(1, count);
for i = 1:count
    fieldColumn = 1 + i;

    label = uilabel(grid, 'Text', labelTexts{i}, 'HorizontalAlignment', 'center', 'WordWrap', 'on');
    label.Layout.Row = 1;
    label.Layout.Column = fieldColumn;

    field = uieditfield(grid, 'numeric', 'Value', defaultValues(i));
    field.Layout.Row = 2;
    field.Layout.Column = fieldColumn;
    applyTooltip({label, field}, tooltipTexts{i});
    fields(i) = field;
end
end

function applyTooltip(components, tooltipText)
if nargin < 2 || isempty(tooltipText)
    return;
end

tooltipText = string(tooltipText);
if all(strlength(tooltipText) == 0)
    return;
end

tooltipText = char(strjoin(tooltipText, newline));
if ~iscell(components)
    components = {components};
end

for i = 1:numel(components)
    component = components{i};
    if ~isempty(component) && isvalid(component) && isprop(component, 'Tooltip')
        component.Tooltip = tooltipText;
    end
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

function position = compactFigurePosition()
screen = get(groot, 'ScreenSize');
screenLeft = screen(1);
screenBottom = screen(2);
screenWidth = screen(3);
screenHeight = screen(4);

figureWidth = min(1440, screenWidth - 60);
figureHeight = min(860, screenHeight - 90);
figureWidth = max(1180, figureWidth);
figureHeight = max(700, figureHeight);

if figureWidth > screenWidth - 20
    figureWidth = max(760, screenWidth - 20);
end
if figureHeight > screenHeight - 40
    figureHeight = max(560, screenHeight - 40);
end

figureLeft = screenLeft + max(10, round((screenWidth - figureWidth) / 2));
figureBottom = screenBottom + max(30, round((screenHeight - figureHeight) / 2));
position = round([figureLeft, figureBottom, figureWidth, figureHeight]);
end

function applyCompactFonts(fig)
items = findall(fig);
for i = 1:numel(items)
    if isprop(items(i), 'FontSize')
        try
            items(i).FontSize = 11;
        catch
            % Some uifigure-backed objects report FontSize but do not allow assignment.
        end
    end
end
end

function name = exposureModeDisplayName(value)
switch string(value)
    case "Point dwell"
        name = 'Point dwell';
    case "Axis scan"
        name = 'Axis scan';
    otherwise
        name = char(value);
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
xValues = xValues(isfinite(xValues));
yValues = yValues(isfinite(yValues));
zValues = zValues(isfinite(zValues));
if isempty(xValues) || isempty(yValues) || isempty(zValues)
    return;
end

mins = [min(xValues), min(yValues), min(zValues)];
maxs = [max(xValues), max(yValues), max(zValues)];
center = (mins + maxs) / 2;
span = max(maxs - mins);

if ~isfinite(span) || span <= 0
    span = 0.001;
end

halfSpan = span * 0.62;
limits = [center(:) - halfSpan, center(:) + halfSpan];

axis(ax, 'normal');
ax.DataAspectRatioMode = 'auto';
ax.PlotBoxAspectRatioMode = 'auto';
xlim(ax, limits(1, :));
ylim(ax, limits(2, :));
zlim(ax, limits(3, :));
pbaspect(ax, [1, 1, 1]);
daspect(ax, [1, 1, 1]);
xlim(ax, limits(1, :));
ylim(ax, limits(2, :));
zlim(ax, limits(3, :));
ax.CameraViewAngleMode = 'auto';
view(ax, 30, 25);
applyPreviewAxisOrientation(ax);
end

function applyPreviewAxisOrientation(ax)
ax.XDir = 'normal';
ax.YDir = 'normal';
ax.ZDir = 'normal';
end
