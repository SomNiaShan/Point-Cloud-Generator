function points = recipe_matrix_to_points(recipeMatrix, config)
%RECIPE_MATRIX_TO_POINTS Convert a recipe raster to ordered XYZ points.
%   POINTS = RECIPE_MATRIX_TO_POINTS(MATRIX, CONFIG) maps raster cells to
%   physical coordinates and returns them in the requested traversal order.
%
%   Required CONFIG fields:
%     originXYZ       finite numeric [x, y, z], in mm
%     pitchXY         positive finite numeric [x pitch, y pitch], in mm
%     columnDirection '+X' or '-X'
%     rowDirection    '+Y' or '-Y'
%     order           'row_major', 'serpentine', or 'recipe_by_recipe'
%     recipeOrder     optional custom id vector for recipe_by_recipe
%     includeZero     optional logical scalar (default false)
%     matrixRowsTopToBottom
%                     optional logical scalar (default false). When true,
%                     +Y traversal begins with the last matrix row at the
%                     origin and advances upward, preserving the visual
%                     orientation of an image whose first row is its top.
%
%   Recipe id 0 is omitted unless includeZero is true. POINTS is a table
%   containing row_index, column_index, recipe_id, x_mm, y_mm, and z_mm.
%   recipe_by_recipe processes ids in ascending order by default and
%   preserves serpentine traversal order within each recipe. recipeOrder
%   can override the group order and must contain every emitted id once.

localValidateRecipeMatrix(recipeMatrix);
if nargin < 2 || ~isstruct(config) || ~isscalar(config)
    error('recipeMatrix:InvalidCoordinateConfig', ...
        'Coordinate configuration must be a scalar struct.');
end

originXYZ = localRequiredNumericVector(config, 'originXYZ', 3);
pitchXY = localRequiredNumericVector(config, 'pitchXY', 2);
if any(pitchXY <= 0)
    error('recipeMatrix:InvalidPitch', ...
        'pitchXY values must be finite positive distances in mm.');
end

columnSign = localDirectionSign(config, 'columnDirection', '+X', '-X');
rowSign = localDirectionSign(config, 'rowDirection', '+Y', '-Y');
order = localRequiredOption(config, 'order');
if ~ismember(order, ["row_major", "serpentine", "recipe_by_recipe"])
    error('recipeMatrix:InvalidOrder', ...
        'Point order must be row_major, serpentine, or recipe_by_recipe.');
end
includeZero = false;
if isfield(config, 'includeZero')
    includeZero = config.includeZero;
    if ~((islogical(includeZero) || isnumeric(includeZero)) && ...
            isscalar(includeZero) && isfinite(includeZero) && ...
            ismember(double(includeZero), [0, 1]))
        error('recipeMatrix:InvalidCoordinateConfig', ...
            'includeZero must be a logical scalar.');
    end
    includeZero = logical(includeZero);
end
matrixRowsTopToBottom = false;
if isfield(config, 'matrixRowsTopToBottom')
    matrixRowsTopToBottom = config.matrixRowsTopToBottom;
    if ~((islogical(matrixRowsTopToBottom) || isnumeric(matrixRowsTopToBottom)) && ...
            isscalar(matrixRowsTopToBottom) && isfinite(matrixRowsTopToBottom) && ...
            ismember(double(matrixRowsTopToBottom), [0, 1]))
        error('recipeMatrix:InvalidCoordinateConfig', ...
            'matrixRowsTopToBottom must be a logical scalar.');
    end
    matrixRowsTopToBottom = logical(matrixRowsTopToBottom);
end

rowCount = size(recipeMatrix, 1);
columnCount = size(recipeMatrix, 2);
totalCount = numel(recipeMatrix);
sourceRowOrder = 1:rowCount;
if matrixRowsTopToBottom && rowSign > 0
    sourceRowOrder = rowCount:-1:1;
end
rowIndexes = repelem(sourceRowOrder.', columnCount);
traversalRowIndexes = repelem((1:rowCount).', columnCount);
columnIndexes = repmat((1:columnCount).', rowCount, 1);
rowIndexes = rowIndexes(:);
traversalRowIndexes = traversalRowIndexes(:);
columnIndexes = columnIndexes(:);

if ismember(order, ["serpentine", "recipe_by_recipe"]) && rowCount > 1
    evenRows = mod(traversalRowIndexes, 2) == 0;
    columnIndexes(evenRows) = columnCount - columnIndexes(evenRows) + 1;
end

linearIndexes = rowIndexes + (columnIndexes - 1) * rowCount;
recipeIds = double(recipeMatrix(linearIndexes));
recipeIds = recipeIds(:);
processMask = includeZero | recipeIds ~= 0;
rowIndexes = rowIndexes(processMask);
columnIndexes = columnIndexes(processMask);
recipeIds = recipeIds(processMask);

if order == "recipe_by_recipe"
    originalOrder = (1:numel(recipeIds)).';
    groupRanks = recipeIds;
    if isfield(config, 'recipeOrder') && ~isempty(config.recipeOrder)
        recipeOrder = localRecipeOrder(config.recipeOrder, recipeIds);
        [~, groupRanks] = ismember(recipeIds, recipeOrder);
    end
    [~, groupedOrder] = sortrows([groupRanks, originalOrder], [1, 2]);
    rowIndexes = rowIndexes(groupedOrder);
    columnIndexes = columnIndexes(groupedOrder);
    recipeIds = recipeIds(groupedOrder);
end

x = originXYZ(1) + columnSign * (double(columnIndexes) - 1) * pitchXY(1);
rowOffsets = double(rowIndexes) - 1;
if matrixRowsTopToBottom && rowSign > 0
    rowOffsets = rowCount - double(rowIndexes);
end
y = originXYZ(2) + rowSign * rowOffsets * pitchXY(2);
z = repmat(originXYZ(3), nnz(processMask), 1);

points = table(double(rowIndexes), double(columnIndexes), recipeIds, ...
    x, y, z, 'VariableNames', ...
    {'row_index', 'column_index', 'recipe_id', 'x_mm', 'y_mm', 'z_mm'});

if height(points) > totalCount
    error('recipeMatrix:InvalidPointCount', ...
        'Recipe point conversion produced an invalid number of points.');
end
end

function recipeOrder = localRecipeOrder(rawOrder, emittedIds)
if ~(isnumeric(rawOrder) || islogical(rawOrder)) || ...
        ~isvector(rawOrder) || ~isreal(rawOrder)
    error('recipeMatrix:InvalidRecipeOrder', ...
        'recipeOrder must be a numeric vector of Recipe IDs.');
end
recipeOrder = double(rawOrder(:));
if isempty(recipeOrder) || any(~isfinite(recipeOrder)) || ...
        any(recipeOrder < 0) || any(recipeOrder ~= fix(recipeOrder)) || ...
        any(recipeOrder > flintmax) || ...
        numel(unique(recipeOrder)) ~= numel(recipeOrder)
    error('recipeMatrix:InvalidRecipeOrder', ...
        'recipeOrder must contain unique finite nonnegative integer IDs.');
end

expectedIds = unique(emittedIds, 'sorted');
if ~isequal(sort(recipeOrder), expectedIds)
    error('recipeMatrix:InvalidRecipeOrder', ...
        'recipeOrder must contain every emitted Recipe ID exactly once.');
end
end

function localValidateRecipeMatrix(recipeMatrix)
if ~(isnumeric(recipeMatrix) || islogical(recipeMatrix)) || ...
        isempty(recipeMatrix) || ~ismatrix(recipeMatrix) || ~isreal(recipeMatrix)
    error('recipeMatrix:InvalidMatrix', ...
        'Recipe matrix must be a nonempty real numeric matrix.');
end

values = double(recipeMatrix);
if any(~isfinite(values), 'all') || any(values < 0, 'all') || ...
        any(values ~= fix(values), 'all') || any(values > flintmax, 'all')
    error('recipeMatrix:InvalidMatrix', ...
        'Recipe matrix values must be finite nonnegative integer ids.');
end
end

function values = localRequiredNumericVector(config, fieldName, expectedLength)
if ~isfield(config, fieldName)
    error('recipeMatrix:MissingCoordinateConfig', ...
        'Coordinate configuration is missing field %s.', fieldName);
end
values = config.(fieldName);
if ~(isnumeric(values) && isreal(values) && numel(values) == expectedLength && ...
        all(isfinite(values), 'all'))
    error('recipeMatrix:InvalidCoordinateConfig', ...
        '%s must contain %d finite numeric values.', fieldName, expectedLength);
end
values = double(reshape(values, 1, []));
end

function signValue = localDirectionSign(config, fieldName, positiveOption, negativeOption)
if ~isfield(config, fieldName)
    error('recipeMatrix:MissingCoordinateConfig', ...
        'Coordinate configuration is missing field %s.', fieldName);
end
value = config.(fieldName);
if ~(ischar(value) || (isstring(value) && isscalar(value)))
    error('recipeMatrix:InvalidCoordinateConfig', ...
        '%s must be a text scalar.', fieldName);
end
option = strtrim(string(value));
if ismissing(option) || strlength(option) == 0
    error('recipeMatrix:InvalidCoordinateConfig', ...
        '%s must be a nonblank text scalar.', fieldName);
end
if strcmpi(option, positiveOption)
    signValue = 1;
elseif strcmpi(option, negativeOption)
    signValue = -1;
else
    error('recipeMatrix:InvalidDirection', ...
        '%s must be %s or %s.', fieldName, positiveOption, negativeOption);
end
end

function option = localRequiredOption(config, fieldName)
if ~isfield(config, fieldName)
    error('recipeMatrix:MissingCoordinateConfig', ...
        'Coordinate configuration is missing field %s.', fieldName);
end
value = config.(fieldName);
if ~(ischar(value) || (isstring(value) && isscalar(value)))
    error('recipeMatrix:InvalidCoordinateConfig', ...
        '%s must be a text scalar.', fieldName);
end
option = lower(strtrim(string(value)));
if ismissing(option) || strlength(option) == 0
    error('recipeMatrix:InvalidCoordinateConfig', ...
        '%s must be a nonblank text scalar.', fieldName);
end
option = regexprep(option, '[\s-]+', '_');
end
