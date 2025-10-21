# ============================================================================
# EXPORT MAPLE VARIABLES TO MATLAB FORMAT
# This code exports all indexed variables (format: Variable__[index])
# to a MATLAB .m file that can be executed to load the calculated values
# ============================================================================

# Get the output file path (in BackendMassBalanceMaster folder)
outputFile := "BackendMassBalanceMaster/MapleExportedVariables.m";

# Open file for writing
fd := fopen(outputFile, WRITE);

# Write header
fprintf(fd, "%% ============================================================================\n");
fprintf(fd, "%% AUTO-GENERATED FROM MAPLE - Calculated Mass Balance Variables\n");
fprintf(fd, "%% ============================================================================\n\n");

# Check if user defined EXPORT_VARIABLES list
useSelectiveExport := false;
exportList := [];

if assigned(EXPORT_VARIABLES) then
    printf("Using selective export - only exporting variables in EXPORT_VARIABLES list\n");
    useSelectiveExport := true;
    exportList := [EXPORT_VARIABLES];
    printf("Export list contains %d variable names\n", nops(exportList));
else
    printf("No EXPORT_VARIABLES defined - exporting all calculated variables\n");
end if;

# Get all user-defined names
allNames := [anames('user')];

# Counter for exported variables
exportCount := 0;

# Loop through all names
for varName in allNames do
    # Check if this is a base name that has indexed subscripts
    # (ends with __ which is our convention)
    varNameStr := convert(varName, string);

    # If selective export is enabled, check if this variable is in the list
    if useSelectiveExport then
        inList := false;
        for exportVar in exportList do
            exportVarStr := convert(exportVar, string);
            # Remove index notation if present [01] or (01)
            exportVarStr := StringTools[SubstituteAll](exportVarStr, "[", "");
            exportVarStr := StringTools[SubstituteAll](exportVarStr, "]", "");
            exportVarStr := StringTools[SubstituteAll](exportVarStr, "(", "");
            exportVarStr := StringTools[SubstituteAll](exportVarStr, ")", "");

            # Check if the base variable name matches
            if StringTools[Search](exportVarStr, varNameStr) > 0 or StringTools[Search](varNameStr, exportVarStr) > 0 then
                inList := true;
                break;
            end if;
        end do;

        # Skip this variable if not in export list
        if not inList then
            next;
        end if;
    end if;

    if StringTools[Search]("__", varNameStr) > 0 then
        # This is likely an indexed variable base name
        try
            # Get the actual variable - it should be a table
            varValue := eval(varName);

            # Check if it's a table (indexed variables are stored as tables)
            if type(varValue, 'table') then
                # Get all indices that have been assigned
                indexList := [indices(varValue, 'nolist')];

                # For each index, export the value
                for idx in indexList do
                    # idx is just the index itself (e.g., 1, 2, 3)

                    # Get the value at this index
                    indexedVal := varValue[idx];

                    # Check if it has a numeric value (not just a symbol)
                    if type(indexedVal, 'numeric') then
                        # Convert index to string (remove brackets if present)
                        idxStr := convert(idx, string);
                        idxStr := StringTools[SubstituteAll](idxStr, "[", "");
                        idxStr := StringTools[SubstituteAll](idxStr, "]", "");

                        # Write to MATLAB format
                        # Export as: PropertyName(ConnectorNum) = value;
                        fprintf(fd, "%s(%s) = %.15g;\n",
                                varNameStr, idxStr, evalf(indexedVal));
                        exportCount := exportCount + 1;
                    end if;
                end do;
            elif type(varValue, 'numeric') then
                # This is a simple numeric variable (no subscript)
                fprintf(fd, "%s = %.15g;\n", varNameStr, evalf(varValue));
                exportCount := exportCount + 1;
            end if;
        catch:
            # Skip if can't evaluate
        end try;
    end if;
end do;

# Write footer
fprintf(fd, "\n%% ============================================================================\n");
fprintf(fd, "%% Total exported variables: %d\n", exportCount);
fprintf(fd, "%% ============================================================================\n");

# Close file
fclose(fd);

# Report to console
printf("Exported %d variables to %s\n", exportCount, outputFile);
printf("Execute this file in MATLAB to load the calculated values.\n");
