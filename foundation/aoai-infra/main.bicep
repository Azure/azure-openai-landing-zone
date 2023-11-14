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
])
param location string = 'northcentralus'
@allowed([
  'gpt-4'
  'gpt-4-32k'
  'gpt-35-turbo'
  'gpt-35-turbo-16k'
])
param model string[] = ['gpt-35-turbo','gpt-35-turbo-16k']

param modelVersion string[] = ['0613','0613']

@description('''The capacity of the deployment in 1000 units. 
The number of items in the array should match the number of deployments.
For e.g to provision 30K TPM, set capacity to 30. Max value of capacity is 300.
''')
param capacity int[]

@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param aoaiServiceName string //= 'aoai-${uniqueString(resourceGroup().id)}-${location}'

@description('Azure OpenAI deployment name.')
param aoai_deployments string[]

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

module aoai 'aoai.bicep' = {
  name: 'aoai-deployment'
  params: {
    location: location
    aoaiServiceName: aoaiServiceName
    deployments: [
      {
        name: aoai_deployments[0]
        model: {
          format: 'OpenAI'
          name: model[0]
          version: modelVersion[0]
        }
        raiPolicyName: 'CustomRaiPolicy_1'
        sku: {
          name: 'Standard'
          capacity: capacity[0]
        }
      }
      {
        name: aoai_deployments[1]
        model: {
          format: 'OpenAI'
          name: model[1]
          version: modelVersion[1]
        }
        raiPolicyName: 'CustomRaiPolicy_1'
        sku: {
          name: 'Standard'
          capacity: capacity[1]
        }
      }
    ]
  }
}


module aoaipe 'privateendpoint.bicep' = {
  name: 'aoai-pe-deployment'
  params: {
    aoaiServiceName: aoaiServiceName
    privateEndpointName: privateEndpointName
    vnetRgName: vnetRgName
    privateDNSZoneRgName: privateDNSZoneRgName
    vnetLocation: vnetLocation
    vnetName: vnetName
    subnetName: subnetName
  }
  dependsOn: [
    aoai
  ]
}


module aoairole 'aoairole.bicep' = {
  name: 'aoai-role-deployment'
  params: {
    aoaiServiceName: aoaiServiceName
  }
  dependsOn: [
    aoai
  ]
}
