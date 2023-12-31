//@description('Azure AI resource Name.')
//param azureAIResourceName string

//@description('Azure AI Project Name.')
//param azureAIProjectName string


//@description('Private endpoint for a Azure OpenAI Resource.')
//param privateEndpointName string

@description('Vnet resource group name.')
param vnetRgName string

//@description('Private DNS Zone resource group name.')
//param privateDNSZoneRgName string

@description('Vnet location.')
param vnetLocation string

@description('Vnet name.')
param vnetName string

@description('Subnet name where the private endpoint should be provisioned.')
param subnetName string

//@description('private DNS zone name. For e.g. privatelink.api.azureml.ms')
//param privateDnsZoneName string


//@description('group id or the sub resource name. For e.g. amlworkspace')
//param privateEndpointGroupId string

@description('PE parameters for multiple resources')
param pedeployments array = []


param location string = resourceGroup().location


//param applicationInsightsId string

//var storageAccountName = 'sa${uniqueString(resourceGroup().id)}'
//var keyVaultName = 'kv${uniqueString(resourceGroup().id)}'
var containerRegistryName = 'cr${uniqueString(resourceGroup().id)}'
//var tenantId = subscription().tenantId

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

/*
resource azureaiResource 'Microsoft.MachineLearningServices/workspaces@2023-02-01-preview' existing = {
  name: azureAIResourceName  
}


resource azureaiProject 'Microsoft.MachineLearningServices/workspaces@2023-02-01-preview' existing = {
  name: azureAIProjectName  
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Enabled'
    
    networkAcls: {
      resourceAccessRules: [
        
        
        {
          tenantId: tenantId
          resourceId: azureaiProject.id
        }
        
        {
          tenantId: tenantId
          resourceId: azureaiResource.id
        }
      ]
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
}
*/

/*
resource storageFileDataPrivilegedContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('storageFileDataPrivilegedContributorRole', azureaiProject.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleAssignments', '69566ab7-960f-475b-8e7c-b3118f30c6bd')
    principalId: azureaiProject.identity.principalId
  }
}


resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location 
  dependsOn:  [
    azureaiProject
  ]
  properties: {
    tenantId: tenantId    
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
    publicNetworkAccess: 'Disabled'
    enableRbacAuthorization: true
  }
  
}



resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId 
        objectId: azureaiResource.identity.principalId
        permissions: {
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
          certificates: [
            'all'
          ]
        }
      }
      
      {
        tenantId: tenantId 
        objectId: azureaiProject.identity.principalId
        permissions: {
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
          certificates: [
            'all'
          ]
        }
      }
      
    ]
  }
}

*/

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}


@batchSize(1)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = [for (peparam, index) in pedeployments: {
  name: '${peparam.privateEndpointName}'
  location: vnetLocation
  dependsOn: [
    //storageAccount
    //keyVault
    containerRegistry
    //azureaiResource
  ]
  properties: {
    customNetworkInterfaceName: '${peparam.privateEndpointName}-nic'
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: peparam.privateEndpointName
        properties: {
          privateLinkServiceId: peparam.azureAIResourceId
          groupIds: [
            peparam.privateEndpointGroupId
          ]
        }
      }
    ]
  } 
}]

@batchSize(1)
resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = [for (peparam, index) in pedeployments:{
  parent: privateEndpoint[index]
  name: '${peparam.azureResourceName}-privatednszonegroup-${peparam.name}'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: peparam.privateDnsZoneName
        properties: {
          privateDnsZoneId: resourceId(peparam.privateDNSZoneRgName, 'Microsoft.Network/privateDnsZones', '${peparam.privateDnsZoneName}') // resourcePrivateDnsZone[index].id 
        }
      }
    ]
  }
}]


