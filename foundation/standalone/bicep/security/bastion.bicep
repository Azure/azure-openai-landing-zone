param location string
param bastion_subnet_id string
param jumpbox_subnet_id string
param adminPassword string
resource bastion_public_ip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'b59-bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Create the Azure Bastion resource
resource bastion 'Microsoft.Network/bastionHosts@2020-11-01' = {
  name: 'b59-bastion'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastion_public_ip.id
          }
          subnet: {
            id: bastion_subnet_id
          }
        }
      }
    ]
  }
}

resource jumpbox_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'jumpboxNic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          subnet: {
            id: jumpbox_subnet_id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource jumpbox 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: 'vm-jumpbox-01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: 'jumpbox'
      adminUsername: 'azureadmin'
      adminPassword:  adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpbox_nic.id
        }
      ]
    }
  }
}
