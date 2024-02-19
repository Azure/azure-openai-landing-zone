data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "random_id" "random" {
  byte_length = 8
}

locals {
  sufix                = var.use_random_suffix ? substr(lower(random_id.random.hex), 1, 4) : ""
  name_sufix           = var.use_random_suffix ? "${local.sufix}" : ""
  resource_group_name  = "${var.resource_group_name}${local.name_sufix}"
  storage_account_name = "${var.storage_account_name}${local.name_sufix}"
  keyvault_name        = "${var.keyvault_name}${local.name_sufix}"
  log_name             = "${var.log_name}${local.name_sufix}"
  appi_name            = "${var.appi_name}${local.name_sufix}"
  acr_name             = "${var.acr_name}${local.name_sufix}"
  search_name          = "${var.search_name}${local.name_sufix}"
  mlw_name             = "${var.mlw_name}${local.name_sufix}"

  private_endpoints = [
    {
      privateEndpointName    = "pe-${module.st.name}-blob"
      resourceId             = module.st.id
      privateEndpointGroupId = "blob"
      privateDnsZoneName     = "privatelink.blob.core.windows.net"
      resourceGroupName      = var.private_dns_zone_resource_group_name
      azureResourceName      = module.st.name
    },
    {
      privateEndpointName    = "pe-${module.st.name}-file"
      resourceId             = module.st.id
      privateEndpointGroupId = "file"
      privateDnsZoneName     = "privatelink.file.core.windows.net"
      resourceGroupName      = var.virtual_network_resource_group_name
      azureResourceName      = module.st.name
    },
    {
      privateEndpointName    = "pe-${module.kv.name}"
      resourceId             = module.kv.id
      privateEndpointGroupId = "vault"
      privateDnsZoneName     = "privatelink.vaultcore.azure.net"
      resourceGroupName      = var.virtual_network_resource_group_name
      azureResourceName      = module.kv.name
    },
    {
      privateEndpointName    = "pe-${module.cr.name}"
      resourceId             = module.cr.id
      privateEndpointGroupId = "registry"
      privateDnsZoneName     = "privatelink.azurecr.io"
      resourceGroupName      = var.virtual_network_resource_group_name
      azureResourceName      = module.cr.name
    },
    {
      privateEndpointName    = "pe-${module.mlw.name}"
      resourceId             = module.mlw.id
      privateEndpointGroupId = "amlworkspace"
      privateDnsZoneName     = "privatelink.api.azureml.ms"
      resourceGroupName      = var.resource_group_name
      azureResourceName      = module.mlw.name
    },
    {
      privateEndpointName    = "pe-${module.search.name}"
      resourceId             = module.search.id
      privateEndpointGroupId = "searchService"
      privateDnsZoneName     = "privatelink.search.windows.net"
      resourceGroupName      = var.virtual_network_resource_group_name
      azureResourceName      = module.search.name
    }
  ]
}

module "st" {
  source               = "./modules/core/st"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_name = local.storage_account_name
  container_names      = {}
}

module "kv" {
  source              = "./modules/security/kv"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  keyvault_name       = local.keyvault_name
  tags                = var.tags
}

module "logs" {
  source              = "./modules/observability/logs"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  log_name            = var.log_name
  tags                = var.tags
}

module "appi" {
  source              = "./modules/observability/appi"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  appi_name           = local.appi_name
  log_id              = module.logs.log_id
  tags                = var.tags
}

module "cr" {
  source              = "./modules/containers/cr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  acr_name            = local.acr_name
}

module "search" {
  source              = "./modules/ai/search"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  search_name         = local.search_name
  search_sku          = var.search_sku
  semantic_search_sku = var.semantic_search_sku
  replica_count       = var.search_replica_count
  partition_count     = var.search_partition_count
  hosting_mode        = var.hosting_mode
}

module "mlw" {
  source                          = "./modules/ai/mlw"
  resource_group_id               = data.azurerm_resource_group.rg.id
  location                        = var.location
  machine_learning_workspace_name = local.mlw_name
  appi_id                         = module.appi.id
  acr_id                          = module.cr.id
  storage_account_id              = module.st.id
  key_vault_id                    = module.kv.id
}

module "pe" {
  count                                = var.enable_private_endpoints ? 1 : 0
  source                               = "./modules/core/pe"
  virtual_network_name                 = var.virtual_network_name
  private_dns_zone_resource_group_name = var.private_dns_zone_resource_group_name
  virtual_network_resource_group_name  = var.virtual_network_resource_group_name
  private_endpoints_subnet_name        = var.private_endpoints_subnet_name
  private_endpoints                    = local.private_endpoints
}
