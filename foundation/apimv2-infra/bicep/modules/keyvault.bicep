@description('Name of the key vault to be created. Must be globally unique.')
param keyVaultName string

@description('Location for the resource.')
param location string

// You have to have the tenantID of the Azure AD instance your Key Vault lives in for deployment. 
// The below var retrieves this information for us.
var tenantId = subscription().tenantId

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableSoftDelete: true
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
  }
}
