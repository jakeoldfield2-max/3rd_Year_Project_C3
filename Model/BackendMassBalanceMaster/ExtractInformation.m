% ExtractInformation.m
% Extracts all connectors from Hospital_Context.slx into a table
% Table columns:
%   1. Connector Name
%   2. Properties (as openable matrix)
%   3. Connects From (source)
%   4. Connects To (destination)

clear; % Clear workspace variables
clc;   % Clear command window
import systemcomposer.query.*

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
stereotypePropertiesMap = containers.Map(); % stereotype -> own properties
stereotypeParentMap = containers.Map();     % stereotype -> parent stereotype

% Find all prototype elements (these are the stereotypes)
prototypes = xDoc.getElementsByTagName('prototypes');

% First pass: extract all stereotypes with their properties and parent info
for i = 0:prototypes.getLength()-1
    prototype = prototypes.item(i);

    % Get the stereotype name and parent
    stereotypeName = '';
    parentName = '';
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
                    % Get the property name, units, and default value
                    propName = '';
                    propUnits = '';
                    propDefault = '';

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
    if ~isempty(stereotypeName)
        fullStereotypeName = ['unitProfile.' stereotypeName];
        stereotypePropertiesMap(fullStereotypeName) = propertyInfo;
    end
end

% Second pass: for each stereotype, collect all properties including inherited
stereotypeAllPropertiesMap = containers.Map();

for i = 0:prototypes.getLength()-1
    prototype = prototypes.item(i);

    % Get stereotype name
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

        % Try to find parent by checking if properties match another stereotype's properties
        allProps = stereotypePropertiesMap(fullStereotypeName);

        % Look for potential parents (stereotypes whose names are prefixes)
        % For example, Pipe_GreyWater inherits from Pipe_
        potentialParents = keys(stereotypePropertiesMap);
        for p = 1:length(potentialParents)
            parentCandidate = potentialParents{p};
            % Remove 'unitProfile.' prefix for comparison
            parentShort = strrep(parentCandidate, 'unitProfile.', '');
            stereoShort = strrep(fullStereotypeName, 'unitProfile.', '');

            % Check if this could be a parent (shorter name that's a prefix)
            if ~strcmp(parentCandidate, fullStereotypeName) && ...
               startsWith(stereoShort, parentShort) && ...
               length(parentShort) < length(stereoShort)
                % This is likely a parent - add parent's properties first
                parentProps = stereotypePropertiesMap(parentCandidate);
                allProps = [parentProps, allProps]; % Horizontal concatenation for cell arrays
                break;
            end
        end

        stereotypeAllPropertiesMap(fullStereotypeName) = allProps;
    end
end

fprintf('Extracted %d stereotypes from profile\n\n', stereotypeAllPropertiesMap.Count);

% --- EXTRACT CONNECTORS ---
connectors = arch.Connectors;
numConnectors = width(connectors);

fprintf('Found %d connectors in the model\n\n', numConnectors);

% Initialize cell arrays for table columns
connectorNames = cell(numConnectors, 1);
connectorProperties = cell(numConnectors, 1);
connectsFrom = cell(numConnectors, 1);
connectsTo = cell(numConnectors, 1);

% Extract information for each connector
for i = 1:numConnectors
    connector = connectors(1, i);

    % Column 1: Connector Name
    connectorNames{i} = connector.Name;

    % Column 3 & 4: Source and Destination
    try
        % Get source element and port
        sourcePort = connector.SourcePort;

        if ~isempty(sourcePort)
            try
                sourceElement = connector.getSourceElement();
                if ~isempty(sourceElement) && isprop(sourceElement, 'Name')
                    connectsFrom{i} = sprintf('%s.%s', sourceElement.Name, sourcePort.Name);
                else
                    connectsFrom{i} = sourcePort.Name;
                end
            catch
                % Port is at architecture boundary
                connectsFrom{i} = sourcePort.Name;
            end
        else
            connectsFrom{i} = 'N/A';
        end
    catch ME
        connectsFrom{i} = sprintf('Error: %s', ME.message);
    end

    try
        % Get destination element and port
        destPort = connector.DestinationPort;

        if ~isempty(destPort)
            try
                destElement = connector.getDestinationElement();
                if ~isempty(destElement) && isprop(destElement, 'Name')
                    connectsTo{i} = sprintf('%s.%s', destElement.Name, destPort.Name);
                else
                    connectsTo{i} = destPort.Name;
                end
            catch
                % Port is at architecture boundary
                connectsTo{i} = destPort.Name;
            end
        else
            connectsTo{i} = 'N/A';
        end
    catch ME
        connectsTo{i} = sprintf('Error: %s', ME.message);
    end

    % Column 2: Extract all properties from stereotypes
    stereotypes = connector.getStereotypes();

    if ~isempty(stereotypes)
        % Convert to cell array if needed
        if ischar(stereotypes) || isstring(stereotypes)
            stereotypes = {char(stereotypes)};
        else
            stereotypes = cellstr(stereotypes);
        end

        % Collect all properties from all stereotypes
        allProperties = {};

        for s = 1:length(stereotypes)
            stereotype = stereotypes{s};

            % Look up property info from the parsed XML (including inherited properties)
            if isKey(stereotypeAllPropertiesMap, stereotype)
                propertyInfo = stereotypeAllPropertiesMap(stereotype);

                % Get each property value
                for p = 1:length(propertyInfo)
                    propName = propertyInfo{p}{1};
                    propUnits = propertyInfo{p}{2};
                    fullPropName = append(stereotype, ".", propName);

                    try
                        propValue = getProperty(connector, fullPropName);

                        % Convert to string for display
                        if isnumeric(propValue)
                            propValueStr = num2str(propValue);
                        elseif ischar(propValue) || isstring(propValue)
                            propValueStr = char(propValue);
                        else
                            propValueStr = mat2str(propValue);
                        end

                        % Store as [Property Name, Value, Units]
                        allProperties{end+1, 1} = fullPropName;
                        allProperties{end, 2} = propValueStr;
                        if ~isempty(propUnits)
                            allProperties{end, 3} = propUnits;
                        else
                            allProperties{end, 3} = '';
                        end
                    catch
                        % Property not set
                        allProperties{end+1, 1} = fullPropName;
                        allProperties{end, 2} = 'NOT SET';
                        if ~isempty(propUnits)
                            allProperties{end, 3} = propUnits;
                        else
                            allProperties{end, 3} = '';
                        end
                    end
                end
            end
        end

        % Store properties as a cell array (will be openable in table)
        if ~isempty(allProperties)
            connectorProperties{i} = allProperties;
        else
            connectorProperties{i} = {'No properties found'};
        end
    else
        connectorProperties{i} = {'No stereotypes applied'};
    end

    fprintf('Processed connector %d/%d: %s\n', i, numConnectors, connectorNames{i});
end

% --- CREATE TABLE ---
connectorTable = table(connectorNames, connectorProperties, connectsFrom, connectsTo, ...
    'VariableNames', {'ConnectorName', 'StereotypeProperties', 'ConnectsFrom', 'ConnectsTo'});

fprintf('\n=== Extraction Complete ===\n');
fprintf('Created table ''connectorTable'' with %d rows\n', height(connectorTable));
fprintf('Columns:\n');
fprintf('  1. ConnectorName - Name of the connector\n');
fprintf('  2. StereotypeProperties - Cell array of [Property, Value, Units] (double-click to open)\n');
fprintf('  3. ConnectsFrom - Source component and port\n');
fprintf('  4. ConnectsTo - Destination component and port\n\n');

% Display the table (first few rows)
disp('First 5 rows:');
disp(connectorTable(1:min(5, height(connectorTable)), :));
