
param location string
param addressPrefix string
param aiSubnetAddressPrefix string
param privateEndpointSubnetAddressPrefix string
param azureBastionSubnetAddressPrefix string
param jumpboxSubnetAddressPrefix string
param appSubnetAddressPrefix string
param vnet_name string


resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'ai-subnet'
        properties: {
          addressPrefix: aiSubnetAddressPrefix
        }
      }
      {
        name: 'private-endpoint-subnet'
        properties: {
          addressPrefix: privateEndpointSubnetAddressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.CognitiveServices'
              locations: [
                location
              ]
            }
          ]
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetAddressPrefix
        }
      }
      {
        name: 'jumpbox-subnet'
        properties: {
          addressPrefix: jumpboxSubnetAddressPrefix
        }
      }
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: appSubnetAddressPrefix
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}
output id string = vnet.id
output subnets array = vnet.properties.subnets
output name string = vnet.name
