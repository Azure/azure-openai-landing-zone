output "appi_instrumentation_key" {
  value = azurerm_application_insights.appinsights.instrumentation_key
}

output "appi_instrumentation_connection_string" {
  value = azurerm_application_insights.appinsights.connection_string
}