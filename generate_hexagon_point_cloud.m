function [data, prefix, summary] = generate_hexagon_point_cloud(params)
%GENERATE_HEXAGON_POINT_CLOUD Generate hexagonal XYZP points for Imported Points.

requiredFields = { ...
    'pointsX', 'pointsY', 'pointsZ', ...
    'pitchXYUm', 'pitchZUm', ...
    'originXUm', 'originYUm', 'originZUm', ...
    'useHcpABShift', 'abDxUm', 'abDyUm'};

for i = 1:numel(requiredFields)
    name = requiredFields{i};
    if ~isfield(params, name)
        error('Missing required parameter "%s".', name);
    end
end

pointsX = localPositiveInteger(params.pointsX, 'Points X');
pointsY = localPositiveInteger(params.pointsY, 'Points Y');
pointsZ = localPositiveInteger(params.pointsZ, 'Points Z');

pitchXYUm = localPositiveScalar(params.pitchXYUm, 'Pitch XY');
pitchZUm = localPositiveScalar(params.pitchZUm, 'Pitch Z');

originXUm = localFiniteScalar(params.originXUm, 'Origin X');
originYUm = localFiniteScalar(params.originYUm, 'Origin Y');
originZUm = localFiniteScalar(params.originZUm, 'Origin Z');
abDxUm = localFiniteScalar(params.abDxUm, 'AB dx');
abDyUm = localFiniteScalar(params.abDyUm, 'AB dy');

if exist('depth2powerMgF2', 'file') ~= 2
    error('depth2powerMgF2.m was not found on the MATLAB path.');
end

if ~isfield(params, 'powerMode') || strlength(string(params.powerMode)) == 0
    params.powerMode = "fixed_value";
end

if ~isfield(params, 'fixedPower') || isempty(params.fixedPower)
    params.fixedPower = 10;
end

if ~isfield(params, 'customFormula')
    params.customFormula = "";
end

if ~isfield(params, 'linearPointsText')
    params.linearPointsText = "";
end

rowSpacingUm = sqrt(3) / 2 * pitchXYUm;
pointCount = pointsX * pointsY * pointsZ;

xUm = zeros(pointCount, 1);
yUm = zeros(pointCount, 1);
zUm = zeros(pointCount, 1);

cursor = 1;
for k = 1:pointsZ
    zLayerUm = originZUm + (k - 1) * pitchZUm;

    if params.useHcpABShift && mod(k, 2) == 0
        layerShiftXUm = abDxUm;
        layerShiftYUm = abDyUm;
    else
        layerShiftXUm = 0;
        layerShiftYUm = 0;
    end

    for j = 1:pointsY
        yRowUm = originYUm + (j - 1) * rowSpacingUm + layerShiftYUm;
        rowOffsetUm = mod(j - 1, 2) * (pitchXYUm / 2);
        xRowUm = originXUm + (0:pointsX-1) * pitchXYUm + rowOffsetUm + layerShiftXUm;

        count = numel(xRowUm);
        idx = cursor:(cursor + count - 1);
        xUm(idx) = xRowUm(:);
        yUm(idx) = yRowUm;
        zUm(idx) = zLayerUm;
        cursor = cursor + count;
    end
end

xMm = xUm / 1000;
yMm = yUm / 1000;
zMm = zUm / 1000;
depthUm = 1070 - (zMm + 0.1) * 1000;

powerMode = lower(strrep(string(params.powerMode), ' ', '_'));
switch powerMode
    case "depth_model"
        power = depth2powerMgF2(depthUm);
    case "fixed_value"
        fixedPower = localNonnegativeScalar(params.fixedPower, 'Fixed Power');
        power = repmat(fixedPower, pointCount, 1);
    case "custom_formula"
        power = localEvaluateCustomFormula(params.customFormula, xUm, yUm, zUm, depthUm);
    case "linear_points"
        power = localEvaluateLinearPoints(params.linearPointsText, zUm);
    otherwise
        error('Unsupported power mode "%s".', params.powerMode);
end

data = [xMm, yMm, zMm, power];

hcpTag = '';
if params.useHcpABShift
    hcpTag = '_hcpAB';
end

powerTag = '';
if powerMode == "fixed_value"
    powerTag = sprintf('_Pfixed_%g', params.fixedPower);
end

prefix = sprintf('%dx%dx%d_hex_xy_%gum_z_%gum%s', ...
    pointsX, pointsY, pointsZ, pitchXYUm, pitchZUm, hcpTag);
prefix = [prefix, powerTag];

summary = struct();
summary.pointCount = pointCount;
summary.rowSpacingUm = rowSpacingUm;
summary.xRangeMm = [min(xMm), max(xMm)];
summary.yRangeMm = [min(yMm), max(yMm)];
summary.zRangeMm = [min(zMm), max(zMm)];
summary.powerRange = [min(power), max(power)];
summary.powerMode = char(powerMode);
summary.powerModeLabel = localPowerModeLabel(powerMode);
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

function power = localEvaluateCustomFormula(formulaText, xUm, yUm, zUm, depthUm)
formulaText = strtrim(string(formulaText));
if strlength(formulaText) == 0
    error('Enter a custom formula for the selected power mode.');
end

x = xUm; %#ok<NASGU>
y = yUm; %#ok<NASGU>
z = zUm; %#ok<NASGU>
depth_um = depthUm; %#ok<NASGU>

try
    power = eval(formulaText);
catch err
    error('Failed to evaluate custom formula: %s', err.message);
end

power = localValidatePowerVector(power, numel(zUm), 'custom formula');
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

function label = localPowerModeLabel(powerMode)
switch powerMode
    case "depth_model"
        label = 'Depth model';
    case "fixed_value"
        label = 'Fixed value';
    case "custom_formula"
        label = 'Custom formula';
    case "linear_points"
        label = 'Linear points';
    otherwise
        label = char(powerMode);
end
end
