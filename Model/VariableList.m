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


%====Mass Flows====
'[01]VolumeFlowRate',       1     
% Replace here with source (How much is coming into the system)
'H2OMassFlowRate__(5)',    0.000001    
% Replace here with source (H2O found in char, from humidity, is as close to zero as possible)
 'MassFlowRate__(16)',        1
% Replace here with source (Temporary Input)
 'MassFlowRate__(3)',        0.6
% Replace here with source (How much water do we expect to come out of filter, including losses [can also be stream 4])


%====Mass Fractions====
'MassFraction_H2O__(4)',    0.03    
% Replace here with source (How much H2O will be taken by char)
'MassFraction_H2O__(5)',    0.00000001    
% Replace here with source (H2O found in char, from humidity, is as close to zero as possible) 
'MassFraction_CHx__(4)',    0.009     
% Replace here with source (How much CHx will be taken by char)
'MassFraction_Char__(4)',    0.961      
% Replace here with source (Mass of Char in output)

%====Composition Out Of Pyrolyzer====
'MassFraction_Gas1__(13)',    0.2      
% Replace here with source (Mass Fraction of Gas 1)
'MassFraction_Gas2__(13)',    0.14      
% Replace here with source (Mass Fraction of Gas 2)
'MassFraction_H2O__(13)',    0.14      
% Replace here with source (Mass Fraction of H2O)
'MassFraction_Char__(13)',    0.35      
% Replace here with source (Mass Fraction of Char)

%====Concentrations====
'CHxConcentration__(1)',    1.0125 
% https://onlinelibrary.wiley.com/doi/abs/10.1002/bms.1200110502
% (Concentration of CHx entering system)
'CHxConcentration__(3)',    0.01
% Replace here with source (concentration of CHx exiting in grey water)


%====Temperatures====
'Temperature__(1)',    10 % C
% Replace here with source (For water entering system)
'Temperature__(3)',    10 % C
% Replace here with source (For water leaving Filter, hot char?)
'Temperature__(13)',    300 % C
% Replace here with source (Temp of Pyrolyzer Output, Gas & Char)
'Temperature__(6)',    290 % C
% Replace here with source (Temp of gas out of char seperator)

%====Density====
'FluidDensity__(1)',   999.70 % kg/m3
% Replace here with source
'FluidDensity__(3)',   999.70 % kg/m3
% Replace here with source
'FluidDensity__(13)',   200 % kg/m3
% Replace here with source (Density of Gas in Pyrolizer Output) 
'FluidDensity__(6)',   180 % kg/m3
% Replace here with source (Density of Gas in Char Seperator Out)

%=============================================================%
%=============================================================%
};