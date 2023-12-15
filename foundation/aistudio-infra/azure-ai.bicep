@description('Specifies the name of the Azure Machine Learning service workspace.')
param azureAIResourceName string = 'azure-ai-${uniqueString(resourceGroup().id)}'

@description('Specifies the location for all resources.')
@allowed([
  'australiaeast'
  'brazilsouth'
  'canadacentral'
  'centralus'
  'eastasia'
  'eastus'
  'eastus2'
  'francecentral'
  'japaneast'
  'koreacentral'
  'northcentralus'
  'northeurope'
  'southeastasia'
  'southcentralus'
  'uksouth'
  'westcentralus'
  'westus'
  'westus2'
  'westeurope'
])
param location string = 'westus'

@description('Private endpoint for a Azure AI Resource.')
param privateEndpointName string

@description('Vnet resource group name.')
param vnetRgName string

@description('Private DNS Zone resource group name.')
param privateDNSZoneRgName string

@description('Vnet location.')
param vnetLocation string

@description('Vnet name.')
param vnetName string

@description('Subnet name where the private endpoint should be provisioned.')
param subnetName string

@description('Name of the project under Azure AI Resource.')
param projectName string

@description('If Private endpoint needs to be enabled')
param peEnabled bool = true


var endpointOption = 'existing'
var storageAccountName = 'sa${uniqueString(resourceGroup().id)}'
var storageAccountType = 'Standard_LRS'
var keyVaultName = 'kv${uniqueString(resourceGroup().id)}'
var tenantId = subscription().tenantId
var applicationInsightsName = 'ai${uniqueString(resourceGroup().id)}'
var containerRegistryName = 'cr${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
    }    
    publicNetworkAccess: peEnabled ? 'Disabled' : 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
    publicNetworkAccess: peEnabled ? 'Disabled' : 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: (((location == 'eastus2') || (location == 'westcentralus')) ? 'southcentralus' : location)
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: peEnabled ? 'Disabled' : 'Enabled'
  }
}

resource azureaiResource 'Microsoft.MachineLearningServices/workspaces@2022-10-01' = {
  name: azureAIResourceName
  location: location
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: azureAIResourceName
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    storageAccount: storageAccount.id
    publicNetworkAccess: peEnabled ? 'Disabled' : 'Enabled'
    workspaceHubConfig : {
      defaultWorkspaceResourceGroup: resourceGroup().id
    }

  }  
}


resource azureAIService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: '${azureAIResourceName}-AIService'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  
  properties: {
    publicNetworkAccess: 'Enabled'    //peEnabled ? 'Disabled' : 'Enabled'
    customSubDomainName: '${azureAIResourceName}-AIService'
  }
}


resource azureaiResourceAOAIEndpoint 'Microsoft.MachineLearningServices/workspaces/endpoints@2023-08-01-preview' = if (endpointOption == 'new') {
  parent: azureaiResource
  name: 'Azure.OpenAI'
  properties: {
    name: 'Azure.OpenAI'
    endpointType: 'Azure.OpenAI'
    associatedResourceId: azureAIService.id
  }
}


resource azureaiResourceContentSafetyEndpoint 'Microsoft.MachineLearningServices/workspaces/endpoints@2023-08-01-preview' = if (endpointOption == 'new') {
  parent: azureaiResource
  name: 'Azure.ContentSafety'
  properties: {
    name: 'Azure.ContentSafety'
    endpointType: 'Azure.ContentSafety'
    associatedResourceId: azureAIService.id
  }
}

resource azureaiResourceSpeechEndpoint 'Microsoft.MachineLearningServices/workspaces/endpoints@2023-08-01-preview' = if (endpointOption == 'new') {
  parent: azureaiResource
  name: 'Azure.Speech'
  properties: {
    name: 'Azure.Speech'
    endpointType: 'Azure.Speech'
    associatedResourceId: azureAIService.id
  }
}



module azureaipe 'azure-ai-pe.bicep' = if(peEnabled) {
  name: 'aoai-pe-deployment'
  params: {
    azureAIResourceName: azureAIResourceName
    azureAIResourceId: azureaiResource.id
    privateEndpointName: privateEndpointName
    vnetRgName: vnetRgName
    privateDNSZoneRgName: privateDNSZoneRgName
    vnetLocation: vnetLocation
    vnetName: vnetName
    subnetName: subnetName
    privateDnsZoneName: 'privatelink.api.azureml.ms'
    privateEndpointGroupId: 'amlworkspace'

  }
 
}

module azureaiservicepe 'azure-ai-pe.bicep' = if(peEnabled) {
  name: 'azureaiservice-pe-deployment'
  params: {
    azureAIResourceName: '${azureAIResourceName}-AIService'
    azureAIResourceId: azureAIService.id
    privateEndpointName: '${privateEndpointName}-AIService' 
    vnetRgName: vnetRgName
    privateDNSZoneRgName: 'vnet'
    vnetLocation: vnetLocation
    vnetName: vnetName
    subnetName: subnetName
    privateDnsZoneName: 'privatelink.openai.azure.com'
    privateEndpointGroupId: 'account'

  }
 
}


