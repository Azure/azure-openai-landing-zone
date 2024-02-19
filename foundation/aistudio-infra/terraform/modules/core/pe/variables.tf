variable "virtual_network_name" {}
variable "virtual_network_resource_group_name" {}
variable "private_endpoints_subnet_name" {}
variable "private_dns_zone_resource_group_name" {}
variable "private_endpoints" {
  type = list(object({
    privateEndpointName    = string
    resourceId             = string
    privateEndpointGroupId = string
    privateDnsZoneName     = string
    resourceGroupName      = string
    azureResourceName      = string
  }))
  default = []
}
