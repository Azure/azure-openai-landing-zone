resource "azurerm_cognitive_account" "this" {
  name                          = var.cognitive_name
  kind                          = var.cognitive_kind
  sku_name                      = var.cognitive_sku
  location                      = var.location
  resource_group_name           = var.resource_group_name
  public_network_access_enabled = false
  custom_subdomain_name         = lower(var.cognitive_name)
}

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

# data resurce to get the private dns zone
data "azurerm_private_dns_zone" "this" {
  name                = var.private_dns_zone_name
  resource_group_name = var.private_dns_zone_resource_group_name
}

resource "azurerm_private_endpoint" "endpoint" {
  name                = var.cognitive_private_endpoint_name
  location            = data.azurerm_virtual_network.this.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.this.id
  tags                = var.tags

  private_service_connection {
    name                           = var.cognitive_private_endpoint_name
    private_connection_resource_id = azurerm_cognitive_account.this.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "dnsgroup"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.this.id]
  }
}

resource "azurerm_cognitive_deployment" "deployment" {
  for_each             = var.deployments
  name                 = each.value.model.name
  cognitive_account_id = azurerm_cognitive_account.this.id
  rai_policy_name      = each.value.model.rai_policy_name
  model {
    format  = each.value.model.format
    name    = each.value.model.name
    version = each.value.model.version
  }

  scale {
    type     = each.value.sku.name
    capacity = each.value.sku.capacity
  }

  depends_on = [
    azurerm_cognitive_account.this,
    azurerm_private_endpoint.endpoint
  ]
}
