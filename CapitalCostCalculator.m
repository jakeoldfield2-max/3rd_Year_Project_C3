% --- SCRIPT CONFIGURATION ---
clear; % Clear workspace variables
clc;   % Clear command window
import systemcomposer.query.*

% --- ANALYSIS ---
modelName = 'Hospital_Context.slx'; %sets up the system composer model
model = systemcomposer.loadModel(modelName); %Loads model
arch = get(model, "Architecture"); %Establishes the architecture of the model

components = arch.Components; %Connects the code to the component objects in the diagram

numComponents = width(components); %Creates the matrix for the saving of information
componentData = cell(numComponents, 10); % Ten Columns for now

%Extracts the information for all of the components
for i = 1:width(components)
    
    componentData{i,1} = components(1,i).Name;
    componentData{i,2} = components(1,i).getStereotypes();

    componentData{i,3} = getProperty(components(1,i), append(componentData{i,2},".capitalCost"));
end

%Sums up all the values
numericCost = str2double(componentData(:,3)); %Was extracted as strings, so must be converted
S = sum(numericCost(:,1));
