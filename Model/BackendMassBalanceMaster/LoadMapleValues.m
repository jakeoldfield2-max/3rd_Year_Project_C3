% ============================================================================
% LOAD CALCULATED VALUES FROM MAPLE
% This script simply loads Maple-calculated variables into MATLAB workspace
% Does NOT update System Composer - just makes the values available
% ============================================================================

% --- SCRIPT CONFIGURATION ---
clc;   % Clear command window

% --- LOAD MAPLE CALCULATED VALUES ---
mapleDataFile = 'MapleExportedVariables.m';

if ~isfile(mapleDataFile)
    error('Maple export file not found: %s\nPlease run the Maple export first (ExportMapleToMatlab.mpl).', mapleDataFile);
end

fprintf('Loading Maple calculated values from %s...\n\n', mapleDataFile);

% Get current workspace variables before loading
varsBefore = who;

% Execute the Maple-generated MATLAB file
run(mapleDataFile);

% Get workspace variables after loading
varsAfter = who;

% Find new variables (those added by the Maple file)
newVars = setdiff(varsAfter, varsBefore);
% Remove script variables from the list
scriptVars = {'mapleDataFile', 'varsBefore', 'varsAfter', 'ans'};
newVars = setdiff(newVars, scriptVars);

numProperties = length(newVars);

fprintf('============================================================================\n');
fprintf('Loaded %d variables from Maple\n', numProperties);
fprintf('============================================================================\n\n');

% Display each variable and its values/size
totalValues = 0;
for p = 1:length(newVars)
    varName = newVars{p};
    varValue = eval(varName);

    fprintf('Variable: %s\n', varName);

    if isnumeric(varValue)
        if isscalar(varValue)
            fprintf('  Value: %.6g\n', varValue);
            totalValues = totalValues + 1;
        else
            % Array/vector
            validIndices = find(~isnan(varValue) & varValue ~= 0);
            numValues = length(validIndices);
            totalValues = totalValues + numValues;

            fprintf('  Number of connectors with values: %d\n', numValues);

            % Show first few values as examples
            numToShow = min(3, numValues);
            for i = 1:numToShow
                idx = validIndices(i);
                fprintf('    (%d) = %.6g\n', idx, varValue(idx));
            end

            if numValues > 3
                fprintf('    ... and %d more\n', numValues - 3);
            end
        end
    end
    fprintf('\n');
end

fprintf('============================================================================\n');
fprintf('Total values loaded: %d\n', totalValues);
fprintf('============================================================================\n\n');

fprintf('Variables are now available directly in your workspace.\n');
fprintf('Access values using: PropertyName__(ConnectorNumber)\n');
fprintf('Example: CHxConcentration__(1)\n');
