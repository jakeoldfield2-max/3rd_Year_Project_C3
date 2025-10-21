% MassBalanceMaster.m
% Master script for mass balance workflow automation
%
% This script orchestrates the complete mass balance process:
% 1. Clears all M_  stereotype properties in connectors
% 2. Writes initial values from VariableList.m into the model
% 3. Exports model data to Maple format (ExportToMaple.m)
% 4. Runs Maple calculations (MassBalanceCalculation.mpl)
% 5. Loads calculated values back into MATLAB (LoadMapleValues.m)
%
% Format: [ConnectorName]PropertyName or PropertyName__[ConnectorName]

clear; clc;
import systemcomposer.query.*

% --- USER INPUT VARIABLES ---
% Load variables from VariableList.m
variableListFile = 'VariableList.m';

if ~isfile(variableListFile)
    error('Variable list file not found: %s\nPlease create VariableList.m with your variable names.', variableListFile);
end

fprintf('Reading variables from: %s\n', variableListFile);

% Run the variable list file to load variableList
run(variableListFile);

% Check if variableList was defined
if ~exist('variableList', 'var')
    error('variableList not found in %s. Please define variableList as a cell array.', variableListFile);
end

% Extract variable names and expected values
variableNames = variableList(:, 1);
expectedValues = variableList(:, 2);

fprintf('Found %d variables in list\n', length(variableNames));

fprintf('\n================================================\n');
fprintf('=== MASS BALANCE MASTER - Full Workflow ===\n');
fprintf('================================================\n');
fprintf('This script will:\n');
fprintf('  1. Clear all M_ stereotype properties\n');
fprintf('  2. Apply values from VariableList.m\n');
fprintf('  3. Export model to Maple format\n');
fprintf('  4. Run Maple calculations\n');
fprintf('  5. Load results back into MATLAB\n');
fprintf('WARNING: This will modify the model!\n');
fprintf('================================================\n\n');

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

% --- FIND AND CLEAR M_ STEREOTYPES ---
fprintf('=== STEP 1: Clearing M_ Stereotype Properties ===\n');

% Find all stereotypes that start with M_
massBalanceStereotypes = {};
allStereotypeKeys = keys(stereotypeAllPropertiesMap);
for k = 1:length(allStereotypeKeys)
    stereoKey = allStereotypeKeys{k};
    % Extract just the name part after 'unitProfile.'
    stereoName = strrep(stereoKey, 'unitProfile.', '');
    if startsWith(stereoName, 'M_')
        massBalanceStereotypes{end+1} = stereoKey;
        fprintf('Found M_ stereotype: %s\n', stereoName);
    end
end

fprintf('\nFound %d M_ stereotypes\n', length(massBalanceStereotypes));

% Clear all properties in connectors with M_ stereotypes
numCleared = 0;
for i = 1:numConnectors
    conn = connectors(1, i);
    connStereotypes = conn.getStereotypes();

    if ~isempty(connStereotypes)
        if ischar(connStereotypes) || isstring(connStereotypes)
            connStereotypes = {char(connStereotypes)};
        else
            connStereotypes = cellstr(connStereotypes);
        end

        % Check if this connector has any M_ stereotypes
        hasM = false;
        for s = 1:length(connStereotypes)
            if any(strcmp(connStereotypes{s}, massBalanceStereotypes))
                hasM = true;
                break;
            end
        end

        if hasM
            fprintf('Clearing connector: %s\n', conn.Name);

            % Clear all properties from M_ stereotypes
            for s = 1:length(connStereotypes)
                stereotype = connStereotypes{s};

                % Only clear if it's an M_ stereotype
                if any(strcmp(stereotype, massBalanceStereotypes))
                    if isKey(stereotypeAllPropertiesMap, stereotype)
                        propertyInfo = stereotypeAllPropertiesMap(stereotype);

                        for p = 1:length(propertyInfo)
                            propName = propertyInfo{p}{1};
                            fullPropName = append(stereotype, ".", propName);

                            try
                                % Set property to '0' (empty/default)
                                setProperty(conn, fullPropName, '0');
                                numCleared = numCleared + 1;
                            catch ME
                                % Silently continue if property can't be cleared
                            end
                        end
                    end
                end
            end
        end
    end
end

fprintf('\nCleared %d properties from connectors with M_ stereotypes\n\n', numCleared);

% --- STEP 2: APPLY VALUES FROM VARIABLELIST ---
fprintf('=== STEP 2: Writing Values from VariableList ===\n\n');

% --- PROCESS EACH VARIABLE ---
numVars = length(variableNames);
resultTable = cell(numVars, 7);

for v = 1:numVars
    varName = variableNames{v};
    expectedValue = expectedValues{v};

    % Display value being set
    if isnumeric(expectedValue)
        valueStr = num2str(expectedValue);
    elseif isempty(expectedValue) || (ischar(expectedValue) && strcmp(expectedValue, ''))
        valueStr = '(empty - will skip)';
    else
        valueStr = char(expectedValue);
    end

    fprintf('Processing variable: %s (Setting to: %s)\n', varName, valueStr);

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
        resultTable{v, 2} = expectedValue;
        resultTable{v, 3} = '';
        resultTable{v, 4} = '';
        resultTable{v, 5} = '';
        resultTable{v, 6} = '';
        resultTable{v, 7} = 'ERROR: Invalid format';
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
        resultTable{v, 2} = expectedValue;
        resultTable{v, 3} = connectorName;
        resultTable{v, 4} = '';
        resultTable{v, 5} = '';
        resultTable{v, 6} = '';
        resultTable{v, 7} = 'ERROR: Connector not found';
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
        resultTable{v, 2} = expectedValue;
        resultTable{v, 3} = connectorName;
        resultTable{v, 4} = '';
        resultTable{v, 5} = '';
        resultTable{v, 6} = '';
        resultTable{v, 7} = 'ERROR: Property not found';
    else
        % Update the model value
        oldValue = matchedValue;
        newValue = expectedValue;
        updateStatus = '';

        % Check if we have a valid value to set
        if isempty(newValue) || (ischar(newValue) && strcmp(newValue, ''))
            % Skip if no value provided
            fprintf('  SKIPPED: No value provided (empty)\n');
            updateStatus = 'SKIPPED: No value';
        else
            try
                % Convert value to string (setProperty requires string input)
                if ischar(newValue) || isstring(newValue)
                    valueToSet = char(newValue);
                elseif isnumeric(newValue)
                    valueToSet = num2str(newValue);
                else
                    valueToSet = char(newValue);
                end

                % Set the property
                setProperty(matchedConnector, matchedFullProp, valueToSet);

                % Verify the change
                verifyValue = getProperty(matchedConnector, matchedFullProp);
                if isnumeric(verifyValue)
                    verifyValueStr = num2str(verifyValue);
                else
                    verifyValueStr = char(verifyValue);
                end

                fprintf('  UPDATED: %s -> %s\n', oldValue, verifyValueStr);
                updateStatus = 'SUCCESS';

            catch ME
                fprintf('  ERROR: Failed to update - %s\n', ME.message);
                updateStatus = sprintf('ERROR: %s', ME.message);
            end
        end

        resultTable{v, 1} = varName;
        resultTable{v, 2} = newValue;
        resultTable{v, 3} = matchedConnector.Name;
        resultTable{v, 4} = matchedFullProp;
        resultTable{v, 5} = oldValue;
        resultTable{v, 6} = matchedUnits;
        resultTable{v, 7} = updateStatus;
    end

    fprintf('\n');
end

% --- CREATE RESULTS TABLE ---
updateTable = cell2table(resultTable, ...
    'VariableNames', {'VariableName', 'NewValue', 'ConnectorName', 'ModelProperty', 'OldValue', 'Units', 'Status'});

fprintf('\n=== Mass Balance Update Complete ===\n');
fprintf('Created ''updateTable'' with %d variables\n\n', height(updateTable));

% Display results
disp(updateTable);

% Summary
numSuccess = sum(strcmp(resultTable(:, 7), 'SUCCESS'));
numSkipped = sum(contains(string(resultTable(:, 7)), 'SKIPPED'));
numErrors = sum(contains(string(resultTable(:, 7)), 'ERROR'));

fprintf('\n===============================================\n');
fprintf('=== MASS BALANCE MASTER SUMMARY ===\n');
fprintf('===============================================\n');
fprintf('STEP 1 - Clearing:\n');
fprintf('  Properties cleared: %d\n', numCleared);
fprintf('\nSTEP 2 - Writing:\n');
fprintf('  Total variables: %d\n', numVars);
fprintf('  Successfully updated: %d\n', numSuccess);
fprintf('  Skipped (no value): %d\n', numSkipped);
fprintf('  Errors: %d\n', numErrors);
fprintf('===============================================\n');

% Save the model
if numCleared > 0 || numSuccess > 0
    fprintf('\nSaving model...\n');
    save(model);
    fprintf('Model saved successfully.\n');
else
    fprintf('\nNo changes made - model not saved.\n');
end

%% ========================================================================
%% STEP 3: EXPORT MODEL TO MAPLE
%% ========================================================================
fprintf('\n================================================\n');
fprintf('=== STEP 3: Exporting Model to Maple ===\n');
fprintf('================================================\n');

try
    run('ExportToMaple.m');
    fprintf('✓ Export to Maple completed successfully\n');
catch ME
    error('ERROR in ExportToMaple: %s', ME.message);
end

%% ========================================================================
%% STEP 4: RUN MAPLE CALCULATIONS
%% ========================================================================
fprintf('\n================================================\n');
fprintf('=== STEP 4: Running Maple Calculations ===\n');
fprintf('================================================\n');

% Check if Maple script exists
mapleScript = 'MassBalanceCalculation.mpl';
if ~isfile(mapleScript)
    error('Maple script not found: %s', mapleScript);
end

% Delete old Maple output file to ensure fresh run
mapleOutputFile = 'MapleExportedVariables.m';
if isfile(mapleOutputFile)
    fprintf('Deleting old Maple output file...\n');
    delete(mapleOutputFile);
end

% Try to find and run Maple automatically
fprintf('Searching for Maple installation...\n');

% Try to find Maple executable
maplePaths = {};

% Try common installation paths on Windows (both maple.exe and cmaple.exe)
commonPaths = {
    'C:\Program Files\Maple 2025\bin.X86_64_WINDOWS\cmaple.exe'
    'C:\Program Files\Maple 2025\bin.X86_64_WINDOWS\maple.exe'
    'C:\Program Files\Maple 2024\bin.X86_64_WINDOWS\cmaple.exe'
    'C:\Program Files\Maple 2024\bin.X86_64_WINDOWS\maple.exe'
    'C:\Program Files\Maple 2023\bin.X86_64_WINDOWS\cmaple.exe'
    'C:\Program Files\Maple 2023\bin.X86_64_WINDOWS\maple.exe'
    'C:\Program Files\Maple 2022\bin.X86_64_WINDOWS\cmaple.exe'
    'C:\Program Files\Maple 2022\bin.X86_64_WINDOWS\maple.exe'
    'C:\Program Files\Maple 2021\bin.X86_64_WINDOWS\cmaple.exe'
    'C:\Program Files\Maple 2021\bin.X86_64_WINDOWS\maple.exe'
};

% Find all Maple installations
for p = 1:length(commonPaths)
    if isfile(commonPaths{p})
        maplePaths{end+1} = commonPaths{p};
    end
end

% Also try finding Maple in PATH
[status, result] = system('where cmaple 2>nul');
if status == 0
    pathMaple = strtrim(result);
    if ~isempty(pathMaple)
        maplePaths{end+1} = pathMaple;
    end
end

mapleFound = false;
mapleExe = '';

if ~isempty(maplePaths)
    % Try each Maple path until one works
    for p = 1:length(maplePaths)
        mapleExe = maplePaths{p};
        fprintf('Trying Maple at: %s\n', mapleExe);

        % Get absolute path to the Maple script
        mapleScriptPath = fullfile(pwd, mapleScript);

        % Run Maple in batch mode - try different command formats
        if contains(mapleExe, 'cmaple')
            % For command-line Maple, use stdin redirection
            cmd = sprintf('"%s" < "%s"', mapleExe, mapleScriptPath);
        else
            % For regular Maple executable
            cmd = sprintf('"%s" "%s"', mapleExe, mapleScriptPath);
        end

        fprintf('Executing command: %s\n', cmd);
        [status, cmdout] = system(cmd);

        fprintf('Maple output:\n%s\n', cmdout);

        % Check if output file was created (this is the definitive test)
        pause(0.5); % Brief pause to ensure file system updates
        if isfile(mapleOutputFile)
            fprintf('✓ Maple calculations completed successfully\n');
            fprintf('✓ Output file created: %s\n', mapleOutputFile);
            mapleFound = true;
            break;
        else
            fprintf('Output file not created, trying next method...\n');
        end
    end
end

% If still not found, verification check
if ~mapleFound
    fprintf('\n⚠ Automatic Maple execution failed\n');
    fprintf('Checking if output file exists anyway...\n');
    if isfile(mapleOutputFile)
        fprintf('✓ Output file found - Maple may have run successfully despite error\n');
        mapleFound = true;
    end
end

if ~mapleFound
    warning('Could not automatically run Maple.');
    fprintf('\nMaple installation paths checked:\n');
    for p = 1:length(commonPaths)
        if isfile(commonPaths{p})
            fprintf('  %s ✓\n', commonPaths{p});
        else
            fprintf('  %s ✗\n', commonPaths{p});
        end
    end
    fprintf('\nPlease either:\n');
    fprintf('  1. Run %s manually in Maple, then press Enter\n', mapleScript);
    fprintf('  2. Add Maple to your system PATH\n');
    input('Press Enter after running Maple calculations...');
end

%% ========================================================================
%% STEP 5: LOAD MAPLE RESULTS BACK INTO MATLAB
%% ========================================================================
fprintf('\n================================================\n');
fprintf('=== STEP 5: Loading Maple Results ===\n');
fprintf('================================================\n');

try
    run('LoadMapleValues.m');
    fprintf('✓ Maple values loaded into MATLAB workspace\n');
catch ME
    error('ERROR in LoadMapleValues: %s', ME.message);
end

%% ========================================================================
%% WORKFLOW COMPLETE
%% ========================================================================
fprintf('\n================================================\n');
fprintf('=== MASS BALANCE WORKFLOW COMPLETE ===\n');
fprintf('================================================\n');
fprintf('Summary:\n');
fprintf('  ✓ Model updated with initial values\n');
fprintf('  ✓ Data exported to Maple\n');
fprintf('  ✓ Maple calculations executed\n');
fprintf('  ✓ Results loaded back into MATLAB\n');
fprintf('\nCalculated variables are now available in workspace\n');
fprintf('================================================\n');
