param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Properties
@description('Location for Application Insights')
// param applicationInsightsName string = ''
param appServicePlanId string
param formRecognizerService string
//param formRecognizerServiceKey string
param azureOpenaiService string
//param azureOpenaiServiceKey string
param azureOpenaiChatgptDeployment string
param azureOpenaigptDeployment string
param azureSearchService string
//param azureSearchServiceKey string
param azureSearchIndex string
param azureStorageContainerName string

// Microsoft.Web/sites/config
param allowedOrigins array = []
param appCommandLine string = ''
param autoHealEnabled bool = true
param numberOfWorkers int = -1
param ftpsState string = 'FtpsOnly'
param httpsOnly bool = true

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('The language worker runtime to load in the function app.')
@allowed([
  'dotnet', 'dotnetcore', 'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
param runtimeVersion string
// Microsoft.Web/sites Properties
param kind string = 'functionapp'
param vnet_subnet_id string =''
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        table: {
          enabled: true
        }
        queue: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true // Infrastructure encryption required by policy
    }
    allowBlobPublicAccess: false // Disallow public blob access as required by policy 
    minimumTlsVersion: 'TLS1_2'   // Minimum TLS version required by policy
  }
}




resource formRecognizerAccount 'Microsoft.CognitiveServices/accounts@2022-12-01' existing = {
  name : formRecognizerService
}
resource azureOpenAiServiceAccount 'Microsoft.CognitiveServices/accounts@2022-12-01' existing = {
  name : azureOpenaiService
}

resource azureSearchServiceAccount 'Microsoft.Search/searchServices@2022-09-01' existing = {
  name : azureSearchService
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    virtualNetworkSubnetId: vnet_subnet_id
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: '${toUpper(runtimeName)}|${runtimeVersion}'
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      autoHealEnabled: autoHealEnabled
      pythonVersion: runtimeVersion
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtimeName
        }
        // {
        //   name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        //   value: applicationInsights.properties.InstrumentationKey
        // }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AZURE_FORM_RECOGNIZER_SERVICE'
          value: formRecognizerAccount.name
        }
        {
          name: 'AZURE_FORM_RECOGNIZER_KEY'
          value: formRecognizerAccount.listKeys().key1
        }
        {
          name: 'AZURE_OPENAI_SERVICE'
          value: azureOpenAiServiceAccount.name
        }
        {
          name: 'AZURE_OPENAI_API_KEY'
          value: azureOpenAiServiceAccount.listKeys().key1
        }
        {
          name: 'AZURE_OPENAI_SERVICE_1'
          value: azureOpenAiServiceAccount.name
        }
        {
          name: 'AZURE_OPENAI_SERVICE_1_KEY'
          value: azureOpenAiServiceAccount.listKeys().key1
        }
        {
          name: 'AZURE_OPENAI_SERVICE_2'
          value: azureOpenAiServiceAccount.name
        }
        {
          name: 'AZURE_OPENAI_SERVICE_2_KEY'
          value: azureOpenAiServiceAccount.listKeys().key1
        }
        {
          name: 'AZURE_OPENAI_SERVICE_3'
          value: azureOpenAiServiceAccount.name
        }
        {
          name: 'AZURE_OPENAI_SERVICE_3_KEY'
          value: azureOpenAiServiceAccount.listKeys().key1
        }
        {
          name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT'
          value: azureOpenaiChatgptDeployment
        }
        {
          name: 'AZURE_OPENAI_GPT_DEPLOYMENT'
          value: azureOpenaigptDeployment
        }
        {
          name: 'AZURE_SEARCH_SERVICE'
          value: azureSearchService
        }
        {
          name: 'AZURE_SEARCH_KEY'
          value: azureSearchServiceAccount.listAdminKeys().primaryKey
        }
        {
          name: 'AZURE_SEARCH_INDEX'
          value: azureSearchIndex
        }
        {
          name: 'AZURE_STORAGE_CONTAINER'
          value: azureStorageContainerName
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT'
          value: storageAccountName
        }
      ]
      ftpsState: ftpsState
      minTlsVersion: '1.2'
    }
    httpsOnly: httpsOnly
  }
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2022-03-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: vnet_subnet_id
    swiftSupported: true
  }
  
}

output id string = functionApp.id
output identityPrincipalId string = functionApp.identity.principalId
output name string = functionApp.name
