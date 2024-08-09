data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                            = var.keyvault_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku_name                        = "standard"
  enabled_for_disk_encryption     = false
  purge_protection_enabled        = false
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  enable_rbac_authorization       = true
  soft_delete_retention_days      = 7
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  tags                            = var.tags

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_secret" "this" {
  for_each     = var.secrets
  name         = each.value.secretName
  value        = each.value.secretValue
  key_vault_id = azurerm_key_vault.kv.id
}
