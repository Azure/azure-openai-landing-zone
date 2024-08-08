using './azure-ai.bicep'

param azureAIResourceName = '<globally unique name for AI resource>'  // e.g 'azure-ai-7uj23hng7h22c-westus'. Remove this parameter to create a new AI resource with a random UUID.
param aiSearchName = '<globally unique name for AI search resource>' // e.g 'azure-ai-search-7uj23hng7h22c-westus'. Remove this parameter to create a new AI search resource with a random UUID.
param privateEndpointName = '<Private endpoint name for the AI Resource>' // e.g 'azure-ai-7uj23hng7h22c-westus-pe'. Remove this parameter to create with a random UUID.
param vnetRgName = '<existing vnet resource group name>'
param vnetName = '<existng vnet name>'
param vnetLocation = '<vnet location>' //e.g 'westus'
param subnetName = '<existing subnet name>'
param azureOpenAIModelName = '<gpt-4-turbo>'
param azureOpenAIModelVersion = '<1106-preview>'
param modelDeploymentName = '<gpt-4-turbo-deployment>'
param modelDeploymentCapacity = 1 //e.g 1 (1000s TPMs)



