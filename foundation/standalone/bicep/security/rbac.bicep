var roleDefinitionIdStorageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var roleDefIdSearchServiceQuery = '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Corrected ID for "Search Service Query"
var roleDefIdKeyVaultSecretUser = 'f25e0fa2-a7c8-4377-a976-54943a77a395' // ID for "Key Vault Secrets User"
var roleDefIdCognitiveOpenAIUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // ID for "Se



param identityPrincipal string


resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, roleDefinitionIdStorageBlobDataContributor, identityPrincipal)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIdStorageBlobDataContributor)
    principalId: identityPrincipal
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceQueryRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, roleDefIdSearchServiceQuery, identityPrincipal)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefIdSearchServiceQuery)
    principalId: identityPrincipal
    principalType: 'ServicePrincipal'
  }
}


resource kvRoleAssingment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, roleDefIdKeyVaultSecretUser, identityPrincipal)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefIdKeyVaultSecretUser)
    principalId: identityPrincipal
    principalType: 'ServicePrincipal'
  }
}

resource kvOpenAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, roleDefIdCognitiveOpenAIUser, identityPrincipal)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefIdCognitiveOpenAIUser)
    principalId: identityPrincipal
    principalType: 'ServicePrincipal'
  }
}
