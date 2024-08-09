output "func_id" {
  value =  azurerm_linux_function_app.func_app.id
}

output "principal_id" {
  value =  azurerm_linux_function_app.func_app.identity[0].principal_id
}