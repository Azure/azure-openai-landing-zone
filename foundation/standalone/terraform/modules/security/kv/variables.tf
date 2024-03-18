variable "resource_group_name" {}
variable "location" {}
variable "keyvault_name" {}
variable "keyvault_private_endpoint_name" {}
variable "virtual_network_id" {}
variable "private_endpoints_subnet_id" {}
variable "tags" {
  default = {}
}
