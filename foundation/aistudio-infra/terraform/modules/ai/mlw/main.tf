
resource "azapi_resource" "this" {
  type     = "Microsoft.MachineLearningServices/workspaces@2023-02-01-preview"
  name     = var.machine_learning_workspace_name
  location = var.location
  identity {
    type = "SystemAssigned"
  }
  parent_id                 = var.resource_group_id
  schema_validation_enabled = false # requiered for now
  body = jsonencode({
    properties = {
      kind                = "Hub"
      friendlyName        = var.machine_learning_workspace_name
      keyVault            = var.key_vault_id
      applicationInsights = var.appi_id
      containerRegistry   = var.acr_id
      storageAccount      = var.storage_account_id
      managedNetwork = {
        isolationMode = "Disabled"
      }
      workspaceHubConfig = {
        defaultWorkspaceResourceGroup = var.resource_group_id
      }
      publicNetworkAccess = "Enabled"
    }
  })
}
