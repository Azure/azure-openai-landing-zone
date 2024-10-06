// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

param sku string
param location string
param cognitiveName string
param kind  string
param privateDnsZoneName string
param vnet_private_endpoint_subnet_id string 
param subnet_id string
param vnetLocation string
param deployments array = []
param privateEndpointcognitiveName string
param virtualNetworkId string

resource cognitive 'Microsoft.CognitiveServices/accounts@2022-03-01' = {
  name: cognitiveName
  location: location
  kind: kind
  tags: null
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: toLower(cognitiveName)
    publicNetworkAccess: 'disabled'
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: json('[{"id": "${subnet_id}"}]')
      ipRules: json('[]')
    }
  }
}

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: {}
  properties: {}

  resource virtualNetworkLink 'virtualNetworkLinks' = {
    name: 'cognitive-${uniqueString(cognitive.id)}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetworkId
      }
      registrationEnabled: false
    }
  }
}

// Other resources that depend on dnsZones...

resource privateEndpointcognitive 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  location: vnetLocation
  name: privateEndpointcognitiveName
  properties: {
    subnet: {
      id: vnet_private_endpoint_subnet_id
    }
    customNetworkInterfaceName: 'pe-nic-${kind}'
    privateLinkServiceConnections: [
      {
        name: privateEndpointcognitiveName
        properties: {
          privateLinkServiceId: cognitive.id
          groupIds: ['account']
        }
      }
    ]
  }
  tags: {}
  dependsOn: [dnsZones]

  resource dnsZoneGroupcognitive 'privateDnsZoneGroups' = {
    name: 'default' // We should remove '${privateEndpointcognitiveName}-' to just use 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: privateDnsZoneName
          properties: {
            privateDnsZoneId: dnsZones.id
          }
        }
      ]
    }
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: cognitive
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: deployment.?raiPolicyName ? deployment.raiPolicyName : null
  }
  sku: deployment.?sku ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

output name string = cognitive.name
