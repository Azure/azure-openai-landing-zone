// Parameters
@description('Specifies the globally unique name for the storage account used to store the boot diagnostics logs of the virtual machine.')
param name string = 'boot${uniqueString(resourceGroup().id)}'

@description('Specifies whether to create containers.')
param createContainers bool = true

@description('Specifies an array of containers to create.')
param containerNames array

@description('Specifies the workspace data retention in days.')
param retentionInDays int = 60

@description('Specifies the location.')
param location string

@description('Specifies the resource tags.')
param tags object

@description('Specifies the subnet ID for the private endpoint connection.')
param subnetId string

@description('Specifies the name of the private endpoint.')
@secure()
param privateEndpointName string

param vnetId string 

// Resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  
  // Containers live inside of a blob service
  resource blobService 'blobServices' = {
    name: 'default'
    // Creating containers with provided names if condition is true
    resource containers 'containers' = [for containerName in containerNames: if(createContainers) {
      name: containerName
      properties: {
        publicAccess: 'None'
      }
    }]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  properties: {}
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-${privateEndpointName}-vnetlink'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
  // Child resource of the private endpoint that establishes the connection to the DNS zone
  resource dnsZoneGroup 'privateDnsZoneGroups@2021-05-01' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: '${privateDnsZone.name}-config'
          properties: {
            privateDnsZoneId: privateDnsZone.id
          }
        }
      ]
    }
  }
}

// Outputs
output id string = storageAccount.id
output name string = storageAccount.name
output privateDnsZoneId string = privateDnsZone.id
output privateDnsZoneVnetLinkId string = privateDnsZoneVnetLink.id
output privateEndpointId string = privateEndpoint.id
