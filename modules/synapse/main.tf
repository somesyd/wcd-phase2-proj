terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.109.0"
    }
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# external key vault holds Synapse SQL Server username & password
data "azurerm_key_vault" "external-kv" {
  name                = var.external_key_vault_name
  resource_group_name = var.external_key_vault_resource_group
}

data "azurerm_key_vault_secret" "sql-user" {
  name         = "SynapseSqlUser"
  key_vault_id = data.azurerm_key_vault.external-kv.id
}

data "azurerm_key_vault_secret" "sql-password" {
  name         = "SynapseSqlPassword"
  key_vault_id = data.azurerm_key_vault.external-kv.id
}

# internal key vault for synapse workspace
data "azurerm_key_vault" "internal" {
  name                = var.internal_key_vault_name
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on = [
    var.depends_on_internal_vault
  ]
}

# resource "azurerm_key_vault" "this" {
#     name = "phase2-proj-synapse-kv"
#     location = data.azurerm_resource_group.this.location
#     resource_group_name = data.azurerm_resource_group.this.name
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     soft_delete_retention_days = 7
#     sku_name = "standard"
#     purge_protection_enabled = true
# }

# resource "azurerm_key_vault_access_policy" "deployer" {
#     key_vault_id = data.azurerm_key_vault.internal.id
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     object_id = data.azurerm_client_config.current.object_id

#     key_permissions = [
#         "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "GetRotationPolicy"
#     ]

#     secret_permissions = [
#         "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
#     ]
# }

resource "azurerm_key_vault_key" "workspace-key" {
  name         = "SynapseWorkspaceKey"
  key_vault_id = data.azurerm_key_vault.internal.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts = [
    "unwrapKey", "wrapKey"
  ]
}

resource "azurerm_synapse_workspace" "this" {
  name                                 = "phase2-proj-synapse"
  resource_group_name                  = data.azurerm_resource_group.this.name
  location                             = data.azurerm_resource_group.this.location
  storage_data_lake_gen2_filesystem_id = var.data_lake_container
  sql_administrator_login              = data.azurerm_key_vault_secret.sql-user.value
  sql_administrator_login_password     = data.azurerm_key_vault_secret.sql-password.value

  customer_managed_key {
    key_versionless_id = azurerm_key_vault_key.workspace-key.versionless_id
    key_name           = "synapseEncKey"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "workspace-policy" {
  key_vault_id = data.azurerm_key_vault.internal.id
  tenant_id    = azurerm_synapse_workspace.this.identity[0].tenant_id
  object_id    = azurerm_synapse_workspace.this.identity[0].principal_id

  key_permissions = [
    "Get", "WrapKey", "UnwrapKey"
  ]
}

resource "azurerm_synapse_workspace_key" "this" {
  customer_managed_key_versionless_id = azurerm_key_vault_key.workspace-key.versionless_id
  synapse_workspace_id                = azurerm_synapse_workspace.this.id
  active                              = true
  customer_managed_key_name           = "synapseEncKey"
  depends_on = [
    azurerm_key_vault_access_policy.workspace-policy
  ]
}

resource "azurerm_synapse_workspace_aad_admin" "this" {
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  login                = "AzureAD Admin"
  object_id            = data.azurerm_client_config.current.object_id
  tenant_id            = data.azurerm_client_config.current.tenant_id
  depends_on = [
    azurerm_synapse_workspace_key.this
  ]
}