locals {
  role_definitions = [
    "Key Vault Secrets User"
  ]
}

resource "azurerm_role_assignment" "this" {
  count                = length(local.role_definitions)
  scope                = var.key_vault_id
  role_definition_name = local.role_definitions[count.index]
  principal_id         = var.principal_id
}
