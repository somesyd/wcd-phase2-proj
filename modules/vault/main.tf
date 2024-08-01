terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.111.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
  depends_on = [
    var.depends_on_resource_group
  ]
}

resource "azurerm_key_vault" "internal" {
  name                       = "${var.prefix}-kv2"
  location                   = data.azurerm_resource_group.this.location
  resource_group_name        = data.azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  sku_name                   = "standard"
  purge_protection_enabled   = true
}

# resource "azurerm_role_assignment" "internal-kv-deployer" {
#   scope = azurerm_key_vault.internal.id
#   role_definition_name = "Key Vault Administrator"
#   principal_id = data.azurerm_client_config.current.object_id
# }

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.internal.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create", "Get", "Delete", "List", "Update", "Recover", "Purge", "GetRotationPolicy", "WrapKey", "UnwrapKey"
  ]
}

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
