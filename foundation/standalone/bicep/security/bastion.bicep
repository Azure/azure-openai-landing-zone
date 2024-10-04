param location string
param bastion_subnet_id string
param jumpbox_subnet_id string
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
  name: 'nic-jumpbox'
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

resource vmJumpbox 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: 'vm-jumpbox-win11'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5' // 'Standard_B2ats_v2'
    }
    osProfile: {
      computerName: 'jumpbox'
      adminUsername: 'azureadmin'
      adminPassword: adminPassword
      customData: base64('Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1")); choco install azure-cli -y')
      // customData: base64(loadFileAsBase64('./install-tools-windows.ps1') // base64('./install-tools-windows.ps1')
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        name: 'osdisk-jumpbox'
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
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vm-simple-windows/install-tools-windows.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File install-tools-windows.ps1'
    }
    // settings: {
    //   AttestationConfig: {
    //     MaaSettings: {
    //       maaEndpoint: maaEndpoint
    //       maaTenantName: maaTenantName
    //     }
    //   }
    // }
  }
}

// managed identity for the jumpbox

// resource "azurerm_linux_virtual_machine" "vm-spoke1" {
//   name                            = "vm-linux-spoke1"
//   resource_group_name             = azurerm_resource_group.rg-spoke1.name
//   location                        = azurerm_resource_group.rg-spoke1.location
//   size                            = "Standard_B2ats_v2"
//   disable_password_authentication = false
//   admin_username                  = "azureuser"
//   admin_password                  = "@Aa123456789"
//   network_interface_ids           = [azurerm_network_interface.nic-vm-spoke1.id]
//   priority                        = "Spot"
//   eviction_policy                 = "Deallocate"

//   custom_data = filebase64("./install-webapp.sh")

//   os_disk {
//     name                 = "os-disk-vm-spoke1"
//     caching              = "ReadWrite"
//     storage_account_type = "Standard_LRS"
//   }

//   source_image_reference {
//     publisher = "canonical"
//     offer     = "0001-com-ubuntu-server-jammy"
//     sku       = "22_04-lts-gen2"
//     version   = "latest"
//   }

//   boot_diagnostics {
//     storage_account_uri = null
//   }
// }
