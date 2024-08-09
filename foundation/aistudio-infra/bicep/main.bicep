// Execute this main file to deploy Azure AI studio resources in the basic security configuration

// Parameters
@minLength(2)
@maxLength(12)
@description('Name for the AI resource and used to derive name of dependent resources.')
param aiHubName string = 'demo'

@description('Friendly name for your Azure AI resource')
param aiHubFriendlyName string = 'Demo AI resource'

@description('Description of your Azure AI resource displayed in AI studio')
param aiHubDescription string = 'This is an example AI resource for use in Azure AI Studio.'

@description('Set of tags to apply to all resources.')
param tags object = {}

@description('Resource name of the virtual network to deploy the resource into.')
param vnetName string

@description('Resource group name of the virtual network to deploy the resource into.')
param vnetRgName string

@description('Name of the subnet to deploy into.')
param subnetName string

@description('The location into which the resources should be deployed.')
param location string = resourceGroup().location

@minLength(2)
@maxLength(10)
@description('Prefix for all resource names.')
param prefix string


@description('Resource group name for the Private DNS Zone for Blob.')
param blobPrivateDnsZoneRg string = 'aml-rg'

@description('Resource group name for the Private DNS Zone for File.')
param filePrivateDnsZoneRg string = 'vnet'


@description('Resource group name for the Private DNS Zone for Vault.')
param vaultPrivateDnsZoneRg string = 'vnet'

@description('Resource group name for the Private DNS Zone for AzureML API.')
param azuremlApiPrivateDnsZoneRg string = 'openai'

@description('Resource group name for the Private DNS Zone for Azure Container Registry.')
param azurecrPrivateDnsZoneRg string = 'vnet'

@description('Resource group name for the Private DNS Zone for Cognitive Services.')
param cognitiveServicesPrivateDnsZoneRg string = 'vnet'

@description('Resource group name for the Private DNS Zone for OpenAI.')
param openAiPrivateDnsZoneRg string = 'vnet'

@description('Resource group name for the Private DNS Zone for Notebooks.')
param notebooksPrivateDnsZoneRg string = 'openai'

@description('Azure OpenAI Model Name.')
param azureOpenAIModelName string 

@description('Azure OpenAI Model Version.')
param azureOpenAIModelVersion string

@description('Model Deployment Name.')
param modelDeploymentName string

@description('Deployment Capacity in 1000s TPM.')
param modelDeploymentCapacity int

// Variables
var name = toLower('${aiHubName}')

// Create a short, unique suffix, that will be unique to each resource group
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 7)

var vnetResourceId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${vnetRgName}/providers/Microsoft.Network/virtualNetworks/${vnetName}'
var subnetResourceId = '${vnetResourceId}/subnets/${subnetName}'

// Dependent resources for the Azure Machine Learning workspace
module aiDependencies 'modules/dependent-resources.bicep' = {
  name: 'dependencies-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    tags: tags
    subnetResourceId: subnetResourceId
    prefix: prefix
    blobPrivateDnsZoneRg: blobPrivateDnsZoneRg
    filePrivateDnsZoneRg: filePrivateDnsZoneRg
    vaultPrivateDnsZoneRg: vaultPrivateDnsZoneRg
    azurecrPrivateDnsZoneRg: azurecrPrivateDnsZoneRg
    cognitiveServicesPrivateDnsZoneRg: cognitiveServicesPrivateDnsZoneRg
    openAiPrivateDnsZoneRg: openAiPrivateDnsZoneRg
    azureOpenAIModelName: azureOpenAIModelName
    azureOpenAIModelVersion: azureOpenAIModelVersion
    modelDeploymentName: modelDeploymentName
    modelDeploymentCapacity: modelDeploymentCapacity
   
  }
}

module aiHub 'modules/ai-hub.bicep' = {
  name: 'ai-${name}-${uniqueSuffix}-deployment'
  params: {
    // workspace organization
    aiHubName: 'aih-${name}-${uniqueSuffix}'
    aiHubFriendlyName: aiHubFriendlyName
    aiHubDescription: aiHubDescription
    location: location
    tags: tags

    //metadata
    uniqueSuffix: uniqueSuffix

    //network related
    subnetResourceId: subnetResourceId
    azuremlApiPrivateDnsZoneRg: azuremlApiPrivateDnsZoneRg
    notebooksPrivateDnsZoneRg: notebooksPrivateDnsZoneRg
    
    // dependent resources
    aiServicesId: aiDependencies.outputs.aiservicesID
    aiServicesTarget: aiDependencies.outputs.aiservicesTarget
    applicationInsightsId: aiDependencies.outputs.applicationInsightsId
    containerRegistryId: aiDependencies.outputs.containerRegistryId
    keyVaultId: aiDependencies.outputs.keyvaultId
    storageAccountId: aiDependencies.outputs.storageId

  }
}
