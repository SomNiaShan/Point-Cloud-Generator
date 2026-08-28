classdef TestParseParameterRowValues < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPath(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            supportFolder = fullfile(repoRoot, 'support_files');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(supportFolder));
        end
    end

    methods (Test)
        function parsesCellLinesInOrder(testCase)
            values = parse_parameter_row_values( ...
                {'1'; '0.5'; '0.1'}, 'Dwell values');

            testCase.verifyEqual(values, [1; 0.5; 0.1], 'AbsTol', 1e-12);
        end

        function ignoresBlankLinesAndParsesScientificNotation(testCase)
            rawValue = ["  1e-2  "; ""; "2.5E+1"; "   "];

            values = parse_parameter_row_values(rawValue, 'Speed values');

            testCase.verifyEqual(values, [0.01; 25], 'AbsTol', 1e-12);
        end

        function reportsThePhysicalLineOfBadInput(testCase)
            rawValue = ["1"; ""; "not-a-number"; "2"];

            [didThrow, message] = localCaptureError( ...
                @() parse_parameter_row_values(rawValue, 'Speed values'));

            testCase.verifyTrue(didThrow);
            testCase.verifyTrue(contains(message, ...
                'Speed values line 3 must be one finite number greater than 0.'));
        end

        function rejectsEmptyInput(testCase)
            emptyInputs = {'', cell(0, 1), "", strings(0, 1)};

            for iCase = 1:numel(emptyInputs)
                [didThrow, message] = localCaptureError( ...
                    @() parse_parameter_row_values(emptyInputs{iCase}, 'Speed values'));

                testCase.verifyTrue(didThrow, sprintf( ...
                    'Expected empty input case %d to be rejected.', iCase));
                testCase.verifyTrue(contains(message, ...
                    'Speed values must contain at least one value greater than 0.'));
            end
        end

        function rejectsInvalidNumericLines(testCase)
            invalidLines = {'0', '-0.5', 'NaN', 'Inf', '1 2'};

            for iCase = 1:numel(invalidLines)
                [didThrow, message] = localCaptureError( ...
                    @() parse_parameter_row_values(invalidLines{iCase}, 'Dwell values'));

                testCase.verifyTrue(didThrow, sprintf( ...
                    'Expected invalid numeric line case %d to be rejected.', iCase));
                testCase.verifyTrue(contains(message, ...
                    'Dwell values line 1 must be one finite number greater than 0.'));
            end
        end
    end
end

function [didThrow, message] = localCaptureError(functionHandle)
didThrow = false;
message = '';
try
    functionHandle();
catch err
    didThrow = true;
    message = err.message;
end
end
