using './main.bicep'

param aiHubName = 'lz-test1-r'
param aiHubFriendlyName = 'lz-test1-r'
param aiHubDescription = 'This is an example AI resource for use in Azure AI Studio.'
param tags = {}
param vnetName = 'vnet-westus'
param vnetRgName = 'vnet'
param subnetName = 'containerapp'
param location = 'westus'
param prefix = 'anildwa'

param azureOpenAIModelName = 'gpt-4o'
param azureOpenAIModelVersion = '2024-05-13'
param modelDeploymentName = 'gpt-4o'
param modelDeploymentCapacity = 1 //e.g 1 (1000s TPMs)

//Private DNS Zones Parameters
param blobPrivateDnsZoneRg = 'aml-rg'
param filePrivateDnsZoneRg = 'vnet'
param vaultPrivateDnsZoneRg = 'vnet'
param azuremlApiPrivateDnsZoneRg = 'openai'
param azurecrPrivateDnsZoneRg = 'vnet'
param cognitiveServicesPrivateDnsZoneRg = 'vnet'
param openAiPrivateDnsZoneRg = 'vnet'
param notebooksPrivateDnsZoneRg = 'openai'


