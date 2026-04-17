function fig = hexagon_matrix_coordinate_generator_app()
%HEXAGON_MATRIX_COORDINATE_GENERATOR_APP Launch the hexagon generator app.

baseFolder = fileparts(mfilename('fullpath'));

if exist(fullfile(baseFolder, 'hexagon_matrix_coordinate_generator_app_impl.m'), 'file') ~= 2
    error('hexagon_matrix_coordinate_generator_app_impl.m was not found in the repository root.');
end

if exist('hexagon_matrix_coordinate_generator_app_impl', 'file') ~= 2
    addpath(baseFolder);
end

fig = hexagon_matrix_coordinate_generator_app_impl();
end
