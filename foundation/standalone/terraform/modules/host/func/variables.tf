variable "resource_group_name" {}
variable "location" {}
variable "func_name" {}
variable "vnet_subnet_id" {}
variable "app_service_plan_id" {}
variable "appi_instrumentation_key" {}
variable "appi_instrumentation_connection_string" {}
variable "tags" {
  default = {}
}

variable "search_name" {}
variable "search_key" {}
variable "search_index" {}

variable "doc_intelligence_name" {}
variable "doc_intelligence_key" {}

variable "openai_service" {}
variable "openai_service_key" {}
variable "openai_service_1" {}
variable "openai_service_1_key" {}
variable "openai_service_2" {}
variable "openai_service_2_key" {}
variable "openai_service_3" {}
variable "openai_service_3_key" {}

variable "gpt_deployment_name" {}
