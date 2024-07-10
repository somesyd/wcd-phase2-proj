terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.109.0"
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_key_vault" "internal" {
  name                       = "phase2-proj-kv"
  location                   = data.azurerm_resource_group.this.location
  resource_group_name        = data.azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  sku_name                   = "standard"
  purge_protection_enabled   = true
}

## added manually
# resource "azurerm_key_vault_access_policy" "deployer" {
#   key_vault_id = azurerm_key_vault.internal.id
#   tenant_id = data.azurerm_client_config.current.tenant_id
#   object_id = data.azurerm_client_config.current.object_id

#   key_permissions = [
#         "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "GetRotationPolicy"
#     ]

#     secret_permissions = [
#         "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
#     ]
# }

# ***** IMPORT EXTERNAL KEY VAULT SECRETS ******
data "azurerm_key_vault" "proj-kv" {
  name                = var.external_key_vault_name
  resource_group_name = var.external_key_vault_resource_group
}

data "azurerm_key_vault_secret" "pg-username" {
  name         = "PgUsername"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "pg-password" {
  name         = "PgPassword"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "wcd-blob-storage-account" {
  name         = "WcdBlobStorageAccount"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "wcd-blob-storage-key" {
  name         = "WcdBlobStorageKey"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "databricks-account-id" {
  name         = "DatabricksAccountId"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "databricks-metastore-id" {
  name         = "DatabricksMetastoreId"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "synapse-sql-user" {
  name         = "SynapseSqlUser"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

data "azurerm_key_vault_secret" "synapse-sql-password" {
  name         = "SynapseSqlPassword"
  key_vault_id = data.azurerm_key_vault.proj-kv.id
}

