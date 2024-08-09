variable "resource_group_name" {}
variable "location" {}
variable "cognitive_name" {}
variable "cognitive_kind" {
  default = "OpenAI"
}
variable "cognitive_sku" {
  default = "S0"
}
variable "deployments" {
  default = {}
}
variable "cognitive_private_endpoint_name" {}
variable "virtual_network_name" {}
variable "virtual_network_resource_group_name" {}
variable "private_endpoints_subnet_name" {}
variable "private_dns_zone_resource_group_name" {}
variable "private_dns_zone_name" {
  default = "privatelink.openai.azure.com"
}
variable "tags" {
  default = {}
}
