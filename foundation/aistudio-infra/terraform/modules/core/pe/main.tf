# data resource to get the vnet
data "azurerm_virtual_network" "this" {
  name                = var.virtual_network_name
  resource_group_name = var.virtual_network_resource_group_name
}

# data resource to get the subnet
data "azurerm_subnet" "this" {
  name                 = var.private_endpoints_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group_name
}

# data resource to get the private dns zone
data "azurerm_private_dns_zone" "this" {
  count               = length(var.private_endpoints)
  name                = var.private_endpoints[count.index].privateDnsZoneName
  resource_group_name = var.private_dns_zone_resource_group_name
}

resource "azurerm_private_endpoint" "endpoint" {
  count               = length(var.private_endpoints)
  name                = var.private_endpoints[count.index].privateEndpointName
  location            = data.azurerm_virtual_network.this.location
  resource_group_name = var.private_endpoints[count.index].resourceGroupName
  subnet_id           = data.azurerm_subnet.this.id

  private_service_connection {
    name                           = var.private_endpoints[count.index].privateEndpointName
    private_connection_resource_id = var.private_endpoints[count.index].resourceId
    is_manual_connection           = false
    subresource_names              = [var.private_endpoints[count.index].privateEndpointGroupId]
  }

  private_dns_zone_group {
    name                 = var.private_endpoints[count.index].privateEndpointGroupId
    private_dns_zone_ids = [data.azurerm_private_dns_zone.this[count.index].id]
  }
}
