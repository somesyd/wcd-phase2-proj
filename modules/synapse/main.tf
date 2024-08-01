terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.111.0"
    }
  }
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
  depends_on = [
    var.depends_on_resource_group
  ]
}

data "azurerm_client_config" "current" {}

# External key vault holds Synapse SQL Server username & password
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

# Create storage container for Synapse data
data "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on = [
    var.depends_on_storage_account
  ]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "this" {
  name               = "synapse"
  storage_account_id = data.azurerm_storage_account.this.id
}

# Internal key vault for synapse workspace
data "azurerm_key_vault" "internal" {
  name                = var.internal_key_vault_name
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on = [
    var.depends_on_internal_vault
  ]
}

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
  name                                 = "${var.prefix}-synapse"
  resource_group_name                  = data.azurerm_resource_group.this.name
  location                             = data.azurerm_resource_group.this.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.this.id
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
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "GetRotationPolicy", "WrapKey", "UnwrapKey"
  ]
}

resource "azurerm_synapse_firewall_rule" "this" {
  name                 = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  start_ip_address     = var.ip_start_and_finish
  end_ip_address       = var.ip_start_and_finish
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
  login                = var.admin_login
  object_id            = data.azurerm_client_config.current.object_id
  tenant_id            = data.azurerm_client_config.current.tenant_id
  depends_on = [
    azurerm_synapse_workspace_key.this
  ]
}

resource "azurerm_synapse_workspace_sql_aad_admin" "example" {
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  login                = var.admin_login
  object_id            = data.azurerm_client_config.current.object_id
  tenant_id            = data.azurerm_client_config.current.tenant_id
  depends_on = [
    azurerm_synapse_workspace_key.this
  ]
}

resource "azurerm_synapse_spark_pool" "small" {
  name                                = "smallSparkPool"
  synapse_workspace_id                = azurerm_synapse_workspace.this.id
  node_size_family                    = "MemoryOptimized"
  node_size                           = "Small"
  node_count                          = 3
  dynamic_executor_allocation_enabled = false
  spark_version                       = "3.4"

  auto_pause {
    delay_in_minutes = 15
  }

  depends_on = [
    azurerm_synapse_workspace_key.this
  ]
}

## --- expensive resource --> USE WITH CAUTION
# resource "azurerm_synapse_sql_pool" "small" {
#   name                 = "smallsqlpool"
#   synapse_workspace_id = azurerm_synapse_workspace.this.id
#   sku_name             = "DW100c"
#   create_mode          = "Default"
#   storage_account_type = "LRS"
#   geo_backup_policy_enabled = false

#   depends_on = [
#     azurerm_synapse_workspace_key.this
#   ]
# }