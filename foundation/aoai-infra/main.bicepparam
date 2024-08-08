using './main.bicep'

param location = 'northcentralus'
param aoaiServiceName = 'aoai-7uj23hng7h22c-northcentralus'
param privateEndpointName = 'aoai-7uj23hng7h22c-northcentralus-pe'
param vnetRgName = 'vnet'
param privateDNSZoneRgName = 'vnet'
param vnetName = 'vnet-westus'
param vnetLocation = 'westus'
param subnetName = 'default'
param aoai_deployments = ['anildwa-test1-gpt-35-turbo', 'anildwa-test1-gpt-4']
param capacity = [30,35]



