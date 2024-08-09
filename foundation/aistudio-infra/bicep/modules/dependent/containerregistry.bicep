// Creates an Azure Container Registry with Azure Private Link endpoint
@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Container registry name')
param containerRegistryName string

@description('Container registry private link endpoint name')
param containerRegistryPleName string

@description('Resource ID of the subnet')
param subnetId string

@description('Resource group name for the Private DNS Zone for Azure Container Registry.')
param azurecrPrivateDnsZoneRg string

var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')

var privateDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'

var groupName = 'registry' 

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryNameCleaned
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'enabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
  }
}

resource containerRegistryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: containerRegistryPleName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: containerRegistryPleName
        properties: {
          groupIds: [
            groupName
          ]
          privateLinkServiceId: containerRegistry.id
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}


resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
  scope: resourceGroup(subscription().subscriptionId, azurecrPrivateDnsZoneRg)
  //location: 'global'
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: containerRegistryPrivateEndpoint
  name: '${groupName}-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties:{
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

output containerRegistryId string = containerRegistry.id
