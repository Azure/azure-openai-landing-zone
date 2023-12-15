@description('Azure AI Resource Name.')
param azureAIResourceName string

@description('Azure AI Service Name.')
param azureAIResourceId string


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

@description('private DNS zone name. For e.g. privatelink.api.azureml.ms')
param privateDnsZoneName string


@description('group id or the sub resource name. For e.g. amlworkspace')
param privateEndpointGroupId string

/*
resource azureAIResource 'Microsoft.MachineLearningServices/workspaces@2022-10-01' existing = {
  name: azureAIResourceName
}


resource azureAIServiceResource 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: azureAIService
}

*/


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
          privateLinkServiceId: azureAIResourceId
          groupIds: [
            privateEndpointGroupId
          ]
        }
      }
    ]
  } 
}

resource resourcePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
  scope: resourceGroup(privateDNSZoneRgName)  
}


resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: privateEndpoint
  name: '${azureAIResourceName}-PrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties: {
          privateDnsZoneId: resourcePrivateDnsZone.id //resourceId(privateDNSZoneRgName, 'Microsoft.Network/privateDnsZones', privateDnsZoneName)
        }
      }
    ]
  } 

}
