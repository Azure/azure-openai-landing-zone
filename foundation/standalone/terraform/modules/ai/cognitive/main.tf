resource "azurerm_cognitive_account" "this" {
  name                          = var.cognitive_name
  kind                          = var.cognitive_kind
  sku_name                      = var.cognitive_sku
  location                      = var.location_cognitive
  resource_group_name           = var.resource_group_name
  public_network_access_enabled = true
  custom_subdomain_name         = lower(var.cognitive_name)
}

resource "azurerm_private_endpoint" "endpoint" {
  name                = var.cognitive_private_endpoint_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${lower(var.cognitive_kind)}-peconnection"
    private_connection_resource_id = azurerm_cognitive_account.this.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.this.id]
  }
}

resource "azurerm_private_dns_zone" "this" {
  name                = var.cognitive_dns_zone_name
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

resource "azurerm_cognitive_deployment" "deployment" {
  count                = length(var.deployments)
  name                 = var.deployments[count.index].name
  cognitive_account_id = azurerm_cognitive_account.this.id
  rai_policy_name      = "Microsoft.Default"
  model {
    format  = var.deployments[count.index].model.format
    name    = var.deployments[count.index].model.name
    version = var.deployments[count.index].model.version
  }

  scale {
    type     = var.deployments[count.index].sku.name
    capacity = var.deployments[count.index].sku.capacity
  }

  depends_on = [
    azurerm_cognitive_account.this,
    azurerm_private_endpoint.endpoint
  ]
}
