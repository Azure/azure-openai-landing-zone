//****************************************************************************************
// Parameters
//****************************************************************************************

@description('Name of the API Management instance. Must be globally unique.')
param apiManagementName string

@description('Location for the resource.')
param location string

//****************************************************************************************
// Variables
//****************************************************************************************

var publisherEmail = 'admin@contoso.com'
var publisherName = 'ContosoAdmin'

//****************************************************************************************
// Resources
//****************************************************************************************

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    apiVersionConstraint: {}
    developerPortalStatus: 'Disabled'
  }
}

//****************************************************************************************
// Outputs
//****************************************************************************************

output managedIdentityPrincipalID string = apiManagement.identity.principalId
