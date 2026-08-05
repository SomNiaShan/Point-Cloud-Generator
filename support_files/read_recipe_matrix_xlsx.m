function [recipeMatrix, info] = read_recipe_matrix_xlsx(filePath, sheetName)
%READ_RECIPE_MATRIX_XLSX Read and validate an Excel recipe raster.
%   [MATRIX, INFO] = READ_RECIPE_MATRIX_XLSX(FILEPATH, SHEETNAME) reads the
%   selected worksheet from an .xlsx file. Blank rows and columns around the
%   data are removed. Every cell inside the remaining rectangle must contain
%   one finite, nonnegative integer. Recipe id 0 is reserved for locations
%   that are not processed.
%
%   INFO contains rowCount, columnCount, recipeIds, recipeCounts,
%   countsTable, totalPixelCount, activePointCount, and skippedPointCount.

if nargin < 2
    error('recipeMatrix:MissingSheet', ...
        'An Excel worksheet name must be specified.');
end

filePath = localScalarText(filePath, 'Excel file path', ...
    'recipeMatrix:InvalidFilePath');
sheetName = localScalarText(sheetName, 'Excel worksheet name', ...
    'recipeMatrix:MissingSheet');

if exist(filePath, 'file') ~= 2
    error('recipeMatrix:MissingFile', ...
        'Excel recipe file was not found: %s', filePath);
end
[~, ~, extension] = fileparts(filePath);
if ~strcmpi(extension, '.xlsx')
    error('recipeMatrix:InvalidFileType', ...
        'Excel recipe files must use the .xlsx extension.');
end

try
    availableSheets = string(sheetnames(filePath));
catch ME
    exception = MException('recipeMatrix:UnreadableWorkbook', ...
        'Could not inspect Excel recipe file "%s".', filePath);
    throwAsCaller(addCause(exception, ME));
end

sheetMatch = find(availableSheets == string(sheetName), 1);
if isempty(sheetMatch)
    error('recipeMatrix:UnknownSheet', ...
        'Worksheet "%s" was not found in "%s". Available worksheets: %s.', ...
        sheetName, filePath, strjoin(availableSheets, ', '));
end
selectedSheet = availableSheets(sheetMatch);

try
    rawCells = readcell(filePath, 'Sheet', char(selectedSheet));
catch ME
    exception = MException('recipeMatrix:UnreadableSheet', ...
        'Could not read worksheet "%s" from "%s".', selectedSheet, filePath);
    throwAsCaller(addCause(exception, ME));
end

if isempty(rawCells)
    error('recipeMatrix:EmptySheet', ...
        'Worksheet "%s" does not contain a recipe matrix.', selectedSheet);
end
if ~iscell(rawCells)
    rawCells = num2cell(rawCells);
end

blankMask = cellfun(@localIsBlankCell, rawCells);
nonblankRows = find(any(~blankMask, 2));
nonblankColumns = find(any(~blankMask, 1));
if isempty(nonblankRows) || isempty(nonblankColumns)
    error('recipeMatrix:EmptySheet', ...
        'Worksheet "%s" does not contain a recipe matrix.', selectedSheet);
end

firstRow = nonblankRows(1);
lastRow = nonblankRows(end);
firstColumn = nonblankColumns(1);
lastColumn = nonblankColumns(end);
matrixCells = rawCells(firstRow:lastRow, firstColumn:lastColumn);
matrixBlankMask = blankMask(firstRow:lastRow, firstColumn:lastColumn);

if any(matrixBlankMask, 'all')
    [localRow, localColumn] = find(matrixBlankMask, 1);
    sourceRow = firstRow + localRow - 1;
    sourceColumn = firstColumn + localColumn - 1;
    error('recipeMatrix:InternalBlank', ...
        ['Recipe matrix must be a complete rectangle. Cell %s is blank ', ...
         'inside the detected matrix.'], ...
        localExcelCellAddress(sourceRow, sourceColumn));
end

numericMask = cellfun(@localIsNumericScalar, matrixCells);
if any(~numericMask, 'all')
    [localRow, localColumn] = find(~numericMask, 1);
    sourceRow = firstRow + localRow - 1;
    sourceColumn = firstColumn + localColumn - 1;
    error('recipeMatrix:InvalidCellType', ...
        ['Recipe matrix cell %s must contain a numeric recipe id. ', ...
         'Text and other cell types are not supported.'], ...
        localExcelCellAddress(sourceRow, sourceColumn));
end

recipeMatrix = cellfun(@double, matrixCells);
invalidFiniteMask = ~isfinite(recipeMatrix);
if any(invalidFiniteMask, 'all')
    [localRow, localColumn] = find(invalidFiniteMask, 1);
    error('recipeMatrix:NonfiniteValue', ...
        'Recipe matrix cell %s must contain a finite value.', ...
        localExcelCellAddress(firstRow + localRow - 1, ...
        firstColumn + localColumn - 1));
end

invalidIntegerMask = recipeMatrix < 0 | recipeMatrix ~= fix(recipeMatrix) | ...
    recipeMatrix > flintmax;
if any(invalidIntegerMask, 'all')
    [localRow, localColumn] = find(invalidIntegerMask, 1);
    error('recipeMatrix:InvalidRecipeId', ...
        ['Recipe matrix cell %s must contain an exactly representable ', ...
         'nonnegative integer recipe id.'], ...
        localExcelCellAddress(firstRow + localRow - 1, ...
        firstColumn + localColumn - 1));
end

[recipeIds, ~, groupIndexes] = unique(recipeMatrix(:), 'sorted');
recipeCounts = accumarray(groupIndexes, 1);
countsTable = table(recipeIds, recipeCounts, ...
    'VariableNames', {'recipe_id', 'pixel_count'});

info = struct();
info.filePath = string(filePath);
info.sheetName = selectedSheet;
info.rowCount = size(recipeMatrix, 1);
info.columnCount = size(recipeMatrix, 2);
info.matrixSize = size(recipeMatrix);
info.recipeIds = recipeIds;
info.recipeCounts = recipeCounts;
info.countsTable = countsTable;
info.totalPixelCount = numel(recipeMatrix);
info.activePointCount = nnz(recipeMatrix ~= 0);
info.skippedPointCount = nnz(recipeMatrix == 0);
info.sourceRange = string(sprintf('%s%d:%s%d', ...
    localExcelColumnName(firstColumn), firstRow, ...
    localExcelColumnName(lastColumn), lastRow));
end

function value = localScalarText(value, label, errorId)
if ~(ischar(value) || (isstring(value) && isscalar(value)))
    error(errorId, '%s must be nonblank text.', label);
end
textValue = strtrim(string(value));
if ismissing(textValue) || strlength(textValue) == 0
    error(errorId, '%s must be nonblank text.', label);
end
value = char(textValue);
end

function tf = localIsBlankCell(value)
tf = isempty(value);
if tf
    return;
end

try
    missingValue = ismissing(value);
    if isscalar(missingValue) && missingValue
        tf = true;
        return;
    end
catch
end

if isnumeric(value) && isscalar(value) && isnan(value)
    tf = true;
elseif ischar(value) || (isstring(value) && isscalar(value))
    tf = strlength(strtrim(string(value))) == 0;
end
end

function tf = localIsNumericScalar(value)
tf = (isnumeric(value) || islogical(value)) && isscalar(value) && isreal(value);
end

function address = localExcelCellAddress(rowIndex, columnIndex)
address = sprintf('%s%d', localExcelColumnName(columnIndex), rowIndex);
end

function name = localExcelColumnName(columnIndex)
name = '';
while columnIndex > 0
    remainder = mod(columnIndex - 1, 26);
    name = [char(double('A') + remainder), name]; %#ok<AGROW>
    columnIndex = floor((columnIndex - 1) / 26);
end
end
