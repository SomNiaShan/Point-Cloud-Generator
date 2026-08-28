classdef TestGeneratorWritingSpec < matlab.unittest.TestCase
    methods (Test)
        function everyGeneratorDeclaresExpectedOwnership(testCase)
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
            powerOwners = [ ...
                "user", "user", "user", "generator", "generator", ...
                "generator", "generator", "user", "user", ...
                "generator", "generator", "generator", "generator"];
            orderingOwners = [ ...
                "user", "user", "user", "generator", "generator", ...
                "generator", "generator", "generator", "generator", ...
                "generator", "generator", "generator", "generator"];

            for iType = 1:numel(types)
                spec = generator_writing_spec(types(iType));
                testCase.verifyEqual(spec.profile, profiles(iType), types(iType));
                testCase.verifyEqual(spec.powerOwner, powerOwners(iType), types(iType));
                testCase.verifyEqual(spec.orderingOwner, orderingOwners(iType), types(iType));
                testCase.verifyNotEmpty(spec.profileSummary, types(iType));
            end
        end

        function specialOwnersAreUnambiguous(testCase)
            scan = generator_writing_spec('Scan Parameter Matrix');
            testCase.verifyEqual(scan.scanSpeedOwner, "generator");
            testCase.verifyEqual(scan.scanLengthOwner, "user");

            dwell = generator_writing_spec('Point Dwell Parameter Matrix');
            testCase.verifyEqual(dwell.dwellOwner, "generator");
            testCase.verifyEqual(dwell.exposureCountOwner, "user");

            exposure = generator_writing_spec('Single Exposure Count Parameter Matrix');
            testCase.verifyEqual(exposure.dwellOwner, "generator");
            testCase.verifyEqual(exposure.exposureCountOwner, "generator");

            grating = generator_writing_spec('Segmented Grating');
            testCase.verifyEqual(grating.scanAxisOwner, "generator");
            testCase.verifyEqual(grating.scanLengthOwner, "generator");

            zPush = generator_writing_spec('Z Push');
            testCase.verifyEqual(zPush.pauseOwner, "generator");
        end

        function unknownGeneratorIsRejected(testCase)
            testCase.verifyError(@() generator_writing_spec('Unknown'), ...
                'generatorWritingSpec:UnsupportedType');
        end
    end
end
