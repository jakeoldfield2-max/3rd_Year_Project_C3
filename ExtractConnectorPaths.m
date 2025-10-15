% --- SCRIPT CONFIGURATION ---
clear; % Clear workspace variables
clc;   % Clear command window
import systemcomposer.query.*

% --- LOAD MODEL ---
modelName = 'Hospital_Context.slx';
model = systemcomposer.loadModel(modelName);
arch = get(model, "Architecture");

% --- PARSE UNIT PROFILE XML ---
fprintf('Parsing unitProfile.xml to extract stereotype definitions...\n');
xmlFile = 'unitProfile.xml';
xDoc = xmlread(xmlFile);

% Create a map to store stereotype -> property info [name, units]
stereotypePropertiesMap = containers.Map();

% Find all prototype elements (these are the stereotypes)
prototypes = xDoc.getElementsByTagName('prototypes');

for i = 0:prototypes.getLength()-1
    prototype = prototypes.item(i);

    % Get the stereotype name
    stereotypeName = '';
    propertyInfo = {}; % Store [name, units] pairs

    % Look for p_Name element (stereotype name)
    childNodes = prototype.getChildNodes();
    for j = 0:childNodes.getLength()-1
        child = childNodes.item(j);
        if strcmp(char(child.getNodeName()), 'p_Name')
            stereotypeName = char(child.getTextContent());
        end

        % Look for propertySet
        if strcmp(char(child.getNodeName()), 'propertySet')
            % Get all properties within this propertySet
            propSetChildren = child.getChildNodes();
            for k = 0:propSetChildren.getLength()-1
                propChild = propSetChildren.item(k);
                if strcmp(char(propChild.getNodeName()), 'properties')
                    % Get the property name and units
                    propName = '';
                    propUnits = '';

                    propNodes = propChild.getChildNodes();
                    for m = 0:propNodes.getLength()-1
                        propNode = propNodes.item(m);

                        % Get property name
                        if strcmp(char(propNode.getNodeName()), 'p_Name')
                            propName = char(propNode.getTextContent());
                        end

                        % Look for units in ownedType
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

                    % Store property info
                    if ~isempty(propName)
                        propertyInfo{end+1} = {propName, propUnits};
                    end
                end
            end
        end
    end

    % Store in map if we found a stereotype name
    if ~isempty(stereotypeName) && ~isempty(propertyInfo)
        fullStereotypeName = ['unitProfile.' stereotypeName];
        stereotypePropertiesMap(fullStereotypeName) = propertyInfo;
        fprintf('  Found stereotype "%s" with %d properties\n', fullStereotypeName, length(propertyInfo));
    end
end

fprintf('\nExtracted %d stereotypes from profile\n\n', stereotypePropertiesMap.Count);

% --- EXTRACT CONNECTORS ---
connectors = arch.Connectors;
numConnectors = width(connectors);

fprintf('Extracting properties from %d connectors...\n\n', numConnectors);

% Pre-allocate matrix: [Connector Name, Properties Matrix, Source, Destination]
connectorPathsMatrix = cell(numConnectors, 4);

for i = 1:numConnectors
    % Get connector name
    connName = connectors(1,i).Name;

    % Get source port and its parent component
    sourcePort = connectors(1,i).SourcePort;
    if ~isempty(sourcePort)
        sourceComponent = sourcePort.Parent.Name;
    else
        sourceComponent = 'N/A';
    end

    % Get destination port and its parent component
    destPort = connectors(1,i).DestinationPort;
    if ~isempty(destPort)
        destComponent = destPort.Parent.Name;
    else
        destComponent = 'N/A';
    end

    % Get all stereotypes for this connector
    stereotypes = connectors(1,i).getStereotypes();

    % Extract all properties from all stereotypes
    propertiesMatrix = {};

    if ~isempty(stereotypes)
        % Convert to cell array if needed
        if ischar(stereotypes) || isstring(stereotypes)
            stereotypes = {char(stereotypes)};
        else
            stereotypes = cellstr(stereotypes);
        end

        % Loop through each stereotype
        for s = 1:length(stereotypes)
            stereotype = stereotypes{s};

            % Look up property info from the parsed XML
            if isKey(stereotypePropertiesMap, stereotype)
                propertyInfo = stereotypePropertiesMap(stereotype);

                % Get each property value and units
                for p = 1:length(propertyInfo)
                    propName = propertyInfo{p}{1};
                    propUnits = propertyInfo{p}{2};
                    fullPropName = append(stereotype, ".", propName);

                    try
                        propValue = getProperty(connectors(1,i), fullPropName);

                        % Check if value is empty/blank
                        if isempty(propValue) || (ischar(propValue) && isempty(strtrim(propValue)))
                            propValue = '[BLANK]';
                        elseif isstring(propValue) && strlength(propValue) == 0
                            propValue = '[BLANK]';
                        end

                        % Add to properties matrix with units
                        if isempty(propUnits)
                            propertiesMatrix = [propertiesMatrix; {fullPropName, propValue, ''}];
                        else
                            propertiesMatrix = [propertiesMatrix; {fullPropName, propValue, propUnits}];
                        end
                    catch ME
                        % Property might not be set or error getting value
                        if isempty(propUnits)
                            propertiesMatrix = [propertiesMatrix; {fullPropName, '[NOT SET]', ''}];
                        else
                            propertiesMatrix = [propertiesMatrix; {fullPropName, '[NOT SET]', propUnits}];
                        end
                    end
                end
            else
                fprintf('  Warning: Stereotype "%s" not found in profile XML\n', stereotype);
            end
        end
    end

    % Store in matrix
    connectorPathsMatrix{i, 1} = connName;
    connectorPathsMatrix{i, 2} = propertiesMatrix; % Nested matrix here!
    connectorPathsMatrix{i, 3} = sourceComponent;
    connectorPathsMatrix{i, 4} = destComponent;
end

% --- DISPLAY RESULTS ---
fprintf('Extracted %d connectors\n\n', numConnectors);

disp('Connector Paths Matrix:');
disp('Column 1: Connector Name | Column 2: Properties Matrix (nested) | Column 3: Source | Column 4: Destination');
disp(connectorPathsMatrix);

fprintf('\nTip: Double-click on any cell in Column 2 to view the properties matrix for that connector\n');
fprintf('The nested matrix contains: Column 1 = Property Name, Column 2 = Property Value, Column 3 = Units\n');

% --- SAVE TO WORKSPACE ---
% The variable 'connectorPathsMatrix' is now available in your workspace
% Column 1: Connector name
% Column 2: Nested properties matrix [Property Name, Property Value, Units]
% Column 3: Source component
% Column 4: Destination component
