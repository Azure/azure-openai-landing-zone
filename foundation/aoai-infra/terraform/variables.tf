variable "resource_group_name" {
  default = "rg-standalone"
}

variable "location" {
  default = "canadaeast"
}

variable "openai_name" {
  default = "aoai-7uj23hng7h22c"
}

variable "openai_private_endpoint_name" {
  default = "aoai-7uj23hng7h22c-pe"
}

variable "virtual_network_name" {
  default = "vnet-ai-standalone"
}

variable "virtual_network_resource_group_name" {
  default = "rg-standalone"
}

variable "private_endpoints_subnet_name" {
  default = "private-endpoint-subnet"
}

variable "private_dns_zone_resource_group_name" {
  default = "rg-standalone"
}

variable "openai_deployments" {
  default = {
    gpt4 = {
      name = "gpt-4"
      model = {
        format          = "OpenAI"
        name            = "gpt-4"
        version         = "1106-Preview"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "Standard"
        capacity = 5
      }
    }
    embeddings = {
      name = "text-embedding-ada-002"
      model = {
        format          = "OpenAI"
        name            = "text-embedding-ada-002"
        version         = "2"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "Standard"
        capacity = 5
      }
    }
  }
}

variable "contributor_principal_ids" {
  default = []
}

variable "user_principal_ids" {
  default = []
}

variable "tags" {
  default = {}
}
