function rowCount = estimate_generator_source_rows(params)
%ESTIMATE_GENERATOR_SOURCE_ROWS Estimate generator output before allocation.

if ~isstruct(params) || ~isfield(params, 'lattice') || ~isstruct(params.lattice)
    error('estimateGeneratorRows:InvalidParams', ...
        'Generator params must contain a lattice struct.');
end
lattice = params.lattice;
type = localNormalize(localField(lattice, 'type'));

switch type
    case {"cartesian", "hex", "hcp"}
        rowCount = localProduct(localField(lattice, 'counts'), 'Lattice counts');
    case "staircase"
        rowCount = localProduct([lattice.nDepths, lattice.nPowers, ...
            lattice.patchNx, lattice.patchNy], 'Staircase counts');
    case "scan_parameter_matrix"
        rowCount = localProduct([lattice.nSpeeds, lattice.nPowers, ...
            lattice.patchNx, lattice.patchNy], 'Scan matrix counts');
    case "point_dwell_parameter_matrix"
        rowCount = localProduct([lattice.nDwells, lattice.nPowers, ...
            lattice.patchNx, lattice.patchNy], 'Dwell matrix counts');
    case "single_exposure_count_parameter_matrix"
        rowCount = localProduct([lattice.nExposureCounts, lattice.nPowers, ...
            lattice.patchNx, lattice.patchNy], 'Exposure-count matrix counts');
    case "segmented_grating"
        starts = localField(lattice, 'channelStartsUm');
        if ~(isnumeric(starts) && size(starts, 2) == 4)
            error('estimateGeneratorRows:InvalidGratingStarts', ...
                'Grating channel starts must be an N-by-4 numeric matrix.');
        end
        perDepth = nnz(isfinite(starts(:, 3))) * lattice.nPeriods1 * lattice.slabCopies1 + ...
            nnz(isfinite(starts(:, 4))) * lattice.nPeriods2 * lattice.slabCopies2;
        rowCount = localProduct([lattice.nDepths, perDepth], 'Grating counts');
    case "z_push"
        rowCount = localProduct(lattice.pushCount, 'Z Push count');
    case "hexagon_cut"
        rowCount = 6;
    case {"hexagon_release_cut", "hexagon_release_cut_array"}
        perCellLayer = 6 * lattice.releaseRingCount + ...
            localHatchUpperBound(lattice.sideLengthUm, lattice.releaseHatchPitchUm);
        cellCount = 1;
        if type == "hexagon_release_cut_array"
            cellCount = nnz(lattice.arraySelectionMask);
        end
        rowCount = localProduct([perCellLayer, lattice.releaseLayerCount, ...
            lattice.releaseRepeatCount, cellCount], 'Hexagon release counts');
    case "circle_release_cut"
        perLayer = lattice.segmentCount * lattice.releaseRingCount + ...
            localHatchUpperBound(lattice.radiusUm, lattice.releaseHatchPitchUm);
        rowCount = localProduct([perLayer, lattice.releaseLayerCount, ...
            lattice.releaseRepeatCount], 'Circle release counts');
    otherwise
        error('estimateGeneratorRows:UnsupportedType', ...
            'Unsupported Generator Type: "%s".', string(lattice.type));
end
end

function count = localHatchUpperBound(radiusUm, pitchUm)
if ~(isscalar(pitchUm) && isnumeric(pitchUm) && isfinite(pitchUm)) || pitchUm <= 0
    count = 0;
    return;
end
if ~(isscalar(radiusUm) && isnumeric(radiusUm) && isfinite(radiusUm) && radiusUm >= 0)
    count = inf;
    return;
end
count = 3 * (ceil(2 * radiusUm / pitchUm) + 2);
end

function value = localProduct(values, label)
if ~(isnumeric(values) && isreal(values) && ~isempty(values) && ...
        all(isfinite(values(:))) && all(values(:) >= 0))
    error('estimateGeneratorRows:InvalidCount', ...
        '%s must contain finite nonnegative values.', label);
end
value = prod(double(values(:)));
if ~isfinite(value) || value > flintmax
    error('estimateGeneratorRows:Overflow', ...
        '%s exceed the supported numeric range.', label);
end
value = round(value);
end

function value = localField(config, name)
if ~isfield(config, name)
    error('estimateGeneratorRows:MissingField', ...
        'Generator config is missing field "%s".', name);
end
value = config.(name);
end

function value = localNormalize(value)
value = lower(strtrim(string(value)));
value = regexprep(value, '[^a-z0-9]+', '_');
value = regexprep(value, '^_+|_+$', '');
end
