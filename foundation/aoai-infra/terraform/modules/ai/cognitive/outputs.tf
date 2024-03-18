output "key" {
  value     = azurerm_cognitive_account.this.primary_access_key
  sensitive = true
}

output "name" {
  value = azurerm_cognitive_account.this.name
}

output "id" {
  value = azurerm_cognitive_account.this.id
}
