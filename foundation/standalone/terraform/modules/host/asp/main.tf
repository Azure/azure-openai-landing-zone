resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  os_type             = "Linux"
  sku_name            = "S1"
}
