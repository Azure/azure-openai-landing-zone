@description('PE parameters for multiple resources')
param pedeployments array = []

@batchSize(1)
resource penic 'Microsoft.Network/networkInterfaces@2023-06-01' existing = [for (peparam, index) in pedeployments: {
  name: '${peparam.privateEndpointName}-nic' 
}]

output nicIpAddress array = [for (peparam, index) in pedeployments: {
   ipConfigurations : penic[index].properties.ipConfigurations
   
}]





// penic[index].properties.ipConfigurations[0].properties.privateIPAddress
