@description('Name of the Public IP to be created.')
param publicIPName string

@description('Location for the resource.')
param location string

resource publicIP 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: publicIPName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: publicIPName
    }
  }
}

output publicIPID string = publicIP.id
