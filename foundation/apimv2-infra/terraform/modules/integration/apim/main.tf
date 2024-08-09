data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azapi_resource" "apim" {
  type      = "Microsoft.ApiManagement/service@2023-05-01-preview"
  name      = var.apim_name
  parent_id = data.azurerm_resource_group.rg.id
  location  = var.location
  identity {
    type = "SystemAssigned"
  }
  schema_validation_enabled = false # requiered for now
  body = jsonencode({
    sku = {
      name     = "StandardV2"
      capacity = 1
    }
    properties = {
      publisherEmail        = var.publisher_email
      publisherName         = var.publisher_name
      apiVersionConstraint  = {}
      developerPortalStatus = "Disabled"
    }
  })
  response_export_values = [
    "identity.principalId",
    "properties.gatewayUrl"
  ]
}
