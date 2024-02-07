param searchServiceName string
param location string
param skuName string = 'basic'
param replicaCount int = 1
param partitionCount int = 1
param subnetId string
param privateEndpointName string
param privateDnsZoneName string
param privateDnsZoneGroupName string = 'searchPrivateDnsZoneGroup'
param virtualNetworkId string

// Azure Search service with Private Endpoint
resource searchService 'Microsoft.Search/searchServices@2021-04-01-preview' = {
  name: searchServiceName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    publicNetworkAccess: 'disabled'
    networkRuleSet: {
      ipRules: []
    }
    semanticSearch: 'free'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: searchService.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  location: 'global'
  name: uniqueString(virtualNetworkId)
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

resource privateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: privateEndpoint
  name: privateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
    
  }
}

output searchServiceId string = searchService.id
output privateEndpointId string = privateEndpoint.id
output privateDnsZoneId string = privateDnsZone.id
output name string = searchService.name
