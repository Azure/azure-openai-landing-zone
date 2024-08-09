resource "azurerm_storage_account" "sa" {
  name                            = "st${var.func_name}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
}

resource "azurerm_linux_function_app" "func_app" {
  name                                           = var.func_name
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = var.app_service_plan_id
  storage_account_name                           = azurerm_storage_account.sa.name
  storage_account_access_key                     = azurerm_storage_account.sa.primary_access_key
  functions_extension_version                    = "~4"
  https_only                                     = true
  virtual_network_subnet_id                      = var.vnet_subnet_id
  tags                                           = var.tags
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_key               = var.appi_instrumentation_key
    application_insights_connection_string = var.appi_instrumentation_connection_string
    remote_debugging_enabled               = false
    remote_debugging_version               = "VS2019"
    vnet_route_all_enabled                 = true
    runtime_scale_monitoring_enabled       = false
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION     = "~4"
    ENABLE_ORYX_BUILD               = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT  = "true"
    WEBSITE_RUN_FROM_PACKAGE        = "1"
    AZURE_FORM_RECOGNIZER_SERVICE   = var.doc_intelligence_name
    AZURE_FORM_RECOGNIZER_KEY       = var.doc_intelligence_key
    AZURE_OPENAI_SERVICE            = var.openai_service
    AZURE_OPENAI_KEY                = var.openai_service_key
    AZURE_OPENAI_SERVICE_1          = var.openai_service_1
    AZURE_OPENAI_KEY_1              = var.openai_service_1_key
    AZURE_OPENAI_SERVICE_2          = var.openai_service_2
    AZURE_OPENAI_KEY_2              = var.openai_service_2_key
    AZURE_OPENAI_SERVICE_3          = var.openai_service_3
    AZURE_OPENAI_KEY_3              = var.openai_service_3_key
    AZURE_OPENAI_CHATGPT_DEPLOYMENT = var.gpt_deployment_name
    AZURE_OPENAI_GPT_DEPLOYMENT     = var.gpt_deployment_name
    AZURE_SEARCH_SERVICE            = var.search_name
    AZURE_SEARCH_KEY                = var.search_key
    AZURE_SEARCH_INDEX              = var.search_index
  }
}
