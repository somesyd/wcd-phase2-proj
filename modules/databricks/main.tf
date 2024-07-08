terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.109.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.48.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "databricks" {
  alias = "workspace"
  host  = azurerm_databricks_workspace.proj-db-ws.workspace_url
}

provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
}

provider "databricks" {
  host                        = azurerm_databricks_workspace.proj-db-ws.workspace_url
  azure_workspace_resource_id = azurerm_databricks_workspace.proj-db-ws.id

  azure_use_msi = true
}

data "azurerm_subscription" "this" {
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {
}

data "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_storage_container" "raw" {
  name                 = var.raw_storage_container
  storage_account_name = var.storage_account_name
}

data "azurerm_storage_container" "layer2" {
  name                 = var.layer2_storage_container
  storage_account_name = var.storage_account_name
}

data "azurerm_storage_container" "layer3" {
  name                 = var.layer3_storage_container
  storage_account_name = var.storage_account_name
}

data "azurerm_storage_container" "meta" {
  name                 = var.meta_storage_container
  storage_account_name = var.storage_account_name
}

resource "azurerm_databricks_workspace" "proj-db-ws" {
  name                = "proj-phase2-databricks"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku                 = "premium"
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.workspace
  workspace_id = azurerm_databricks_workspace.proj-db-ws.workspace_id
  metastore_id = var.databricks_metastore_id
}

resource "azurerm_databricks_access_connector" "ext_access_connector" {
  name                = "databricks-access-connector"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "ext_storage" {
  scope                = data.azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ext_access_connector.identity[0].principal_id
}

resource "databricks_group" "data_eng" {
  provider     = databricks.accounts
  display_name = "Data Engineers"
}

data "databricks_user" "me" {
  provider  = databricks.accounts
  user_name = var.my_databricks_id
}

resource "databricks_group_member" "add_me" {
  provider  = databricks.accounts
  group_id  = databricks_group.data_eng.id
  member_id = data.databricks_user.me.id
}

resource "databricks_mws_permission_assignment" "workspace_user_group" {
  provider     = databricks.accounts
  workspace_id = azurerm_databricks_workspace.proj-db-ws.workspace_id
  principal_id = databricks_group.data_eng.id
  permissions  = ["ADMIN"]
}

resource "databricks_storage_credential" "external" {
  name = azurerm_databricks_access_connector.ext_access_connector.name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.ext_access_connector.id
  }
  metastore_id = var.databricks_metastore_id
  provider     = databricks.accounts
  owner        = databricks_group.data_eng.display_name
  comment      = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this,
    azurerm_databricks_workspace.proj-db-ws
  ]
}

resource "databricks_external_location" "raw" {
  name     = "bronze_layer"
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net",
    data.azurerm_storage_container.raw.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_external_location" "layer2" {
  name     = "silver_layer"
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net",
    data.azurerm_storage_container.layer2.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_external_location" "layer3" {
  name     = "gold_layer"
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net",
    data.azurerm_storage_container.layer3.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_external_location" "meta" {
  name     = "meta"
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net",
    data.azurerm_storage_container.meta.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_catalog" "dev" {
  name         = "phase2_proj_dev"
  provider     = databricks.workspace
  metastore_id = var.databricks_metastore_id
  storage_root = databricks_external_location.meta.url
  owner        = "Data Engineers"
  comment      = "Managed by TF"
}

resource "databricks_schema" "raw" {
  name         = "bronze"
  provider     = databricks.workspace
  catalog_name = databricks_catalog.dev.id
  comment      = "Managed by TF"
  owner        = "Data Engineers"
  storage_root = databricks_external_location.raw.url
}

resource "databricks_schema" "layer2" {
  name         = "silver"
  provider     = databricks.workspace
  catalog_name = databricks_catalog.dev.id
  comment      = "Managed by TF"
  owner        = "Data Engineers"
  storage_root = databricks_external_location.layer2.url
}

resource "databricks_schema" "layer3" {
  name         = "gold"
  provider     = databricks.workspace
  catalog_name = databricks_catalog.dev.id
  comment      = "Managed by TF"
  owner        = "Data Engineers"
  storage_root = databricks_external_location.layer3.url
}

data "databricks_node_type" "smallest" {}

data "databricks_spark_version" "latest_lts" {
  provider          = databricks.workspace
  long_term_support = true
}

resource "databricks_cluster" "small" {
  cluster_name            = "small_cluster"
  provider                = databricks.workspace
  node_type_id            = data.databricks_node_type.smallest.id
  spark_version           = data.databricks_spark_version.latest_lts.id
  autotermination_minutes = 30
  num_workers             = 2
}