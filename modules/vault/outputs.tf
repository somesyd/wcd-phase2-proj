data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "proj-rg" {
  name = "wcdphase2"
}

data "azurerm_key_vault" "proj-kv" {
  name                = "kv-wcd-phase2-proj"
  resource_group_name = data.azurerm_resource_group.proj-rg.name
}

data "azurerm_key_vault_secret" "pg-username" {
  name         = "PgUsername"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

output "pg_username" {
  value     = data.azurerm_key_vault_secret.pg-username.value
  sensitive = true
}

data "azurerm_key_vault_secret" "pg-password" {
  name         = "PgPassword"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

output "pg_password" {
  value     = data.azurerm_key_vault_secret.pg-password.value
  sensitive = true
}

data "azurerm_key_vault_secret" "wcd-blob-storage-account" {
  name         = "WcdBlobStorageAccount"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

output "wcd_blob_storage_account" {
  value     = data.azurerm_key_vault_secret.wcd-blob-storage-account.value
  sensitive = true
}

data "azurerm_key_vault_secret" "wcd-blob-storage-key" {
  name         = "WcdBlobStorageKey"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

output "wcd_blob_storage_key" {
  value     = data.azurerm_key_vault_secret.wcd-blob-storage-key.value
  sensitive = true
}