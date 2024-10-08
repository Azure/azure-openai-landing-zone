// Creates a KeyVault with Private Link Endpoint
@description('The Azure Region to deploy the resources into')
param location string = resourceGroup().location

@description('Tags to apply to the Key Vault Instance')
param tags object = {}

@description('The name of the Key Vault')
param keyvaultName string

@description('The name of the Key Vault private link endpoint')
param keyvaultPleName string

@description('The Subnet ID where the Key Vault Private Link is to be created')
param subnetId string

@description('The VNet ID where the Key Vault Private Link is to be created')
param virtualNetworkId string

var privateDnsZoneName = 'privatelink${environment().suffixes.keyvaultDns}'
var keyvaultVnetLinkUniqueString = uniqueString(virtualNetworkId, location, keyVault.id)

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    enableRbacAuthorization: true
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: keyvaultPleName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: keyvaultPleName
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: keyVault.id
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: subnetId
    }
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  // Locations for DNS zones are always 'global' per Azure documentation
  location: 'global'
  name: privateDnsZoneName
}

resource keyVaultPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  // The name of the VNet link resource should be composed of the DNS zone name followed by a unique string
  parent: keyVaultPrivateDnsZone
  name: keyvaultVnetLinkUniqueString
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

resource privateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default' // The name 'default' is typically used for DNS zone group name for simplicity
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatednszoneconfig1' // This can be any string, but keeping it simple as configuration1
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

output keyvaultId string = keyVault.id
