classdef TestGeneratorUiIntegration < matlab.unittest.TestCase
    methods (Test)
        function integratedWritingProfilesAndDirtyState(testCase)
            appFolder = fileparts(fileparts(mfilename('fullpath')));
            addpath(appFolder, '-begin');
            [fig, appUi] = point_cloud_generator_app();
            cleanup = onCleanup(@() close(fig));
            drawnow;

            generatorTab = testCase.localTagged(appUi, 'generator-tab');
            patternTab = testCase.localTagged(appUi, 'excel-pattern-tab');
            testCase.verifyEqual(string(generatorTab.Title), "Generator");
            testCase.verifyEqual(string(patternTab.Title), "Excel Pattern");
            testCase.verifyEmpty(findall(fig, 'Title', 'Writing Settings'));
            testCase.verifyEqual(appUi.OriginZField.Value, 0);
            testCase.verifyEqual(appUi.ZPushOriginZField.Value, 0);
            testCase.verifyEqual(appUi.PatternOriginZField.Value, 0);

            generator = testCase.localTagged(appUi, 'generator-type');
            exposure = testCase.localTagged(appUi, 'exposure-mode');
            powerPanel = testCase.localTagged(appUi, 'writing-power-panel');
            planPanel = testCase.localTagged(appUi, 'writing-plan-panel');
            pathModeRow = testCase.localTagged(appUi, 'path-mode-row');
            profile = testCase.localTagged(appUi, 'writing-profile-summary');
            generate = testCase.localTagged(appUi, 'generate-preview');
            save = testCase.localTagged(appUi, 'save-plan');
            status = testCase.localTagged(appUi, 'status-label');

            types = [ ...
                "Cartesian", "Hex", "HCP", "Staircase", ...
                "Scan Parameter Matrix", "Point Dwell Parameter Matrix", ...
                "Single Exposure Count Parameter Matrix", "Segmented Grating", ...
                "Z Push", "Hexagon Cut", "Hexagon Release Cut", ...
                "Hexagon Release Cut Array", "Circle Release Cut"];
            profiles = [ ...
                "configurable", "configurable", "configurable", "configurable", ...
                "axis_path", "point", "point", "axis_path", "point", ...
                "recipe_path", "recipe_path", "recipe_path", "recipe_path"];
            powerVisible = [true, true, true, false, false, false, false, ...
                true, true, false, false, false, false];
            orderEditable = [true, true, true, false, false, false, false, ...
                false, false, false, false, false, false];

            for iType = 1:numel(types)
                generator.Value = char(types(iType));
                testCase.localInvoke(generator);
                drawnow;
                testCase.verifyEqual(string(powerPanel.Visible), testCase.localOnOff(powerVisible(iType)), types(iType));
                testCase.verifyEqual(string(pathModeRow.Visible), testCase.localOnOff(orderEditable(iType)), types(iType));
                if profiles(iType) == "configurable"
                    testCase.verifyEqual(string(exposure.Enable), "on", types(iType));
                    testCase.verifyEqual(string(planPanel.Visible), "on", types(iType));
                elseif profiles(iType) == "recipe_path"
                    testCase.verifyEqual(string(planPanel.Visible), "off", types(iType));
                    testCase.verifyTrue(contains(string(profile.Text), "Recipe path (fixed)"), types(iType));
                else
                    testCase.verifyEqual(string(exposure.Enable), "off", types(iType));
                    testCase.verifyEqual(string(planPanel.Visible), "on", types(iType));
                end
                testCase.localInvoke(generate);
                testCase.verifyTrue(startsWith(string(status.Text), "Generated"), types(iType));
                testCase.verifyEqual(string(save.Enable), "on", types(iType));
            end

            % Drafts do not leak between generator types.
            scanSpeed = testCase.localTagged(appUi, 'scan-speed');
            generator.Value = 'Cartesian';
            testCase.localInvoke(generator);
            scanSpeed.Value = 0.123;
            testCase.localInvoke(scanSpeed);
            generator.Value = 'Hex';
            testCase.localInvoke(generator);
            testCase.verifyEqual(scanSpeed.Value, 0.01, 'AbsTol', 1e-12);
            scanSpeed.Value = 0.456;
            testCase.localInvoke(scanSpeed);
            generator.Value = 'Cartesian';
            testCase.localInvoke(generator);
            testCase.verifyEqual(scanSpeed.Value, 0.123, 'AbsTol', 1e-12);

            % Generate creates a saveable snapshot; any input edit invalidates it.
            testCase.localInvoke(generate);
            testCase.verifyEqual(string(save.Enable), "on");
            fixedPower = testCase.localTagged(appUi, 'fixed-power');
            fixedPower.Value = fixedPower.Value + 1;
            testCase.localInvoke(fixedPower);
            testCase.verifyEqual(string(save.Enable), "off");

            % Invalid hidden scan settings cannot block a point-only generator.
            generator.Value = 'Point Dwell Parameter Matrix';
            testCase.localInvoke(generator);
            scanSpeed.Value = 0;
            testCase.localInvoke(generate);
            testCase.verifyTrue(startsWith(string(status.Text), "Generated"));

            % Explicit cut recipes ignore every hidden generic point/scan value.
            generator.Value = 'Hexagon Cut';
            testCase.localInvoke(generator);
            testCase.localTagged(appUi, 'dwell-seconds').Value = -1;
            testCase.localTagged(appUi, 'scan-length').Value = 0;
            scanSpeed.Value = 0;
            testCase.localInvoke(generate);
            testCase.verifyTrue(startsWith(string(status.Text), "Generated"));
        end
    end

    methods (Access = private)
function component = localTagged(~, appUi, tag)
component = gobjects(0);
if isstruct(appUi)
    values = struct2cell(appUi);
    for iValue = 1:numel(values)
        value = values{iValue};
        for iItem = 1:numel(value)
            try
                if isgraphics(value(iItem)) && isprop(value(iItem), 'Tag') && ...
                        strcmp(value(iItem).Tag, tag)
                    component(end + 1, 1) = value(iItem); %#ok<AGROW>
                end
            catch
            end
        end
    end
end
if numel(component) ~= 1
    error('Expected one component tagged "%s"; found %d.', tag, numel(component));
end
end

function localInvoke(~, component)
if isprop(component, 'ButtonPushedFcn') && ~isempty(component.ButtonPushedFcn)
    callback = component.ButtonPushedFcn;
elseif isprop(component, 'ValueChangedFcn') && ~isempty(component.ValueChangedFcn)
    callback = component.ValueChangedFcn;
else
    error('Component does not expose an invokable callback.');
end
if isa(callback, 'function_handle')
    callback(component, []);
else
    feval(callback{1}, component, [], callback{2:end});
end
end

function value = localOnOff(~, tf)
if tf
    value = "on";
else
    value = "off";
end
end
    end
end
