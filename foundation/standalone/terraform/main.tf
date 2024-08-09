data "azurerm_subscription" "current" {}

resource "random_id" "random" {
  byte_length = 8
}

locals {
  sufix                          = var.use_random_suffix ? substr(lower(random_id.random.hex), 1, 4) : ""
  name_sufix                     = var.use_random_suffix ? "${local.sufix}" : ""
  resource_group_name            = "${var.resource_group_name}${local.name_sufix}"
  virtual_network_name           = "${var.virtual_network_name}${local.name_sufix}"
  storage_account_name           = "${var.storage_account_name}${local.name_sufix}"
  storage_private_endpoint_name  = "${var.storage_private_endpoint_name}${local.name_sufix}"
  keyvault_name                  = "${var.keyvault_name}${local.name_sufix}"
  keyvault_private_endpoint_name = "${var.keyvault_private_endpoint_name}${local.name_sufix}"
  openai_name                    = "${var.openai_name}${local.name_sufix}"
  doc_intelligence_name          = "${var.doc_intelligence_name}${local.name_sufix}"
  search_name                    = "${var.search_name}${local.name_sufix}"
  app_service_plan_name          = "${var.app_service_plan_name}${local.name_sufix}"
  appi_name                      = "${var.appi_name}${local.name_sufix}"
  log_name                       = "${var.log_name}${local.name_sufix}"
  func_name                      = "${var.func_name}${local.name_sufix}"
  stapp_name                     = "${var.stapp_name}${local.name_sufix}"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "vnet" {
  source                                  = "./modules/core/vnet"
  resource_group_name                     = azurerm_resource_group.rg.name
  location                                = var.location
  virtual_network_name                    = local.virtual_network_name
  address_prefix                          = var.address_prefix
  ai_subnet_address_prefix                = var.ai_subnet_address_prefix
  private_endpoints_subnet_address_prefix = var.private_endpoints_subnet_address_prefix
  bastion_subnet_address_prefix           = var.bastion_subnet_address_prefix
  jumpbox_subnet_address_prefix           = var.jumpbox_subnet_address_prefix
  app_subnet_address_prefix               = var.app_subnet_address_prefix
}

module "boot" {
  source                        = "./modules/core/st"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  storage_account_name          = local.storage_account_name
  storage_private_endpoint_name = local.storage_private_endpoint_name
  container_names               = var.container_names
  virtual_network_id            = module.vnet.virtual_network_id
  private_endpoints_subnet_id   = module.vnet.private_endpoints_subnet_id
}

module "kv" {
  source                         = "./modules/security/kv"
  resource_group_name            = azurerm_resource_group.rg.name
  location                       = var.location
  keyvault_name                  = local.keyvault_name
  keyvault_private_endpoint_name = local.keyvault_private_endpoint_name
  virtual_network_id             = module.vnet.virtual_network_id
  private_endpoints_subnet_id    = module.vnet.private_endpoints_subnet_id
  tags                           = var.tags
}

module "bastion" {
  source              = "./modules/security/bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  bastion_name        = "bastion"
  bastion_subnet_id   = module.vnet.bastion_subnet_id
  tags                = var.tags
}

module "jumpbox" {
  source              = "./modules/security/jumpbox"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  jumpbox_name        = "jumpbox"
  jumpbox_subnet_id   = module.vnet.jumpbox_subnet_id
  tags                = var.tags
}

module "openai" {
  source                          = "./modules/ai/cognitive"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  location_cognitive              = var.location_openai
  virtual_network_id              = module.vnet.virtual_network_id
  private_endpoints_subnet_id     = module.vnet.private_endpoints_subnet_id
  cognitive_name                  = local.openai_name
  cognitive_kind                  = "OpenAI"
  cognitive_sku                   = var.openai_sku
  cognitive_dns_zone_name         = "privatelink.openai.azure.com"
  tags                            = var.tags
  cognitive_private_endpoint_name = var.openai_private_endpoint_name
  deployments                     = var.openai_deployments
}

module "doc_intelligence" {
  source                          = "./modules/ai/cognitive"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  location_cognitive              = var.location_doc_intelligence
  virtual_network_id              = module.vnet.virtual_network_id
  private_endpoints_subnet_id     = module.vnet.private_endpoints_subnet_id
  cognitive_name                  = local.doc_intelligence_name
  cognitive_kind                  = "FormRecognizer"
  cognitive_sku                   = var.doc_intelligence_sku
  cognitive_dns_zone_name         = "privatelink.cognitiveservices.azure.com"
  tags                            = var.tags
  cognitive_private_endpoint_name = var.doc_intelligence_private_endpoint_name
}

module "search" {
  source                       = "./modules/ai/search"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  virtual_network_id           = module.vnet.virtual_network_id
  private_endpoints_subnet_id  = module.vnet.private_endpoints_subnet_id
  search_name                  = local.search_name
  search_sku                   = var.search_sku
  semantic_search_sku          = var.semantic_search_sku
  search_private_endpoint_name = "pe-search"
  tags                         = var.tags
}

module "plan" {
  source                = "./modules/host/asp"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  app_service_plan_name = local.app_service_plan_name
  tags                  = var.tags
}

module "appi" {
  source              = "./modules/host/appi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  appi_name           = local.appi_name
  log_name            = local.log_name
  tags                = var.tags
}

module "func" {
  source                                 = "./modules/host/func"
  resource_group_name                    = azurerm_resource_group.rg.name
  location                               = var.location
  func_name                              = local.func_name
  app_service_plan_id                    = module.plan.app_service_plan_id
  vnet_subnet_id                         = module.vnet.app_subnet_id
  appi_instrumentation_key               = module.appi.appi_instrumentation_key
  appi_instrumentation_connection_string = module.appi.appi_instrumentation_connection_string
  tags                                   = var.tags

  search_name  = module.search.name
  search_key   = module.search.key
  search_index = var.search_index

  doc_intelligence_name = module.doc_intelligence.name
  doc_intelligence_key  = module.doc_intelligence.key

  openai_service       = module.openai.name
  openai_service_key   = module.openai.key
  openai_service_1     = module.openai.name
  openai_service_1_key = module.openai.key
  openai_service_2     = module.openai.name
  openai_service_2_key = module.openai.key
  openai_service_3     = module.openai.name
  openai_service_3_key = module.openai.key

  gpt_deployment_name = var.gpt_deployment_name
}

module "stapp" {
  source              = "./modules/host/stapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  location_stapp      = var.location_stapp
  stapp_name          = local.stapp_name
  backend_id          = module.func.func_id
  tags                = var.tags
}

module "rbac" {
  source            = "./modules/security/rbac"
  principal_id      = module.func.principal_id
  resource_group_id = azurerm_resource_group.rg.id
  depends_on        = [module.func]
}
