# 3rd_Year_Project_C3

## System Composer Guide

#### Before doing anything, make sure to pull using the source control so that all of the latest information is available to you.

### Key Files

#### Main diagram page
```Hospital_Context.slx ```

#### Profile File
```unitProfile.xml```

This is used to differenciate between the different parts within the system and give them their "Identity"

#### Matlab & Maple Front-End Scripts
```ExportToMaple.m```

```LoadMapleValues.m```

```MassBalanceCalculations.mw```

These are the main files you need to interact with. If you find yourself opening other files, you are lost... or better be carrying a keyboard.

#### Backend Files
```MassBalanceCalculations.mpl```

```ExportMapleToMatlab.mpl```

```MapleExportedVariables.m```

```Hospital_Context.slx.r.2024b```

These are mostly files used to help export information between the different softwares. You shouldn't have to interact with them. The file dates 2024 is just used to convert the information to the latest version of matlab


## Hot to use MATLAB ↔ Maple transfer scripts

### Step 1: Export System Composer Data to Maple
In MATLAB, run:
```matlab
ExportToMaple.m
```
This extracts all connector properties from `Hospital_Context.slx` and exports them to `MassBalanceCalculation.mpl` in Maple format.

### Step 2: Solve Mass Balance Equations in Maple
1. Open `MassBalanceCalculation.mw` in Maple
2. Variables are automatically loaded from `MassBalanceCalculation.mpl`
3. Edit the mass balance equations below the marker lines
4. Solve the equations to calculate values
5. The line "read "ExportMapleToMatlab.mpl":" will result in the calculated numeric values to be exported to `MapleExportedVariables.m`

### Step 4: Load Values Back into MATLAB
In MATLAB, run:
```matlab
LoadMapleValues
```
This loads all calculated values into a structure called `MapleVars` in your workspace.

Access values using:
```matlab
MapleVars.CHxConcentration__(1)     % Connector 1
MapleVars.Temperature__(5)          % Connector 5
```

---

## Architecture Overview

### System Components

The workflow consists of four main components working together:

1. **System Composer Model** (`Hospital_Context.slx`)
   - Contains the hospital pyrolysis system architecture
   - Components connected by connectors with stereotyped properties
   - Properties defined in `unitProfile.xml` profile

2. **MATLAB → Maple Export** (`ExportToMaple.m`)
   - Parses `unitProfile.xml` to extract stereotype definitions
   - Handles stereotype inheritance (e.g., Pipe_GreyWater inherits from Pipe_)
   - Extracts all connector properties with units
   - Exports to Maple format: `PropertyName__[ConnectorNumber] := value;`
   - Preserves user equations using marker system

3. **Maple Calculation Environment** (`MassBalanceCalculation.mw` + `.mpl`)
   - `.mpl` file: Auto-generated variables (regenerated each export)
   - `.mw` file: User's mass balance equations (manually created)
   - Variables use indexed format: `CHxConcentration__[01]`
   - Blank/default values become symbolic: `Variable__[01] := Variable__[01];`

4. **Maple → MATLAB Import** (`ExportMapleToMatlab.mpl` + `LoadMapleValues.m`)
   - Scans Maple workspace for all indexed variables (`__` pattern)
   - Exports only numeric values (skips symbolic expressions)
   - Creates MATLAB structure format for easy access

### Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    MATLAB Environment                        │
│                                                              │
│  Hospital_Context.slx  ──→  ExportToMaple.m                  │
│  (System Composer)          (Parses unitProfile.xml)         │
│                                  │                           │
│                                  ↓                           │
└──────────────────────────────────┼───────────────────────────┘
                                   │
                    MassBalanceCalculation.mpl
                    (Auto-generated variables)
                                   │
                                   ↓
┌─────────────────────────────────────────────────────────────┐
│                     Maple Environment                       │
│                                                             │
│  MassBalanceCalculation.mw                                  │
│  (User equations + calculations)                            │
│  - Loads variables from .mpl                                │
│  - User writes mass balance equations                       │
│  - Solves for calculated values                             │
│                                  │                          |
│                                  ↓                          │
│                      ExportMapleToMatlab.mpl                │
│                      (Exports numeric values)               │
└──────────────────────────────────┼──────────────────────────┘
                                   │
                   MapleExportedVariables.m
                   (Auto-generated MATLAB code)
                                   │
                                   ↓
┌─────────────────────────────────────────────────────────────┐
│                    MATLAB Environment                       │
│                                                             │
│  LoadMapleValues.m  ──→  MapleVars structure                │
│  (Loads calculated values into workspace)                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### File Descriptions

**Essential MATLAB Scripts:**
- `ExportToMaple.m` - Exports System Composer properties to Maple
- `LoadMapleValues.m` - Imports Maple calculated values to MATLAB workspace

**Essential Maple Scripts:**
- `ExportMapleToMatlab.mpl` - Exports calculated values from Maple to MATLAB format

**Data Files:**
- `MassBalanceCalculation.mpl` - Auto-generated Maple variables (DO NOT EDIT manually)
- `MassBalanceCalculation.mw` - Maple worksheet for equations (USER EDITS THIS)
- `MapleExportedVariables.m` - Auto-generated MATLAB code (regenerated each export)
- `unitProfile.xml` - System Composer profile defining stereotypes and properties

**Model Files:**
- `Hospital_Context.slx` - Main System Composer architecture model

### Key Features

**Stereotype Inheritance:**
- Base stereotypes (e.g., `Pipe_`) define common properties
- Derived stereotypes (e.g., `Pipe_GreyWater`) inherit and extend properties
- Export automatically merges inherited properties

**Blank Value Handling:**
- Properties set to `0` or empty are treated as symbolic unknowns
- Exported as self-references: `Temperature__[01] := Temperature__[01];`
- Allows Maple to solve for these values

**Equation Preservation:**
- User equations in `.mpl` file are preserved during regeneration
- Marker line separates auto-generated variables from user equations
- Safe to re-run `ExportToMaple` without losing equation work

**Partial Solution Support:**
- Export from Maple works with partially solved systems
- Only exports variables with numeric values
- Symbolic/unsolved variables are automatically skipped

### Variable Naming Convention

**In Maple:**
```maple
PropertyName__[ConnectorNumber] := value;
```
Examples:
- `CHxConcentration__[01] := 150;`
- `Temperature__[05] := 298.15;`
- `VolumeFlowRate__[02] := 1.5;`

**In MATLAB (after import):**
```matlab
MapleVars.PropertyName__(ConnectorNumber)
```
Examples:
- `MapleVars.CHxConcentration__(1)`
- `MapleVars.Temperature__(5)`
- `MapleVars.VolumeFlowRate__(2)`

---

# SMILE:)    Or else...

#Mathilda testing stuff
##Peter trying this
###Jake TOO ! :)
