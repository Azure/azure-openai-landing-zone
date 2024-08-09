variable "resource_group_name" {
  default = "rg-standalone"
}

variable "location" {
  default = "canadaeast"
}

variable "location_apim" {
  default = "eastus"
}

variable "appi_name" {
  default = "appi-standalone"
}

variable "log_name" {
  default = "log-standalone"
}

variable "keyvault_name" {
  default = "kv-standalone"
}

variable "storage_account_name" {
  default = "ststandalone"
}

variable "eventhub_namespace_name" {
  default = "evh-standalone"
}

variable "eventhub_name" {
  default = "evh-standalone"
}

variable "stream_analytics_name" {
  default = "asa-standalone"
}

variable "apim_name" {
  default = "apim-standalone"
}
variable "publisher_name" {
  default = "ContosoAdmin"
}

variable "publisher_email" {
  default = "admin@contoso.com"
}

variable "apim_secrets" {
  default = {
    aoaiaustraliaeastkey = {
      secretName   = "aoai-australiaeast-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://australiaeast.openai.azure.com/openai"
      endpointName = "aoai-australiaeast-endpoint"
      region       = "australiaeast"
    }

    aoaicanadaeastkey = {
      secretName   = "aoai-canadaeast-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://canadaeast.openai.azure.com/openai"
      endpointName = "aoai-canadaeast-endpoint"
      region       = "canadaeast"
    }

    aoaieastus2key = {
      secretName   = "aoai-eastus2-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://eastus2.openai.azure.com/openai"
      endpointName = "aoai-eastus2-endpoint"
      region       = "eastus2"
    }

    aoaieastuskey = {
      secretName   = "aoai-eastus-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://eastus.openai.azure.com/openai"
      endpointName = "aoai-eastus-endpoint"
      region       = "eastus"
    }

    aoaifrancecentralkey = {
      secretName   = "aoai-francecentral-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://francecentral.openai.azure.com/openai"
      endpointName = "aoai-francecentral-endpoint"
      region       = "francecentral"
    }

    aoaijapaneastkey = {
      secretName   = "aoai-japaneast-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://japaneast.openai.azure.com/openai"
      endpointName = "aoai-japaneast-endpoint"
      region       = "japaneast"
    }

    aoainorthcentralkey = {
      secretName   = "aoai-northcentral-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://northcentral.openai.azure.com/openai"
      endpointName = "aoai-northcentral-endpoint"
      region       = "northcentralus"
    }

    aoainorwayeastkey = {
      secretName   = "aoai-norwayeast-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://norwayeast.openai.azure.com/openai"
      endpointName = "aoai-norwayeast-endpoint"
      region       = "norwayeast"
    }

    aoaisouthindiakey = {
      secretName   = "aoai-southindia-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://southindia.openai.azure.com/openai"
      endpointName = "aoai-southindia-endpoint"
      region       = "southindia"
    }

    aoaiswedencentralkey = {
      secretName   = "aoai-swedencentral-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://swedencentral.openai.azure.com/openai"
      endpointName = "aoai-swedencentral-endpoint"
      region       = "swedencentral"
    }

    aoaiswitzerlandnorthkey = {
      secretName   = "aoai-switzerlandnorth-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://switzerlandnorth.openai.azure.com/openai"
      endpointName = "aoai-switzerlandnorth-endpoint"
      region       = "switzerlandnorth"
    }

    aoaiuksouthkey = {
      secretName   = "aoai-uksouth-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://uksouth.openai.azure.com/openai"
      endpointName = "aoai-uksouth-endpoint"
      region       = "uksouth"
    }

    aoaiwesteuropekey = {
      secretName   = "aoai-westeurope-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://westeurope.openai.azure.com/openai"
      endpointName = "aoai-westeurope-endpoint"
      region       = "westeurope"
    }

    aoaiwestuskey = {
      secretName   = "aoai-westus-key"
      secretValue  = "aoaiKeyValue"
      endpointURL  = "https://westus.openai.azure.com/openai"
      endpointName = "aoai-westus-endpoint"
      region       = "westus"
    }
  }

}

variable "use_random_suffix" {
  default = true
}
