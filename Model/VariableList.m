% VariableList.m
% Key Independant variables for mass balance
% Add one variable per line in the cell array below
% please format within '' and write the variable with the same format
% For adding our sources, please use % followed by the URL.

% Format: {'Variable Name', Expected Value}
% to leave value empty, write ('')
variableList = {
%=============================================================%
%WRITE AFTER THIS POINT%
%=============================================================%
%   Variable Name              Value



%======Needed Variables Into Pyrolyzer======
% ( These  will be reduced as we know more about the plant processes )
 'ChipMassFlowRate__(16)',        2
% CHANGE to be function of char required
 'MassFraction_Chips__(16)',        0.65
% Replace here with source (Temporary Input)
 'MassFraction_H2O__(16)',        0.2
% Replace here with source (Temporary Input)
 'MassFraction_TreatmentChemicals__(16)',        0.15
% Replace here with source (Temporary Input)
 'InertMassFlowRate__(14)',        0.5
% Replace here with source (Amount of Inert Gas we will be passing through the pipes)



%======Compounds from Char Pyrolysis======
'CharConversionFraction__(13)',    0.33      
% https://pubs.acs.org/doi/10.1021/acssuschemeng.4c01733
'Gas1ConversionFraction__(13)',    0.41      
% https://pubs.acs.org/doi/10.1021/acssuschemeng.4c01733
% bio oil component
'Gas2ConversionFraction__(13)',    0.25      
% https://pubs.acs.org/doi/10.1021/acssuschemeng.4c01733
% NCG component
% Do we want to add H2O here, currently I am just counting it seperatly
% from the chips with a seperate wight fraction



%======Needed Variables For Char Seperator======
'H2OMassFlowRate__(5)',    0.000001    
% Replace here with source (H2O found in char, from humidity, is as close to zero as possible)
'MassFraction_H2O__(5)',    0.00000001    
% Replace here with source (H2O found in char, from humidity, is as close to zero as possible) 



%======Needed Variables PBR======
'MassFraction_H2O__(4)',    0.03    
% Replace here with source (How much H2O will be taken by char out of filter)
'MassFraction_CHx__(4)',    0.0833     
% kg/kg Excel Biochar filter tab average placeholder value
'MassFraction_Char__(4)',    0.961      
% CHANGE TO BE FUNCTION OF [CHX] AND WATER (Mass of Char in output of filter)
'CHxConcentration__(3)',    0.01
% REPLACE with function of adsorption and flow rates to see how much remains (concentration of CHx exiting in grey water)


%======Needed Variables Buffer Tank======
'CHxConcentration__(1)',    1.0125 
% https://onlinelibrary.wiley.com/doi/abs/10.1002/bms.1200110502
% (Concentration of CHx entering system)
'[01]VolumeFlowRate',       1     
% Replace here with source (How much is coming into the system)



%======Condition Variables======
'Temperature__(1)',    10 % C
% Replace here with source (For water entering system)
'FluidDensity__(1)',   999.70 % kg/m3
% Replace here with source
'Temperature__(3)',    10 % C
% Replace here with source (For water leaving Filter, hot char affect temp?)
'FluidDensity__(3)',   999.70 % kg/m3
% Replace here with source(If temp change, then density?)
'Temperature__(6)',    290 % C
% Replace here with source (Temp of gas out of char seperator)
'FluidDensity__(6)',   180 % kg/m3
% Replace here with source (Density of Gas in Char Seperator Out)
'Temperature__(13)',    300 % C
% Replace here with source (Temp of Pyrolyzer Output, Gas & Char)
'FluidDensity__(13)',   200 % kg/m3
% Replace here with source (Density of Gas in Pyrolizer Output) 



%=============================================================%
%=============================================================%
};
