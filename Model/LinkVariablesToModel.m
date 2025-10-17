% LinkVariablesToModel.m
% Takes variable names (e.g., [01]massflow) and links them to actual connector properties
% Format: [ConnectorName]PropertyName or PropertyName__[ConnectorName]
%
% Usage: Put your variable names in column 1 of a cell array called 'variableNames'
% Example:
%   variableNames = {'[01]massflow'; '[02]temperature'; 'pressure__[03]'};
%   LinkVariablesToModel

clear; clc;
import systemcomposer.query.*

% --- USER INPUT VARIABLES ---
% Load variables from VariableList.m
variableListFile = 'VariableList.m';

if ~isfile(variableListFile)
    error('Variable list file not found: %s\nPlease create VariableList.m with your variable names.', variableListFile);
end

fprintf('Reading variables from: %s\n', variableListFile);

% Run the variable list file to load variableNames
run(variableListFile);

% Check if variableNames was defined
if ~exist('variableNames', 'var')
    error('variableNames not found in %s. Please define variableNames as a cell array.', variableListFile);
end

fprintf('Found %d variables in list\n', length(variableNames));

fprintf('=== Linking Variables to Model Properties ===\n\n');

% --- LOAD MODEL ---
modelName = 'Hospital_Context.slx';
fprintf('Loading model: %s\n', modelName);
model = systemcomposer.loadModel(modelName);
arch = get(model, "Architecture");

% --- PARSE UNIT PROFILE XML ---
fprintf('Parsing unitProfile.xml to extract stereotype definitions...\n');
xmlFile = 'unitProfile.xml';
xDoc = xmlread(xmlFile);

% Create maps to store stereotype info
stereotypePropertiesMap = containers.Map();
prototypes = xDoc.getElementsByTagName('prototypes');

% Extract all stereotypes with their properties
for i = 0:prototypes.getLength()-1
    prototype = prototypes.item(i);
    stereotypeName = '';
    propertyInfo = {};

    childNodes = prototype.getChildNodes();
    for j = 0:childNodes.getLength()-1
        child = childNodes.item(j);
        if strcmp(char(child.getNodeName()), 'p_Name')
            stereotypeName = char(child.getTextContent());
        end

        if strcmp(char(child.getNodeName()), 'propertySet')
            propSetChildren = child.getChildNodes();
            for k = 0:propSetChildren.getLength()-1
                propChild = propSetChildren.item(k);
                if strcmp(char(propChild.getNodeName()), 'properties')
                    propName = '';
                    propUnits = '';

                    propNodes = propChild.getChildNodes();
                    for m = 0:propNodes.getLength()-1
                        propNode = propNodes.item(m);
                        if strcmp(char(propNode.getNodeName()), 'p_Name')
                            propName = char(propNode.getTextContent());
                        end
                        if strcmp(char(propNode.getNodeName()), 'ownedType')
                            unitsNodes = propNode.getChildNodes();
                            for n = 0:unitsNodes.getLength()-1
                                unitsNode = unitsNodes.item(n);
                                if strcmp(char(unitsNode.getNodeName()), 'units')
                                    propUnits = char(unitsNode.getTextContent());
                                end
                            end
                        end
                    end

                    if ~isempty(propName)
                        propertyInfo{end+1} = {propName, propUnits};
                    end
                end
            end
        end
    end

    if ~isempty(stereotypeName)
        fullStereotypeName = ['unitProfile.' stereotypeName];
        stereotypePropertiesMap(fullStereotypeName) = propertyInfo;
    end
end

% Handle inheritance
stereotypeAllPropertiesMap = containers.Map();
for i = 0:prototypes.getLength()-1
    prototype = prototypes.item(i);
    stereotypeName = '';
    childNodes = prototype.getChildNodes();
    for j = 0:childNodes.getLength()-1
        child = childNodes.item(j);
        if strcmp(char(child.getNodeName()), 'p_Name')
            stereotypeName = char(child.getTextContent());
            break;
        end
    end

    if ~isempty(stereotypeName)
        fullStereotypeName = ['unitProfile.' stereotypeName];
        allProps = stereotypePropertiesMap(fullStereotypeName);

        potentialParents = keys(stereotypePropertiesMap);
        for p = 1:length(potentialParents)
            parentCandidate = potentialParents{p};
            parentShort = strrep(parentCandidate, 'unitProfile.', '');
            stereoShort = strrep(fullStereotypeName, 'unitProfile.', '');

            if ~strcmp(parentCandidate, fullStereotypeName) && ...
               startsWith(stereoShort, parentShort) && ...
               length(parentShort) < length(stereoShort)
                parentProps = stereotypePropertiesMap(parentCandidate);
                allProps = [parentProps, allProps];
                break;
            end
        end

        stereotypeAllPropertiesMap(fullStereotypeName) = allProps;
    end
end

fprintf('Extracted %d stereotypes from profile\n\n', stereotypeAllPropertiesMap.Count);

% --- GET ALL CONNECTORS ---
connectors = arch.Connectors;
numConnectors = width(connectors);
fprintf('Found %d connectors in model\n\n', numConnectors);

% --- PROCESS EACH VARIABLE ---
numVars = length(variableNames);
resultTable = cell(numVars, 6);

for v = 1:numVars
    varName = variableNames{v};
    fprintf('Processing variable: %s\n', varName);

    % Parse the variable name to extract connector and property
    connectorName = '';
    propertyName = '';

    % Try format: [ConnectorName]PropertyName
    pattern1 = '\[([^\]]+)\](.+)';
    tokens1 = regexp(varName, pattern1, 'tokens');

    % Try format: PropertyName__[ConnectorName]
    pattern2 = '(.+)__\[([^\]]+)\]';
    tokens2 = regexp(varName, pattern2, 'tokens');

    % Try format: (ConnectorName)PropertyName
    pattern3 = '\(([^\)]+)\)(.+)';
    tokens3 = regexp(varName, pattern3, 'tokens');

    % Try format: PropertyName__(ConnectorName)
    pattern4 = '(.+)__\(([^\)]+)\)';
    tokens4 = regexp(varName, pattern4, 'tokens');

    if ~isempty(tokens1)
        connectorName = tokens1{1}{1};
        propertyName = tokens1{1}{2};
        fprintf('  Format: [Connector]Property\n');
    elseif ~isempty(tokens2)
        propertyName = tokens2{1}{1};
        connectorName = tokens2{1}{2};
        fprintf('  Format: Property__[Connector]\n');
    elseif ~isempty(tokens3)
        connectorName = tokens3{1}{1};
        propertyName = tokens3{1}{2};
        fprintf('  Format: (Connector)Property\n');
    elseif ~isempty(tokens4)
        propertyName = tokens4{1}{1};
        connectorName = tokens4{1}{2};
        fprintf('  Format: Property__(Connector)\n');
    else
        fprintf('  ERROR: Could not parse variable format\n');
        resultTable{v, 1} = varName;
        resultTable{v, 2} = 'ERROR: Invalid format';
        continue;
    end

    % Handle property names with dots (e.g., MapleVars.H2OConcentration)
    % Extract just the final property name after the last dot
    dotPos = strfind(propertyName, '.');
    if ~isempty(dotPos)
        propertyName = propertyName(dotPos(end)+1:end);
        fprintf('  (Extracted property after dot: %s)\n', propertyName);
    end

    fprintf('  Connector: %s\n', connectorName);
    fprintf('  Property: %s\n', propertyName);

    % Find the connector in the model
    connectorFound = false;
    matchedConnector = [];

    for i = 1:numConnectors
        conn = connectors(1, i);
        % Match by name (handle [XX] or (XX) format, or just the name)
        if strcmp(conn.Name, sprintf('[%s]', connectorName)) || ...
           strcmp(conn.Name, sprintf('(%s)', connectorName)) || ...
           strcmp(conn.Name, connectorName) || ...
           strcmp(conn.Name, sprintf('[0%s]', connectorName)) % Handle leading zero
            connectorFound = true;
            matchedConnector = conn;
            break;
        end
    end

    if ~connectorFound
        fprintf('  ERROR: Connector not found in model\n');
        resultTable{v, 1} = varName;
        resultTable{v, 2} = connectorName;
        resultTable{v, 3} = propertyName;
        resultTable{v, 4} = 'NOT FOUND';
        continue;
    end

    fprintf('  Found connector: %s\n', matchedConnector.Name);

    % Find the property in the connector's stereotypes
    stereotypes = matchedConnector.getStereotypes();
    propertyFound = false;
    matchedStereotype = '';
    matchedFullProp = '';
    matchedValue = '';
    matchedUnits = '';

    if ~isempty(stereotypes)
        if ischar(stereotypes) || isstring(stereotypes)
            stereotypes = {char(stereotypes)};
        else
            stereotypes = cellstr(stereotypes);
        end

        for s = 1:length(stereotypes)
            stereotype = stereotypes{s};

            if isKey(stereotypeAllPropertiesMap, stereotype)
                propertyInfo = stereotypeAllPropertiesMap(stereotype);

                for p = 1:length(propertyInfo)
                    propName = propertyInfo{p}{1};
                    propUnits = propertyInfo{p}{2};

                    % Case-insensitive match
                    if strcmpi(propName, propertyName)
                        propertyFound = true;
                        matchedStereotype = stereotype;
                        fullPropName = append(stereotype, ".", propName);
                        matchedFullProp = fullPropName;
                        matchedUnits = propUnits;

                        try
                            propValue = getProperty(matchedConnector, fullPropName);
                            if isnumeric(propValue)
                                matchedValue = num2str(propValue);
                            elseif ischar(propValue) || isstring(propValue)
                                matchedValue = char(propValue);
                            else
                                matchedValue = mat2str(propValue);
                            end
                        catch
                            matchedValue = 'NOT SET';
                        end

                        fprintf('  MATCH FOUND!\n');
                        fprintf('    Stereotype: %s\n', matchedStereotype);
                        fprintf('    Full Property: %s\n', matchedFullProp);
                        fprintf('    Value: %s\n', matchedValue);
                        fprintf('    Units: %s\n', matchedUnits);
                        break;
                    end
                end
            end

            if propertyFound
                break;
            end
        end
    end

    if ~propertyFound
        fprintf('  ERROR: Property not found in connector stereotypes\n');
        resultTable{v, 1} = varName;
        resultTable{v, 2} = connectorName;
        resultTable{v, 3} = propertyName;
        resultTable{v, 4} = 'PROPERTY NOT FOUND';
    else
        resultTable{v, 1} = varName;
        resultTable{v, 2} = matchedConnector.Name;
        resultTable{v, 3} = matchedFullProp;
        resultTable{v, 4} = matchedValue;
        resultTable{v, 5} = matchedUnits;
        resultTable{v, 6} = 'LINKED';
    end

    fprintf('\n');
end

% --- CREATE RESULTS TABLE ---
linkageTable = cell2table(resultTable, ...
    'VariableNames', {'VariableName', 'ConnectorName', 'ModelProperty', 'CurrentValue', 'Units', 'Status'});

fprintf('=== Linkage Complete ===\n');
fprintf('Created ''linkageTable'' with %d variables\n\n', height(linkageTable));

% Display results
disp(linkageTable);

% Summary
numLinked = sum(strcmp(resultTable(:, 6), 'LINKED'));
fprintf('\nSummary: %d/%d variables successfully linked to model properties\n', numLinked, numVars);
