function spec = generator_writing_spec(generatorType)
%GENERATOR_WRITING_SPEC Declare which layer owns each writing-plan setting.

key = localNormalize(generatorType);
spec = struct( ...
    'key', key, ...
    'profile', "configurable", ...
    'powerOwner', "user", ...
    'orderingOwner', "user", ...
    'dwellOwner', "user", ...
    'exposureCountOwner', "user", ...
    'scanAxisOwner', "user", ...
    'scanDirectionOwner', "user", ...
    'scanAnchorOwner', "user", ...
    'scanLengthOwner', "user", ...
    'scanSpeedOwner', "user", ...
    'scanLeadOwner', "user", ...
    'pauseOwner', "user", ...
    'preserveOrder', false, ...
    'profileSummary', "Choose Point dwell or Axis scan.");

switch key
    case {"cartesian", "hex", "hcp"}
        % Defaults above describe the three configurable lattice generators.
    case "staircase"
        spec.powerOwner = "generator";
        spec.orderingOwner = "generator";
        spec.profileSummary = "Choose Point dwell or Axis scan; power and region order come from the staircase matrix.";
    case "scan_parameter_matrix"
        spec.profile = "axis_path";
        spec.powerOwner = "generator";
        spec.orderingOwner = "generator";
        spec.dwellOwner = "none";
        spec.exposureCountOwner = "none";
        spec.scanSpeedOwner = "generator";
        spec.profileSummary = "Axis scan is fixed; speed comes from matrix rows and power from matrix columns.";
    case "point_dwell_parameter_matrix"
        spec.profile = "point";
        spec.powerOwner = "generator";
        spec.orderingOwner = "generator";
        spec.dwellOwner = "generator";
        spec.scanAxisOwner = "none";
        spec.scanDirectionOwner = "none";
        spec.scanAnchorOwner = "none";
        spec.scanLengthOwner = "none";
        spec.scanSpeedOwner = "none";
        spec.scanLeadOwner = "none";
        spec.profileSummary = "Point dwell is fixed; dwell comes from matrix rows and power from matrix columns.";
    case "single_exposure_count_parameter_matrix"
        spec.profile = "point";
        spec.powerOwner = "generator";
        spec.orderingOwner = "generator";
        spec.dwellOwner = "generator";
        spec.exposureCountOwner = "generator";
        spec.scanAxisOwner = "none";
        spec.scanDirectionOwner = "none";
        spec.scanAnchorOwner = "none";
        spec.scanLengthOwner = "none";
        spec.scanSpeedOwner = "none";
        spec.scanLeadOwner = "none";
        spec.preserveOrder = true;
        spec.profileSummary = "Point dwell is fixed; every matrix exposure uses a 200 us shutter dwell.";
    case "segmented_grating"
        spec.profile = "axis_path";
        spec.orderingOwner = "generator";
        spec.dwellOwner = "none";
        spec.exposureCountOwner = "none";
        spec.scanAxisOwner = "generator";
        spec.scanLengthOwner = "generator";
        spec.preserveOrder = true;
        spec.profileSummary = "Axis scan is fixed; scan axis and length come from the grating geometry.";
    case "z_push"
        spec.profile = "point";
        spec.orderingOwner = "generator";
        spec.scanAxisOwner = "none";
        spec.scanDirectionOwner = "none";
        spec.scanAnchorOwner = "none";
        spec.scanLengthOwner = "none";
        spec.scanSpeedOwner = "none";
        spec.scanLeadOwner = "none";
        spec.pauseOwner = "generator";
        spec.preserveOrder = true;
        spec.profileSummary = "Point dwell is fixed; Z Push Interval supplies the pause after each move.";
    case {"hexagon_cut", "hexagon_release_cut", ...
            "hexagon_release_cut_array", "circle_release_cut"}
        spec.profile = "recipe_path";
        spec.powerOwner = "generator";
        spec.orderingOwner = "generator";
        spec.dwellOwner = "none";
        spec.exposureCountOwner = "none";
        spec.scanAxisOwner = "generator";
        spec.scanDirectionOwner = "generator";
        spec.scanAnchorOwner = "generator";
        spec.scanLengthOwner = "generator";
        spec.scanSpeedOwner = "generator";
        spec.scanLeadOwner = "generator";
        spec.pauseOwner = "generator";
        spec.preserveOrder = true;
        spec.profileSummary = "Recipe path is fixed; cut geometry and motion define every laser-off/on segment.";
    otherwise
        error('generatorWritingSpec:UnsupportedType', ...
            'Unsupported Generator Type: "%s".', string(generatorType));
end
end

function value = localNormalize(value)
value = lower(strtrim(string(value)));
value = regexprep(value, '[^a-z0-9]+', '_');
value = regexprep(value, '^_+|_+$', '');
if ~isscalar(value) || strlength(value) == 0
    error('generatorWritingSpec:InvalidType', ...
        'Generator Type must be one nonempty value.');
end
end
