
output "internal_key_vault_name" {
  value     = azurerm_key_vault.internal.name
  sensitive = true
}

output "internal_vault_id" {
  value = azurerm_key_vault.internal.id
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

output "databricks_account_id" {
  value     = data.azurerm_key_vault_secret.databricks-account-id.value
  sensitive = true
}

output "databricks_metastore_id" {
  value     = data.azurerm_key_vault_secret.databricks-metastore-id.value
  sensitive = true
}

output "synapse_sql_user" {
  value     = data.azurerm_key_vault_secret.synapse-sql-user.value
  sensitive = true
}

output "synapse_sql_password" {
  value     = data.azurerm_key_vault_secret.synapse-sql-password.value
  sensitive = true
}

