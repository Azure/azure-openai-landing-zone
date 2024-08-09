output "virtual_network_id" {
  value = azurerm_virtual_network.vnet.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}

output "jumpbox_subnet_id" {
  value = azurerm_subnet.jumpbox.id
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}
