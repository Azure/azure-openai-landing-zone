resource "azurerm_stream_analytics_job" "this" {
  name                = var.stream_analytics_name
  resource_group_name = var.resource_group_name
  location            = var.location
  streaming_units     = 3
  identity {
    type = "SystemAssigned"
  }
  events_out_of_order_max_delay_in_seconds = 0
  events_late_arrival_max_delay_in_seconds = 5
  data_locale                              = "en-US"
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Stop"
  compatibility_level                      = "1.2"
  content_storage_policy                   = "SystemAccount"
  type                                     = "Cloud"

  transformation_query = <<QUERY
SELECT
    *
INTO
    [YourOutputAlias]
FROM
    [YourInputAlias]
QUERY

}
