data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
}

module "openai" {
  source                               = "./modules/ai/cognitive"
  resource_group_name                  = data.azurerm_resource_group.rg.name
  location                             = var.location
  cognitive_name                       = var.openai_name
  tags                                 = var.tags
  cognitive_private_endpoint_name      = var.openai_private_endpoint_name
  deployments                          = var.openai_deployments
  virtual_network_name                 = var.virtual_network_name
  virtual_network_resource_group_name  = var.virtual_network_resource_group_name
  private_endpoints_subnet_name        = var.private_endpoints_subnet_name
  private_dns_zone_resource_group_name = var.private_dns_zone_resource_group_name
}

module "rbac" {
  source                    = "./modules/security/rbac"
  contributor_principal_ids = var.contributor_principal_ids
  user_principal_ids        = var.user_principal_ids
  cognitive_service_id      = module.openai.id
}
