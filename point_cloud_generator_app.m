function fig = point_cloud_generator_app()
%POINT_CLOUD_GENERATOR_APP Launch the point cloud generator app.

baseFolder = fileparts(mfilename('fullpath'));

if exist(fullfile(baseFolder, 'point_cloud_generator_app_impl.m'), 'file') ~= 2
    error('point_cloud_generator_app_impl.m was not found in the repository root.');
end

if exist('point_cloud_generator_app_impl', 'file') ~= 2
    addpath(baseFolder);
end

fig = point_cloud_generator_app_impl();
end
