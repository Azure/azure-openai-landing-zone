resource "azurerm_role_assignment" "contributor" {
  count                = length(var.contributor_principal_ids)
  scope                = var.cognitive_service_id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = var.contributor_principal_ids[count.index]
}

resource "azurerm_role_assignment" "user" {
  count                = length(var.user_principal_ids)
  scope                = var.cognitive_service_id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.contributor_principal_ids[count.index]
}
