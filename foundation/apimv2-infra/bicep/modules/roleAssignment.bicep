@description('principalId of the APIM Managed Identity. This is used to grant the APIM Managed Identity access to Key Vault.')
param APIMPrincipalId string

@description('Name of the Key Vault. This is used to grant the APIM Managed Identity access to Key Vault.')
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource userRoleID 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(APIMPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6', keyVault.id)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleAssignments', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: APIMPrincipalId
  }
}
