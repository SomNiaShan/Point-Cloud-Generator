function values = parse_parameter_row_values(rawValue, label)
%PARSE_PARAMETER_ROW_VALUES Parse one positive parameter value per text line.

if nargin < 2 || strlength(string(label)) == 0
    label = 'Custom parameter values';
end
label = char(string(label));

if ischar(rawValue)
    textValue = string(rawValue);
elseif isstring(rawValue)
    textValue = strjoin(rawValue(:), newline);
elseif iscell(rawValue)
    try
        textValue = strjoin(string(rawValue(:)), newline);
    catch
        error('%s must contain text with one value per line.', label);
    end
else
    error('%s must contain text with one value per line.', label);
end

lines = splitlines(textValue);
values = zeros(0, 1);
for iLine = 1:numel(lines)
    lineText = strtrim(lines(iLine));
    if strlength(lineText) == 0
        continue;
    end

    value = str2double(lineText);
    if ~(isscalar(value) && isreal(value) && isfinite(value) && value > 0)
        error('%s line %d must be one finite number greater than 0.', label, iLine);
    end
    values(end + 1, 1) = value; %#ok<AGROW>
end

if isempty(values)
    error('%s must contain at least one value greater than 0.', label);
end
end
