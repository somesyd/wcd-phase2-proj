
output "internal_key_vault_name" {
  value     = azurerm_key_vault.internal.name
  sensitive = true
}

output "internal_vault_id" {
  value = azurerm_key_vault.internal.id
  depends_on = [
    azurerm_key_vault_access_policy.deployer
  ]
}

output "pg_username" {
  value     = data.azurerm_key_vault_secret.pg-username.value
  sensitive = true
}

output "pg_password" {
  value     = data.azurerm_key_vault_secret.pg-password.value
  sensitive = true
}

output "wcd_blob_storage_account" {
  value     = data.azurerm_key_vault_secret.wcd-blob-storage-account.value
  sensitive = true
}

output "wcd_blob_storage_key" {
  value     = data.azurerm_key_vault_secret.wcd-blob-storage-key.value
  sensitive = true
}


