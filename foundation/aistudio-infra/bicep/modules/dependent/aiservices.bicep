// Creates AI services resources, private endpoints, and DNS zones
@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Name of the AI service')
param aiServiceName string

@description('Name of the AI service private link endpoint for cognitive services')
param aiServicesPleName string

@description('Resource ID of the subnet')
param subnetId string

@description('Resource group name for the Private DNS Zone for Cognitive Services.')
param cognitiveServicesPrivateDnsZoneRg string


@description('Resource group name for the Private DNS Zone for OpenAI.')
param openAiPrivateDnsZoneRg string

@description('Azure OpenAI Model Name.')
param azureOpenAIModelName string 

@description('Azure OpenAI Model Version.')
param azureOpenAIModelVersion string

@description('Model Deployment Name.')
param modelDeploymentName string

@description('Deployment Capacity in 1000s TPM.')
param modelDeploymentCapacity int

@allowed([
  'S0'
])

@description('AI service SKU')
param aiServiceSkuName string = 'S0'

var aiServiceNameCleaned = replace(aiServiceName, '-', '')

var cognitiveServicesPrivateDnsZoneName = 'privatelink.cognitiveservices.azure.com'
var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'

resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiServiceNameCleaned
  location: location
  sku: {
    name: aiServiceSkuName
  }
  kind: 'AIServices'
  properties: {
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    apiProperties: {
      statisticsEnabled: false
    }
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: subnetId
          ignoreMissingVnetServiceEndpoint: true
        }
      ]
    }
    customSubDomainName: aiServiceNameCleaned
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: '${aiServiceNameCleaned}-${modelDeploymentName}'
  parent: aiServices
  dependsOn: [
    //azureaiResourceAOAIEndpoint
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

resource aiServicesPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: aiServicesPleName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      { 
        name: aiServicesPleName
        properties: {
          groupIds: [
            'account'
          ]
          privateLinkServiceId: aiServices.id
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource cognitiveServicesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: cognitiveServicesPrivateDnsZoneName
  scope: resourceGroup(subscription().subscriptionId, cognitiveServicesPrivateDnsZoneRg)
  //location: 'global'
}

resource openAiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: openAiPrivateDnsZoneName
  scope: resourceGroup(subscription().subscriptionId, openAiPrivateDnsZoneRg)
  //location: 'global'
}

resource aiServicesPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: aiServicesPrivateEndpoint
  name: 'default'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: replace(openAiPrivateDnsZoneName, '.', '-')
        properties:{
          privateDnsZoneId: openAiPrivateDnsZone.id
        }
      }
      {
        name: replace(cognitiveServicesPrivateDnsZoneName, '.', '-')
        properties:{
          privateDnsZoneId: cognitiveServicesPrivateDnsZone.id
        }
      }
    ]
  }
}

output aiServicesId string = aiServices.id
output aiServicesEndpoint string = aiServices.properties.endpoint
