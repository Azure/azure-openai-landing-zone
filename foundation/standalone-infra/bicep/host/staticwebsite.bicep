param name string
param location string = resourceGroup().location
param tags object = {}
param sku string = 'Standard'
param backendResourceId string
param siteLocation string

resource frontend 'Microsoft.Web/staticSites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
  }

  properties: {
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

resource linkapi 'Microsoft.Web/staticSites/linkedBackends@2022-09-01' = {
  parent: frontend
  name: 'api'
  properties: {
    backendResourceId: backendResourceId
    region: siteLocation
  }
}
output name string = frontend.name
