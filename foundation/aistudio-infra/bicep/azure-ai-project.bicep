@description('Specifies the name of the Azure AI Studio Resource')
param azureAIResourceName string = 'ai-${uniqueString(resourceGroup().id)}'

@description('Specifies the Name of the project under Azure AI Resource.')
param azureAIProjectResourceName string //= 'ai-project-${uniqueString(resourceGroup().id)}'

@description('Specifies the location of the project')
param location string = resourceGroup().location

resource azureaiResource 'Microsoft.MachineLearningServices/workspaces@2023-02-01-preview' existing = {
  name: azureAIResourceName
}


resource azureaiProjectResource 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: azureAIProjectResourceName
  location: location
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: azureAIProjectResourceName
    hbiWorkspace: false
    hubResourceId: azureaiResource.id    
  }  
}

/*

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName  
}


resource storageAccountFile 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' existing = {
  name: 'default'
  parent: storageAccount
}



resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVaultName  
}


resource secret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: 'blobaccesskey'
  parent: keyVault
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}


resource workspaceblobstore 'Microsoft.MachineLearningServices/workspaces/datastores@2023-10-01' = {
  parent: azureaiProjectResource
  name: 'workspaceblobstore'
  properties: {
    datastoreType: 'AzureBlob'
    accountName: storageAccount.name
    containerName: '${azureAIProjectResourceName}workspaceblobstore'
    credentials: {
      credentialsType: 'AccountKey'      
      secrets: {
        secretsType: 'AccountKey'
        key: storageAccount.listKeys().keys[0].value
      }
    }
  }
}


resource workspaceartifactstore 'Microsoft.MachineLearningServices/workspaces/datastores@2023-10-01' = {
  parent: azureaiProjectResource
  name: 'workspaceartifactstore'
  properties: {
    datastoreType: 'AzureBlob'
    accountName: storageAccount.name
    containerName: '${azureAIProjectResourceName}workspaceartifactstore'
    credentials: {
      credentialsType: 'AccountKey'      
      secrets: {
        secretsType: 'AccountKey'
        key: storageAccount.listKeys().keys[0].value
      }
    }
  }
}


resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: fileShareName
  parent: storageAccountFile  
}

resource workspaceworkingdirectory 'Microsoft.MachineLearningServices/workspaces/datastores@2020-05-01-preview' = {
  parent: azureaiProjectResource
  name: 'workspaceworkingdirectory'
  dependsOn: [
    fileShare
  ]
  properties: {
    dataStoreType: 'file'
    SkipValidation: false
    AccountName: storageAccount.name
    ShareName: fileShareName
    AccountKey: storageAccount.listKeys().keys[0].value  
  }
}
*/


output azureAIResourceId  string = azureaiResource.id
