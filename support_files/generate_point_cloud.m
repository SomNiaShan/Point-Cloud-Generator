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
summary.layerTraversalLabel = 'Layer-by-layer';
summary.prefix = prefix;
end

function [data, prefix, summary] = localGenerateStaircaseFull(lattice)
nDepths = localPositiveInteger(localRequireField(lattice, 'nDepths'), 'Depth count');
zStartUm = localFiniteScalar(localRequireField(lattice, 'zStartUm'), 'Z Start');
zStepUm = localFiniteScalar(localRequireField(lattice, 'zStepUm'), 'Z Step');
if zStepUm == 0
    error('Z Step must be non-zero.');
end

nPowers = localPositiveInteger(localRequireField(lattice, 'nPowers'), 'Power count');
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

prefix = localBuildStaircasePrefix( ...
    nDepths, nPowers, zStartUm, zStepUm, powerStart, powerEnd, ...
    patchNx, patchNy, pitchXUm, pitchYUm, gapXUm, gapYUm, originXUm, originYUm);

summary = struct();
summary.pointCount = totalPoints;
summary.sourcePointCount = totalPoints;
summary.xRangeMm = [min(xMm), max(xMm)];
summary.yRangeMm = [min(yMm), max(yMm)];
summary.zRangeMm = [min(zMm), max(zMm)];
summary.powerRange = [min(pVals), max(pVals)];
summary.latticeType = 'staircase';
summary.latticeLabel = 'Staircase';
summary.pitchLabel = sprintf('Patch %dx%d, pitch X/Y: %s/%s um, gap X/Y: %s/%s um', ...
    patchNx, patchNy, ...
    localCompactNumber(pitchXUm), localCompactNumber(pitchYUm), ...
    localCompactNumber(gapXUm), localCompactNumber(gapYUm));
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

function [xUm, yUm, zUm, layerIndex, rowIndex, info] = localGenerateLatticeUm(lattice)
latticeType = localLatticeType(lattice);
counts = localCounts(lattice);
originUm = localVector3(lattice.originUm, 'Origin');

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
        info.pitchLabel = sprintf('Pitch X/Y/Z: %s / %s / %s um', ...
            localCompactNumber(pitchXUm), localCompactNumber(pitchYUm), localCompactNumber(pitchZUm));
        info.rowSpacingUm = pitchYUm;
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
        info.pitchLabel = sprintf('Pitch XY/Z: %s / %s um', ...
            localCompactNumber(pitchXYUm), localCompactNumber(pitchZUm));
        info.rowSpacingUm = rowSpacingUm;
        info.counts = counts;
        info.pitchXYUm = pitchXYUm;
        info.pitchZUm = pitchZUm;
        info.hcpShiftDxUm = shiftDxUm;
        info.hcpShiftDyUm = shiftDyUm;

    otherwise
        error('Unsupported lattice type "%s".', latticeType);
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
                    error('Box size values must all be greater than zero.');
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
                error('Unsupported primitive type "%s".', primitiveType);
        end

    case "custom_formula"
        formulaText = string(localRequireField(region, 'formula'));
        mask = localEvaluateRegionFormula(formulaText, xUm, yUm, zUm);

    otherwise
        error('Unsupported region mode "%s".', regionMode);
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
        error('Unsupported path mode "%s".', pathMode);
end

sortKeys = [layerIndex(:), rowIndex(:), sortX(:)];
[~, order] = sortrows(sortKeys, [1, 2, 3]);
xUm = xUm(order);
yUm = yUm(order);
zUm = zUm(order);
end

function power = localEvaluatePower(powerConfig, powerMode, xUm, yUm, zUm)
switch powerMode
    case "fixed_value"
        fixedValue = localNonnegativeScalar(localFieldOrDefault(powerConfig, 'fixedValue', 10), 'Fixed Power');
        power = repmat(fixedValue, numel(xUm), 1);

    case "custom_formula"
        formulaText = string(localFieldOrDefault(powerConfig, 'formula', ""));
        power = localEvaluateCustomPowerFormula(formulaText, xUm, yUm, zUm);

    case "linear_points"
        pointsText = string(localFieldOrDefault(powerConfig, 'linearPointsText', ""));
        power = localEvaluateLinearPoints(pointsText, zUm);

    case "depth_model"
        if exist('depth2powerMgF2', 'file') ~= 2
            error('depth2powerMgF2.m was not found on the MATLAB path.');
        end

        zMm = zUm / 1000;
        depthUm = 1070 - (zMm + 0.1) * 1000;
        power = depth2powerMgF2(depthUm);
        power = localValidatePowerVector(power, numel(zUm), 'depth model');

    otherwise
        error('Unsupported power mode "%s".', powerMode);
end
end

function power = localEvaluateCustomPowerFormula(formulaText, xUm, yUm, zUm)
formulaText = strtrim(string(formulaText));
if strlength(formulaText) == 0
    error('Enter a custom formula for the selected power mode.');
end

x = xUm; %#ok<NASGU>
y = yUm; %#ok<NASGU>
z = zUm; %#ok<NASGU>

try
    power = eval(formulaText);
catch err
    error('Failed to evaluate custom formula: %s', err.message);
end

power = localValidatePowerVector(power, numel(zUm), 'custom formula');
end

function mask = localEvaluateRegionFormula(formulaText, xUm, yUm, zUm)
formulaText = strtrim(string(formulaText));
if strlength(formulaText) == 0
    error('Enter a custom region formula for the selected mode.');
end

x = xUm; %#ok<NASGU>
y = yUm; %#ok<NASGU>
z = zUm; %#ok<NASGU>

try
    mask = eval(formulaText);
catch err
    error('Failed to evaluate custom region formula: %s', err.message);
end

mask = localValidateMaskVector(mask, numel(zUm));
end

function power = localEvaluateLinearPoints(pointsText, zUm)
[zPoints, powerPoints] = localParseLinearPoints(pointsText);
power = interp1(zPoints, powerPoints, zUm, 'linear', 'extrap');
power = localValidatePowerVector(power, numel(zUm), 'linear points');
end

function [zPoints, powerPoints] = localParseLinearPoints(pointsText)
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
        error('Each linear-points row must contain exactly two numbers: z_um and power.');
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
    error('Enter at least two z-power pairs for linear interpolation.');
end

[zPoints, sortIdx] = sort(zPoints);
powerPoints = powerPoints(sortIdx);

if any(diff(zPoints) == 0)
    error('Z values for linear interpolation must be unique.');
end
end

function prefix = localBuildPrefix(latticeInfo, regionMode, primitiveType, pathMode, powerMode, powerConfig)
switch latticeInfo.type
    case 'cartesian'
        latticeTag = sprintf('%dx%dx%d_cart_px_%s_py_%s_pz_%s', ...
            latticeInfo.counts(1), latticeInfo.counts(2), latticeInfo.counts(3), ...
            localCompactNumber(latticeInfo.pitchXUm), ...
            localCompactNumber(latticeInfo.pitchYUm), ...
            localCompactNumber(latticeInfo.pitchZUm));
    case 'hex'
        latticeTag = sprintf('%dx%dx%d_hex_pxy_%s_pz_%s', ...
            latticeInfo.counts(1), latticeInfo.counts(2), latticeInfo.counts(3), ...
            localCompactNumber(latticeInfo.pitchXYUm), ...
            localCompactNumber(latticeInfo.pitchZUm));
    case 'hcp'
        latticeTag = sprintf('%dx%dx%d_hcp_pxy_%s_pz_%s', ...
            latticeInfo.counts(1), latticeInfo.counts(2), latticeInfo.counts(3), ...
            localCompactNumber(latticeInfo.pitchXYUm), ...
            localCompactNumber(latticeInfo.pitchZUm));
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
    error('Missing required struct field "%s".', fieldName);
end

lattice = params.(fieldName);
end

function value = localRequireField(structValue, fieldName)
if ~isfield(structValue, fieldName)
    error('Missing required field "%s".', fieldName);
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
    error('Lattice counts must contain exactly three numeric values.');
end

counts = reshape(counts, 1, []);
counts(1) = localPositiveInteger(counts(1), 'Points X');
counts(2) = localPositiveInteger(counts(2), 'Points Y');
counts(3) = localPositiveInteger(counts(3), 'Points Z');
end

function vector = localVector3(value, label)
if ~(isnumeric(value) && numel(value) == 3 && all(isfinite(value(:))))
    error('%s must contain exactly three finite numeric values.', label);
end

vector = reshape(double(value), 1, []);
end

function latticeType = localLatticeType(lattice)
latticeType = localNormalizeOption(localRequireField(lattice, 'type'));
allowed = ["cartesian", "hex", "hcp"];
if ~any(latticeType == allowed)
    error('Unsupported lattice type "%s".', latticeType);
end
end

function regionMode = localRegionMode(region)
regionMode = localNormalizeOption(localRequireField(region, 'mode'));
allowed = ["full_block", "primitive", "custom_formula"];
if ~any(regionMode == allowed)
    error('Unsupported region mode "%s".', regionMode);
end
end

function primitiveType = localPrimitiveType(region)
primitiveType = localNormalizeOption(localFieldOrDefault(region, 'primitiveType', 'box'));
allowed = ["box", "cylinder", "sphere", "tube"];
if ~any(primitiveType == allowed)
    error('Unsupported primitive type "%s".', primitiveType);
end
end

function powerMode = localPowerMode(power)
powerMode = localNormalizeOption(localFieldOrDefault(power, 'mode', 'fixed_value'));
allowed = ["fixed_value", "custom_formula", "linear_points", "depth_model"];
if ~any(powerMode == allowed)
    error('Unsupported power mode "%s".', powerMode);
end
end

function pathMode = localPathMode(ordering)
pathMode = localNormalizeOption(localFieldOrDefault(ordering, 'pathMode', 'serpentine'));
allowed = ["row_major", "serpentine"];
if ~any(pathMode == allowed)
    error('Unsupported path mode "%s".', pathMode);
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
    error('%s must be greater than zero.', label);
end
end

function value = localNonnegativeScalar(value, label)
value = localFiniteScalar(value, label);
if value < 0
    error('%s must be greater than or equal to zero.', label);
end
end

function value = localFiniteScalar(value, label)
if ~(isscalar(value) && isnumeric(value) && isfinite(value))
    error('%s must be a finite numeric scalar.', label);
end
end

function power = localValidatePowerVector(power, expectedCount, sourceName)
if isscalar(power)
    power = repmat(power, expectedCount, 1);
else
    power = power(:);
end

if numel(power) ~= expectedCount
    error('The %s output must be a scalar or have one value per point.', sourceName);
end

if any(~isfinite(power))
    error('The %s output contains non-finite values.', sourceName);
end
end

function mask = localValidateMaskVector(mask, expectedCount)
if isscalar(mask)
    mask = repmat(mask, expectedCount, 1);
else
    mask = mask(:);
end

if numel(mask) ~= expectedCount
    error('The custom region formula must return a scalar or one value per point.');
end

if any(~isfinite(mask))
    error('The custom region formula output contains non-finite values.');
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
        label = ['Primitive (', localPrimitiveLabel(primitiveType), ')'];
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
        label = 'Fixed value';
    case "custom_formula"
        label = 'Custom formula';
    case "linear_points"
        label = 'Linear points';
    case "depth_model"
        label = 'Depth model';
    otherwise
        label = char(powerMode);
end
end

function label = localStaircasePowerModeLabel(nPowers, powerStart, powerEnd)
if nPowers == 1
    label = sprintf('Single column (1 level at %s %%)', localCompactNumber(powerStart));
else
    label = sprintf('Per column (%d levels, %s to %s %%)', ...
        nPowers, localCompactNumber(powerStart), localCompactNumber(powerEnd));
end
end

function label = localStaircaseTraversalLabel(zStepUm)
if zStepUm > 0
    label = 'Deep to shallow (Z ascending)';
else
    label = 'Shallow to deep (Z descending)';
end
end

function prefix = localBuildStaircasePrefix( ...
    nDepths, nPowers, zStartUm, zStepUm, powerStart, powerEnd, ...
    patchNx, patchNy, pitchXUm, pitchYUm, gapXUm, gapYUm, originXUm, originYUm)
powerTag = localBuildStaircasePowerTag(nPowers, powerStart, powerEnd);
prefix = sprintf([ ...
    'stair_nd_%d_np_%d_zstart_%s_dz_%s_%s_patch_%dx%d_', ...
    'px_%s_py_%s_gx_%s_gy_%s_ox_%s_oy_%s'], ...
    nDepths, nPowers, ...
    localCompactNumber(zStartUm), localCompactNumber(zStepUm), powerTag, ...
    patchNx, patchNy, ...
    localCompactNumber(pitchXUm), localCompactNumber(pitchYUm), ...
    localCompactNumber(gapXUm), localCompactNumber(gapYUm), ...
    localCompactNumber(originXUm), localCompactNumber(originYUm));
end

function powerTag = localBuildStaircasePowerTag(nPowers, powerStart, powerEnd)
if nPowers == 1
    powerTag = ['P_', localCompactNumber(powerStart)];
else
    powerTag = ['P_', localCompactNumber(powerStart), '_to_', localCompactNumber(powerEnd)];
end
end

function textValue = localCompactNumber(value)
textValue = regexprep(num2str(value, '%.15g'), '\s+', '');
end

function value = localNormalizeOption(value)
value = lower(string(value));
value = regexprep(value, '[\s-]+', '_');
end
