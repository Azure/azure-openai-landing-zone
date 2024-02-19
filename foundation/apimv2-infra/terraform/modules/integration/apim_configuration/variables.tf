variable "resource_group_name" {}
variable "location" {}
variable "apim_name" {}
variable "apim_id" {}
variable "gatewayUrl" {}
variable "appi_resource_id" {}
variable "appi_instrumentation_key" {}
variable "keyvault_name" {}
variable "eventhub_connection_string" {}
variable "eventhub_name" {}
variable "secrets" {
  default = {}
}
