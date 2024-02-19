resource "azurerm_storage_account" "sa" {
  name                            = var.storage_account_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
}

# Create containers
resource "azurerm_storage_container" "container" {
  count                 = length(var.container_names)
  name                  = var.container_names[count.index]
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.sa.name
}

# # Create the Private endpoint. This is where the Storage account gets a private IP inside the VNet.sur
# resource "azurerm_private_endpoint" "endpoint" {
#   name                = var.storage_private_endpoint_name
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   subnet_id           = var.private_endpoints_subnet_id

#   private_service_connection {
#     name                           = "sa-peconnection"
#     private_connection_resource_id = azurerm_storage_account.sa.id
#     is_manual_connection           = false
#     subresource_names              = ["blob"]
#   }

#   private_dns_zone_group {
#     name                 = "blob-config"
#     private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
#   }
# }

# resource "azurerm_private_dns_zone" "blob" {
#   name                = "privatelink.blob.core.windows.net"
#   resource_group_name = var.resource_group_name
# }

# # Link the Private Zone with the VNet
# resource "azurerm_private_dns_zone_virtual_network_link" "sa" {
#   name                  = "${azurerm_private_dns_zone.blob.name}-${azurerm_private_endpoint.endpoint.name}-vnetlink"
#   resource_group_name   = var.resource_group_name
#   private_dns_zone_name = azurerm_private_dns_zone.blob.name
#   virtual_network_id    = var.virtual_network_id
# }
