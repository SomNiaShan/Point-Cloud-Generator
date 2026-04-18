function fig = point_cloud_generator_app_CC()
%POINT_CLOUD_GENERATOR_APP_CC Launch the CC version of the point cloud generator app.

baseFolder = fileparts(mfilename('fullpath'));

if exist(fullfile(baseFolder, 'point_cloud_generator_app_impl_CC.m'), 'file') ~= 2
    error('point_cloud_generator_app_impl_CC.m was not found in the repository root.');
end

if exist('point_cloud_generator_app_impl_CC', 'file') ~= 2
    addpath(baseFolder);
end

fig = point_cloud_generator_app_impl_CC();
end
