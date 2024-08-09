variable "resource_group_name" {
  default = "rg-standalone"
}

variable "location" {
  default = "canadaeast"
}

variable "storage_account_name" {
  default = "sastudio"
}

variable "keyvault_name" {
  default = "kv-studio"
}

variable "log_name" {
  default = "log-studio"
}

variable "appi_name" {
  default = "appi-studio"
}

variable "acr_name" {
  default = "acrstudio"
}

variable "search_name" {
  default = "search-studio"
}

variable "search_partition_count" {
  default = 1
}

variable "search_replica_count" {
  default = 1
}

variable "search_sku" {
  default = "basic"
}

variable "semantic_search_sku" {
  default = "free"
}

variable "hosting_mode" {
  default = "default"
}

variable "mlw_name" {
  default = "mlw-studio"
}

variable "use_random_suffix" {
  default = true
}

variable "tags" {
  default = {}
}

variable "private_dns_zone_resource_group_name" {
  default = "rg-standalone"
}

variable "virtual_network_resource_group_name" {
  default = "rg-standalone"
}

variable "virtual_network_name" {
  default = "vnet-ai-standalone"
}

variable "private_endpoints_subnet_name" {
  default = "private-endpoint-subnet"
}

variable "enable_private_endpoints" {
  default = false
}
