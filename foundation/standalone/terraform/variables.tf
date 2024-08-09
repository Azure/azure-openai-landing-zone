variable "resource_group_name" {
  default = "rg-standalone"
}
variable "location" {
  default = "canadaeast"
}
variable "location_openai" {
  default = "canadaeast"
}
variable "location_doc_intelligence" {
  default = "canadacentral"
}
variable "location_stapp" {
  default = "westus2"
}
variable "virtual_network_name" {
  default = "vnet-ai-standalone"
}
variable "address_prefix" {
  default = "11.0.0.0/16"
}
variable "ai_subnet_address_prefix" {
  default = "11.0.0.0/24"
}
variable "private_endpoints_subnet_address_prefix" {
  default = "11.0.2.0/24"
}
variable "bastion_subnet_address_prefix" {
  default = "11.0.1.0/24"
}
variable "jumpbox_subnet_address_prefix" {
  default = "11.0.3.0/24"
}
variable "app_subnet_address_prefix" {
  default = "11.0.4.0/24"
}
variable "storage_account_name" {
  default = "boot"
}
variable "storage_private_endpoint_name" {
  default = "pe-search-oai"
}
variable "container_names" {
  default = ["aoai-standalone"]
}
variable "keyvault_name" {
  default = "kv-standalone"
}
variable "keyvault_private_endpoint_name" {
  default = "pe-kv-standalone"
}
variable "openai_name" {
  default = "oai-standalone"
}
variable "openai_sku" {
  default = "S0"
}
variable "openai_private_endpoint_name" {
  default = "pe-oai"
}
variable "doc_intelligence_name" {
  default = "frm-standalone"
}
variable "doc_intelligence_sku" {
  default = "S0"
}
variable "doc_intelligence_private_endpoint_name" {
  default = "pe-frm"
}
variable "search_name" {
  default = "search-standalone"
}
variable "search_index" {
  default = "idx-standalone"
}
variable "search_private_endpoint_name" {
  default = "pe-search-standalone"
}
variable "search_sku" {
  default = "basic"
}
variable "semantic_search_sku" {
  default = "free"
}

variable "gpt_deployment_name" {
  default = "gpt-4"
}

variable "embedding_deployment_name" {
  default = "text-embedding-ada-002"
}

variable "openai_deployments" {
  default = [
    {
      name = "gpt-4"
      model = {
        format  = "OpenAI"
        name    = "gpt-4"
        version = "1106-Preview"
      }
      sku = {
        name     = "Standard"
        capacity = 5
      }
    },
    {
      name = "text-embedding-ada-002"
      model = {
        format  = "OpenAI"
        name    = "text-embedding-ada-002"
        version = "2"
      }
      sku = {
        name     = "Standard"
        capacity = 5
      }
    }
  ]
}

variable "app_service_plan_name" {
  default = "asp-standalone"
}
variable "appi_name" {
  default = "appi-standalone"
}
variable "log_name" {
  default = "log-standalone"
}
variable "func_name" {
  default = "func"
}
variable "stapp_name" {
  default = "stapp"
}

variable "use_random_suffix" {
  default = true
}
variable "tags" {
  default = {}
}
