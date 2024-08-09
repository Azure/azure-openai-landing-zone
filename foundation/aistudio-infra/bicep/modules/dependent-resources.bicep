// Creates Azure dependent resources for Azure AI studio
@minLength(2)
@maxLength(10)
@description('Prefix for all resource names.')
param prefix string

@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object = {}

@description('Subnet Id to deploy into.')
param subnetResourceId string

// Variables
var name = toLower('${prefix}')

@description('Resource group name for the Private DNS Zone for Blob.')
param blobPrivateDnsZoneRg string

@description('Resource group name for the Private DNS Zone for File.')
param filePrivateDnsZoneRg string

@description('Resource group name for the Private DNS Zone for Vault.')
param vaultPrivateDnsZoneRg string

@description('Resource group name for the Private DNS Zone for Azure Container Registry.')
param azurecrPrivateDnsZoneRg string

@description('Resource group name for the Private DNS Zone for Cognitive Services.')
param cognitiveServicesPrivateDnsZoneRg string

@description('Resource group name for the Private DNS Zone for OpenAI.')
param openAiPrivateDnsZoneRg string

@description('Azure OpenAI Model Name.')
param azureOpenAIModelName string 

@description('Azure OpenAI Model Version.')
param azureOpenAIModelVersion string

@description('Model Deployment Name.')
param modelDeploymentName string

@description('Deployment Capacity in 1000s TPM.')
param modelDeploymentCapacity int

// Create a short, unique suffix, that will be unique to each resource group
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)

module applicationInsights 'dependent/applicationinsights.bicep' = {
  name: 'appi-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    applicationInsightsName: 'appi-${name}-${uniqueSuffix}'
    logAnalyticsWorkspaceName: 'ws-${name}-${uniqueSuffix}'
    tags: tags
  }
}

// Dependent resources for the Azure Machine Learning workspace
module keyvault 'dependent/keyvault.bicep' = {
  name: 'kv-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    keyvaultName: 'kv-${name}-${uniqueSuffix}'
    keyvaultPleName: 'ple-${name}-${uniqueSuffix}-kv'
    subnetId: subnetResourceId
    tags: tags
    vaultPrivateDnsZoneRg: vaultPrivateDnsZoneRg
  }
}

module containerRegistry 'dependent/containerregistry.bicep' = {
  name: 'cr${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    containerRegistryName: 'cr${name}${uniqueSuffix}'
    containerRegistryPleName: 'ple-${name}-${uniqueSuffix}-cr'
    subnetId: subnetResourceId
    tags: tags
    azurecrPrivateDnsZoneRg: azurecrPrivateDnsZoneRg

  }
}

module aiServices 'dependent/aiservices.bicep' = {
  name: 'ai${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    aiServiceName: 'ai${name}${uniqueSuffix}'
    aiServicesPleName: 'ple-${name}-${uniqueSuffix}-ais'
    subnetId: subnetResourceId
    tags: tags
    cognitiveServicesPrivateDnsZoneRg: cognitiveServicesPrivateDnsZoneRg
    openAiPrivateDnsZoneRg: openAiPrivateDnsZoneRg
    azureOpenAIModelName: azureOpenAIModelName
    azureOpenAIModelVersion: azureOpenAIModelVersion
    modelDeploymentName: modelDeploymentName
    modelDeploymentCapacity: modelDeploymentCapacity
    
  }
}

module storage 'dependent/storage.bicep' = {
  name: 'st${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    storageName: 'st${name}${uniqueSuffix}'
    storagePleBlobName: 'ple-${name}-${uniqueSuffix}-st-blob'
    storagePleFileName: 'ple-${name}-${uniqueSuffix}-st-file'
    storageSkuName: 'Standard_LRS'
    subnetId: subnetResourceId
    tags: tags
    blobPrivateDnsZoneRg: blobPrivateDnsZoneRg
    filePrivateDnsZoneRg: filePrivateDnsZoneRg

  }
}

output aiservicesID string = aiServices.outputs.aiServicesId
output aiservicesTarget string = aiServices.outputs.aiServicesEndpoint
output storageId string = storage.outputs.storageId
output keyvaultId string = keyvault.outputs.keyvaultId
output containerRegistryId string = containerRegistry.outputs.containerRegistryId
output applicationInsightsId string = applicationInsights.outputs.applicationInsightsId
