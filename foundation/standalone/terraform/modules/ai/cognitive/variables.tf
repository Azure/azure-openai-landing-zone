variable "resource_group_name" {}
variable "location" {}
variable "location_cognitive" {}
variable "cognitive_name" {}
variable "cognitive_kind" {}
variable "cognitive_sku" {}
variable "deployments" {
  default = []
}
variable "cognitive_private_endpoint_name" {}
variable "cognitive_dns_zone_name" {}
variable "virtual_network_id" {}
variable "private_endpoints_subnet_id" {}
variable "tags" {
  default = {}
}
