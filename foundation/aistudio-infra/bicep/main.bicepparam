using './main.bicep'

param aiHubName = 'demo'
param aiHubFriendlyName = 'Demo AI resource'
param aiHubDescription = 'This is an example AI resource for use in Azure AI Studio.'
param tags = {}
param vnetName = 'your-vnet-name'
param vnetRgName = 'your-vnet-resource-group'
param subnetName = 'your-subnet-name'
param location = 'your-location'
param prefix = 'prefix'

param azureOpenAIModelName = '<gpt-4o>'
param azureOpenAIModelVersion = '2024-05-13'
param modelDeploymentName = '<gpt-4o-deployment>'
param modelDeploymentCapacity = 1 //e.g 1 (1000s TPMs)

param blobPrivateDnsZoneRg = 'aml-rg'
param filePrivateDnsZoneRg = 'vnet'
param vaultPrivateDnsZoneRg = 'vnet'
param azuremlApiPrivateDnsZoneRg = 'openai'
param azurecrPrivateDnsZoneRg = 'vnet'
param cognitiveServicesPrivateDnsZoneRg = 'vnet'
param openAiPrivateDnsZoneRg = 'vnet'
param notebooksPrivateDnsZoneRg = 'openai'


