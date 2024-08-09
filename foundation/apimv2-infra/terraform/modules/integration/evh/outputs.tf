output "eventhub_name" {
  value = var.eventhub_name
}

output "eventhub_connection_string" {
  value = azurerm_eventhub_namespace.this.default_primary_connection_string
}
