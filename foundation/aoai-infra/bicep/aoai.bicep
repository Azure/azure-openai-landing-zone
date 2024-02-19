@description('Location for all resources.')
@allowed([
  'australiaeast'
  'canadaeast'
  'eastus'
  'eastus2'
  'francecentral'
  'japaneast'
  'northcentralus'
  'southcentralus'
  'swedencentral'
  'switzerlandnorth'
  'uksouth'
  'westeurope'
  'westus'
])
param location string = 'westus'


@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param aoaiServiceName string 



param deployments array = []


var sku = 'S0'



resource cognitiveService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aoaiServiceName
  location: location
  sku: {
    name: sku
  }
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Disabled'
    customSubDomainName: aoaiServiceName
  }
}



@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  name: deployment.name
  parent: cognitiveService
  properties: {
    model: deployment.model
    raiPolicyName: deployment.raiPolicyName
  }
  sku: deployment.sku
}]


