param location string = 'canadaeast'
param locationFomsRecogniser string ='canadacentral'
param locationStaticWebApp string ='westus2'

param addressPrefixParam string = '10.0.0.0/16'

param aiSubnetAddressPrefixParam string = '10.0.0.0/24'

param azureBastionSubnetAddressPrefix string = '10.0.1.0/24'

param privateEndpointSubnetAddressPrefixParam string = '10.0.2.0/24'

param jumpboxSubnetAddressPrefixParam string = '10.0.3.0/24'

param  appSubnetAddressPrefix string  = '10.0.4.0/24'

module vnet './core/vnet.bicep' = {
  name: 'vnetnDeployment'
  params: {
    location: location
    addressPrefix: addressPrefixParam
    aiSubnetAddressPrefix: aiSubnetAddressPrefixParam
    azureBastionSubnetAddressPrefix: azureBastionSubnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefixParam
    jumpboxSubnetAddressPrefix: jumpboxSubnetAddressPrefixParam
    appSubnetAddressPrefix: appSubnetAddressPrefix
  }
}

module passwordGeneratorModule './core/password-generator.bicep' = {
  name: 'passwordGeneratorDeployment'
  params: {
    location: location
  }
}

module bastion './core/bastion.bicep' = {
  name: 'bastionDeployment'
  params: {
    location: location // Replace 'yourLocation' with the desired location value
    bastion_subnet_id: vnet.outputs.subnets[2].id
    jumpbox_subnet_id: vnet.outputs.subnets[3].id
    adminPassword: passwordGeneratorModule.outputs.generatedPassword
  }
}

module keyvault './core/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyvaultName: 'kv-oai-standalone'
    keyvaultPleName: 'pv-kv-oai'
    subnetId: vnet.outputs.subnets[1].id
    virtualNetworkId: vnet.outputs.id
    location: location // Replace 'yourLocation' with the desired location value
  }
}

module searchServiceModule './ai/search.bicep' = {
  name: 'deploySearchServiceWithPrivateEndpoint'
  params: {
    searchServiceName: 'as-aoai-standalone'
    location: location
    skuName: 'basic'
    subnetId: vnet.outputs.subnets[1].id
    privateEndpointName: 'pv-search-oai'
    privateDnsZoneName: 'privatelink.search.windows.net'
    virtualNetworkId: vnet.outputs.id
  }
}

//GPT

param gptDeploymentName string= 'gpt-4'
param searchIndexName string= 'idx-aoai-standalone'
param chatGptModelVersion string ='1106-Preview'
param chatGptDeploymentCapacity int = 30
param embeddingDeploymentName  string=  'text-embedding-ada-002'
param embeddingModelName string =  'text-embedding-ada-002'
param embeddingDeploymentCapacity int =30

var defaultOpenAiDeployments = [
  {
    name: gptDeploymentName
    model: {
      format: 'OpenAI'
      name: gptDeploymentName
      version: chatGptModelVersion
    }
    sku: {
      name: 'Standard'
      capacity: chatGptDeploymentCapacity
    }
  }
  {
    name: embeddingDeploymentName
    model: {
      format: 'OpenAI'
      name: embeddingModelName
      version: '2'
    }
    sku: {
      name: 'Standard'
      capacity: embeddingDeploymentCapacity
    }
  }
]



module privateEndpointOpenAIModule './ai/cognitive.bicep' = {
  name: 'PrivateEndpointOpenAIDeployment'
  params: {
    location: location
    privateEndpointcognitiveName: 'pe-oai'
    subnet_id: vnet.outputs.subnets[1].id
    virtualNetworkId: vnet.outputs.id
    sku: 'S0'
    cognitiveName: 'oai-standalone'   
    privateDnsZoneName: 'privatelink.openai.azure.com'
    kind: 'OpenAI'
    vnet_private_endpoint_subnet_id: vnet.outputs.subnets[1].id 
    vnetLocation:location
    deployments: defaultOpenAiDeployments
  }
}

module privateEndpointFormRecogModule  './ai/cognitive.bicep' = {
  name: 'PrivateEndpointFormRecogDeployment'
  params: {
    location: locationFomsRecogniser
    privateEndpointcognitiveName: 'pe-form'    
    virtualNetworkId: vnet.outputs.id
    sku: 'S0'
    cognitiveName: 'frm-standalone' 
    subnet_id: vnet.outputs.subnets[1].id
    privateDnsZoneName: 'privatelink.cognitiveservices.azure.com'
    kind: 'FormRecognizer'
    vnet_private_endpoint_subnet_id: vnet.outputs.subnets[1].id 
    vnetLocation:location
  }
}
module storageAccount './core/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    privateEndpointName: 'pe-storage'   
    subnetId: vnet.outputs.subnets[1].id
    vnetId: vnet.outputs.id
    containerNames: [
      'oai-standalone'
    ]
    tags: {
    }
  }
}

param appServicePlanName string = 'appserviceplan-03'
param azFunctionName string = 'fn-aoai-standalone-01'
param staticWebsiteName string = 'sw-aoai-standalone-01'

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup()
  params: {
    name: appServicePlanName
    location: location
    tags: {}
    sku: {
      name: 'S1'
      capacity: 1
    }
    kind: 'linux'
  }
}



module function './host/azfunctions.bicep' = {
  name: 'azf'
  scope: resourceGroup()
  params: {
    name: azFunctionName 
    location:   location
    appServicePlanId: appServicePlan.outputs.id
    azureOpenaiChatgptDeployment: gptDeploymentName
    azureOpenaigptDeployment: gptDeploymentName
    azureOpenaiService:privateEndpointOpenAIModule.outputs.name
    //azureOpenaiServiceKey: ''
    azureSearchIndex: searchIndexName
    azureSearchService: searchServiceModule.outputs.name
    //azureSearchServiceKey: ''
    azureStorageContainerName: 'oai-standalone'
    formRecognizerService: privateEndpointFormRecogModule.outputs.name
    //formRecognizerServiceKey: ''
    runtimeName: 'python'
    runtimeVersion: '3.10'
    vnet_subnet_id: vnet.outputs.subnets[4].id
  }
}

module staticwebsite './host/staticwebsite.bicep' = {
  scope: resourceGroup()
  name: 'website'
  params: {
    name:  staticWebsiteName
    location:  locationStaticWebApp
    sku: 'Standard'
    backendResourceId: function.outputs.id
    siteLocation: location

  }
}
module mangedIdentities './security/rbac.bicep' = {
  name: 'managedIdentityDeployment'
  params: {
    identityPrincipal: function.outputs.identityPrincipalId
  }
}

output searchServiceIdOutput string = searchServiceModule.outputs.searchServiceId
output privateEndpointIdOutput string = searchServiceModule.outputs.privateEndpointId
output privateDnsZoneIdOutput string = searchServiceModule.outputs.privateDnsZoneId
