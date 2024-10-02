/*
  Multiple locations are being specified as parameters in this code.
  The reason for having multiple locations is that different resources or services may not be available in the same location.
  
  - `location` parameter represents the location for general resources.
  - `locationFomsRecogniser` parameter represents the location for Form Recognizer resources.
  - `locationStaticWebApp` parameter represents the location for Static Web App resources.
  - `locationOpenAI` parameter represents the location for OpenAI resources.
*/
param location string = 'canadaeast'
param locationFomsRecogniser string = 'canadacentral'
param locationStaticWebApp string = 'westus2'
param locationOpenAI string = 'canadaeast'
param env string = 'dev'
param postFix string = '-02'
param globalName string = 'oai-standalone'
@secure()
param tempBastionPassword string = ''

/*
  The address prefixes defined above represent the IP address ranges for different subnets in the virtual network used by each service.

  Parameters:
  - addressPrefixParam: The address prefix for the VNet.
  - aiSubnetAddressPrefixParam: The address prefix for the AI subnet.
  - azureBastionSubnetAddressPrefix: The address prefix for the Azure Bastion subnet.
  - privateEndpointSubnetAddressPrefixParam: The address prefix for the private endpoint subnet.
  - jumpboxSubnetAddressPrefixParam: The address prefix for the jumpbox subnet.
  - appSubnetAddressPrefix: The address prefix for the application subnet.
*/
param vnet_name string = 'vnet-ai-standalone${postFix}'
param addressPrefixParam string = '11.0.0.0/16'
param aiSubnetAddressPrefixParam string = '11.0.0.0/24'
param azureBastionSubnetAddressPrefix string = '11.0.1.0/24'
param privateEndpointSubnetAddressPrefixParam string = '11.0.2.0/24'
param jumpboxSubnetAddressPrefixParam string = '11.0.3.0/24'
param appSubnetAddressPrefix string = '11.0.4.0/24'

/*
  These are  the parameters and variables for deploying OpenAI models.
  It includes parameters for GPT deployment, search index name, chat GPT model version,
  chat GPT deployment capacity, embedding deployment name, embedding model name, and
  embedding deployment capacity.

  The 'defaultOpenAiDeployments' variable is an array that contains the configurations
  for the default OpenAI deployments. It includes the name, model format, model name,
  model version, SKU name, and deployment capacity for each deployment.

  Usage:
  - Modify the parameter values according to your requirements.
  - Use the 'defaultOpenAiDeployments' variable to define additional OpenAI deployments.
*/

param gptDeploymentName string = 'gpt-4'
param searchIndexName string = 'idx-a${globalName}'
param chatGptModelVersion string = '1106-Preview'
param chatGptDeploymentCapacity int = 5
param embeddingDeploymentName string = 'text-embedding-ada-002'
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingDeploymentCapacity int = 5

/*
  This Bicep file contains parameters for various resources used in the standalone infrastructure deployment.
  The parameters include search service, key vault, OpenAI, document intelligence, storage endpoint, app service plan, Azure function, and static website names.
  These parameters can be customized to fit the specific requirements of the deployment.
*/
param searchServiceName string = 'ais-a${globalName}-${env}${postFix}'
param skuName string = 'basic'
param privateEndpointName string = 'pv-search-oai-${env}${postFix}'
param privateDnsZoneNameSearch string = 'privatelink.search.windows.net'

param keyvaultName string = 'kv-${globalName}-${env}${postFix}'
param keyvaultPleName string = 'pv-kv-oai-${env}${postFix}'

param privateEndpointOpenAIName string = 'pe-oai-${env}${postFix}'
param skuOpenAI string = 'S0'
param OpenAIName string = '${globalName}-${env}${postFix}'
param privateDnsZoneNameOpenAI string = 'privatelink.openai.azure.com'

param privateEndpointDocumentIntelligenceName string = 'pe-form-${env}${postFix}'
param skuDocumentIntelligence string = 'S0'
param DocumentIntelligenceName string = 'frm-${globalName}-${env}${postFix}'
param privateDnsZoneNameDocumentIntelligence string = 'privatelink.cognitiveservices.azure.com'

param storageEndpointDocumentIntelligenceName string = 'pe-storage-${env}${postFix}'

param appServicePlanName string = 'asp-03-${env}${postFix}'
param azFunctionName string = 'afn-a${globalName}-${env}${postFix}'
param staticWebsiteName string = 'swa-a${globalName}-${env}${postFix}'

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
    vnet_name: vnet_name
  }
}

/*module passwordGeneratorModule './security/password-generator.bicep' = {
  name: 'passwordGeneratorDeployment'
  params: {
    location: location
  }
}*/

module bastion './security/bastion.bicep' = {
  name: 'bastionDeployment'
  params: {
    location: location
    bastion_subnet_id: vnet.outputs.subnets[2].id
    jumpbox_subnet_id: vnet.outputs.subnets[3].id
    adminPassword: tempBastionPassword
  }
}

module keyvault './security/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyvaultName: keyvaultName
    keyvaultPleName: keyvaultPleName
    subnetId: vnet.outputs.subnets[1].id
    virtualNetworkId: vnet.outputs.id
    location: location
  }
}

module searchServiceModule './ai/search.bicep' = {
  name: 'deploySearchServiceWithPrivateEndpoint'
  params: {
    searchServiceName: searchServiceName
    location: location
    skuName: skuName
    privateEndpointName: privateEndpointName
    privateDnsZoneName: privateDnsZoneNameSearch
    subnetId: vnet.outputs.subnets[1].id
    virtualNetworkId: vnet.outputs.id
  }
}

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
    privateEndpointcognitiveName: privateEndpointOpenAIName
    subnet_id: vnet.outputs.subnets[1].id
    virtualNetworkId: vnet.outputs.id
    sku: skuOpenAI
    cognitiveName: OpenAIName
    privateDnsZoneName: privateDnsZoneNameOpenAI
    kind: 'OpenAI'
    vnet_private_endpoint_subnet_id: vnet.outputs.subnets[1].id
    vnetLocation: locationOpenAI
    deployments: defaultOpenAiDeployments
  }
}

module privateEndpointFormRecogModule './ai/cognitive.bicep' = {
  name: 'PrivateEndpointFormRecogDeployment'
  params: {
    location: locationFomsRecogniser
    privateEndpointcognitiveName: privateEndpointDocumentIntelligenceName
    virtualNetworkId: vnet.outputs.id
    sku: skuDocumentIntelligence
    cognitiveName: DocumentIntelligenceName
    subnet_id: vnet.outputs.subnets[1].id
    privateDnsZoneName: privateDnsZoneNameDocumentIntelligence
    kind: 'FormRecognizer'
    vnet_private_endpoint_subnet_id: vnet.outputs.subnets[1].id
    vnetLocation: location
  }
}

module storageAccount './core/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    privateEndpointName: storageEndpointDocumentIntelligenceName
    subnetId: vnet.outputs.subnets[1].id
    vnetId: vnet.outputs.id
    containerNames: [
      '${globalName}'
    ]
    tags: {}
  }
}

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
    location: location
    appServicePlanId: appServicePlan.outputs.id
    azureOpenaiChatgptDeployment: gptDeploymentName
    azureOpenaigptDeployment: gptDeploymentName
    azureOpenaiService: privateEndpointOpenAIModule.outputs.name
    azureSearchIndex: searchIndexName
    azureSearchService: searchServiceModule.outputs.name
    //azureSearchServiceKey: ''
    azureStorageContainerName: '${globalName}'
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
    name: staticWebsiteName
    location: locationStaticWebApp
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

output openAIPrivateEndpointUrl string = '${OpenAIName}.${privateDnsZoneNameOpenAI}'
output documentIntelligencePrivateEndpointUrl string = '${DocumentIntelligenceName}.${privateDnsZoneNameDocumentIntelligence}'
output keyVaultPrivateEndpointUrl string = '${keyvaultName}.privatelink.azure.com'
output searchPrivateEndpointUrl string = '${searchServiceName}.${privateDnsZoneNameSearch}'
#disable-next-line no-hardcoded-env-urls
output storagePrivateEndpointUrl string = '${storageEndpointDocumentIntelligenceName}.blob.core.windows.net'
output functionPrivateEndpointUrl string = '${azFunctionName}.azurewebsites.net'
output staticWebsiteUrl string = staticwebsite.outputs.url
