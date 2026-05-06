function outputs = build_standalone(varargin)
%BUILD_STANDALONE Build a standalone Windows app and optional installer.
%   BUILD_STANDALONE packages point_cloud_generator_app.m by using MATLAB
%   Compiler. By default it creates:
%     1. A standalone executable in deploy/PointCloudGenerator/build
%     2. An installer in deploy/PointCloudGenerator/package
%
%   Example
%     build_standalone
%     build_standalone('RuntimeDelivery','web')
%     build_standalone('BuildInstaller',false)
%
%   Name-value pairs
%     'ExecutableName'        default: 'PointCloudGenerator'
%     'ApplicationName'       default: 'Point Cloud Generator'
%     'InstallerName'         default: 'PointCloudGeneratorInstaller'
%     'Version'               default: '1.0'
%     'OutputRoot'            default: fullfile(repoRoot,'deploy','PointCloudGenerator')
%     'RuntimeDelivery'       default: 'installer'
%     'RuntimeInstallerZip'   default: ''
%     'RuntimeCacheDir'       default: fullfile(getenv('LOCALAPPDATA'),'MathWorks','MatlabRuntimeCache','Persistent')
%     'AutoDownloadRuntime'   default: true
%     'BuildInstaller'        default: true
%     'Verbose'               default: 'on'
%     'Shortcut'              default: '.\PointCloudGenerator.exe'
%     'Summary'               default: 'Point cloud generator desktop application.'
%     'Description'           default: 'Standalone MATLAB point cloud generator.'
%     'ExecutableIcon'        default: ''
%     'ExecutableSplashScreen'default: ''
%     'InstallerIcon'         default: ''
%     'InstallerLogo'         default: ''
%     'InstallerSplash'       default: ''
%     'AdditionalFiles'       default: {}

if ~ispc
    error('build_standalone:WindowsOnly', ...
        'This helper builds a Windows desktop application and must be run on Windows.');
end

if ~(license('test', 'Compiler') || license('test', 'MATLAB_Compiler'))
    error('build_standalone:MissingCompiler', ...
        'MATLAB Compiler is required to build a standalone application.');
end

supportFolder = fileparts(mfilename('fullpath'));
repoRoot = fileparts(supportFolder);
mainFile = fullfile(repoRoot, 'point_cloud_generator_app.m');
if exist(mainFile, 'file') ~= 2
    error('build_standalone:MissingMainFile', ...
        'Could not find point_cloud_generator_app.m in the repository root.');
end
addpath(supportFolder, '-begin');

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'ExecutableName', 'PointCloudGenerator');
addParameter(parser, 'ApplicationName', 'Point Cloud Generator');
addParameter(parser, 'InstallerName', 'PointCloudGeneratorInstaller');
addParameter(parser, 'Version', '1.0');
addParameter(parser, 'OutputRoot', fullfile(repoRoot, 'deploy', 'PointCloudGenerator'));
addParameter(parser, 'RuntimeDelivery', 'installer');
addParameter(parser, 'RuntimeInstallerZip', '');
addParameter(parser, 'RuntimeCacheDir', '');
addParameter(parser, 'AutoDownloadRuntime', true, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'BuildInstaller', true, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'Verbose', 'on');
addParameter(parser, 'Shortcut', '');
addParameter(parser, 'Summary', 'Point cloud generator desktop application.');
addParameter(parser, 'Description', 'Standalone MATLAB point cloud generator.');
addParameter(parser, 'ExecutableIcon', '');
addParameter(parser, 'ExecutableSplashScreen', '');
addParameter(parser, 'InstallerIcon', '');
addParameter(parser, 'InstallerLogo', '');
addParameter(parser, 'InstallerSplash', '');
addParameter(parser, 'AdditionalFiles', {}, @(x) ischar(x) || isstring(x) || iscell(x));
parse(parser, varargin{:});

options = parser.Results;
options.RuntimeDelivery = validatestring(options.RuntimeDelivery, {'installer', 'web', 'none'});
options.Verbose = validatestring(options.Verbose, {'on', 'off'});
options.AutoDownloadRuntime = logical(options.AutoDownloadRuntime);
options.BuildInstaller = logical(options.BuildInstaller);
if isempty(options.Shortcut)
    options.Shortcut = ['.\', options.ExecutableName, '.exe'];
end
if isempty(options.RuntimeCacheDir)
    options.RuntimeCacheDir = fullfile(getenv('LOCALAPPDATA'), 'MathWorks', 'MatlabRuntimeCache', 'Persistent');
end

buildOutputDir = fullfile(options.OutputRoot, 'build');
packageOutputDir = fullfile(options.OutputRoot, 'package');

if exist(options.OutputRoot, 'dir') ~= 7
    mkdir(options.OutputRoot);
end

additionalFiles = localNormalizePaths(options.AdditionalFiles, repoRoot);

buildArgs = { ...
    mainFile, ...
    'ExecutableName', options.ExecutableName, ...
    'OutputDir', buildOutputDir, ...
    'AutoDetectDataFiles', 'on', ...
    'Verbose', options.Verbose};

if ~isempty(additionalFiles)
    buildArgs = [buildArgs, {'AdditionalFiles', additionalFiles}];
end

buildArgs = localAppendFileOption(buildArgs, 'ExecutableIcon', options.ExecutableIcon, repoRoot);
buildArgs = localAppendFileOption(buildArgs, 'ExecutableSplashScreen', options.ExecutableSplashScreen, repoRoot);

fprintf('Building standalone executable: %s\n', options.ExecutableName);
results = compiler.build.standaloneWindowsApplication(buildArgs{:});

outputs = struct();
outputs.buildResults = results;
outputs.buildOutputDir = buildOutputDir;
outputs.packageOutputDir = packageOutputDir;

shortcutTarget = localResolveShortcutTarget(options.Shortcut, buildOutputDir, options.ExecutableName);

if ~options.BuildInstaller
    fprintf('Build complete.\nExecutable output: %s\n', buildOutputDir);
    return;
end

runtimeInstaller = localEnsureRuntimeInstaller(options, repoRoot);
outputs.runtimeInstaller = runtimeInstaller;

installerArgs = { ...
    results, ...
    'ApplicationName', options.ApplicationName, ...
    'InstallerName', options.InstallerName, ...
    'OutputDir', packageOutputDir, ...
    'RuntimeDelivery', options.RuntimeDelivery, ...
    'Version', options.Version, ...
    'Summary', options.Summary, ...
    'Description', options.Description, ...
    'Verbose', options.Verbose};

if ~isempty(shortcutTarget)
    installerArgs = [installerArgs, {'Shortcut', shortcutTarget}];
end

installerArgs = localAppendFileOption(installerArgs, 'InstallerIcon', options.InstallerIcon, repoRoot);
installerArgs = localAppendFileOption(installerArgs, 'InstallerLogo', options.InstallerLogo, repoRoot);
installerArgs = localAppendFileOption(installerArgs, 'InstallerSplash', options.InstallerSplash, repoRoot);

fprintf('Packaging installer: %s\n', options.InstallerName);
compiler.package.installer(installerArgs{:});

fprintf('Packaging complete.\nBuild output: %s\nInstaller output: %s\n', ...
    buildOutputDir, packageOutputDir);
end

function runtimeInstaller = localEnsureRuntimeInstaller(options, repoRoot)
runtimeInstaller = '';

if ~any(strcmp(options.RuntimeDelivery, {'installer', 'none'}))
    return;
end

if ~isempty(options.RuntimeInstallerZip)
    runtimeInstaller = localResolvePath(options.RuntimeInstallerZip, repoRoot);
    if ~localIsValidRuntimeInstaller(runtimeInstaller)
        error('build_standalone:InvalidRuntimeInstaller', ...
            'The specified Runtime installer ZIP is invalid: %s', runtimeInstaller);
    end
    runtimeInstaller = localPersistAndSelectRuntimeInstaller(runtimeInstaller, options.RuntimeCacheDir, options.Verbose);
    return;
end

cachedInstaller = localDefaultRuntimeInstallerPath(options.RuntimeCacheDir);
if ~isempty(cachedInstaller) && localIsValidRuntimeInstaller(cachedInstaller)
    compiler.internal.runtime.utils.setInstallerLocation(cachedInstaller);
    runtimeInstaller = cachedInstaller;
    return;
end

if ~isempty(cachedInstaller) && isfile(cachedInstaller)
    delete(cachedInstaller);
end

runtimeInstaller = localGetValidRuntimeInstaller();
if ~isempty(runtimeInstaller)
    runtimeInstaller = localPersistAndSelectRuntimeInstaller(runtimeInstaller, options.RuntimeCacheDir, options.Verbose);
    return;
end

invalidConfiguredInstaller = localGetConfiguredRuntimeInstaller();
if ~isempty(invalidConfiguredInstaller) && isfile(invalidConfiguredInstaller) && ...
        localIsSafeToDeleteRuntimeCache(invalidConfiguredInstaller)
    delete(invalidConfiguredInstaller);
end

if ~options.AutoDownloadRuntime
    error('build_standalone:MissingRuntimeInstaller', ...
        ['No valid MATLAB Runtime installer ZIP is configured.\n' ...
         'Provide one with build_standalone(''RuntimeInstallerZip'', ''<path-to-zip>'').']);
end

fprintf('Downloading MATLAB Runtime installer. This may take several minutes...\n');
try
    compiler.runtime.download;
catch ME
    runtimeUrl = localGetRuntimeDownloadUrl();
    if strlength(runtimeUrl) > 0
        error('build_standalone:RuntimeDownloadFailed', ...
            ['Automatic MATLAB Runtime download failed.\n' ...
             'Download the following ZIP manually and rerun with:\n' ...
             '  build_standalone(''RuntimeInstallerZip'', ''<path-to-zip>'')\n\n' ...
             '%s\n\nOriginal error:\n%s'], ...
            runtimeUrl, getReport(ME, 'basic', 'hyperlinks', 'off'));
    end
    rethrow(ME);
end

runtimeInstaller = localGetValidRuntimeInstaller();
if isempty(runtimeInstaller)
    runtimeUrl = localGetRuntimeDownloadUrl();
    if strlength(runtimeUrl) > 0
        error('build_standalone:MissingRuntimeInstaller', ...
            ['MATLAB finished the download step, but no valid Runtime installer ZIP was found.\n' ...
             'Download it manually and rerun with:\n' ...
             '  build_standalone(''RuntimeInstallerZip'', ''<path-to-zip>'')\n\n' ...
             '%s'], ...
            runtimeUrl);
    end
    error('build_standalone:MissingRuntimeInstaller', ...
        'MATLAB finished the download step, but no valid Runtime installer ZIP was found.');
end

runtimeInstaller = localPersistAndSelectRuntimeInstaller(runtimeInstaller, options.RuntimeCacheDir, options.Verbose);
end

function runtimeInstaller = localPersistAndSelectRuntimeInstaller(sourceInstaller, runtimeCacheDir, verboseMode)
runtimeInstaller = sourceInstaller;

if isempty(runtimeCacheDir)
    compiler.internal.runtime.utils.setInstallerLocation(runtimeInstaller);
    return;
end

targetInstaller = localDefaultRuntimeInstallerPath(runtimeCacheDir);
if isempty(targetInstaller)
    compiler.internal.runtime.utils.setInstallerLocation(runtimeInstaller);
    return;
end

if ~strcmpi(runtimeInstaller, targetInstaller)
    if exist(runtimeCacheDir, 'dir') ~= 7
        mkdir(runtimeCacheDir);
    end
    if ~localIsValidRuntimeInstaller(targetInstaller)
        if isfile(targetInstaller)
            delete(targetInstaller);
        end
        if strcmp(verboseMode, 'on')
            fprintf('Caching MATLAB Runtime installer: %s\n', targetInstaller);
        end
        [copyOk, copyMsg] = copyfile(runtimeInstaller, targetInstaller, 'f');
        if ~copyOk
            error('build_standalone:RuntimeCacheCopyFailed', ...
                'Failed to copy MATLAB Runtime installer to cache.\n%s', copyMsg);
        end
    end
    runtimeInstaller = targetInstaller;
end

if ~localIsValidRuntimeInstaller(runtimeInstaller)
    error('build_standalone:InvalidRuntimeInstaller', ...
        'The MATLAB Runtime installer ZIP is invalid: %s', runtimeInstaller);
end

compiler.internal.runtime.utils.setInstallerLocation(runtimeInstaller);
end

function paths = localNormalizePaths(value, repoRoot)
if isempty(value)
    paths = {};
    return;
end

if ischar(value) || isstring(value)
    value = cellstr(value);
end

paths = cell(size(value));
for idx = 1:numel(value)
    paths{idx} = localResolvePath(value{idx}, repoRoot);
end
end

function args = localAppendFileOption(args, optionName, filePath, repoRoot)
if isempty(filePath)
    return;
end

resolvedPath = localResolvePath(filePath, repoRoot);
args = [args, {optionName, resolvedPath}];
end

function resolvedPath = localResolvePath(filePath, repoRoot)
resolvedPath = char(filePath);
if ~isempty(resolvedPath) && ~(isfile(resolvedPath) || isfolder(resolvedPath))
    candidate = fullfile(repoRoot, resolvedPath);
    if isfile(candidate) || isfolder(candidate)
        resolvedPath = candidate;
    end
end

if ~(isfile(resolvedPath) || isfolder(resolvedPath))
    error('build_standalone:MissingFile', 'Required file was not found: %s', char(filePath));
end
end

function runtimeInstaller = localGetValidRuntimeInstaller()
try
    runtimeInstaller = compiler.internal.runtime.utils.getExistingMCRInstallerWithValidation();
catch
    runtimeInstaller = '';
end

if ~localIsValidRuntimeInstaller(runtimeInstaller)
    runtimeInstaller = '';
end
end

function configuredInstaller = localGetConfiguredRuntimeInstaller()
result = '';
try
    settingsRoot = settings;
    runtimeInstallerKey = compiler.internal.utils.CLIConstants.RuntimeInstallerKeyCurrentPlatform;
    if settingsRoot.hasGroup('matlabCompiler')
        compilerGroup = settingsRoot.matlabCompiler;
        if compilerGroup.hasSetting(runtimeInstallerKey)
            try
                result = compilerGroup.(runtimeInstallerKey).ActiveValue;
            catch
                result = '';
            end
        end
    end
catch
    result = '';
end
configuredInstaller = result;
end

function tf = localIsValidRuntimeInstaller(installerPath)
tf = false;
if isempty(installerPath) || exist(installerPath, 'file') ~= 2
    return;
end

try
    tf = compiler.internal.runtime.utils.isValidMCRInstaller(installerPath);
catch
    tf = false;
end
end

function installerPath = localDefaultRuntimeInstallerPath(runtimeCacheDir)
installerPath = '';
if isempty(runtimeCacheDir)
    return;
end

installerFileName = localRuntimeInstallerFileName();
if isempty(installerFileName)
    return;
end

installerPath = fullfile(runtimeCacheDir, installerFileName);
end

function installerFileName = localRuntimeInstallerFileName()
runtimeUrl = localGetRuntimeDownloadUrl();
if strlength(runtimeUrl) > 0
    urlText = char(runtimeUrl);
    slashIdx = find(urlText == '/', 1, 'last');
    if ~isempty(slashIdx) && slashIdx < strlength(urlText)
        installerFileName = urlText(slashIdx + 1:end);
        return;
    end
end

releaseName = version('-release');
releaseName = char(releaseName);
arch = lower(computer('arch'));
[~, ~, updateLevel] = mcrversion;
if ~isempty(updateLevel) && updateLevel > 0
    installerFileName = sprintf('MATLAB_Runtime_R%s_Update_%d_%s.zip', releaseName, updateLevel, arch);
else
    installerFileName = sprintf('MATLAB_Runtime_R%s_%s.zip', releaseName, arch);
end
end

function runtimeUrl = localGetRuntimeDownloadUrl()
try
    runtimeUrl = string(char(javaMethod('getMCRInstallerDownloadURL', ...
        'com.mathworks.toolbox.compiler.MatlabRuntimeUtils')));
catch
    runtimeUrl = "";
end
end

function tf = localIsSafeToDeleteRuntimeCache(installerPath)
tf = false;
if isempty(installerPath)
    return;
end

lowerPath = lower(char(installerPath));
tempRoot = lower(char(tempdir));
localCacheRoot = lower(fullfile(getenv('LOCALAPPDATA'), 'MathWorks', 'MatlabRuntimeCache'));
tf = startsWith(lowerPath, tempRoot) || startsWith(lowerPath, localCacheRoot);
end

function shortcutTarget = localResolveShortcutTarget(shortcutOption, buildOutputDir, executableName)
if isempty(shortcutOption)
    shortcutTarget = '';
    return;
end

candidate = char(shortcutOption);
if startsWith(candidate, '.\') || startsWith(candidate, './')
    candidate = fullfile(buildOutputDir, candidate(3:end));
elseif ~isfile(candidate) && ~isfolder(candidate)
    candidate = fullfile(buildOutputDir, candidate);
end

if ~(isfile(candidate) || isfolder(candidate))
    defaultExe = fullfile(buildOutputDir, [executableName, '.exe']);
    if isfile(defaultExe)
        candidate = defaultExe;
    else
        error('build_standalone:MissingShortcutTarget', ...
            'Could not find the shortcut target: %s', char(shortcutOption));
    end
end

shortcutTarget = candidate;
end
