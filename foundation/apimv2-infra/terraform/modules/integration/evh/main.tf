resource "azurerm_eventhub_namespace" "this" {
  name                          = var.eventhub_namespace_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Basic"
  capacity                      = 1
  tags                          = var.tags
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
  zone_redundant                = false
  local_authentication_enabled  = true
}

resource "azurerm_eventhub" "apim" {
  name                = var.eventhub_name
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = var.resource_group_name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_eventhub" "apim_diagnostics_settings" {
  name                = "insights-metrics-pt1m"
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = var.resource_group_name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "apim" {
  name                = "apim_logger_access_policy"
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = var.resource_group_name
  eventhub_name       = azurerm_eventhub.apim.name
  listen              = false
  send                = true
  manage              = false
}
