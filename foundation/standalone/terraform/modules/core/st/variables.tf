variable "resource_group_name" {}
variable "location" {}
variable "storage_account_name" {}
variable "storage_private_endpoint_name" {}
variable "container_names" {
  default = []
}
variable "virtual_network_id" {}
variable "private_endpoints_subnet_id" {}