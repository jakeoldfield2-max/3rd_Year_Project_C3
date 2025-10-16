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

        % Look for parentProxy to find base stereotype
        if strcmp(char(child.getNodeName()), 'parentProxy')
            % Try to find the parent stereotype name
            parentChildren = child.getChildNodes();
            for k = 0:parentChildren.getLength()-1
                parentChild = parentChildren.item(k);
                if strcmp(char(parentChild.getNodeName()), 'realElement')
                    % This points to the parent - we need to find its name
                    % We'll store the reference and resolve it later
                end
            end
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

                        % Look for default value
                        if strcmp(char(propNode.getNodeName()), 'defaultValue')
                            % Try to get the value text content
                            try
                                % Default value might have child nodes with actual value
                                defaultNodes = propNode.getChildNodes();
                                for n = 0:defaultNodes.getLength()-1
                                    defaultNode = defaultNodes.item(n);
                                    if strcmp(char(defaultNode.getNodeName()), 'value')
                                        propDefault = char(defaultNode.getTextContent());
                                    end
                                end
                                % If no 'value' node, try text content directly
                                if isempty(propDefault)
                                    propDefault = char(propNode.getTextContent());
                                end
                            catch
                                propDefault = '';
                            end
                        end
                    end

                    % Store property info with default value
                    if ~isempty(propName)
                        propertyInfo{end+1} = {propName, propUnits, propDefault};
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

fprintf('Extracting properties from %d connectors...\n\n', numConnectors);

% Open Maple file for reading (to preserve equations section)
mapleFileName = 'MassBalanceCalculation.mpl';
equationsSection = '';
markerFound = false;

% Check if file exists and read equations section
if isfile(mapleFileName)
    fid_read = fopen(mapleFileName, 'r');
    fileContent = fread(fid_read, '*char')';
    fclose(fid_read);

    % Look for the marker that separates variables from equations
    marker = '### END OF AUTO-GENERATED VARIABLES ###';
    markerPos = strfind(fileContent, marker);

    if ~isempty(markerPos)
        % Preserve everything after the marker (use first occurrence)
        equationsSection = fileContent(markerPos(1):end);
        markerFound = true;
        fprintf('Found existing equations section, preserving...\n');
    end
end

% Open Maple file for writing
fid = fopen(mapleFileName, 'w');

% Write header
fprintf(fid, '# ============================================================================\n');
fprintf(fid, '# AUTO-GENERATED VARIABLES - DO NOT EDIT THIS SECTION MANUALLY\n');
fprintf(fid, '# Generated from MATLAB System Composer\n');
fprintf(fid, '# Date: %s\n', datestr(now));
fprintf(fid, '# ============================================================================\n\n');

% Extract and write properties for each connector
for i = 1:numConnectors
    % Get connector name
    connName = connectors(1,i).Name;

    % Clean connector name for Maple (remove brackets and special characters)
    cleanConnName = strrep(connName, '[', '');
    cleanConnName = strrep(cleanConnName, ']', '');
    cleanConnName = strrep(cleanConnName, ' ', '_');

    fprintf(fid, '# Connector: %s\n', connName);

    % Get all stereotypes for this connector
    stereotypes = connectors(1,i).getStereotypes();

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

            % Look up property info from the parsed XML (including inherited properties)
            if isKey(stereotypeAllPropertiesMap, stereotype)
                propertyInfo = stereotypeAllPropertiesMap(stereotype);

                % Get each property value
                for p = 1:length(propertyInfo)
                    propName = propertyInfo{p}{1};
                    propUnits = propertyInfo{p}{2};
                    propDefault = '';
                    if length(propertyInfo{p}) >= 3
                        propDefault = propertyInfo{p}{3};
                    end
                    fullPropName = append(stereotype, ".", propName);

                    try
                        propValue = getProperty(connectors(1,i), fullPropName);

                        % Check if value should be treated as "blank"/default
                        % Treat as blank if: equals 0, empty string, or whitespace only
                        isBlank = false;

                        if ischar(propValue) || isstring(propValue)
                            propValueStr = char(propValue);
                            trimmedValue = strtrim(propValueStr);

                            % Check if it's '0' or empty
                            if isempty(trimmedValue) || strcmp(trimmedValue, '0')
                                isBlank = true;
                            end
                        elseif isnumeric(propValue)
                            % Check if numeric value is 0
                            if abs(propValue) < 1e-10
                                isBlank = true;
                            end
                        elseif isempty(propValue)
                            isBlank = true;
                        end

                        % If it's blank/default, write as self-reference
                        if isBlank
                            fprintf(fid, '%s__[%s] := %s__[%s];', propName, cleanConnName, propName, cleanConnName);
                            if ~isempty(propUnits)
                                fprintf(fid, ' # %s (blank)', propUnits);
                            else
                                fprintf(fid, ' # (blank)');
                            end
                            fprintf(fid, '\n');
                        else
                            % Convert to string for output
                            if isnumeric(propValue)
                                propValueStr = num2str(propValue);
                            elseif ischar(propValue) || isstring(propValue)
                                propValueStr = char(propValue);
                            else
                                propValueStr = '0';
                            end

                            % Write normal Maple assignment statement
                            fprintf(fid, '%s__[%s] := %s;', propName, cleanConnName, propValueStr);

                            % Add units as a comment if available
                            if ~isempty(propUnits)
                                fprintf(fid, ' # %s', propUnits);
                            end

                            fprintf(fid, '\n');
                        end

                    catch ME
                        % Property not set, write as self-reference
                        fprintf(fid, '%s__[%s] := %s__[%s]; # NOT SET\n', propName, cleanConnName, propName, cleanConnName);
                    end
                end
            end
        end
    end

    fprintf(fid, '\n'); % Blank line between connectors
end

% Write the marker
fprintf(fid, '### END OF AUTO-GENERATED VARIABLES ###\n');
fprintf(fid, '# Add your equations below this line\n');
fprintf(fid, '# This section will be preserved when variables are regenerated\n\n');

% If there was an existing equations section, write it back
if markerFound
    fprintf(fid, '%s', equationsSection);
    fprintf('Preserved existing equations section\n');
else
    % First time creating the file - add template
    fprintf(fid, '# ============================================================================\n');
    fprintf(fid, '# YOUR MASS BALANCE EQUATIONS GO HERE\n');
    fprintf(fid, '# ============================================================================\n\n');
    fprintf(fid, '# Example:\n');
    fprintf(fid, '# eq1 := CHxConcentration__[01] + CHxConcentration__[02] = TotalCHx;\n\n');
end

% Close the file
fclose(fid);

fprintf('\nSuccessfully exported %d connectors to %s\n', numConnectors, mapleFileName);
fprintf('Maple variables use format: PropertyName__[ConnectorNumber] := value;\n');
fprintf('Your equations section has been preserved below the marker line.\n');
