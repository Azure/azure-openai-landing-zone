//****************************************************************************************
// Parameters
//****************************************************************************************

@description('Name of the API Management instance. Must be globally unique.')
param apiManagementName string

@description('Location for the resource.')
param location string

param privateDeployment bool

param virtualNetworkResourceGroupName string

param virtualNetworkName string

param subnetName string

param publicIPID string

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
    name: (privateDeployment ? 'Premium' : 'StandardV2')
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
    virtualNetworkType: (privateDeployment ? 'Internal' : null)
    virtualNetworkConfiguration: (privateDeployment ? {
      subnetResourceId: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
    } : null)
    publicIpAddressId: (privateDeployment ? publicIPID : null)
  }
}

//****************************************************************************************
// Outputs
//****************************************************************************************

output managedIdentityPrincipalID string = apiManagement.identity.principalId
