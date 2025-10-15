% --- SCRIPT CONFIGURATION ---
clear; % Clear workspace variables
clc;   % Clear command window
import systemcomposer.query.*

% --- LOAD MODEL ---
modelName = 'Hospital_Context.slx';
model = systemcomposer.loadModel(modelName);
arch = get(model, "Architecture");

% --- EXTRACT COMPONENTS ---
components = arch.Components;
numComponents = width(components);

% Pre-allocate cell array for component data
componentRows = cell(numComponents, 1);

for i = 1:numComponents
    % Get component name
    compName = components(1,i).Name;

    % Get stereotypes (returns array if multiple stereotypes applied)
    stereotypes = components(1,i).getStereotypes();

    % Create row: [Name, Stereotype1, Stereotype2, ...]
    if isempty(stereotypes)
        componentRows{i} = {compName};
    else
        % Convert stereotypes to cell array if it's a single string
        if ischar(stereotypes) || isstring(stereotypes)
            stereotypes = {char(stereotypes)};
        else
            stereotypes = cellstr(stereotypes);
        end
        componentRows{i} = [compName, stereotypes];
    end
end

% --- EXTRACT CONNECTORS ---
connectors = arch.Connectors;
numConnectors = width(connectors);

% Pre-allocate cell array for connector data
connectorRows = cell(numConnectors, 1);

for i = 1:numConnectors
    % Get connector name
    connName = connectors(1,i).Name;

    % Get stereotypes
    stereotypes = connectors(1,i).getStereotypes();

    % Create row: [Name, Stereotype1, Stereotype2, ...]
    if isempty(stereotypes)
        connectorRows{i} = {connName};
    else
        % Convert stereotypes to cell array if it's a single string
        if ischar(stereotypes) || isstring(stereotypes)
            stereotypes = {char(stereotypes)};
        else
            stereotypes = cellstr(stereotypes);
        end
        connectorRows{i} = [connName, stereotypes];
    end
end

% --- COMBINE INTO SINGLE MATRIX ---
% Find the maximum number of stereotypes to determine matrix width
maxCols = 1; % At least 1 for the name column

for i = 1:numComponents
    maxCols = max(maxCols, length(componentRows{i}));
end

for i = 1:numConnectors
    maxCols = max(maxCols, length(connectorRows{i}));
end

% Create the final matrix with proper dimensions
totalRows = numComponents + numConnectors;
allElementsMatrix = cell(totalRows, maxCols);

% Fill in component data
for i = 1:numComponents
    rowData = componentRows{i};
    allElementsMatrix(i, 1:length(rowData)) = rowData;
end

% Fill in connector data
for i = 1:numConnectors
    rowData = connectorRows{i};
    allElementsMatrix(numComponents + i, 1:length(rowData)) = rowData;
end

% --- DISPLAY RESULTS ---
fprintf('Extracted %d components and %d connectors\n', numComponents, numConnectors);
fprintf('Matrix dimensions: %d rows x %d columns\n\n', size(allElementsMatrix, 1), size(allElementsMatrix, 2));

% Display the matrix
disp('All Elements Matrix:');
disp(allElementsMatrix);

% --- SAVE TO WORKSPACE ---
% The variable 'allElementsMatrix' is now available in your workspace
% Column 1: Element name (component or connector)
% Columns 2+: Stereotypes applied to that element
