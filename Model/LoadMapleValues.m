% ============================================================================
% LOAD CALCULATED VALUES FROM MAPLE
% This script simply loads Maple-calculated variables into MATLAB workspace
% Does NOT update System Composer - just makes the values available
% ============================================================================

% --- SCRIPT CONFIGURATION ---
clear MapleVars; % Clear previous Maple variables
clc;   % Clear command window

% --- LOAD MAPLE CALCULATED VALUES ---
mapleDataFile = 'MapleExportedVariables.m';

if ~isfile(mapleDataFile)
    error('Maple export file not found: %s\nPlease run the Maple export first (ExportMapleToMatlab.mpl).', mapleDataFile);
end

fprintf('Loading Maple calculated values from %s...\n\n', mapleDataFile);

% Execute the Maple-generated MATLAB file
run(mapleDataFile);

% Check if MapleVars exists
if ~exist('MapleVars', 'var')
    error('MapleVars structure not found in the Maple export file.');
end

% --- DISPLAY SUMMARY ---
propertyNames = fieldnames(MapleVars);
numProperties = length(propertyNames);

fprintf('============================================================================\n');
fprintf('Loaded %d property types from Maple\n', numProperties);
fprintf('============================================================================\n\n');

% Display each property and its values
totalValues = 0;
for p = 1:length(propertyNames)
    propName = propertyNames{p};
    propValues = MapleVars.(propName);

    if isnumeric(propValues)
        % Find non-zero, non-NaN values
        validIndices = find(~isnan(propValues) & propValues ~= 0);
        numValues = length(validIndices);
        totalValues = totalValues + numValues;

        fprintf('Property: %s\n', propName);
        fprintf('  Number of connectors with values: %d\n', numValues);

        % Show first few values as examples
        numToShow = min(3, numValues);
        for i = 1:numToShow
            idx = validIndices(i);
            fprintf('    [%02d] = %.6g\n', idx, propValues(idx));
        end

        if numValues > 3
            fprintf('    ... and %d more\n', numValues - 3);
        end
        fprintf('\n');
    end
end

fprintf('============================================================================\n');
fprintf('Total values loaded: %d\n', totalValues);
fprintf('============================================================================\n\n');

fprintf('The structure "MapleVars" is now available in your workspace.\n');
fprintf('Access values using: MapleVars.PropertyName__(ConnectorNumber)\n');
fprintf('Example: MapleVars.CHxConcentration__(1)\n');
