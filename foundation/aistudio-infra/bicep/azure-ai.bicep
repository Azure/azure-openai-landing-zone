@description('Specifies the name of the Azure AI Studio Resource.')
param azureAIResourceName string = 'ai-${uniqueString(resourceGroup().id)}'


@description('Azure OpenAI Model Name.')
param azureOpenAIModelName string 

@description('Azure OpenAI Model Version.')
param azureOpenAIModelVersion string

@description('Model Deployment Name.')
param modelDeploymentName string

@description('Deployment Capacity in 1000s TPM.')
param modelDeploymentCapacity int

@description('Specifies log workspace name of the log workspace created for the Application Insights.')
param appInsightsLogWorkspaceName string = 'appinsights-workspace-${uniqueString(resourceGroup().id)}'


@description('Service name must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, and is limited between 2 and 60 characters in length.')
@minLength(2)
@maxLength(60)
param aiSearchName string = 'aisearch-${uniqueString(resourceGroup().id)}'


@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
@description('The pricing tier of the search service you want to create (for example, basic or standard).')
param aiSearchSku string = 'standard'


@description('Replicas distribute search workloads across the service. You need at least two replicas to support high availability of query workloads (not applicable to the free tier).')
@minValue(1)
@maxValue(12)
param replicaCount int = 1


@description('Partitions allow for scaling of document count as well as faster indexing by sharding your index over multiple search units.')
@allowed([
  1
  2
  3
  4
  6
  12
])
param partitionCount int = 1


@description('Applicable only for SKUs set to standard3. You can set this property to enable a single, high density partition that allows up to 1000 indexes, which is much higher than the maximum indexes allowed for any other SKU.')
@allowed([
  'default'
  'highDensity'
])
param hostingMode string = 'default'

@description('Specifies the location for all resources.')
/*
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
  'westus3'
  'westeurope'
])
*/
param location string = resourceGroup().location

@description('Private endpoint for a Azure AI Resource.')
param privateEndpointName string = '${azureAIResourceName}-pe'

@description('Vnet resource group name.')
param vnetRgName string

//@description('Private DNS Zone resource group name.')
//param privateDNSZoneRgName string

@description('Vnet location.')
param vnetLocation string

@description('Vnet name.')
param vnetName string

@description('Subnet name where the private endpoint should be provisioned.')
param subnetName string

//@description('Specifies the name of the compute instance.')
//param computeInstanceName string = 'pfci-${uniqueString(resourceGroup().id)}'

@description('If Private endpoint needs to be enabled')
param peEnabled bool = true

@description('Whether endpoints should be created or not. new or existing')
param endpointOption string = 'new'


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
    minimumTlsVersion: 'TLS1_2'  
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      resourceAccessRules: []      
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }    
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
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

resource appInsightsLogWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: appInsightsLogWorkspaceName
  location: location
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: appInsightsLogWorkspace.id
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
    
  }
}

resource aiSearch 'Microsoft.Search/searchServices@2020-08-01' = {
  name: aiSearchName
  location: location
  sku: {
    name: aiSearchSku
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: hostingMode
    publicNetworkAccess: 'enabled'
  }
}

resource azureaiResource 'Microsoft.MachineLearningServices/workspaces@2023-02-01-preview' = {
  name: azureAIResourceName
  location: location
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    friendlyName: azureAIResourceName
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    publicNetworkAccess: peEnabled ? 'Disabled' : 'Enabled'
    managedNetwork: {
      //isolationMode: 'AllowInternetOutbound'
      isolationMode: 'Disabled'
    }
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id
    }
  } 
}

/*
resource azureaiProjectResource 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: azureAIProjectResourceName
  location: location
  kind: 'Project'
  dependsOn: [
    azureAIService
    azureaiResourceAOAIEndpoint
    azureaiResourceContentSafetyEndpoint
    azureaiResourceSpeechEndpoint    
  ]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: azureAIProjectResourceName
    hbiWorkspace: false
    hubResourceId: azureaiResource.id    
  }  
}

*/

resource azureAIService 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: '${azureAIResourceName}-aiservices'
}

/*
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = {
  name: '${vnetName}/${subnetName}'
  scope: resourceGroup(vnetRgName)
}
*/

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: '${azureAIResourceName}-${modelDeploymentName}'
  parent: azureAIService
  dependsOn: [
    azureaiResourceAOAIEndpoint
    //azureaiProjectResource
  ]
  properties: {
    model: {
      format: 'OpenAI'
      name: azureOpenAIModelName
      version: azureOpenAIModelVersion
    }
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: modelDeploymentCapacity
  }
}



resource azureaiResourceAOAIEndpoint 'Microsoft.MachineLearningServices/workspaces/endpoints@2023-08-01-preview' = if (endpointOption == 'new') {
  parent: azureaiResource
  name: 'Azure.OpenAI'
  properties: {
    name: 'Azure.OpenAI'
    endpointType: 'Azure.OpenAI'
    associatedResourceId: null
  }
}


resource azureaiResourceContentSafetyEndpoint 'Microsoft.MachineLearningServices/workspaces/endpoints@2023-08-01-preview' = if (endpointOption == 'new') {
  parent: azureaiResource
  name: 'Azure.ContentSafety'
  properties: {
    name: 'Azure.ContentSafety'
    endpointType: 'Azure.ContentSafety'
    associatedResourceId: null
  }
}

resource azureaiResourceSpeechEndpoint 'Microsoft.MachineLearningServices/workspaces/endpoints@2023-08-01-preview' = if (endpointOption == 'new') {
  parent: azureaiResource
  name: 'Azure.Speech'
  properties: {
    name: 'Azure.Speech'
    endpointType: 'Azure.Speech'
    associatedResourceId: null
  }
}

/*
resource azureaiResourceComputeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2023-10-01' = {
  name: computeInstanceName
  parent: azureaiResource
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'ComputeInstance'
    
    properties: {
      subnet: {
        id: subnet.id
      }
      enableNoPublicIp: true
      vmSize: 'Standard_D2s_v3'
    }
    
  }
}
*/

module azureaipe 'azure-ai-pe-multi.bicep' = if(peEnabled) {
  name: 'aoai-pe-deployment'
  dependsOn: [
    //azureaiProjectResource
    //azureaiResourceComputeInstance
    modelDeployment
  ]
  params: {
    vnetLocation: vnetLocation
    vnetName: vnetName
    location: location
    //applicationInsightsId: applicationInsights.id
    subnetName: subnetName
    vnetRgName: vnetRgName
    //azureAIResourceName: azureAIResourceName
    //azureAIProjectName: azureAIProjectResourceName
    pedeployments: [
      
      {
        name: 'storage-blob'
        privateEndpointName : '${privateEndpointName}-storageblob'
        azureAIResourceId : storageAccount.id
        privateEndpointGroupId: 'blob'
        privateDnsZoneName: 'privatelink.blob.${environment().suffixes.storage}' //'privatelink.blob.core.windows.net'
        privateDNSZoneRgName: 'aml-rg'
        azureResourceName : storageAccountName
      }
      {
        name: 'storage-file'
        privateEndpointName : '${privateEndpointName}-storagefile'
        azureAIResourceId : storageAccount.id
        privateEndpointGroupId: 'file'
        privateDnsZoneName: 'privatelink.file.${environment().suffixes.storage}' //'privatelink.blob.core.windows.net'
        privateDNSZoneRgName: 'vnet'
        azureResourceName : storageAccountName
      }
      
      {
        name: 'keyvault'
        privateEndpointName : '${privateEndpointName}-keyvault'
        azureAIResourceId : keyVault.id
        privateEndpointGroupId: 'vault'
        privateDnsZoneName: 'privatelink.vaultcore.azure.net' //'privatelink.vault.windows.net'
        privateDNSZoneRgName: 'vnet'
        azureResourceName : keyVaultName
      }
      
      {
        name: 'containerregistry'
        privateEndpointName : '${privateEndpointName}-containerregistry'
        azureAIResourceId : containerRegistry.id
        privateEndpointGroupId: 'registry'
        privateDnsZoneName: 'privatelink.azurecr.io' 
        privateDNSZoneRgName: 'vnet'
        azureResourceName : containerRegistryName
      }
      
      {
        name: 'aistudio'
        privateEndpointName : '${privateEndpointName}-aistudio'
        azureAIResourceId : azureaiResource.id
        privateEndpointGroupId: 'amlworkspace'
        privateDnsZoneName: 'privatelink.api.azureml.ms' 
        privateDNSZoneRgName: 'openai'
        azureResourceName : azureAIResourceName
      }

      
      {
        name: 'aisearch'
        privateEndpointName : '${privateEndpointName}-aisearch'
        azureAIResourceId : aiSearch.id
        privateEndpointGroupId: 'searchService'
        privateDnsZoneName: 'privatelink.search.windows.net' 
        privateDNSZoneRgName: 'vnet'
        azureResourceName : aiSearchName
      }
      
    ]

  }

}

module peoutput 'azure-ai-output.bicep' = if(peEnabled)  {
  name: 'peoutput'
  dependsOn: [azureaipe]
  params: {
    pedeployments: [
    {
      privateEndpointName : '${privateEndpointName}-aistudio'
    }
  ]
  }
}


//output aiProjectWorkspaceId string = azureaiProjectResource.properties.workspaceId
