output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "depends_on_storage_account" {
  value = azurerm_storage_account.this.id
}