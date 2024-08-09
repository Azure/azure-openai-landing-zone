resource "azurerm_search_service" "search" {
  name                = var.search_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "basic"
  semantic_search_sku = "free"

  local_authentication_enabled = false

  replica_count   = var.replica_count
  partition_count = var.partition_count
  hosting_mode    = var.hosting_mode

}
