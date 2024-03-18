@description('Azure OpenAI Resource Name.')
param aoaiServiceName string

@description('Private endpoint for a Azure OpenAI Resource.')
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


var privateDnsZoneName = 'privatelink.openai.azure.com'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aoaiServiceName
}


resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetRgName)  
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: subnetName  
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: privateEndpointName
  location: vnetLocation
  properties: {
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: cognitiveService.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  } 
}


resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: privateEndpoint
  name: 'dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${aoaiServiceName}-config'
        properties: {
          privateDnsZoneId: resourceId(privateDNSZoneRgName, 'Microsoft.Network/privateDnsZones', privateDnsZoneName)
        }
      }
    ]
  } 

}

