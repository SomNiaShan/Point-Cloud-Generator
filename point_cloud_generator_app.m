function fig = point_cloud_generator_app()
%POINT_CLOUD_GENERATOR_APP Launch the point cloud generator app.

baseFolder = fileparts(mfilename('fullpath'));
generatorFolder = fullfile(baseFolder, 'Coordinate generator');

if exist(fullfile(generatorFolder, 'point_cloud_generator_app_impl.m'), 'file') ~= 2
    error('Coordinate generator app implementation was not found.');
end

addpath(generatorFolder);
fig = point_cloud_generator_app_impl();
end
