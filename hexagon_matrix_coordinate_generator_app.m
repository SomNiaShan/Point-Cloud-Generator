function fig = hexagon_matrix_coordinate_generator_app()
%HEXAGON_MATRIX_COORDINATE_GENERATOR_APP Launch the hexagon generator app.

baseFolder = fileparts(mfilename('fullpath'));
generatorFolder = fullfile(baseFolder, 'Coordinate generator');

if exist(fullfile(generatorFolder, 'hexagon_matrix_coordinate_generator_app_impl.m'), 'file') ~= 2
    error('Hexagon coordinate generator app implementation was not found.');
end

addpath(generatorFolder);
fig = hexagon_matrix_coordinate_generator_app_impl();
end
