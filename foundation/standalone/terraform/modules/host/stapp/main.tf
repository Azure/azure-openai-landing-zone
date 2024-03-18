resource "azurerm_static_site" "this" {
  name                = var.stapp_name
  location            = var.location_stapp
  resource_group_name = var.resource_group_name
  sku_size            = "Standard"
  sku_tier            = "Standard"
}

resource "azapi_resource" "symbolicname" {
  type                      = "Microsoft.Web/staticSites/linkedBackends@2022-09-01"
  name                      = "api"
  parent_id                 = azurerm_static_site.this.id
  schema_validation_enabled = false # requiered for now
  body = jsonencode({
    properties = {
      backendResourceId = var.backend_id
      region            = var.location
    }
  })
}
