resource "random_id" "random" {
  byte_length = 8
}

locals {
  sufix                   = var.use_random_suffix ? substr(lower(random_id.random.hex), 1, 4) : ""
  name_sufix              = var.use_random_suffix ? "${local.sufix}" : ""
  appi_name               = "${var.appi_name}${local.name_sufix}"
  log_name                = "${var.log_name}${local.name_sufix}"
  keyvault_name           = "${var.keyvault_name}${local.name_sufix}"
  storage_account_name    = "${var.storage_account_name}${local.name_sufix}"
  eventhub_namespace_name = "${var.eventhub_namespace_name}${local.name_sufix}"
  eventhub_name           = "${var.eventhub_name}${local.name_sufix}"
  stream_analytics_name   = "${var.stream_analytics_name}${local.name_sufix}"
  apim_name               = "${var.apim_name}${local.name_sufix}"
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

module "logs" {
  source              = "./modules/observability/logs"
  log_name            = local.log_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

module "appi" {
  source              = "./modules/observability/appi"
  appi_name           = local.appi_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  log_id              = module.logs.log_id
}

module "kv" {
  source              = "./modules/security/kv"
  keyvault_name       = local.keyvault_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  secrets             = var.apim_secrets
}

module "st" {
  source               = "./modules/core/st"
  storage_account_name = local.storage_account_name
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
}

module "evh" {
  source                  = "./modules/integration/evh"
  eventhub_namespace_name = local.eventhub_namespace_name
  eventhub_name           = local.eventhub_name
  location                = var.location
  resource_group_name     = data.azurerm_resource_group.rg.name
}

module "asa" {
  source                = "./modules/integration/asa"
  stream_analytics_name = local.stream_analytics_name
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.rg.name
}

module "apim" {
  source              = "./modules/integration/apim"
  apim_name           = local.apim_name
  location            = var.location_apim
  resource_group_name = data.azurerm_resource_group.rg.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
}

module "rbac" {
  source       = "./modules/security/rbac"
  principal_id = module.apim.principal_id
  key_vault_id = module.kv.key_vault_id
}

module "apim_configuration" {
  source                     = "./modules/integration/apim_configuration"
  apim_name                  = local.apim_name
  apim_id                    = module.apim.apim_id
  gatewayUrl                 = module.apim.gateway_url
  location                   = var.location_apim
  resource_group_name        = data.azurerm_resource_group.rg.name
  appi_resource_id           = module.appi.appi_id
  appi_instrumentation_key   = module.appi.appi_instrumentation_key
  keyvault_name              = module.kv.keyvault_name
  eventhub_connection_string = module.evh.eventhub_connection_string
  eventhub_name              = module.evh.eventhub_name
  secrets                    = var.apim_secrets

  depends_on = [
    module.rbac
  ]
}
