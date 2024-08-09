resource "azurerm_storage_account" "sa" {
  name                            = var.storage_account_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

# Create containers
resource "azurerm_storage_container" "container" {
  count                 = length(var.container_names)
  name                  = var.container_names[count.index]
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.sa.name
}
