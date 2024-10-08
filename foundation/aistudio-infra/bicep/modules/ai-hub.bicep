// Creates an Azure AI resource with proxied endpoints for the Azure AI services provider

@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('AI hub name')
param aiHubName string

@description('AI hub display name')
param aiHubFriendlyName string = aiHubName

@description('AI hub description')
param aiHubDescription string

@description('Resource ID of the application insights resource for storing diagnostics logs')
param applicationInsightsId string

@description('Resource ID of the container registry resource for storing docker images')
param containerRegistryId string

@description('Resource ID of the key vault resource for storing connection strings')
param keyVaultId string

@description('Resource ID of the storage account resource for storing experimentation outputs')
param storageAccountId string

@description('Resource ID of the AI Services resource')
param aiServicesId string

@description('Resource ID of the AI Services endpoint')
param aiServicesTarget string

@description('Subnet Id to deploy into.')
param subnetResourceId string

@description('Unique Suffix used for name generation')
param uniqueSuffix string

@description('Resource group name for the Private DNS Zone for AzureML API.')
param azuremlApiPrivateDnsZoneRg string

@description('Resource group name for the Private DNS Zone for Notebooks.')
param notebooksPrivateDnsZoneRg string

var privateEndpointName = '${aiHubName}-AIHub-PE'
var targetSubResource = [
    'amlworkspace'
]

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: aiHubName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // organization
    friendlyName: aiHubFriendlyName
    description: aiHubDescription

    // dependent resources
    keyVault: keyVaultId
    storageAccount: storageAccountId
    applicationInsights: applicationInsightsId
    containerRegistry: containerRegistryId

    // network settings
    publicNetworkAccess: 'Disabled'
    managedNetwork: {
      isolationMode: 'AllowInternetOutBound'
    }

    // private link settings
    sharedPrivateLinkResources: []
  }
  kind: 'hub'

  resource aiServicesConnection 'connections@2024-01-01-preview' = {
    name: '${aiHubName}-connection-AIServices'
    properties: {
      category: 'AIServices'
      target: aiServicesTarget
      authType: 'ApiKey'
      isSharedToAll: true
      credentials: {
        key: '${listKeys(aiServicesId, '2021-10-01').key1}'
      }
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiServicesId
      }
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetResourceId
    }
    customNetworkInterfaceName: '${aiHubName}-nic-${uniqueSuffix}'
    privateLinkServiceConnections: [
      {
        name: aiHubName
        properties: {
          privateLinkServiceId: aiHub.id
          groupIds: targetSubResource
        }
      }
    ]
  }

}


resource privateLinkApi 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.api.azureml.ms'
  scope: resourceGroup(subscription().subscriptionId, azuremlApiPrivateDnsZoneRg)
  //location: 'global'
  //tags: {}
  //properties: {}
}

resource privateLinkNotebooks 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.notebooks.azure.net'
  scope: resourceGroup(subscription().subscriptionId, notebooksPrivateDnsZoneRg)
  //location: 'global'
  //tags: {}
  //properties: {}
}

resource dnsZoneGroupAiHub 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-api-azureml-ms'
        properties: {
            privateDnsZoneId: privateLinkApi.id
        }
      }
      {
        name: 'privatelink-notebooks-azure-net'
        properties: {
            privateDnsZoneId: privateLinkNotebooks.id
        }
      }
    ]
  }
  dependsOn: [
    //vnetLinkApi
    //vnetLinkNotebooks
  ]
}


output aiHubID string = aiHub.id
