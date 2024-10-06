param location string
param bastion_subnet_id string
param jumpbox_subnet_id string
param adminUsername string
@secure()
param adminPassword string

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'pip-bastion'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-11-01' = {
  name: 'bst-bastion'
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
            id: bastionPublicIp.id
          }
          subnet: {
            id: bastion_subnet_id
          }
        }
      }
    ]
  }
}

resource nicJumpbox 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'nic-vm-jumpbox'
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

resource vmJumpbox 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-jumpbox-win11'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5' // 'Standard_B2ats_v2'
    }
    osProfile: {
      computerName: adminUsername
      adminUsername: adminUsername
      adminPassword: adminPassword
      // customData: base64('Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1")); choco install azure-cli -y')
      // customData: base64(loadFileAsBase64('./install-tools-windows.ps1') // base64('./install-tools-windows.ps1')
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        name: 'osdisk-vm-jumpbox'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicJumpbox.id
        }
      ]
    }
  }
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vmJumpbox
  name: 'install-tools-windows'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/HoussemDellai/azure-openai-landing-zone/refs/heads/branch-houssem/foundation/standalone/bicep/security/install-tools-windows.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File install-tools-windows.ps1'
    }
  }
}

var roleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleDefinitionId, resourceGroup().id, vmJumpbox.name)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: vmJumpbox.identity.principalId
  }
}
