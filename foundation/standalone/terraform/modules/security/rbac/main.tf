locals {
  role_definitions = [
    "Storage Blob Data Contributor",
    "Search Service Contributor",
    "Key Vault Secrets User",
    "Cognitive Services OpenAI User"
  ]
}

resource "azurerm_role_assignment" "this" {
  count                = length(local.role_definitions)
  scope                = var.resource_group_id
  role_definition_name = local.role_definitions[count.index]
  principal_id         = var.principal_id
}
