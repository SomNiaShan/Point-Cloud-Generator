function [data, prefix, summary] = generate_point_cloud(params)
%GENERATE_POINT_CLOUD Generate generic XYZP point clouds for Imported Points.

if ~isstruct(params)
    error('Input params must be a struct.');
end

lattice = localRequireStruct(params, 'lattice');

latticeTypeStr = localNormalizeOption(localRequireField(lattice, 'type'));
if latticeTypeStr == "staircase"
    [data, prefix, summary] = localGenerateStaircaseFull(lattice);
    return;
end
if latticeTypeStr == "segmented_grating"
    power = localRequireStruct(params, 'power');
    [data, prefix, summary] = localGenerateSegmentedGratingFull(lattice, power);
    return;
end
if latticeTypeStr == "z_push"
    power = localRequireStruct(params, 'power');
    [data, prefix, summary] = localGenerateZPushFull(lattice, power);
    return;
end
if latticeTypeStr == "hexagon_cut"
    [data, prefix, summary] = localGenerateHexagonCutFull(lattice);
    return;
end
if latticeTypeStr == "hexagon_release_cut"
    [data, prefix, summary] = localGenerateHexagonReleaseCutFull(lattice);
    return;
end
if latticeTypeStr == "hexagon_release_cut_array"
    [data, prefix, summary] = localGenerateHexagonReleaseCutArrayFull(lattice);
    return;
end
if latticeTypeStr == "circle_release_cut"
    [data, prefix, summary] = localGenerateCircleReleaseCutFull(lattice);
    return;
end

region = localRequireStruct(params, 'region');
power = localRequireStruct(params, 'power');

if isfield(params, 'ordering') && isstruct(params.ordering)
    ordering = params.ordering;
else
    ordering = struct();
end

[xUm, yUm, zUm, layerIndex, rowIndex, latticeInfo] = localGenerateLatticeUm(lattice);
sourcePointCount = numel(xUm);

mask = localBuildRegionMask(region, xUm, yUm, zUm);
xUm = xUm(mask);
yUm = yUm(mask);
zUm = zUm(mask);
layerIndex = layerIndex(mask);
rowIndex = rowIndex(mask);

if isempty(xUm)
    error('The selected lattice and region settings produced zero points.');
end

pathMode = localPathMode(ordering);
[xUm, yUm, zUm] = localApplyOrdering(xUm, yUm, zUm, layerIndex, rowIndex, pathMode);

powerMode = localPowerMode(power);
powerValues = localEvaluatePower(power, powerMode, xUm, yUm, zUm);

xMm = xUm / 1000;
yMm = yUm / 1000;
zMm = zUm / 1000;
data = [xMm, yMm, zMm, powerValues];

regionMode = localRegionMode(region);
primitiveType = localPrimitiveType(region);
prefix = localBuildPrefix(latticeInfo, regionMode, primitiveType, pathMode, powerMode, power);

summary = struct();
summary.pointCount = size(data, 1);
summary.sourcePointCount = sourcePointCount;
summary.xRangeMm = [min(xMm), max(xMm)];
summary.yRangeMm = [min(yMm), max(yMm)];
summary.zRangeMm = [min(zMm), max(zMm)];
summary.powerRange = [min(powerValues), max(powerValues)];
summary.latticeType = latticeInfo.type;
summary.latticeLabel = latticeInfo.label;
summary.pitchLabel = latticeInfo.pitchLabel;
summary.rowSpacingUm = latticeInfo.rowSpacingUm;
summary.regionMode = char(regionMode);
summary.regionLabel = localRegionLabel(regionMode, primitiveType);
summary.pathMode = char(pathMode);
summary.pathModeLabel = localPathModeLabel(pathMode);
summary.powerMode = char(powerMode);
summary.powerModeLabel = localPowerModeLabel(powerMode);
summary.layerTraversalLabel = 'Deep to shallow (ascending Z; smaller Z is deeper)';
summary.prefix = prefix;
end

function [data, prefix, summary] = localGenerateStaircaseFull(lattice)
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);
nDepths = localPositiveInteger(localRequireField(lattice, 'nDepths'), 'Depth Count');
zStartUm = localFiniteScalar(localRequireField(lattice, 'zStartUm'), 'Z Start');
zStepUm = localFiniteScalar(localRequireField(lattice, 'zStepUm'), 'Z Step');
if zStepUm == 0
    error('Z Step must be non-zero.');
end

nPowers = localPositiveInteger(localRequireField(lattice, 'nPowers'), 'Power Count');
powerStart = localFiniteScalar(localRequireField(lattice, 'powerStart'), 'Power start');
powerEnd = localFiniteScalar(localRequireField(lattice, 'powerEnd'), 'Power end');

patchNx = localPositiveInteger(localRequireField(lattice, 'patchNx'), 'Patch Nx');
patchNy = localPositiveInteger(localRequireField(lattice, 'patchNy'), 'Patch Ny');
pitchXUm = localPositiveScalar(localRequireField(lattice, 'patchPitchXUm'), 'Patch Pitch X');
pitchYUm = localPositiveScalar(localRequireField(lattice, 'patchPitchYUm'), 'Patch Pitch Y');
gapXUm = localNonnegativeScalar(localRequireField(lattice, 'gapXUm'), 'Gap X');
gapYUm = localNonnegativeScalar(localRequireField(lattice, 'gapYUm'), 'Gap Y');
originXUm = localFiniteScalar(localFieldOrDefault(lattice, 'originXUm', 0), 'Origin X');
originYUm = localFiniteScalar(localFieldOrDefault(lattice, 'originYUm', 0), 'Origin Y');

if nPowers == 1
    powerCols = powerStart;
else
    powerCols = linspace(powerStart, powerEnd, nPowers);
end

patchWidth = (patchNx - 1) * pitchXUm;
patchHeight = (patchNy - 1) * pitchYUm;
strideX = patchWidth + gapXUm;
strideY = patchHeight + gapYUm;

totalPoints = nDepths * nPowers * patchNx * patchNy;
xUm = zeros(totalPoints, 1);
yUm = zeros(totalPoints, 1);
zUm = zeros(totalPoints, 1);
pVals = zeros(totalPoints, 1);

cursor = 1;
for iDepth = 1:nDepths
    zVal = zStartUm + (iDepth - 1) * zStepUm;
    yBase = originYUm + (iDepth - 1) * strideY;

    for iPower = 1:nPowers
        xBase = originXUm + (iPower - 1) * strideX;
        pVal = powerCols(iPower);

        for iRow = 1:patchNy
            yVal = yBase + (iRow - 1) * pitchYUm;
            xVals = xBase + (0:patchNx - 1) * pitchXUm;

            idx = cursor:(cursor + patchNx - 1);
            xUm(idx) = xVals(:);
            yUm(idx) = yVal;
            zUm(idx) = zVal;
            pVals(idx) = pVal;
            cursor = cursor + patchNx;
        end
    end
end

xMm = xUm / 1000;
yMm = yUm / 1000;
zMm = zUm / 1000;
data = [xMm, yMm, zMm, pVals];
data = localSortRowsByZAscending(data);

prefix = localBuildStaircasePrefix( ...
    nDepths, nPowers, zStartUm, zStepUm, powerStart, powerEnd, ...
    patchNx, patchNy, pitchXUm, pitchYUm, gapXUm, gapYUm, originXUm, originYUm, displayUnit);

summary = struct();
summary.pointCount = totalPoints;
summary.sourcePointCount = totalPoints;
summary.xRangeMm = [min(xMm), max(xMm)];
summary.yRangeMm = [min(yMm), max(yMm)];
summary.zRangeMm = [min(zMm), max(zMm)];
summary.powerRange = [min(pVals), max(pVals)];
summary.latticeType = 'staircase';
summary.latticeLabel = 'Staircase';
summary.pitchLabel = sprintf('Patch %dx%d, pitch X/Y: %s/%s %s, gap X/Y: %s/%s %s', ...
    patchNx, patchNy, ...
    localCompactDistance(pitchXUm, displayUnit), localCompactDistance(pitchYUm, displayUnit), unitText, ...
    localCompactDistance(gapXUm, displayUnit), localCompactDistance(gapYUm, displayUnit), unitText);
summary.rowSpacingUm = strideY;
summary.regionMode = 'full_block';
summary.regionLabel = 'Full Block';
summary.pathMode = 'row_major';
summary.pathModeLabel = 'Row-major (fixed)';
summary.powerMode = 'staircase_columns';
summary.powerModeLabel = localStaircasePowerModeLabel(nPowers, powerStart, powerEnd);
summary.layerTraversalLabel = localStaircaseTraversalLabel(zStepUm);
summary.prefix = prefix;
end

function [data, prefix, summary] = localGenerateSegmentedGratingFull(lattice, power)
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);
nDepths = localPositiveInteger(localRequireField(lattice, 'nDepths'), 'Depth Count');
depthStartUm = localFiniteScalar(localRequireField(lattice, 'depthStartUm'), 'Depth start');
depthStepUm = localFiniteScalar(localRequireField(lattice, 'depthStepUm'), 'Depth step');
if depthStepUm == 0
    error('Depth step must be non-zero.');
end

period1Um = localPositiveScalar(localRequireField(lattice, 'period1Um'), 'Segment 1 period');
nPeriods1 = localPositiveInteger(localRequireField(lattice, 'nPeriods1'), 'Segment 1 period count');
period2Um = localPositiveScalar(localRequireField(lattice, 'period2Um'), 'Segment 2 period');
nPeriods2 = localPositiveInteger(localRequireField(lattice, 'nPeriods2'), 'Segment 2 period count');
segmentGapUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'segmentGapUm', period1Um), 'Segment Gap');
defaultSlabCopies = localFieldOrDefault(lattice, 'slabCopies', 1);
defaultSlabPitchUm = localFieldOrDefault(lattice, 'slabPitchUm', 0);
slabCopies1 = localPositiveInteger(localFieldOrDefault(lattice, 'slabCopies1', defaultSlabCopies), 'Segment 1 slab copies');
slabPitch1Um = localNonnegativeScalar(localFieldOrDefault(lattice, 'slabPitch1Um', defaultSlabPitchUm), 'Segment 1 slab pitch');
slabCopies2 = localPositiveInteger(localFieldOrDefault(lattice, 'slabCopies2', defaultSlabCopies), 'Segment 2 slab copies');
slabPitch2Um = localNonnegativeScalar(localFieldOrDefault(lattice, 'slabPitch2Um', defaultSlabPitchUm), 'Segment 2 slab pitch');
if slabCopies1 > 1 && slabPitch1Um <= 0
    error('When segment 1 slab copies is greater than 1, segment 1 slab pitch must be greater than 0.');
end
if slabCopies2 > 1 && slabPitch2Um <= 0
    error('When segment 2 slab copies is greater than 1, segment 2 slab pitch must be greater than 0.');
end

originUm = localVector3(localFieldOrDefault(lattice, 'originUm', [0, 0, 0]), 'Origin');
depthAxis = localAxisIndex(localFieldOrDefault(lattice, 'depthAxis', 'X'), 'Depth Axis');
periodAxis = localAxisIndex(localFieldOrDefault(lattice, 'periodAxis', 'Y'), 'Period Axis');
if depthAxis == periodAxis
    error('Depth axis and period axis cannot be the same.');
end

scanAxis = setdiff(1:3, [depthAxis, periodAxis]);
depthAxisName = localAxisName(depthAxis);
periodAxisName = localAxisName(periodAxis);
scanAxisName = localAxisName(scanAxis);

channelRows = localPositiveInteger(localFieldOrDefault(lattice, 'channelRows', 1), 'Channel rows');
channelCols = localPositiveInteger(localFieldOrDefault(lattice, 'channelCols', 1), 'Channel columns');
channelRowPitchUm = localFiniteScalar(localFieldOrDefault(lattice, 'channelRowPitchUm', 0), 'Channel row pitch');
channelColPitchUm = localFiniteScalar(localFieldOrDefault(lattice, 'channelColPitchUm', 0), 'Channel column pitch');
if channelRows > 1 && channelRowPitchUm == 0
    error('When channel rows is greater than 1, channel row pitch must be non-zero.');
end
if channelCols > 1 && channelColPitchUm == 0
    error('When channel columns is greater than 1, channel column pitch must be non-zero.');
end

rowAxis = depthAxis;
colAxis = scanAxis;
rowAxisName = localAxisName(rowAxis);
colAxisName = localAxisName(colAxis);
channelCount = channelRows * channelCols;
[channelSegmentOneStartUm, channelSegmentTwoStartUm, ...
    channelSegmentOneEnabled, channelSegmentTwoEnabled, customChannelStartCount] = ...
    localSegmentedGratingChannelStarts(lattice, channelRows, channelCols, period1Um, nPeriods1, segmentGapUm);
channelRowOrder = localSegmentedGratingChannelRowOrder(channelRows, originUm, rowAxis, channelRowPitchUm, depthAxis);

segmentPeriods = [repmat(period1Um, nPeriods1, 1); repmat(period2Um, nPeriods2, 1)];
segmentIndex = [ones(nPeriods1, 1); 2 * ones(nPeriods2, 1)];
segmentOnePeriodOffsets = (0:nPeriods1 - 1).' * period1Um;
segmentTwoPeriodOffsets = (0:nPeriods2 - 1).' * period2Um;
depthOffsets = depthStartUm + (0:nDepths - 1) * depthStepUm;
depthOffsets = localSegmentedGratingDepthOffsets(depthOffsets, depthAxis);

channelOperationCounts = double(channelSegmentOneEnabled) * nPeriods1 * slabCopies1 + ...
    double(channelSegmentTwoEnabled) * nPeriods2 * slabCopies2;
totalOperations = nDepths * sum(channelOperationCounts(:));
if totalOperations == 0
    error('The channel start table did not enable any grating segments.');
end
xUm = zeros(totalOperations, 1);
yUm = zeros(totalOperations, 1);
zUm = zeros(totalOperations, 1);

cursor = 1;
for iDepth = 1:nDepths
    depthOffset = depthOffsets(iDepth);

    for iChannelRow = channelRowOrder
        for iChannelCol = 1:channelCols
            channelOriginUm = originUm;
            channelOriginUm(rowAxis) = channelOriginUm(rowAxis) + (iChannelRow - 1) * channelRowPitchUm;
            channelOriginUm(colAxis) = channelOriginUm(colAxis) + (iChannelCol - 1) * channelColPitchUm;

            if channelSegmentOneEnabled(iChannelRow, iChannelCol)
                segmentOneStarts = channelSegmentOneStartUm(iChannelRow, iChannelCol) + segmentOnePeriodOffsets;
                for iPeriod = 1:numel(segmentOneStarts)
                    for iCopy = 1:slabCopies1
                        pointUm = channelOriginUm;
                        pointUm(depthAxis) = channelOriginUm(depthAxis) + depthOffset;
                        pointUm(periodAxis) = channelOriginUm(periodAxis) + segmentOneStarts(iPeriod) + (iCopy - 1) * slabPitch1Um;

                        xUm(cursor) = pointUm(1);
                        yUm(cursor) = pointUm(2);
                        zUm(cursor) = pointUm(3);
                        cursor = cursor + 1;
                    end
                end
            end

            if channelSegmentTwoEnabled(iChannelRow, iChannelCol)
                segmentTwoStarts = channelSegmentTwoStartUm(iChannelRow, iChannelCol) + segmentTwoPeriodOffsets;
                for iPeriod = 1:numel(segmentTwoStarts)
                    for iCopy = 1:slabCopies2
                        pointUm = channelOriginUm;
                        pointUm(depthAxis) = channelOriginUm(depthAxis) + depthOffset;
                        pointUm(periodAxis) = channelOriginUm(periodAxis) + segmentTwoStarts(iPeriod) + (iCopy - 1) * slabPitch2Um;

                        xUm(cursor) = pointUm(1);
                        yUm(cursor) = pointUm(2);
                        zUm(cursor) = pointUm(3);
                        cursor = cursor + 1;
                    end
                end
            end
        end
    end
end

powerMode = localPowerMode(power);
powerValues = localEvaluatePower(power, powerMode, xUm, yUm, zUm);

xMm = xUm / 1000;
yMm = yUm / 1000;
zMm = zUm / 1000;
data = [xMm, yMm, zMm, powerValues];

prefix = localBuildSegmentedGratingPrefix( ...
    depthAxisName, periodAxisName, scanAxisName, nDepths, depthStartUm, depthStepUm, ...
    period1Um, nPeriods1, period2Um, nPeriods2, segmentGapUm, ...
    slabCopies1, slabPitch1Um, slabCopies2, slabPitch2Um, ...
    channelRows, channelCols, channelRowPitchUm, channelColPitchUm, originUm, powerMode, power, displayUnit);

summary = struct();
summary.pointCount = totalOperations;
summary.sourcePointCount = totalOperations;
summary.xRangeMm = [min(xMm), max(xMm)];
summary.yRangeMm = [min(yMm), max(yMm)];
summary.zRangeMm = [min(zMm), max(zMm)];
summary.powerRange = [min(powerValues), max(powerValues)];
summary.latticeType = 'segmented_grating';
summary.latticeLabel = 'Segmented Grating';
summary.pitchLabel = sprintf(['depth axis %s, period axis %s, scan axis %s; channels %dx%d (row axis %s/%s %s, column axis %s/%s %s); ', ...
    'segment 1: %d periods x %s %s, slab %d lines/%s %s; segment gap %s %s; ', ...
    'segment 2: %d periods x %s %s, slab %d lines/%s %s'], ...
    depthAxisName, periodAxisName, scanAxisName, ...
    channelRows, channelCols, rowAxisName, localCompactDistance(channelRowPitchUm, displayUnit), unitText, ...
    colAxisName, localCompactDistance(channelColPitchUm, displayUnit), unitText, ...
    nPeriods1, localCompactDistance(period1Um, displayUnit), unitText, ...
    slabCopies1, localCompactDistance(slabPitch1Um, displayUnit), unitText, ...
    localCompactDistance(segmentGapUm, displayUnit), unitText, ...
    nPeriods2, localCompactDistance(period2Um, displayUnit), unitText, ...
    slabCopies2, localCompactDistance(slabPitch2Um, displayUnit), unitText);
summary.rowSpacingUm = min(segmentPeriods);
summary.regionMode = 'segmented_grating';
summary.regionLabel = sprintf('%dx%d two-segment channel matrix', channelRows, channelCols);
summary.pathMode = 'depth_layered';
summary.pathModeLabel = sprintf('depth-layered; channels row-by-row and column-by-column; segment 1 before segment 2 within each channel (%s scan)', scanAxisName);
summary.powerMode = char(powerMode);
summary.powerModeLabel = localPowerModeLabel(powerMode);
summary.layerTraversalLabel = localSegmentedGratingTraversalLabel(depthStepUm, depthAxisName);
summary.prefix = prefix;
summary.depthAxis = depthAxisName;
summary.periodAxis = periodAxisName;
summary.scanAxis = scanAxisName;
summary.channelRows = channelRows;
summary.channelCols = channelCols;
summary.channelCount = channelCount;
summary.channelRowAxis = rowAxisName;
summary.channelColAxis = colAxisName;
summary.customChannelStartCount = customChannelStartCount;
summary.segmentIndex = segmentIndex;
end

function depthOffsets = localSegmentedGratingDepthOffsets(depthOffsets, depthAxis)
depthOffsets = reshape(depthOffsets, 1, []);
if depthAxis == 3
    depthOffsets = sort(depthOffsets, 'ascend');
end
end

function channelRowOrder = localSegmentedGratingChannelRowOrder(channelRows, originUm, rowAxis, channelRowPitchUm, depthAxis)
channelRowOrder = 1:channelRows;
if depthAxis ~= 3 || rowAxis ~= 3 || channelRows < 2
    return;
end

rowDepthUm = originUm(rowAxis) + (channelRowOrder - 1) * channelRowPitchUm;
[~, order] = sort(rowDepthUm, 'ascend');
channelRowOrder = channelRowOrder(order);
end

function [segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, customCount] = ...
    localSegmentedGratingChannelStarts(lattice, channelRows, channelCols, period1Um, nPeriods1, segmentGapUm)
defaultSegmentOneStartUm = localFiniteScalar(localFieldOrDefault(lattice, 'segment1StartUm', 0), 'Segment 1 start');
if isfield(lattice, 'segment2StartUm') && ~isempty(lattice.segment2StartUm)
    defaultSegmentTwoStartUm = localFiniteScalar(lattice.segment2StartUm, 'Segment 2 start');
else
    defaultSegmentTwoStartUm = defaultSegmentOneStartUm + (nPeriods1 - 1) * period1Um + segmentGapUm;
end

explicitStarts = logical(localFieldOrDefault(lattice, 'channelStartsExplicit', false));
if explicitStarts
    segmentOneStartUm = nan(channelRows, channelCols);
    segmentTwoStartUm = nan(channelRows, channelCols);
    segmentOneEnabled = false(channelRows, channelCols);
    segmentTwoEnabled = false(channelRows, channelCols);
else
    segmentOneStartUm = repmat(defaultSegmentOneStartUm, channelRows, channelCols);
    segmentTwoStartUm = repmat(defaultSegmentTwoStartUm, channelRows, channelCols);
    segmentOneEnabled = true(channelRows, channelCols);
    segmentTwoEnabled = true(channelRows, channelCols);
end
customCount = 0;

if isfield(lattice, 'channelStartsUm') && ~isempty(lattice.channelStartsUm)
    rows = localSegmentedGratingChannelStartRows(lattice.channelStartsUm, 'channelStartsUm', explicitStarts);
    [segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, customCount] = ...
        localApplySegmentedGratingChannelStartRows( ...
        segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, ...
        rows, channelRows, channelCols, period1Um, nPeriods1, segmentGapUm, ...
        customCount, 'channelStartsUm', explicitStarts);
end

if isfield(lattice, 'channelStartsText') && any(strlength(strtrim(string(lattice.channelStartsText))) > 0)
    rows = localParseSegmentedGratingChannelStartsText(lattice.channelStartsText);
    [segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, customCount] = ...
        localApplySegmentedGratingChannelStartRows( ...
        segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, ...
        rows, channelRows, channelCols, period1Um, nPeriods1, segmentGapUm, ...
        customCount, 'Channel starts', false);
end
end

function rows = localSegmentedGratingChannelStartRows(value, sourceName, allowBlankSegments)
if nargin < 3
    allowBlankSegments = false;
end

if isempty(value)
    rows = zeros(0, 4);
    return;
end

if ~(isnumeric(value) && ismatrix(value) && size(value, 2) >= 3 && size(value, 2) <= 4)
    error('%s must be an Nx3 or Nx4 numeric matrix: row, col, segment1Start[, segment2Start].', sourceName);
end

rows = double(value);
if size(rows, 2) == 3
    rows(:, 4) = nan;
end

if any(any(~isfinite(rows(:, 1:2))))
    error('%s row and col values must be finite numbers.', sourceName);
end
if allowBlankSegments
    invalidStarts = ~isfinite(rows(:, 3:4)) & ~isnan(rows(:, 3:4));
    if any(invalidStarts(:))
        error('%s segment starts must be finite numbers, or NaN to leave blank.', sourceName);
    end
else
    if any(~isfinite(rows(:, 3)))
        error('%s segment 1 start must be a finite number.', sourceName);
    end
    if any(~isfinite(rows(:, 4)) & ~isnan(rows(:, 4)))
        error('%s segment 2 start must be a finite number, or NaN for automatic inference.', sourceName);
    end
end
end

function rows = localParseSegmentedGratingChannelStartsText(textValue)
rows = zeros(0, 4);
lines = string(textValue);
if isempty(lines)
    return;
end
if isscalar(lines)
    lines = splitlines(lines);
else
    lines = lines(:);
end

for iLine = 1:numel(lines)
    lineText = strtrim(lines(iLine));
    if strlength(lineText) == 0 || startsWith(lineText, "#") || startsWith(lineText, "%")
        continue;
    end

    lineChar = regexprep(char(lineText), '[#%].*$', '');
    tokens = regexp(lineChar, '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
    values = str2double(tokens);
    if numel(values) < 3 || numel(values) > 4 || any(isnan(values))
        error('Channel starts row %d must contain 3 or 4 numeric values: row,col,segment1Start[,segment2Start].', iLine);
    end
    if numel(values) == 3
        values(4) = nan;
    end

    rows(end + 1, :) = values(1:4); %#ok<AGROW>
end
end

function [segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, customCount] = ...
    localApplySegmentedGratingChannelStartRows( ...
    segmentOneStartUm, segmentTwoStartUm, segmentOneEnabled, segmentTwoEnabled, ...
    rows, channelRows, channelCols, period1Um, nPeriods1, segmentGapUm, ...
    customCount, sourceName, explicitStarts)
if isempty(rows)
    return;
end

for iRow = 1:size(rows, 1)
    channelRow = localPositiveInteger(rows(iRow, 1), sprintf('%s row %d row', sourceName, iRow));
    channelCol = localPositiveInteger(rows(iRow, 2), sprintf('%s row %d col', sourceName, iRow));
    if channelRow > channelRows || channelCol > channelCols
        error('%s row %d specifies a nonexistent channel (%d,%d); current matrix is %dx%d.', ...
            sourceName, iRow, channelRow, channelCol, channelRows, channelCols);
    end

    if explicitStarts
        segmentOneEnabled(channelRow, channelCol) = isfinite(rows(iRow, 3));
        segmentTwoEnabled(channelRow, channelCol) = isfinite(rows(iRow, 4));
        segmentOneStartUm(channelRow, channelCol) = rows(iRow, 3);
        segmentTwoStartUm(channelRow, channelCol) = rows(iRow, 4);
    else
        segmentOneStart = localFiniteScalar(rows(iRow, 3), sprintf('%s row %d segment 1 start', sourceName, iRow));
        segmentOneStartUm(channelRow, channelCol) = segmentOneStart;
        segmentOneEnabled(channelRow, channelCol) = true;
        segmentTwoEnabled(channelRow, channelCol) = true;
        if isfinite(rows(iRow, 4))
            segmentTwoStartUm(channelRow, channelCol) = localFiniteScalar( ...
                rows(iRow, 4), sprintf('%s row %d segment 2 start', sourceName, iRow));
        else
            segmentTwoStartUm(channelRow, channelCol) = segmentOneStart + (nPeriods1 - 1) * period1Um + segmentGapUm;
        end
    end
    customCount = customCount + 1;
end
end

function [data, prefix, summary] = localGenerateZPushFull(lattice, power)
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);
originUm = localVector3(localRequireField(lattice, 'originUm'), 'Initial position');
moveXYUm = localVector2(localFieldOrDefault(lattice, 'moveXYUm', [0, 0]), 'XY move');
pushCount = localPositiveInteger(localRequireField(lattice, 'pushCount'), 'Push count');
pushStepUm = localPositiveScalar(localRequireField(lattice, 'pushStepUm'), 'Push step');
intervalSeconds = localNonnegativeScalar(localFieldOrDefault(lattice, 'intervalSeconds', 0), 'Push interval');

xUm = repmat(originUm(1) + moveXYUm(1), pushCount, 1);
yUm = repmat(originUm(2) + moveXYUm(2), pushCount, 1);
zUm = originUm(3) - (1:pushCount).' * pushStepUm;

powerMode = localPowerMode(power);
powerValues = localEvaluatePower(power, powerMode, xUm, yUm, zUm);
pauseSeconds = repmat(intervalSeconds, pushCount, 1);

xMm = xUm / 1000;
yMm = yUm / 1000;
zMm = zUm / 1000;
data = [xMm, yMm, zMm, powerValues, pauseSeconds];

finalDepthUm = pushCount * pushStepUm;
prefix = localBuildZPushPrefix(originUm, moveXYUm, pushCount, pushStepUm, intervalSeconds, powerMode, power, displayUnit);

summary = struct();
summary.pointCount = pushCount;
summary.sourcePointCount = pushCount;
summary.xRangeMm = [min(xMm), max(xMm)];
summary.yRangeMm = [min(yMm), max(yMm)];
summary.zRangeMm = [min(zMm), max(zMm)];
summary.powerRange = [min(powerValues), max(powerValues)];
summary.latticeType = 'z_push';
summary.latticeLabel = 'Z Push';
summary.pitchLabel = sprintf('XY target: X0 + %s %s, Y0 + %s %s; Z step -%s %s, final -%s %s; interval %s s', ...
    localCompactDistance(moveXYUm(1), displayUnit), unitText, localCompactDistance(moveXYUm(2), displayUnit), unitText, ...
    localCompactDistance(pushStepUm, displayUnit), unitText, localCompactDistance(finalDepthUm, displayUnit), unitText, ...
    localCompactNumber(intervalSeconds));
summary.rowSpacingUm = pushStepUm;
summary.regionMode = 'z_push';
summary.regionLabel = 'Single-point push';
summary.pathMode = 'z_push';
summary.pathModeLabel = 'fixed XY, step toward -Z (deeper)';
summary.powerMode = char(powerMode);
summary.powerModeLabel = localPowerModeLabel(powerMode);
summary.layerTraversalLabel = sprintf('from Z0 - %s %s to Z0 - %s %s (%d pushes deeper)', ...
    localCompactDistance(pushStepUm, displayUnit), unitText, localCompactDistance(finalDepthUm, displayUnit), unitText, pushCount);
summary.prefix = prefix;
end

function [data, prefix, summary] = localGenerateHexagonCutFull(lattice)
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);
centerUm = localVector3(localRequireField(lattice, 'centerUm'), 'Cut center');
sideLengthUm = localPositiveScalar(localRequireField(lattice, 'sideLengthUm'), 'Hexagon side length');
rotationDeg = localFiniteScalar(localFieldOrDefault(lattice, 'rotationDeg', 0), 'Hexagon rotation');
direction = localNormalizeOption(localFieldOrDefault(lattice, 'direction', 'counter_clockwise'));
if ~any(direction == ["counter_clockwise", "clockwise"])
    error('Hexagon cut direction must be Counter-clockwise or Clockwise.');
end

powerPercent = localNonnegativeScalar(localRequireField(lattice, 'powerPercent'), 'Cut power');
cutSpeedMmPerSecond = localPositiveScalar(localRequireField(lattice, 'cutSpeedMmPerSecond'), 'Cut speed');
accelerationMmPerSecondSquared = localPositiveScalar( ...
    localRequireField(lattice, 'accelerationMmPerSecondSquared'), 'Acceleration');
leadSafetyFactor = localPositiveScalar(localFieldOrDefault(lattice, 'leadSafetyFactor', 1.5), 'Lead safety factor');
exitSafetyFactor = localNonnegativeScalar(localFieldOrDefault(lattice, 'exitSafetyFactor', 1), 'Exit safety factor');

[leadInUm, leadOutUm] = localCutLeadDistances( ...
    cutSpeedMmPerSecond, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor);

[cutStartUm, cutEndUm] = localHexagonEdgeSegments(centerUm, sideLengthUm, rotationDeg, direction);
data = localBuildCutScanData(cutStartUm, cutEndUm, powerPercent, ...
    cutSpeedMmPerSecond, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor, 0);

allX = [data(:, 8); data(:, 1); data(:, 5); data(:, 11)];
allY = [data(:, 9); data(:, 2); data(:, 6); data(:, 12)];
allZ = [data(:, 10); data(:, 3); data(:, 7); data(:, 13)];

prefix = sprintf('hexcut_side_%s_rot_%s_speed_%s_P_%s_leadin_%s', ...
    localCompactDistance(sideLengthUm, displayUnit), localCompactNumber(rotationDeg), ...
    localCompactNumber(cutSpeedMmPerSecond), localCompactNumber(powerPercent), ...
    localCompactDistance(leadInUm, displayUnit));

summary = struct();
summary.pointCount = 6;
summary.sourcePointCount = 6;
summary.xRangeMm = [min(allX), max(allX)];
summary.yRangeMm = [min(allY), max(allY)];
summary.zRangeMm = [min(allZ), max(allZ)];
summary.powerRange = [powerPercent, powerPercent];
summary.latticeType = 'hexagon_cut';
summary.latticeLabel = 'Hexagon Cut';
summary.pitchLabel = sprintf(['side %s %s, rotation %s deg, %s; cut speed %s mm/s; ', ...
    'lead-in %s %s, lead-out %s %s from acceleration %s mm/s^2'], ...
    localCompactDistance(sideLengthUm, displayUnit), unitText, localCompactNumber(rotationDeg), ...
    localHexagonCutDirectionLabel(direction), localCompactNumber(cutSpeedMmPerSecond), ...
    localCompactDistance(leadInUm, displayUnit), unitText, localCompactDistance(leadOutUm, displayUnit), unitText, ...
    localCompactNumber(accelerationMmPerSecondSquared));
summary.rowSpacingUm = sideLengthUm;
summary.regionMode = 'hexagon_cut';
summary.regionLabel = 'Six exposed edges with laser-off lead-in and lead-out';
summary.pathMode = 'hexagon_cut';
summary.pathModeLabel = 'edge-by-edge, laser off for lead-in/out and on for each edge';
summary.powerMode = 'fixed_value';
summary.powerModeLabel = sprintf('Fixed Value (%s)', localCompactNumber(powerPercent));
summary.layerTraversalLabel = sprintf('Six %s edges in the XY plane at Z = %s %s', ...
    localHexagonCutDirectionLabel(direction), localCompactDistance(centerUm(3), displayUnit), unitText);
summary.prefix = prefix;
summary.cutSpeedMmPerSecond = cutSpeedMmPerSecond;
summary.accelerationMmPerSecondSquared = accelerationMmPerSecondSquared;
summary.leadInUm = leadInUm;
summary.leadOutUm = leadOutUm;
end

function [data, prefix, summary] = localGenerateHexagonReleaseCutFull(lattice)
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);
centerUm = localVector3(localRequireField(lattice, 'centerUm'), 'Cut center');
sideLengthUm = localPositiveScalar(localRequireField(lattice, 'sideLengthUm'), 'Hexagon side length');
rotationDeg = localFiniteScalar(localFieldOrDefault(lattice, 'rotationDeg', 0), 'Hexagon rotation');
direction = localNormalizeOption(localFieldOrDefault(lattice, 'direction', 'counter_clockwise'));
if ~any(direction == ["counter_clockwise", "clockwise"])
    error('Hexagon release cut direction must be Counter-clockwise or Clockwise.');
end

powerPercent = localNonnegativeScalar(localRequireField(lattice, 'powerPercent'), 'Cut power');
cutSpeedMmPerSecond = localPositiveScalar(localRequireField(lattice, 'cutSpeedMmPerSecond'), 'Cut speed');
accelerationMmPerSecondSquared = localPositiveScalar( ...
    localRequireField(lattice, 'accelerationMmPerSecondSquared'), 'Acceleration');
leadSafetyFactor = localPositiveScalar(localFieldOrDefault(lattice, 'leadSafetyFactor', 1.5), 'Lead safety factor');
exitSafetyFactor = localNonnegativeScalar(localFieldOrDefault(lattice, 'exitSafetyFactor', 1), 'Exit safety factor');
ringPowerPercent = localNonnegativeScalar( ...
    localFieldOrDefault(lattice, 'releaseRingPowerPercent', powerPercent), 'Release ring power');
ringSpeedMmPerSecond = localPositiveScalar( ...
    localFieldOrDefault(lattice, 'releaseRingSpeedMmPerSecond', cutSpeedMmPerSecond), 'Release ring speed');
hatchPowerPercent = localNonnegativeScalar( ...
    localFieldOrDefault(lattice, 'releaseHatchPowerPercent', ringPowerPercent), 'Release hatch power');
hatchSpeedMmPerSecond = localPositiveScalar( ...
    localFieldOrDefault(lattice, 'releaseHatchSpeedMmPerSecond', ringSpeedMmPerSecond), 'Release hatch speed');

wallMarginUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'releaseWallMarginUm', 15), 'Release wall margin');
ringCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseRingCount', 3), 'Release ring count');
ringPitchUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'releaseRingPitchUm', 10), 'Release ring pitch');
hatchPitchUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'releaseHatchPitchUm', 80), 'Release hatch pitch');
layerCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseLayerCount', 1), 'Release layer count');
zStepUm = localFiniteScalar(localFieldOrDefault(lattice, 'releaseZStepUm', 0), 'Release Z step');
repeatCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseRepeatCount', 1), 'Release repeat count');
releaseOrder = localNormalizeOption(localFieldOrDefault(lattice, 'releaseOrder', 'inside_out'));
if ~any(releaseOrder == ["inside_out", "outside_in"])
    error('Release order must be Inside-out or Outside-in.');
end

apothemUm = sideLengthUm * cosd(30);
if wallMarginUm >= apothemUm
    error('Release wall margin must be smaller than the hexagon apothem %s %s.', ...
        localCompactDistance(apothemUm, displayUnit), unitText);
end
if ringCount > 1 && ringPitchUm <= 0
    error('Release ring pitch must be greater than 0 when ring count is greater than 1.');
end

maxRingOffsetUm = (ringCount - 1) * ringPitchUm;
if maxRingOffsetUm >= apothemUm
    error('Release rings extend past the hexagon center. Reduce ring count or ring pitch.');
end
if layerCount > 1 && zStepUm == 0
    error('Release Z step must be non-zero when layer count is greater than 1.');
end

innerHatchSideUm = sideLengthUm - wallMarginUm / cosd(30);
if hatchPitchUm > 0 && innerHatchSideUm <= 0
    error('Release hatch region collapsed. Reduce the wall margin.');
end

allStartUm = zeros(0, 3);
allEndUm = zeros(0, 3);
allPowerValues = zeros(0, 1);
allSpeedValues = zeros(0, 1);
for iLayer = 1:layerCount
    layerCenterUm = centerUm;
    layerCenterUm(3) = centerUm(3) + (iLayer - 1) * zStepUm;

    if hatchPitchUm > 0
        [hatchStartUm, hatchEndUm] = localHexagonHatchSegments( ...
            layerCenterUm, innerHatchSideUm, rotationDeg, hatchPitchUm);
    else
        hatchStartUm = zeros(0, 3);
        hatchEndUm = zeros(0, 3);
    end

    if releaseOrder == "inside_out"
        [allStartUm, allEndUm, allPowerValues, allSpeedValues] = localAppendReleaseSegments( ...
            allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
            hatchStartUm, hatchEndUm, hatchPowerPercent, hatchSpeedMmPerSecond);
        ringOffsetsUm = ((ringCount - 1):-1:0) * ringPitchUm;
    else
        ringOffsetsUm = (0:(ringCount - 1)) * ringPitchUm;
    end

    for iRing = 1:numel(ringOffsetsUm)
        ringSideLengthUm = sideLengthUm - ringOffsetsUm(iRing) / cosd(30);
        if ringSideLengthUm <= 0
            error('Release ring %d collapsed. Reduce ring count or ring pitch.', iRing);
        end
        [ringStartUm, ringEndUm] = localHexagonEdgeSegments( ...
            layerCenterUm, ringSideLengthUm, rotationDeg, direction);
        if ringOffsetsUm(iRing) == 0
            segmentPowerPercent = powerPercent;
            segmentSpeedMmPerSecond = cutSpeedMmPerSecond;
        else
            segmentPowerPercent = ringPowerPercent;
            segmentSpeedMmPerSecond = ringSpeedMmPerSecond;
        end
        [allStartUm, allEndUm, allPowerValues, allSpeedValues] = localAppendReleaseSegments( ...
            allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
            ringStartUm, ringEndUm, segmentPowerPercent, segmentSpeedMmPerSecond);
    end

    if releaseOrder == "outside_in"
        [allStartUm, allEndUm, allPowerValues, allSpeedValues] = localAppendReleaseSegments( ...
            allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
            hatchStartUm, hatchEndUm, hatchPowerPercent, hatchSpeedMmPerSecond);
    end
end

if isempty(allStartUm)
    error('Hexagon release cut generated zero cut segments.');
end

data = localBuildCutScanData(allStartUm, allEndUm, allPowerValues, ...
    allSpeedValues, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor, 0);
data = localRepeatRows(data, repeatCount);
[leadInValuesUm, leadOutValuesUm] = localCutLeadDistances( ...
    allSpeedValues, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor);

allX = [data(:, 8); data(:, 1); data(:, 5); data(:, 11)];
allY = [data(:, 9); data(:, 2); data(:, 6); data(:, 12)];
allZ = [data(:, 10); data(:, 3); data(:, 7); data(:, 13)];

prefix = sprintf('hexrelease_%s_side_%s_rot_%s_layers_%d_dz_%s_rings_%d_rpitch_%s_margin_%s_hatch_%s_wallP_%s_wallS_%s_ringP_%s_ringS_%s_hatchP_%s_hatchS_%s', ...
    char(releaseOrder), ...
    localCompactDistance(sideLengthUm, displayUnit), localCompactNumber(rotationDeg), ...
    layerCount, localCompactDistance(zStepUm, displayUnit), ringCount, localCompactDistance(ringPitchUm, displayUnit), ...
    localCompactDistance(wallMarginUm, displayUnit), localCompactDistance(hatchPitchUm, displayUnit), ...
    localCompactNumber(powerPercent), localCompactNumber(cutSpeedMmPerSecond), ...
    localCompactNumber(ringPowerPercent), localCompactNumber(ringSpeedMmPerSecond), ...
    localCompactNumber(hatchPowerPercent), localCompactNumber(hatchSpeedMmPerSecond));
if repeatCount > 1
    prefix = sprintf('%s_rep_%d', prefix, repeatCount);
end

summary = struct();
summary.pointCount = size(data, 1);
summary.sourcePointCount = size(data, 1);
summary.xRangeMm = [min(allX), max(allX)];
summary.yRangeMm = [min(allY), max(allY)];
summary.zRangeMm = [min(allZ), max(allZ)];
summary.powerRange = [min(data(:, 4)), max(data(:, 4))];
summary.latticeType = 'hexagon_release_cut';
summary.latticeLabel = 'Hexagon Release Cut';
summary.pitchLabel = sprintf(['side %s %s, rotation %s deg, %s; %d Z layer(s), dz %s %s; ', ...
    '%d outline ring(s) at %s %s pitch; hatch pitch %s %s with %s %s wall margin; ', ...
    'wall P/speed %s/%s, ring P/speed %s/%s, hatch P/speed %s/%s'], ...
    localCompactDistance(sideLengthUm, displayUnit), unitText, localCompactNumber(rotationDeg), ...
    localHexagonCutDirectionLabel(direction), layerCount, localCompactDistance(zStepUm, displayUnit), unitText, ...
    ringCount, localCompactDistance(ringPitchUm, displayUnit), unitText, ...
    localCompactDistance(hatchPitchUm, displayUnit), unitText, ...
    localCompactDistance(wallMarginUm, displayUnit), unitText, ...
    localCompactNumber(powerPercent), localCompactNumber(cutSpeedMmPerSecond), ...
    localCompactNumber(ringPowerPercent), localCompactNumber(ringSpeedMmPerSecond), ...
    localCompactNumber(hatchPowerPercent), localCompactNumber(hatchSpeedMmPerSecond));
if repeatCount > 1
    summary.pitchLabel = sprintf('%s; repeated %d time(s)', summary.pitchLabel, repeatCount);
end
summary.rowSpacingUm = hatchPitchUm;
summary.regionMode = 'hexagon_release_cut';
summary.regionLabel = 'Interior hatch plus concentric outline release cuts';
summary.pathMode = 'hexagon_release_cut';
if releaseOrder == "outside_in"
    summary.pathModeLabel = 'per Z layer: final outer wall, then outer-to-inner release rings, then internal 3-direction hatch';
    orderSummary = 'final outer wall first on each layer';
else
    summary.pathModeLabel = 'per Z layer: internal 3-direction hatch, then inner-to-outer hexagon rings';
    orderSummary = 'final outer wall last on each layer';
end
summary.powerMode = 'fixed_value';
summary.powerModeLabel = sprintf('Wall/Ring/Hatch fixed values: %s / %s / %s', ...
    localCompactNumber(powerPercent), localCompactNumber(ringPowerPercent), localCompactNumber(hatchPowerPercent));
summary.layerTraversalLabel = sprintf('Z layers follow Z = %s %s + k * %s %s, %s', ...
    localCompactDistance(centerUm(3), displayUnit), unitText, ...
    localCompactDistance(zStepUm, displayUnit), unitText, orderSummary);
summary.prefix = prefix;
summary.releaseOrder = char(releaseOrder);
summary.cutSpeedMmPerSecond = cutSpeedMmPerSecond;
summary.releaseRingPowerPercent = ringPowerPercent;
summary.releaseRingSpeedMmPerSecond = ringSpeedMmPerSecond;
summary.releaseHatchPowerPercent = hatchPowerPercent;
summary.releaseHatchSpeedMmPerSecond = hatchSpeedMmPerSecond;
summary.accelerationMmPerSecondSquared = accelerationMmPerSecondSquared;
summary.leadInUm = [min(leadInValuesUm), max(leadInValuesUm)];
summary.leadOutUm = [min(leadOutValuesUm), max(leadOutValuesUm)];
summary.releaseWallMarginUm = wallMarginUm;
summary.releaseRingCount = ringCount;
summary.releaseRingPitchUm = ringPitchUm;
summary.releaseHatchPitchUm = hatchPitchUm;
summary.releaseLayerCount = layerCount;
summary.releaseZStepUm = zStepUm;
summary.releaseRepeatCount = repeatCount;
end

function [data, prefix, summary] = localGenerateHexagonReleaseCutArrayFull(lattice)
displayUnit = localDisplayDistanceUnit(lattice);
arrayCenterUm = localVector3(localRequireField(lattice, 'centerUm'), 'Array center');
sideLengthUm = localPositiveScalar(localRequireField(lattice, 'sideLengthUm'), 'Hexagon side length');
rotationDeg = localFiniteScalar(localFieldOrDefault(lattice, 'rotationDeg', 0), 'Hexagon rotation');
arrayRows = localPositiveInteger(localFieldOrDefault(lattice, 'arrayRows', 3), 'Honeycomb array rows');
arrayCols = localPositiveInteger(localFieldOrDefault(lattice, 'arrayCols', 3), 'Honeycomb array columns');
repeatCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseRepeatCount', 1), 'Release repeat count');
selectionMask = localLogicalMatrix( ...
    localRequireField(lattice, 'arraySelectionMask'), arrayRows, arrayCols, 'Honeycomb cut mask');

selectedCellCount = nnz(selectionMask);
totalCellCount = arrayRows * arrayCols;
if selectedCellCount == 0
    error('Select at least one honeycomb cell for Hexagon Release Cut Array.');
end

centersUm = localHoneycombArrayCenters(arrayCenterUm, sideLengthUm, rotationDeg, arrayRows, arrayCols);
dataParts = cell(selectedCellCount, 1);
selectedRows = zeros(selectedCellCount, 1);
selectedCols = zeros(selectedCellCount, 1);
partIndex = 0;
firstSummary = struct();

for iRow = 1:arrayRows
    for iCol = 1:arrayCols
        if ~selectionMask(iRow, iCol)
            continue;
        end

        partIndex = partIndex + 1;
        cellLattice = lattice;
        cellLattice.type = 'Hexagon Release Cut';
        cellLattice.centerUm = reshape(centersUm(iRow, iCol, :), 1, []);
        cellLattice.releaseRepeatCount = 1;
        [cellData, ~, cellSummary] = localGenerateHexagonReleaseCutFull(cellLattice);
        dataParts{partIndex} = cellData;
        selectedRows(partIndex) = iRow;
        selectedCols(partIndex) = iCol;
        if partIndex == 1
            firstSummary = cellSummary;
        end
    end
end

data = vertcat(dataParts{:});
data = localRepeatRows(data, repeatCount);
allX = [data(:, 8); data(:, 1); data(:, 5); data(:, 11)];
allY = [data(:, 9); data(:, 2); data(:, 6); data(:, 12)];
allZ = [data(:, 10); data(:, 3); data(:, 7); data(:, 13)];

cellTags = strings(selectedCellCount, 1);
for iCell = 1:selectedCellCount
    cellTags(iCell) = sprintf('R%dC%d', selectedRows(iCell), selectedCols(iCell));
end
selectedCellText = char(strjoin(cellTags, ', '));
selectedCellTag = localCompactCellTag(strjoin(cellTags, '-'));

prefix = sprintf('hexrelease_array_%dx%d_sel_%d_side_%s_rot_%s_%s', ...
    arrayRows, arrayCols, selectedCellCount, ...
    localCompactDistance(sideLengthUm, displayUnit), localCompactNumber(rotationDeg), ...
    selectedCellTag);
if repeatCount > 1
    prefix = sprintf('%s_rep_%d', prefix, repeatCount);
end

summary = firstSummary;
summary.pointCount = size(data, 1);
summary.sourcePointCount = size(data, 1);
summary.xRangeMm = [min(allX), max(allX)];
summary.yRangeMm = [min(allY), max(allY)];
summary.zRangeMm = [min(allZ), max(allZ)];
summary.powerRange = [min(data(:, 4)), max(data(:, 4))];
summary.latticeType = 'hexagon_release_cut_array';
summary.latticeLabel = 'Hexagon Release Cut Array';
summary.pitchLabel = sprintf('%dx%d honeycomb array, selected %d/%d cells (%s); %s', ...
    arrayRows, arrayCols, selectedCellCount, totalCellCount, ...
    selectedCellText, firstSummary.pitchLabel);
if repeatCount > 1
    summary.pitchLabel = sprintf('%s; repeated %d time(s)', summary.pitchLabel, repeatCount);
end
summary.rowSpacingUm = sqrt(3) * sideLengthUm;
summary.regionMode = 'hexagon_release_cut_array';
summary.regionLabel = 'Selected honeycomb cells using hexagon release cuts';
summary.pathMode = 'hexagon_release_cut_array';
summary.pathModeLabel = sprintf('row-major selected cells; within each cell: %s', firstSummary.pathModeLabel);
summary.layerTraversalLabel = sprintf('Selected honeycomb cells are written row-major; each cell uses %s', firstSummary.layerTraversalLabel);
summary.prefix = prefix;
summary.arrayRows = arrayRows;
summary.arrayCols = arrayCols;
summary.selectedCellCount = selectedCellCount;
summary.totalCellCount = totalCellCount;
summary.selectedCells = cellstr(cellTags);
summary.arrayCenterUm = arrayCenterUm;
summary.releaseRepeatCount = repeatCount;
end

function [data, prefix, summary] = localGenerateCircleReleaseCutFull(lattice)
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);
centerUm = localVector3(localRequireField(lattice, 'centerUm'), 'Circle center');
radiusUm = localPositiveScalar(localRequireField(lattice, 'radiusUm'), 'Circle radius');
startAngleDeg = localFiniteScalar(localFieldOrDefault(lattice, 'startAngleDeg', 0), 'Circle start angle');
segmentCount = localPositiveInteger(localFieldOrDefault(lattice, 'segmentCount', 128), 'Circle segments');
if segmentCount < 8
    error('Circle segments must be at least 8.');
end
direction = localNormalizeOption(localFieldOrDefault(lattice, 'direction', 'counter_clockwise'));
if ~any(direction == ["counter_clockwise", "clockwise"])
    error('Circle release cut direction must be Counter-clockwise or Clockwise.');
end

powerPercent = localNonnegativeScalar(localRequireField(lattice, 'powerPercent'), 'Cut power');
cutSpeedMmPerSecond = localPositiveScalar(localRequireField(lattice, 'cutSpeedMmPerSecond'), 'Cut speed');
accelerationMmPerSecondSquared = localPositiveScalar( ...
    localRequireField(lattice, 'accelerationMmPerSecondSquared'), 'Acceleration');
leadSafetyFactor = localPositiveScalar(localFieldOrDefault(lattice, 'leadSafetyFactor', 1.5), 'Lead safety factor');
exitSafetyFactor = localNonnegativeScalar(localFieldOrDefault(lattice, 'exitSafetyFactor', 1), 'Exit safety factor');
ringPowerPercent = localNonnegativeScalar( ...
    localFieldOrDefault(lattice, 'releaseRingPowerPercent', powerPercent), 'Release ring power');
ringSpeedMmPerSecond = localPositiveScalar( ...
    localFieldOrDefault(lattice, 'releaseRingSpeedMmPerSecond', cutSpeedMmPerSecond), 'Release ring speed');
hatchPowerPercent = localNonnegativeScalar( ...
    localFieldOrDefault(lattice, 'releaseHatchPowerPercent', ringPowerPercent), 'Release hatch power');
hatchSpeedMmPerSecond = localPositiveScalar( ...
    localFieldOrDefault(lattice, 'releaseHatchSpeedMmPerSecond', ringSpeedMmPerSecond), 'Release hatch speed');

wallMarginUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'releaseWallMarginUm', 15), 'Release wall margin');
ringCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseRingCount', 3), 'Release ring count');
ringPitchUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'releaseRingPitchUm', 10), 'Release ring pitch');
hatchPitchUm = localNonnegativeScalar(localFieldOrDefault(lattice, 'releaseHatchPitchUm', 80), 'Release hatch pitch');
layerCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseLayerCount', 1), 'Release layer count');
zStepUm = localFiniteScalar(localFieldOrDefault(lattice, 'releaseZStepUm', 0), 'Release Z step');
repeatCount = localPositiveInteger(localFieldOrDefault(lattice, 'releaseRepeatCount', 1), 'Release repeat count');
releaseOrder = localNormalizeOption(localFieldOrDefault(lattice, 'releaseOrder', 'inside_out'));
if ~any(releaseOrder == ["inside_out", "outside_in"])
    error('Release order must be Inside-out or Outside-in.');
end

if wallMarginUm >= radiusUm
    error('Release wall margin must be smaller than the circle radius %s %s.', ...
        localCompactDistance(radiusUm, displayUnit), unitText);
end
if ringCount > 1 && ringPitchUm <= 0
    error('Release ring pitch must be greater than 0 when ring count is greater than 1.');
end
maxRingOffsetUm = (ringCount - 1) * ringPitchUm;
if maxRingOffsetUm >= radiusUm
    error('Release rings extend past the circle center. Reduce ring count or ring pitch.');
end
if layerCount > 1 && zStepUm == 0
    error('Release Z step must be non-zero when layer count is greater than 1.');
end

hatchRadiusUm = radiusUm - wallMarginUm;
if hatchPitchUm > 0 && hatchRadiusUm <= 0
    error('Release hatch region collapsed. Reduce the wall margin.');
end

allStartUm = zeros(0, 3);
allEndUm = zeros(0, 3);
allPowerValues = zeros(0, 1);
allSpeedValues = zeros(0, 1);
allGroupIds = zeros(0, 1);
allGroupSegments = zeros(0, 1);
groupCounter = 0;

for iLayer = 1:layerCount
    layerCenterUm = centerUm;
    layerCenterUm(3) = centerUm(3) + (iLayer - 1) * zStepUm;

    if hatchPitchUm > 0
        [hatchStartUm, hatchEndUm] = localCircleHatchSegments( ...
            layerCenterUm, hatchRadiusUm, startAngleDeg, hatchPitchUm);
    else
        hatchStartUm = zeros(0, 3);
        hatchEndUm = zeros(0, 3);
    end

    if releaseOrder == "inside_out"
        [allStartUm, allEndUm, allPowerValues, allSpeedValues, allGroupIds, allGroupSegments, groupCounter] = ...
            localAppendGroupedReleaseSegments(allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
            allGroupIds, allGroupSegments, groupCounter, hatchStartUm, hatchEndUm, ...
            hatchPowerPercent, hatchSpeedMmPerSecond, false);
        ringOffsetsUm = ((ringCount - 1):-1:0) * ringPitchUm;
    else
        ringOffsetsUm = (0:(ringCount - 1)) * ringPitchUm;
    end

    for iRing = 1:numel(ringOffsetsUm)
        ringRadiusUm = radiusUm - ringOffsetsUm(iRing);
        if ringRadiusUm <= 0
            error('Release ring %d collapsed. Reduce ring count or ring pitch.', iRing);
        end
        [ringStartUm, ringEndUm] = localCircleEdgeSegments( ...
            layerCenterUm, ringRadiusUm, startAngleDeg, segmentCount, direction);
        if ringOffsetsUm(iRing) == 0
            segmentPowerPercent = powerPercent;
            segmentSpeedMmPerSecond = cutSpeedMmPerSecond;
        else
            segmentPowerPercent = ringPowerPercent;
            segmentSpeedMmPerSecond = ringSpeedMmPerSecond;
        end
        [allStartUm, allEndUm, allPowerValues, allSpeedValues, allGroupIds, allGroupSegments, groupCounter] = ...
            localAppendGroupedReleaseSegments(allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
            allGroupIds, allGroupSegments, groupCounter, ringStartUm, ringEndUm, ...
            segmentPowerPercent, segmentSpeedMmPerSecond, true);
    end

    if releaseOrder == "outside_in"
        [allStartUm, allEndUm, allPowerValues, allSpeedValues, allGroupIds, allGroupSegments, groupCounter] = ...
            localAppendGroupedReleaseSegments(allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
            allGroupIds, allGroupSegments, groupCounter, hatchStartUm, hatchEndUm, ...
            hatchPowerPercent, hatchSpeedMmPerSecond, false);
    end
end

if isempty(allStartUm)
    error('Circle release cut generated zero cut segments.');
end

data = localBuildCutScanData(allStartUm, allEndUm, allPowerValues, ...
    allSpeedValues, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor, 0);
data = localAppendCutGroupColumns(data, allGroupIds, allGroupSegments);
data = localRepeatRows(data, repeatCount);
[leadInValuesUm, leadOutValuesUm] = localCutLeadDistances( ...
    allSpeedValues, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor);

allX = [data(:, 8); data(:, 1); data(:, 5); data(:, 11)];
allY = [data(:, 9); data(:, 2); data(:, 6); data(:, 12)];
allZ = [data(:, 10); data(:, 3); data(:, 7); data(:, 13)];

prefix = sprintf('circlerelease_%s_radius_%s_start_%s_seg_%d_layers_%d_dz_%s_rings_%d_rpitch_%s_margin_%s_hatch_%s_wallP_%s_wallS_%s_ringP_%s_ringS_%s_hatchP_%s_hatchS_%s', ...
    char(releaseOrder), localCompactDistance(radiusUm, displayUnit), ...
    localCompactNumber(startAngleDeg), segmentCount, layerCount, localCompactDistance(zStepUm, displayUnit), ...
    ringCount, localCompactDistance(ringPitchUm, displayUnit), ...
    localCompactDistance(wallMarginUm, displayUnit), localCompactDistance(hatchPitchUm, displayUnit), ...
    localCompactNumber(powerPercent), localCompactNumber(cutSpeedMmPerSecond), ...
    localCompactNumber(ringPowerPercent), localCompactNumber(ringSpeedMmPerSecond), ...
    localCompactNumber(hatchPowerPercent), localCompactNumber(hatchSpeedMmPerSecond));
if repeatCount > 1
    prefix = sprintf('%s_rep_%d', prefix, repeatCount);
end

summary = struct();
summary.pointCount = size(data, 1);
summary.sourcePointCount = size(data, 1);
summary.xRangeMm = [min(allX), max(allX)];
summary.yRangeMm = [min(allY), max(allY)];
summary.zRangeMm = [min(allZ), max(allZ)];
summary.powerRange = [min(data(:, 4)), max(data(:, 4))];
summary.latticeType = 'circle_release_cut';
summary.latticeLabel = 'Circle Release Cut';
summary.pitchLabel = sprintf(['radius %s %s, start angle %s deg, %d segments/ring, %s; ', ...
    '%d Z layer(s), dz %s %s; %d circular ring(s) at %s %s pitch; ', ...
    'hatch pitch %s %s with %s %s wall margin; wall P/speed %s/%s, ', ...
    'ring P/speed %s/%s, hatch P/speed %s/%s'], ...
    localCompactDistance(radiusUm, displayUnit), unitText, localCompactNumber(startAngleDeg), ...
    segmentCount, localHexagonCutDirectionLabel(direction), layerCount, localCompactDistance(zStepUm, displayUnit), unitText, ...
    ringCount, localCompactDistance(ringPitchUm, displayUnit), unitText, ...
    localCompactDistance(hatchPitchUm, displayUnit), unitText, ...
    localCompactDistance(wallMarginUm, displayUnit), unitText, ...
    localCompactNumber(powerPercent), localCompactNumber(cutSpeedMmPerSecond), ...
    localCompactNumber(ringPowerPercent), localCompactNumber(ringSpeedMmPerSecond), ...
    localCompactNumber(hatchPowerPercent), localCompactNumber(hatchSpeedMmPerSecond));
if repeatCount > 1
    summary.pitchLabel = sprintf('%s; repeated %d time(s)', summary.pitchLabel, repeatCount);
end
summary.rowSpacingUm = hatchPitchUm;
summary.regionMode = 'circle_release_cut';
summary.regionLabel = 'Internal hatch plus grouped continuous circular release rings';
summary.pathMode = 'circle_release_cut';
if releaseOrder == "outside_in"
    summary.pathModeLabel = 'per Z layer: final circular wall, then outer-to-inner release rings, then internal 3-direction hatch chords';
    orderSummary = 'final circular wall first on each layer';
else
    summary.pathModeLabel = 'per Z layer: internal 3-direction hatch chords, then inner-to-outer grouped circular rings';
    orderSummary = 'final circular wall last on each layer';
end
summary.powerMode = 'fixed_value';
summary.powerModeLabel = sprintf('Wall/Ring/Hatch fixed values: %s / %s / %s', ...
    localCompactNumber(powerPercent), localCompactNumber(ringPowerPercent), localCompactNumber(hatchPowerPercent));
summary.layerTraversalLabel = sprintf('Z layers follow Z = %s %s + k * %s %s, %s; each circular ring is one continuous cut group', ...
    localCompactDistance(centerUm(3), displayUnit), unitText, ...
    localCompactDistance(zStepUm, displayUnit), unitText, orderSummary);
summary.prefix = prefix;
summary.releaseOrder = char(releaseOrder);
summary.cutSpeedMmPerSecond = cutSpeedMmPerSecond;
summary.releaseRingPowerPercent = ringPowerPercent;
summary.releaseRingSpeedMmPerSecond = ringSpeedMmPerSecond;
summary.releaseHatchPowerPercent = hatchPowerPercent;
summary.releaseHatchSpeedMmPerSecond = hatchSpeedMmPerSecond;
summary.accelerationMmPerSecondSquared = accelerationMmPerSecondSquared;
summary.leadInUm = [min(leadInValuesUm), max(leadInValuesUm)];
summary.leadOutUm = [min(leadOutValuesUm), max(leadOutValuesUm)];
summary.releaseWallMarginUm = wallMarginUm;
summary.releaseRingCount = ringCount;
summary.releaseRingPitchUm = ringPitchUm;
summary.releaseHatchPitchUm = hatchPitchUm;
summary.releaseLayerCount = layerCount;
summary.releaseZStepUm = zStepUm;
summary.releaseRepeatCount = repeatCount;
summary.radiusUm = radiusUm;
summary.circleSegmentCount = segmentCount;
end

function [allStartUm, allEndUm, allPowerValues, allSpeedValues] = localAppendReleaseSegments( ...
    allStartUm, allEndUm, allPowerValues, allSpeedValues, segmentStartUm, segmentEndUm, powerPercent, speedMmPerSecond)
segmentCount = size(segmentStartUm, 1);
if segmentCount == 0
    return;
end

allStartUm = [allStartUm; segmentStartUm];
allEndUm = [allEndUm; segmentEndUm];
allPowerValues = [allPowerValues; repmat(powerPercent, segmentCount, 1)];
allSpeedValues = [allSpeedValues; repmat(speedMmPerSecond, segmentCount, 1)];
end

function [allStartUm, allEndUm, allPowerValues, allSpeedValues, allGroupIds, allGroupSegments, groupCounter] = ...
    localAppendGroupedReleaseSegments(allStartUm, allEndUm, allPowerValues, allSpeedValues, ...
    allGroupIds, allGroupSegments, groupCounter, segmentStartUm, segmentEndUm, ...
    powerPercent, speedMmPerSecond, isContinuousGroup)
segmentCount = size(segmentStartUm, 1);
if segmentCount == 0
    return;
end

if isContinuousGroup
    groupCounter = groupCounter + 1;
    groupIds = repmat(groupCounter, segmentCount, 1);
    groupSegments = (1:segmentCount).';
else
    groupIds = (groupCounter + 1:groupCounter + segmentCount).';
    groupSegments = ones(segmentCount, 1);
    groupCounter = groupCounter + segmentCount;
end

allStartUm = [allStartUm; segmentStartUm];
allEndUm = [allEndUm; segmentEndUm];
allPowerValues = [allPowerValues; repmat(powerPercent, segmentCount, 1)];
allSpeedValues = [allSpeedValues; repmat(speedMmPerSecond, segmentCount, 1)];
allGroupIds = [allGroupIds; groupIds];
allGroupSegments = [allGroupSegments; groupSegments];
end

function data = localRepeatRows(data, repeatCount)
if repeatCount <= 1 || isempty(data)
    return;
end

baseData = data;
data = repmat(baseData, repeatCount, 1);
if size(baseData, 2) >= 18
    baseRowCount = size(baseData, 1);
    maxGroupId = max(baseData(:, 17));
    for iRepeat = 2:repeatCount
        rows = (iRepeat - 1) * baseRowCount + (1:baseRowCount);
        data(rows, 17) = data(rows, 17) + (iRepeat - 1) * maxGroupId;
    end
end
end

function data = localAppendCutGroupColumns(data, groupIds, groupSegments)
if size(data, 1) ~= numel(groupIds) || size(data, 1) ~= numel(groupSegments)
    error('Cut group columns must match the generated cut segment count.');
end
if any(~isfinite(groupIds) | groupIds < 1 | groupIds ~= round(groupIds) | ...
        ~isfinite(groupSegments) | groupSegments < 1 | groupSegments ~= round(groupSegments))
    error('Cut group columns must contain positive integers.');
end

data = [data, groupIds(:), groupSegments(:)];
end

function [cutStartUm, cutEndUm] = localHexagonEdgeSegments(centerUm, sideLengthUm, rotationDeg, direction)
verticesUm = localHexagonVertices(centerUm, sideLengthUm, rotationDeg, direction);
cutStartUm = verticesUm;
cutEndUm = verticesUm([2:6, 1], :);
end

function verticesUm = localHexagonVertices(centerUm, sideLengthUm, rotationDeg, direction)
angleStep = 60;
if localNormalizeOption(direction) == "clockwise"
    angleStep = -60;
end

anglesDeg = rotationDeg + (0:5).' * angleStep;
verticesUm = [ ...
    centerUm(1) + sideLengthUm * cosd(anglesDeg), ...
    centerUm(2) + sideLengthUm * sind(anglesDeg), ...
    repmat(centerUm(3), 6, 1)];
end

function [cutStartUm, cutEndUm] = localCircleEdgeSegments(centerUm, radiusUm, startAngleDeg, segmentCount, direction)
angleStep = 360 / segmentCount;
if localNormalizeOption(direction) == "clockwise"
    angleStep = -angleStep;
end

anglesDeg = startAngleDeg + (0:segmentCount - 1).' * angleStep;
verticesUm = [ ...
    centerUm(1) + radiusUm * cosd(anglesDeg), ...
    centerUm(2) + radiusUm * sind(anglesDeg), ...
    repmat(centerUm(3), segmentCount, 1)];
cutStartUm = verticesUm;
cutEndUm = verticesUm([2:segmentCount, 1], :);
end

function [hatchStartUm, hatchEndUm] = localCircleHatchSegments(centerUm, radiusUm, startAngleDeg, hatchPitchUm)
hatchStartUm = zeros(0, 3);
hatchEndUm = zeros(0, 3);
if hatchPitchUm <= 0
    return;
end

centerXY = centerUm(1:2);
familyAnglesDeg = startAngleDeg + [0, 60, 120];
lineCount = 0;
minSegmentLengthUm = max(1e-6, hatchPitchUm * 0.05);

for iFamily = 1:numel(familyAnglesDeg)
    directionXY = [cosd(familyAnglesDeg(iFamily)), sind(familyAnglesDeg(iFamily))];
    normalXY = [-directionXY(2), directionXY(1)];
    firstOffset = ceil((-radiusUm + 1e-9) / hatchPitchUm) * hatchPitchUm;
    lastOffset = floor((radiusUm - 1e-9) / hatchPitchUm) * hatchPitchUm;
    offsets = firstOffset:hatchPitchUm:lastOffset;

    for iOffset = 1:numel(offsets)
        halfLengthUm = sqrt(max(radiusUm ^ 2 - offsets(iOffset) ^ 2, 0));
        if 2 * halfLengthUm < minSegmentLengthUm
            continue;
        end

        linePointXY = centerXY + offsets(iOffset) * normalXY;
        pointA = linePointXY - halfLengthUm * directionXY;
        pointB = linePointXY + halfLengthUm * directionXY;

        lineCount = lineCount + 1;
        if mod(lineCount, 2) == 0
            startXY = pointB;
            endXY = pointA;
        else
            startXY = pointA;
            endXY = pointB;
        end

        hatchStartUm(end + 1, :) = [startXY, centerUm(3)]; %#ok<AGROW>
        hatchEndUm(end + 1, :) = [endXY, centerUm(3)]; %#ok<AGROW>
    end
end
end

function centersUm = localHoneycombArrayCenters(arrayCenterUm, sideLengthUm, rotationDeg, arrayRows, arrayCols)
xAxis = [cosd(rotationDeg), sind(rotationDeg), 0];
yAxis = [-sind(rotationDeg), cosd(rotationDeg), 0];
colStepUm = 1.5 * sideLengthUm * xAxis;
rowStepUm = -sqrt(3) * sideLengthUm * yAxis;
columnStaggerUm = 0.5 * rowStepUm;

centersUm = zeros(arrayRows, arrayCols, 3);
for iRow = 1:arrayRows
    for iCol = 1:arrayCols
        offsetUm = (iCol - 1) * colStepUm + (iRow - 1) * rowStepUm;
        if mod(iCol - 1, 2) == 1
            offsetUm = offsetUm + columnStaggerUm;
        end
        centersUm(iRow, iCol, :) = reshape(offsetUm, 1, 1, []);
    end
end

flatOffsetsUm = reshape(centersUm, [], 3);
offsetCenterUm = mean(flatOffsetsUm, 1);
for iRow = 1:arrayRows
    for iCol = 1:arrayCols
        centeredOffsetUm = reshape(centersUm(iRow, iCol, :), 1, []) - offsetCenterUm + arrayCenterUm;
        centersUm(iRow, iCol, :) = reshape(centeredOffsetUm, 1, 1, []);
    end
end
end

function data = localBuildCutScanData(cutStartUm, cutEndUm, powerPercent, cutSpeedMmPerSecond, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor, pauseSeconds)
if isempty(cutStartUm)
    data = zeros(0, 16);
    return;
end

if size(cutStartUm, 2) ~= 3 || size(cutEndUm, 2) ~= 3 || size(cutStartUm, 1) ~= size(cutEndUm, 1)
    error('Cut segments must provide matching Nx3 start and end coordinates.');
end

edgeVectorsUm = cutEndUm - cutStartUm;
edgeLengthsUm = sqrt(sum(edgeVectorsUm .^ 2, 2));
if any(edgeLengthsUm <= eps)
    error('Cut segments must have non-zero length.');
end

segmentCount = size(cutStartUm, 1);
powerValues = localCutColumnValues(powerPercent, segmentCount, 'Cut power');
speedValues = localCutColumnValues(cutSpeedMmPerSecond, segmentCount, 'Cut speed');
if any(powerValues < 0)
    error('Cut power values must be greater than or equal to 0.');
end
if any(speedValues <= 0)
    error('Cut speed values must be greater than 0.');
end
[leadInUm, leadOutUm] = localCutLeadDistances(speedValues, ...
    accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor);

unitVectors = edgeVectorsUm ./ edgeLengthsUm;
leadStartUm = cutStartUm - unitVectors .* leadInUm;
exitEndUm = cutEndUm + unitVectors .* leadOutUm;

leadSpeedValues = speedValues;
if isscalar(pauseSeconds)
    pauseSeconds = repmat(pauseSeconds, segmentCount, 1);
else
    pauseSeconds = pauseSeconds(:);
end
if numel(pauseSeconds) ~= segmentCount
    error('Cut pause values must be scalar or match the cut segment count.');
end

data = [cutStartUm / 1000, powerValues, cutEndUm / 1000, ...
    leadStartUm / 1000, exitEndUm / 1000, speedValues, leadSpeedValues, pauseSeconds];
end

function values = localCutColumnValues(value, segmentCount, label)
if isscalar(value)
    values = repmat(value, segmentCount, 1);
else
    values = value(:);
end

if numel(values) ~= segmentCount || any(~isfinite(values))
    error('%s values must be finite and either scalar or match the cut segment count.', label);
end
end

function [leadInUm, leadOutUm] = localCutLeadDistances(speedMmPerSecond, accelerationMmPerSecondSquared, leadSafetyFactor, exitSafetyFactor)
speedMmPerSecond = speedMmPerSecond(:);
baseLeadUm = (speedMmPerSecond .^ 2 ./ (2 * accelerationMmPerSecondSquared)) * 1000;
leadInUm = baseLeadUm * leadSafetyFactor;
leadOutUm = baseLeadUm * exitSafetyFactor;
end

function [hatchStartUm, hatchEndUm] = localHexagonHatchSegments(centerUm, sideLengthUm, rotationDeg, hatchPitchUm)
hatchStartUm = zeros(0, 3);
hatchEndUm = zeros(0, 3);
if hatchPitchUm <= 0
    return;
end

verticesUm = localHexagonVertices(centerUm, sideLengthUm, rotationDeg, "counter_clockwise");
polygonXY = verticesUm(:, 1:2);
centerXY = centerUm(1:2);
familyAnglesDeg = rotationDeg + [0, 60, 120];
lineCount = 0;
minSegmentLengthUm = max(1e-6, hatchPitchUm * 0.05);

for iFamily = 1:numel(familyAnglesDeg)
    directionXY = [cosd(familyAnglesDeg(iFamily)), sind(familyAnglesDeg(iFamily))];
    normalXY = [-directionXY(2), directionXY(1)];
    projections = (polygonXY - centerXY) * normalXY.';
    firstOffset = ceil((min(projections) - 1e-9) / hatchPitchUm) * hatchPitchUm;
    lastOffset = floor((max(projections) + 1e-9) / hatchPitchUm) * hatchPitchUm;
    offsets = firstOffset:hatchPitchUm:lastOffset;

    for iOffset = 1:numel(offsets)
        linePointXY = centerXY + offsets(iOffset) * normalXY;
        [pointA, pointB, didClip] = localClipLineToPolygon(linePointXY, directionXY, polygonXY);
        if ~didClip || norm(pointB - pointA) < minSegmentLengthUm
            continue;
        end

        lineCount = lineCount + 1;
        if mod(lineCount, 2) == 0
            startXY = pointB;
            endXY = pointA;
        else
            startXY = pointA;
            endXY = pointB;
        end

        hatchStartUm(end + 1, :) = [startXY, centerUm(3)]; %#ok<AGROW>
        hatchEndUm(end + 1, :) = [endXY, centerUm(3)]; %#ok<AGROW>
    end
end
end

function [pointA, pointB, didClip] = localClipLineToPolygon(linePointXY, directionXY, polygonXY)
pointA = [nan, nan];
pointB = [nan, nan];
didClip = false;
tValues = zeros(0, 1);
vertexCount = size(polygonXY, 1);

for iVertex = 1:vertexCount
    nextVertex = iVertex + 1;
    if nextVertex > vertexCount
        nextVertex = 1;
    end

    edgeStartXY = polygonXY(iVertex, :);
    edgeVectorXY = polygonXY(nextVertex, :) - edgeStartXY;
    systemMatrix = [directionXY(:), -edgeVectorXY(:)];
    if abs(det(systemMatrix)) < 1e-10
        continue;
    end

    solution = systemMatrix \ (edgeStartXY(:) - linePointXY(:));
    edgeParameter = solution(2);
    if edgeParameter >= -1e-9 && edgeParameter <= 1 + 1e-9
        tValues(end + 1, 1) = solution(1); %#ok<AGROW>
    end
end

if numel(tValues) < 2
    return;
end

tValues = sort(tValues);
keepMask = [true; diff(tValues) > 1e-6];
tValues = tValues(keepMask);
if numel(tValues) < 2
    return;
end

pointA = linePointXY + tValues(1) * directionXY;
pointB = linePointXY + tValues(end) * directionXY;
didClip = true;
end

function [xUm, yUm, zUm, layerIndex, rowIndex, info] = localGenerateLatticeUm(lattice)
latticeType = localLatticeType(lattice);
counts = localCounts(lattice);
originUm = localVector3(lattice.originUm, 'Origin');
displayUnit = localDisplayDistanceUnit(lattice);
unitText = localDistanceUnitText(displayUnit);

switch latticeType
    case "cartesian"
        pitch = localRequireStruct(lattice, 'pitch');
        pitchXUm = localPositiveScalar(localRequireField(pitch, 'xUm'), 'Pitch X');
        pitchYUm = localPositiveScalar(localRequireField(pitch, 'yUm'), 'Pitch Y');
        pitchZUm = localPositiveScalar(localRequireField(pitch, 'zUm'), 'Pitch Z');

        [xUm, yUm, zUm, layerIndex, rowIndex] = localGenerateCartesianLattice(counts, [pitchXUm, pitchYUm, pitchZUm], originUm);

        info = struct();
        info.type = 'cartesian';
        info.label = 'Cartesian';
        info.pitchLabel = sprintf('X/Y/Z pitch: %s / %s / %s %s', ...
            localCompactDistance(pitchXUm, displayUnit), localCompactDistance(pitchYUm, displayUnit), ...
            localCompactDistance(pitchZUm, displayUnit), unitText);
        info.rowSpacingUm = pitchYUm;
        info.displayDistanceUnit = displayUnit;
        info.counts = counts;
        info.pitchXUm = pitchXUm;
        info.pitchYUm = pitchYUm;
        info.pitchZUm = pitchZUm;

    case {"hex", "hcp"}
        pitch = localRequireStruct(lattice, 'pitch');
        pitchXYUm = localPositiveScalar(localRequireField(pitch, 'xyUm'), 'Pitch XY');
        pitchZUm = localPositiveScalar(localRequireField(pitch, 'zUm'), 'Pitch Z');

        hcpShift = struct();
        if isfield(lattice, 'hcpShift') && isstruct(lattice.hcpShift)
            hcpShift = lattice.hcpShift;
        end

        defaultDx = pitchXYUm / 2;
        defaultDy = (sqrt(3) / 6) * pitchXYUm;
        shiftDxUm = localFiniteScalar(localFieldOrDefault(hcpShift, 'dxUm', defaultDx), 'AB dx');
        shiftDyUm = localFiniteScalar(localFieldOrDefault(hcpShift, 'dyUm', defaultDy), 'AB dy');

        [xUm, yUm, zUm, layerIndex, rowIndex, rowSpacingUm] = localGenerateHexLikeLattice(counts, pitchXYUm, pitchZUm, originUm, latticeType == "hcp", shiftDxUm, shiftDyUm);

        info = struct();
        info.type = char(latticeType);
        info.label = localLatticeLabel(latticeType);
        info.pitchLabel = sprintf('XY/Z pitch: %s / %s %s', ...
            localCompactDistance(pitchXYUm, displayUnit), localCompactDistance(pitchZUm, displayUnit), unitText);
        info.rowSpacingUm = rowSpacingUm;
        info.displayDistanceUnit = displayUnit;
        info.counts = counts;
        info.pitchXYUm = pitchXYUm;
        info.pitchZUm = pitchZUm;
        info.hcpShiftDxUm = shiftDxUm;
        info.hcpShiftDyUm = shiftDyUm;

    otherwise
        error('Unsupported lattice type: "%s".', latticeType);
end
end

function [xUm, yUm, zUm, layerIndex, rowIndex] = localGenerateCartesianLattice(counts, pitchUm, originUm)
pointsX = counts(1);
pointsY = counts(2);
pointsZ = counts(3);

pointCount = pointsX * pointsY * pointsZ;
xUm = zeros(pointCount, 1);
yUm = zeros(pointCount, 1);
zUm = zeros(pointCount, 1);
layerIndex = zeros(pointCount, 1);
rowIndex = zeros(pointCount, 1);

cursor = 1;
for layer = 1:pointsZ
    zValue = originUm(3) + (layer - 1) * pitchUm(3);
    for row = 1:pointsY
        yValue = originUm(2) + (row - 1) * pitchUm(2);
        xRow = originUm(1) + (0:pointsX-1) * pitchUm(1);

        count = numel(xRow);
        idx = cursor:(cursor + count - 1);
        xUm(idx) = xRow(:);
        yUm(idx) = yValue;
        zUm(idx) = zValue;
        layerIndex(idx) = layer;
        rowIndex(idx) = row;
        cursor = cursor + count;
    end
end
end

function [xUm, yUm, zUm, layerIndex, rowIndex, rowSpacingUm] = localGenerateHexLikeLattice(counts, pitchXYUm, pitchZUm, originUm, useHcpShift, shiftDxUm, shiftDyUm)
pointsX = counts(1);
pointsY = counts(2);
pointsZ = counts(3);
rowSpacingUm = sqrt(3) / 2 * pitchXYUm;

pointCount = pointsX * pointsY * pointsZ;
xUm = zeros(pointCount, 1);
yUm = zeros(pointCount, 1);
zUm = zeros(pointCount, 1);
layerIndex = zeros(pointCount, 1);
rowIndex = zeros(pointCount, 1);

cursor = 1;
for layer = 1:pointsZ
    zValue = originUm(3) + (layer - 1) * pitchZUm;

    if useHcpShift && mod(layer, 2) == 0
        layerShiftXUm = shiftDxUm;
        layerShiftYUm = shiftDyUm;
    else
        layerShiftXUm = 0;
        layerShiftYUm = 0;
    end

    for row = 1:pointsY
        yValue = originUm(2) + (row - 1) * rowSpacingUm + layerShiftYUm;
        rowOffsetUm = mod(row - 1, 2) * (pitchXYUm / 2);
        xRow = originUm(1) + (0:pointsX-1) * pitchXYUm + rowOffsetUm + layerShiftXUm;

        count = numel(xRow);
        idx = cursor:(cursor + count - 1);
        xUm(idx) = xRow(:);
        yUm(idx) = yValue;
        zUm(idx) = zValue;
        layerIndex(idx) = layer;
        rowIndex(idx) = row;
        cursor = cursor + count;
    end
end
end

function mask = localBuildRegionMask(region, xUm, yUm, zUm)
regionMode = localRegionMode(region);

switch regionMode
    case "full_block"
        mask = true(size(xUm));

    case "primitive"
        primitiveType = localPrimitiveType(region);
        centerUm = localVector3(localRequireField(region, 'centerUm'), 'Center');

        switch primitiveType
            case "box"
                sizeUm = localVector3(localRequireField(region, 'sizeUm'), 'Box size');
                if any(sizeUm <= 0)
                    error('Box dimensions must all be greater than 0.');
                end

                mask = abs(xUm - centerUm(1)) <= sizeUm(1) / 2 & ...
                    abs(yUm - centerUm(2)) <= sizeUm(2) / 2 & ...
                    abs(zUm - centerUm(3)) <= sizeUm(3) / 2;

            case "cylinder"
                radiusUm = localPositiveScalar(localRequireField(region, 'radiusUm'), 'Cylinder radius');
                heightUm = localPositiveScalar(localRequireField(region, 'heightUm'), 'Cylinder height');
                radialSq = (xUm - centerUm(1)).^2 + (yUm - centerUm(2)).^2;
                mask = radialSq <= radiusUm^2 & abs(zUm - centerUm(3)) <= heightUm / 2;

            case "sphere"
                radiusUm = localPositiveScalar(localRequireField(region, 'radiusUm'), 'Sphere radius');
                distanceSq = (xUm - centerUm(1)).^2 + (yUm - centerUm(2)).^2 + (zUm - centerUm(3)).^2;
                mask = distanceSq <= radiusUm^2;

            case "tube"
                innerRadiusUm = localNonnegativeScalar(localRequireField(region, 'innerRadiusUm'), 'Tube inner radius');
                outerRadiusUm = localPositiveScalar(localRequireField(region, 'outerRadiusUm'), 'Tube outer radius');
                heightUm = localPositiveScalar(localRequireField(region, 'heightUm'), 'Tube height');
                if outerRadiusUm <= innerRadiusUm
                    error('Tube outer radius must be greater than inner radius.');
                end

                radialSq = (xUm - centerUm(1)).^2 + (yUm - centerUm(2)).^2;
                mask = radialSq >= innerRadiusUm^2 & radialSq <= outerRadiusUm^2 & ...
                    abs(zUm - centerUm(3)) <= heightUm / 2;

            otherwise
                error('Unsupported geometry type: "%s".', primitiveType);
        end

    case "custom_formula"
        formulaText = string(localRequireField(region, 'formula'));
        mask = localEvaluateRegionFormula(formulaText, xUm, yUm, zUm);

    otherwise
        error('Unsupported region mode: "%s".', regionMode);
end
end

function [xUm, yUm, zUm] = localApplyOrdering(xUm, yUm, zUm, layerIndex, rowIndex, pathMode)
if isempty(xUm)
    return;
end

switch pathMode
    case "row_major"
        sortX = xUm;
    case "serpentine"
        sortX = xUm;
        descendingRows = mod(rowIndex, 2) == 0;
        sortX(descendingRows) = -sortX(descendingRows);
    otherwise
        error('Unsupported path mode: "%s".', pathMode);
end

sortKeys = [zUm(:), layerIndex(:), rowIndex(:), sortX(:)];
[~, order] = sortrows(sortKeys, [1, 2, 3, 4]);
xUm = xUm(order);
yUm = yUm(order);
zUm = zUm(order);
end

function data = localSortRowsByZAscending(data)
if isempty(data) || size(data, 1) < 2 || size(data, 2) < 3
    return;
end

rowIndex = (1:size(data, 1)).';
sortKeys = [data(:, 3), rowIndex];
[~, order] = sortrows(sortKeys, [1, 2]);
data = data(order, :);
end

function power = localEvaluatePower(powerConfig, powerMode, xUm, yUm, zUm)
distanceUnit = localPowerDistanceUnit(powerConfig);
switch powerMode
    case "fixed_value"
        fixedValue = localNonnegativeScalar(localFieldOrDefault(powerConfig, 'fixedValue', 10), 'Fixed Power');
        power = repmat(fixedValue, numel(xUm), 1);

    case "custom_formula"
        formulaText = string(localFieldOrDefault(powerConfig, 'formula', ""));
        power = localEvaluateCustomPowerFormula(formulaText, ...
            localDisplayDistance(xUm, distanceUnit), ...
            localDisplayDistance(yUm, distanceUnit), ...
            localDisplayDistance(zUm, distanceUnit));

    case "linear_points"
        pointsText = string(localFieldOrDefault(powerConfig, 'linearPointsText', ""));
        power = localEvaluateLinearPoints(pointsText, ...
            localDisplayDistance(zUm, distanceUnit), localLinearPointZLabel(distanceUnit));

    case "depth_model"
        if exist('depth2powerMgF2', 'file') ~= 2
            error('depth2powerMgF2.m was not found on the MATLAB path.');
        end

        zMm = zUm / 1000;
        depthUm = (0.1 - zMm) * 1000;
        power = depth2powerMgF2(depthUm);
        power = localValidatePowerVector(power, numel(zUm), 'Depth Model');

    otherwise
        error('Unsupported power mode: "%s".', powerMode);
end
end

function power = localEvaluateCustomPowerFormula(formulaText, xUm, yUm, zUm)
formulaText = strtrim(string(formulaText));
if strlength(formulaText) == 0
    error('Enter a custom formula for the current power mode.');
end

x = xUm; %#ok<NASGU>
y = yUm; %#ok<NASGU>
z = zUm; %#ok<NASGU>

try
    power = eval(formulaText);
catch err
    error('Custom formula evaluation failed: %s', err.message);
end

power = localValidatePowerVector(power, numel(zUm), 'Custom Formula');
end

function mask = localEvaluateRegionFormula(formulaText, xUm, yUm, zUm)
formulaText = strtrim(string(formulaText));
if strlength(formulaText) == 0
    error('Enter a custom region formula for the current mode.');
end

x = xUm; %#ok<NASGU>
y = yUm; %#ok<NASGU>
z = zUm; %#ok<NASGU>

try
    mask = eval(formulaText);
catch err
    error('Custom region formula evaluation failed: %s', err.message);
end

mask = localValidateMaskVector(mask, numel(zUm));
end

function power = localEvaluateLinearPoints(pointsText, zValues, zLabel)
[zPoints, powerPoints] = localParseLinearPoints(pointsText, zLabel);
power = interp1(zPoints, powerPoints, zValues, 'linear', 'extrap');
power = localValidatePowerVector(power, numel(zValues), 'linear points');
end

function [zPoints, powerPoints] = localParseLinearPoints(pointsText, zLabel)
lines = splitlines(string(pointsText));
zPoints = [];
powerPoints = [];

for i = 1:numel(lines)
    lineText = strtrim(lines(i));
    if strlength(lineText) == 0 || startsWith(lineText, "#")
        continue;
    end

    parts = regexp(char(lineText), '[,\s;]+', 'split');
    parts = parts(~cellfun('isempty', parts));
    if numel(parts) ~= 2
        error('Each linear-points row must contain two numbers: %s and power.', zLabel);
    end

    zValue = str2double(parts{1});
    powerValue = str2double(parts{2});
    if ~isfinite(zValue) || ~isfinite(powerValue)
        error('Invalid linear-points row: %s', lineText);
    end

    zPoints(end + 1, 1) = zValue; %#ok<AGROW>
    powerPoints(end + 1, 1) = powerValue; %#ok<AGROW>
end

if numel(zPoints) < 2
    error('Enter at least two z-power points for linear interpolation.');
end

[zPoints, sortIdx] = sort(zPoints);
powerPoints = powerPoints(sortIdx);

if any(diff(zPoints) == 0)
    error('Z values for linear interpolation cannot repeat.');
end
end

function prefix = localBuildPrefix(latticeInfo, regionMode, primitiveType, pathMode, powerMode, powerConfig)
displayUnit = localFieldOrDefault(latticeInfo, 'displayDistanceUnit', "um");
switch latticeInfo.type
    case 'cartesian'
        latticeTag = sprintf('%dx%dx%d_cart_px_%s_py_%s_pz_%s', ...
            latticeInfo.counts(1), latticeInfo.counts(2), latticeInfo.counts(3), ...
            localCompactDistance(latticeInfo.pitchXUm, displayUnit), ...
            localCompactDistance(latticeInfo.pitchYUm, displayUnit), ...
            localCompactDistance(latticeInfo.pitchZUm, displayUnit));
    case 'hex'
        latticeTag = sprintf('%dx%dx%d_hex_pxy_%s_pz_%s', ...
            latticeInfo.counts(1), latticeInfo.counts(2), latticeInfo.counts(3), ...
            localCompactDistance(latticeInfo.pitchXYUm, displayUnit), ...
            localCompactDistance(latticeInfo.pitchZUm, displayUnit));
    case 'hcp'
        latticeTag = sprintf('%dx%dx%d_hcp_pxy_%s_pz_%s', ...
            latticeInfo.counts(1), latticeInfo.counts(2), latticeInfo.counts(3), ...
            localCompactDistance(latticeInfo.pitchXYUm, displayUnit), ...
            localCompactDistance(latticeInfo.pitchZUm, displayUnit));
    otherwise
        latticeTag = char(latticeInfo.type);
end

switch regionMode
    case "full_block"
        regionTag = 'full';
    case "primitive"
        regionTag = char(primitiveType);
    case "custom_formula"
        regionTag = 'formula';
    otherwise
        regionTag = char(regionMode);
end

switch pathMode
    case "row_major"
        orderTag = 'row';
    case "serpentine"
        orderTag = 'serp';
    otherwise
        orderTag = char(pathMode);
end

powerTag = '';
if powerMode == "fixed_value"
    fixedValue = localFieldOrDefault(powerConfig, 'fixedValue', 10);
    powerTag = ['_Pfixed_', localCompactNumber(fixedValue)];
end

prefix = [latticeTag, '_', regionTag, '_', orderTag, powerTag];
end

function lattice = localRequireStruct(params, fieldName)
if ~isfield(params, fieldName) || ~isstruct(params.(fieldName))
    error('Missing required struct field: "%s".', fieldName);
end

lattice = params.(fieldName);
end

function value = localRequireField(structValue, fieldName)
if ~isfield(structValue, fieldName)
    error('Missing required field: "%s".', fieldName);
end

value = structValue.(fieldName);
end

function value = localFieldOrDefault(structValue, fieldName, defaultValue)
if isfield(structValue, fieldName) && ~isempty(structValue.(fieldName))
    value = structValue.(fieldName);
else
    value = defaultValue;
end
end

function counts = localCounts(lattice)
counts = localRequireField(lattice, 'counts');
if ~(isnumeric(counts) && numel(counts) == 3)
    error('Lattice counts must contain exactly three values.');
end

counts = reshape(counts, 1, []);
counts(1) = localPositiveInteger(counts(1), 'Points X');
counts(2) = localPositiveInteger(counts(2), 'Points Y');
counts(3) = localPositiveInteger(counts(3), 'Points Z');
end

function vector = localVector3(value, label)
if ~(isnumeric(value) && numel(value) == 3 && all(isfinite(value(:))))
    error('%s must contain exactly three finite values.', label);
end

vector = reshape(double(value), 1, []);
end

function vector = localVector2(value, label)
if ~(isnumeric(value) && numel(value) == 2 && all(isfinite(value(:))))
    error('%s must contain exactly two finite values.', label);
end

vector = reshape(double(value), 1, []);
end

function axisIndex = localAxisIndex(value, label)
axisName = upper(strtrim(string(value)));
switch axisName
    case "X"
        axisIndex = 1;
    case "Y"
        axisIndex = 2;
    case "Z"
        axisIndex = 3;
    otherwise
        error('%s must be X, Y, or Z.', label);
end
end

function axisName = localAxisName(axisIndex)
axisNames = ["X", "Y", "Z"];
axisIndex = round(axisIndex);
if axisIndex < 1 || axisIndex > numel(axisNames)
    error('Axis index must be 1, 2, or 3.');
end

axisName = char(axisNames(axisIndex));
end

function latticeType = localLatticeType(lattice)
latticeType = localNormalizeOption(localRequireField(lattice, 'type'));
allowed = ["cartesian", "hex", "hcp"];
if ~any(latticeType == allowed)
    error('Unsupported lattice type: "%s".', latticeType);
end
end

function regionMode = localRegionMode(region)
regionMode = localNormalizeOption(localRequireField(region, 'mode'));
allowed = ["full_block", "primitive", "custom_formula"];
if ~any(regionMode == allowed)
    error('Unsupported region mode: "%s".', regionMode);
end
end

function primitiveType = localPrimitiveType(region)
primitiveType = localNormalizeOption(localFieldOrDefault(region, 'primitiveType', 'box'));
allowed = ["box", "cylinder", "sphere", "tube"];
if ~any(primitiveType == allowed)
    error('Unsupported geometry type: "%s".', primitiveType);
end
end

function powerMode = localPowerMode(power)
powerMode = localNormalizeOption(localFieldOrDefault(power, 'mode', 'fixed_value'));
allowed = ["fixed_value", "custom_formula", "linear_points", "depth_model"];
if ~any(powerMode == allowed)
    error('Unsupported power mode: "%s".', powerMode);
end
end

function pathMode = localPathMode(ordering)
pathMode = localNormalizeOption(localFieldOrDefault(ordering, 'pathMode', 'serpentine'));
allowed = ["row_major", "serpentine"];
if ~any(pathMode == allowed)
    error('Unsupported path mode: "%s".', pathMode);
end
end

function value = localPositiveInteger(value, label)
value = localFiniteScalar(value, label);
value = round(value);
if value < 1
    error('%s must be a positive integer.', label);
end
end

function value = localPositiveScalar(value, label)
value = localFiniteScalar(value, label);
if value <= 0
    error('%s must be greater than 0.', label);
end
end

function value = localNonnegativeScalar(value, label)
value = localFiniteScalar(value, label);
if value < 0
    error('%s must be greater than or equal to 0.', label);
end
end

function value = localFiniteScalar(value, label)
if ~(isscalar(value) && isnumeric(value) && isfinite(value))
    error('%s must be a finite numeric scalar.', label);
end
end

function mask = localLogicalMatrix(value, expectedRows, expectedCols, label)
if istable(value)
    value = table2array(value);
end

if iscell(value)
    mask = false(size(value));
    for iValue = 1:numel(value)
        mask(iValue) = localLogicalScalar(value{iValue}, label);
    end
elseif islogical(value)
    mask = value;
elseif isnumeric(value)
    if any(~isfinite(value(:)))
        error('%s must contain only finite values.', label);
    end
    mask = value ~= 0;
else
    textValues = strtrim(string(value));
    mask = strcmpi(textValues, "true") | strcmpi(textValues, "1") | ...
        strcmpi(textValues, "yes") | strcmpi(textValues, "y");
    invalidMask = ~(mask | strcmpi(textValues, "false") | strcmpi(textValues, "0") | ...
        strcmpi(textValues, "no") | strcmpi(textValues, "n") | strlength(textValues) == 0);
    if any(invalidMask(:))
        error('%s must contain logical, 0/1, yes/no, or blank values.', label);
    end
end

if ~isequal(size(mask), [expectedRows, expectedCols])
    error('%s must be a %d-by-%d matrix.', label, expectedRows, expectedCols);
end

mask = logical(mask);
end

function value = localLogicalScalar(value, label)
if isempty(value)
    value = false;
elseif islogical(value)
    if ~isscalar(value)
        error('%s cells must contain scalar logical values.', label);
    end
elseif isnumeric(value)
    if ~(isscalar(value) && isfinite(value))
        error('%s cells must contain finite scalar numeric values.', label);
    end
    value = value ~= 0;
else
    textValue = strtrim(string(value));
    if strlength(textValue) == 0 || strcmpi(textValue, "false") || ...
            strcmpi(textValue, "0") || strcmpi(textValue, "no") || strcmpi(textValue, "n")
        value = false;
    elseif strcmpi(textValue, "true") || strcmpi(textValue, "1") || ...
            strcmpi(textValue, "yes") || strcmpi(textValue, "y")
        value = true;
    else
        error('%s cells must contain logical, 0/1, yes/no, or blank values.', label);
    end
end

value = logical(value);
end

function power = localValidatePowerVector(power, expectedCount, sourceName)
if isscalar(power)
    power = repmat(power, expectedCount, 1);
else
    power = power(:);
end

if numel(power) ~= expectedCount
    error('%s output must be scalar, or provide one value per point.', sourceName);
end

if any(~isfinite(power))
    error('%s output contains non-finite values.', sourceName);
end
end

function mask = localValidateMaskVector(mask, expectedCount)
if isscalar(mask)
    mask = repmat(mask, expectedCount, 1);
else
    mask = mask(:);
end

if numel(mask) ~= expectedCount
    error('Custom region formula must return a scalar, or one value per point.');
end

if any(~isfinite(mask))
    error('Custom region formula output contains non-finite values.');
end

mask = logical(mask);
end

function label = localLatticeLabel(latticeType)
switch latticeType
    case "cartesian"
        label = 'Cartesian';
    case "hex"
        label = 'Hex';
    case "hcp"
        label = 'HCP';
    otherwise
        label = char(latticeType);
end
end

function label = localRegionLabel(regionMode, primitiveType)
switch regionMode
    case "full_block"
        label = 'Full Block';
    case "primitive"
        label = ['Geometry (', localPrimitiveLabel(primitiveType), ')'];
    case "custom_formula"
        label = 'Custom Formula';
    otherwise
        label = char(regionMode);
end
end

function label = localPrimitiveLabel(primitiveType)
switch primitiveType
    case "box"
        label = 'Box';
    case "cylinder"
        label = 'Cylinder';
    case "sphere"
        label = 'Sphere';
    case "tube"
        label = 'Tube';
    otherwise
        label = char(primitiveType);
end
end

function label = localPathModeLabel(pathMode)
switch pathMode
    case "row_major"
        label = 'Row-major';
    case "serpentine"
        label = 'Serpentine';
    otherwise
        label = char(pathMode);
end
end

function label = localPowerModeLabel(powerMode)
switch powerMode
    case "fixed_value"
        label = 'Fixed Value';
    case "custom_formula"
        label = 'Custom Formula';
    case "linear_points"
        label = 'Linear Points';
    case "depth_model"
        label = 'Depth Model';
    otherwise
        label = char(powerMode);
end
end

function label = localStaircasePowerModeLabel(nPowers, powerStart, powerEnd)
if nPowers == 1
    label = sprintf('Single column (1 level, %s)', localCompactNumber(powerStart));
else
    label = sprintf('Column-varying (%d levels, %s to %s)', ...
        nPowers, localCompactNumber(powerStart), localCompactNumber(powerEnd));
end
end

function label = localStaircaseTraversalLabel(zStepUm)
if zStepUm ~= 0
    label = 'Deep to shallow (ascending Z; smaller Z is deeper)';
else
    label = 'Z Step is 0';
end
end

function label = localSegmentedGratingTraversalLabel(depthStepUm, depthAxisName)
if strcmpi(depthAxisName, 'Z')
    label = 'Deep to shallow (ascending Z; smaller Z is deeper)';
elseif depthStepUm > 0
    label = sprintf('Increasing along %s', depthAxisName);
else
    label = sprintf('Decreasing along %s', depthAxisName);
end
end

function label = localHexagonCutDirectionLabel(direction)
if string(direction) == "clockwise"
    label = 'clockwise';
else
    label = 'counter-clockwise';
end
end

function prefix = localBuildStaircasePrefix( ...
    nDepths, nPowers, zStartUm, zStepUm, powerStart, powerEnd, ...
    patchNx, patchNy, pitchXUm, pitchYUm, gapXUm, gapYUm, originXUm, originYUm, displayUnit)
powerTag = localBuildStaircasePowerTag(nPowers, powerStart, powerEnd);
prefix = sprintf([ ...
    'stair_nd_%d_np_%d_zstart_%s_dz_%s_%s_patch_%dx%d_', ...
    'px_%s_py_%s_gx_%s_gy_%s_ox_%s_oy_%s'], ...
    nDepths, nPowers, ...
    localCompactDistance(zStartUm, displayUnit), localCompactDistance(zStepUm, displayUnit), powerTag, ...
    patchNx, patchNy, ...
    localCompactDistance(pitchXUm, displayUnit), localCompactDistance(pitchYUm, displayUnit), ...
    localCompactDistance(gapXUm, displayUnit), localCompactDistance(gapYUm, displayUnit), ...
    localCompactDistance(originXUm, displayUnit), localCompactDistance(originYUm, displayUnit));
end

function powerTag = localBuildStaircasePowerTag(nPowers, powerStart, powerEnd)
if nPowers == 1
    powerTag = ['P_', localCompactNumber(powerStart)];
else
    powerTag = ['P_', localCompactNumber(powerStart), '_to_', localCompactNumber(powerEnd)];
end
end

function prefix = localBuildSegmentedGratingPrefix( ...
    depthAxisName, periodAxisName, scanAxisName, nDepths, depthStartUm, depthStepUm, ...
    period1Um, nPeriods1, period2Um, nPeriods2, segmentGapUm, ...
    slabCopies1, slabPitch1Um, slabCopies2, slabPitch2Um, ...
    channelRows, channelCols, channelRowPitchUm, channelColPitchUm, originUm, powerMode, powerConfig, displayUnit)
powerTag = '';
if powerMode == "fixed_value"
    fixedValue = localFieldOrDefault(powerConfig, 'fixedValue', 10);
    powerTag = ['_Pfixed_', localCompactNumber(fixedValue)];
end

prefix = sprintf([ ...
    'seggrating_d%s_p%s_s%s_nd_%d_dstart_%s_dd_%s_', ...
    'seg1_%dx%s_slab_%d_pitch_%s_gap_%s_seg2_%dx%s_slab_%d_pitch_%s_', ...
    'ch_%dx%d_rp_%s_cp_%s_ox_%s_oy_%s_oz_%s%s'], ...
    lower(depthAxisName), lower(periodAxisName), lower(scanAxisName), ...
    nDepths, localCompactDistance(depthStartUm, displayUnit), localCompactDistance(depthStepUm, displayUnit), ...
    nPeriods1, localCompactDistance(period1Um, displayUnit), ...
    slabCopies1, localCompactDistance(slabPitch1Um, displayUnit), ...
    localCompactDistance(segmentGapUm, displayUnit), ...
    nPeriods2, localCompactDistance(period2Um, displayUnit), ...
    slabCopies2, localCompactDistance(slabPitch2Um, displayUnit), ...
    channelRows, channelCols, ...
    localCompactDistance(channelRowPitchUm, displayUnit), localCompactDistance(channelColPitchUm, displayUnit), ...
    localCompactDistance(originUm(1), displayUnit), localCompactDistance(originUm(2), displayUnit), localCompactDistance(originUm(3), displayUnit), ...
    powerTag);
end

function prefix = localBuildZPushPrefix(originUm, moveXYUm, pushCount, pushStepUm, intervalSeconds, powerMode, powerConfig, displayUnit)
powerTag = '';
if powerMode == "fixed_value"
    fixedValue = localFieldOrDefault(powerConfig, 'fixedValue', 10);
    powerTag = ['_Pfixed_', localCompactNumber(fixedValue)];
end

prefix = sprintf('zpush_n_%d_dz_%s_wait_%s_ox_%s_oy_%s_oz_%s_dx_%s_dy_%s%s', ...
    pushCount, localCompactDistance(pushStepUm, displayUnit), localCompactNumber(intervalSeconds), ...
    localCompactDistance(originUm(1), displayUnit), localCompactDistance(originUm(2), displayUnit), localCompactDistance(originUm(3), displayUnit), ...
    localCompactDistance(moveXYUm(1), displayUnit), localCompactDistance(moveXYUm(2), displayUnit), powerTag);
end

function textValue = localCompactNumber(value)
textValue = regexprep(num2str(value, '%.15g'), '\s+', '');
end

function textValue = localCompactDistance(valueUm, unit)
textValue = localCompactNumber(localDisplayDistance(valueUm, unit));
end

function value = localDisplayDistance(valueUm, unit)
unit = localCanonicalDistanceUnit(unit);
if unit == "mm"
    value = valueUm ./ 1000;
else
    value = valueUm;
end
end

function unit = localDisplayDistanceUnit(config)
unit = localCanonicalDistanceUnit(localNormalizeOption(localFieldOrDefault(config, 'displayDistanceUnit', 'um')));
end

function unit = localPowerDistanceUnit(powerConfig)
unit = localCanonicalDistanceUnit(localNormalizeOption(localFieldOrDefault(powerConfig, 'distanceUnit', 'um')));
end

function unit = localCanonicalDistanceUnit(unit)
unit = localNormalizeOption(unit);
switch unit
    case {"mm", "millimeter", "millimeters"}
        unit = "mm";
    case {"um", "micron", "microns", "micrometer", "micrometers"}
        unit = "um";
    otherwise
        error('Distance unit must be "mm" or "um".');
end
end

function textValue = localDistanceUnitText(unit)
textValue = char(localCanonicalDistanceUnit(unit));
end

function label = localLinearPointZLabel(unit)
if localCanonicalDistanceUnit(unit) == "mm"
    label = 'z_mm';
else
    label = 'z_um';
end
end

function textValue = localCompactCellTag(value)
textValue = char(value);
textValue = regexprep(textValue, '[^A-Za-z0-9]+', '_');
textValue = regexprep(textValue, '^_+|_+$', '');
if strlength(string(textValue)) > 80
    textValue = [textValue(1:80), '_more'];
end
end

function value = localNormalizeOption(value)
value = lower(string(value));
value = regexprep(value, '[\s-]+', '_');
end
