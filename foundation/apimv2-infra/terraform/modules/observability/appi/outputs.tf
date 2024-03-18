output "appi_id" {
  value = azurerm_application_insights.this.id
}

output "appi_instrumentation_key" {
  value = azurerm_application_insights.this.instrumentation_key
}

output "appi_instrumentation_connection_string" {
  value = azurerm_application_insights.this.connection_string
}
