resource "azurerm_search_service" "search" {
  name                = var.search_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "basic"
  semantic_search_sku = "free"

  local_authentication_enabled = false
}


resource "azurerm_private_endpoint" "endpoint" {
  name                = var.search_private_endpoint_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "search-peconnection"
    private_connection_resource_id = azurerm_search_service.search.id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "searchService"
    private_dns_zone_ids = [azurerm_private_dns_zone.this.id]
  }
}

# Create the privatelink.file.core.windows.net Private DNS Zone
resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.search.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link the Private Zone with the VNet
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${azurerm_private_dns_zone.this.name}-${azurerm_private_endpoint.endpoint.name}-vnetlink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.virtual_network_id
}
