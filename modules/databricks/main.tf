terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.111.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.48.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.53.1"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "databricks" {
  alias = "workspace"
  host  = azurerm_databricks_workspace.this.workspace_url
}

provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
}

provider "databricks" {
  host                        = azurerm_databricks_workspace.this.workspace_url
  azure_workspace_resource_id = azurerm_databricks_workspace.this.id

  azure_use_msi = true
}

data "azurerm_subscription" "this" {
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
  depends_on = [
    var.depends_on_resource_group
  ]
}

data "azurerm_client_config" "current" {
}

data "databricks_current_config" "this" {
  depends_on = [
    azurerm_databricks_workspace.this
  ]
}

data "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
  depends_on = [
    var.depends_on_storage_account
  ]
}

# Create containers and folders for unity-catalog storage
resource "azurerm_storage_data_lake_gen2_filesystem" "layer1" {
  name               = var.medallion.layer1.container_name
  storage_account_id = data.azurerm_storage_account.this.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "layer2" {
  name               = var.medallion.layer2.container_name
  storage_account_id = data.azurerm_storage_account.this.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "layer3" {
  name               = var.medallion.layer3.container_name
  storage_account_id = data.azurerm_storage_account.this.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "root" {
  name               = var.medallion.root.container_name
  storage_account_id = data.azurerm_storage_account.this.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "volume" {
  name               = var.volume.source.container_name
  storage_account_id = data.azurerm_storage_account.this.id
}

resource "azurerm_storage_data_lake_gen2_path" "volume" {
  path               = var.volume.source.landing_folder_name
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.volume.name
  storage_account_id = data.azurerm_storage_account.this.id
  resource           = "directory"
}

# Set up Databricks workspace and connect Metastore
resource "azurerm_databricks_workspace" "this" {
  name                = "${var.prefix}-databricks"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku                 = "premium"
}

data "databricks_current_metastore" "this" {
  provider = databricks.workspace
  depends_on = [
    azurerm_databricks_workspace.this
  ]
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.accounts
  workspace_id = azurerm_databricks_workspace.this.workspace_id
  metastore_id = data.databricks_current_metastore.this.id
  depends_on = [
    databricks_group_member.add_me
  ]
}

# Set up Databricks connection to storage
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

# Add permissions to access Databricks workspace tools
resource "databricks_group" "data_eng" {
  provider         = databricks.accounts
  display_name     = var.group_name
  workspace_access = true
  depends_on = [
    data.databricks_current_config.this
  ]
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
  workspace_id = azurerm_databricks_workspace.this.workspace_id
  principal_id = databricks_group.data_eng.id
  permissions  = ["ADMIN"]
  depends_on = [
    databricks_group_member.add_me
  ]
}

# # Storage credential for Databricks Unity Catalog
resource "databricks_storage_credential" "external" {
  name = azurerm_databricks_access_connector.ext_access_connector.name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.ext_access_connector.id
  }
  metastore_id = data.databricks_current_metastore.this.id
  provider     = databricks.accounts
  owner        = databricks_group.data_eng.display_name
  comment      = "Managed by TF"
  depends_on = [
    azurerm_role_assignment.ext_storage
  ]
}

resource "databricks_grants" "external_cred" {
  provider           = databricks.workspace
  storage_credential = databricks_storage_credential.external.id
  grant {
    principal  = data.databricks_user.me.user_name
    privileges = ["ALL_PRIVILEGES"]
  }
  depends_on = [
    databricks_group_member.add_me
  ]
}

# Create the Unity Catalog 
resource "databricks_external_location" "root" {
  name     = var.medallion.root.external_loc_name
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.root.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  owner           = databricks_group.data_eng.display_name
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_catalog" "unity-catalog" {
  name         = var.medallion.root.catalog_name
  provider     = databricks.workspace
  metastore_id = data.databricks_current_metastore.this.id
  storage_root = databricks_external_location.root.url
  owner        = databricks_group.data_eng.display_name
  comment      = "Managed by TF"
}

resource "databricks_external_location" "layer1" {
  name     = var.medallion.layer1.external_loc_name
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.layer1.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  owner           = databricks_group.data_eng.display_name
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_schema" "layer1" {
  name         = var.medallion.layer1.schema_name
  provider     = databricks.workspace
  catalog_name = databricks_catalog.unity-catalog.id
  comment      = "Managed by TF"
  owner        = databricks_group.data_eng.display_name
  storage_root = databricks_external_location.layer1.url
}

resource "databricks_external_location" "layer2" {
  name     = var.medallion.layer2.external_loc_name
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.layer2.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  owner           = databricks_group.data_eng.display_name
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_schema" "layer2" {
  name         = var.medallion.layer2.schema_name
  provider     = databricks.workspace
  catalog_name = databricks_catalog.unity-catalog.id
  comment      = "Managed by TF"
  owner        = databricks_group.data_eng.display_name
  storage_root = databricks_external_location.layer2.url
}

resource "databricks_external_location" "layer3" {
  name     = var.medallion.layer3.external_loc_name
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.layer3.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  owner           = databricks_group.data_eng.display_name
  depends_on = [
    databricks_metastore_assignment.this
  ]
}

resource "databricks_schema" "layer3" {
  name         = var.medallion.layer3.schema_name
  provider     = databricks.workspace
  catalog_name = databricks_catalog.unity-catalog.id
  comment      = "Managed by TF"
  owner        = databricks_group.data_eng.display_name
  storage_root = databricks_external_location.layer3.url
}


# Create volume for Databricks access to non-tabular date in storage
resource "databricks_external_location" "volume" {
  name     = var.volume.source.external_loc_name
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.volume.name,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this
  ]
  owner = databricks_group.data_eng.display_name
}

resource "databricks_schema" "volume" {
  name         = var.volume.source.schema_name
  provider     = databricks.workspace
  catalog_name = databricks_catalog.unity-catalog.id
  comment      = "Managed by TF"
  owner        = databricks_group.data_eng.display_name
  storage_root = databricks_external_location.root.url
}

resource "databricks_volume" "landing" {
  name             = var.volume.source.landing_folder_name
  provider         = databricks.workspace
  catalog_name     = databricks_catalog.unity-catalog.name
  schema_name      = databricks_schema.volume.name
  volume_type      = "EXTERNAL"
  storage_location = "${databricks_external_location.volume.url}${azurerm_storage_data_lake_gen2_path.volume.path}"
  comment          = "Managed by TF"
}

# Connect Synapse storage container to Unity Catalog volume
resource "azurerm_storage_data_lake_gen2_path" "synapse" {
  path               = var.volume.synapse.landing_folder_name
  filesystem_name    = var.synapse_container
  storage_account_id = data.azurerm_storage_account.this.id
  resource           = "directory"
}

resource "databricks_external_location" "synapse" {
  name     = var.volume.synapse.external_loc_name
  provider = databricks.workspace
  url = format("abfss://%s@%s.dfs.core.windows.net/",
    var.synapse_container,
  data.azurerm_storage_account.this.name)

  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on = [
    databricks_metastore_assignment.this
  ]
  owner = databricks_group.data_eng.display_name
}

resource "databricks_schema" "synapse" {
  name         = var.volume.synapse.schema_name
  provider     = databricks.workspace
  catalog_name = databricks_catalog.unity-catalog.id
  comment      = "Managed by TF"
  owner        = databricks_group.data_eng.display_name
  storage_root = databricks_external_location.synapse.url
}

resource "databricks_volume" "synapse" {
  name             = "data"
  provider         = databricks.workspace
  catalog_name     = databricks_catalog.unity-catalog.name
  schema_name      = databricks_schema.synapse.name
  volume_type      = "EXTERNAL"
  storage_location = "${databricks_external_location.synapse.url}${azurerm_storage_data_lake_gen2_path.synapse.path}"
  comment          = "Managed by TF"
}


# Set up Databricks cluster
data "databricks_node_type" "smallest" {}

data "databricks_spark_version" "latest_lts" {
  provider          = databricks.workspace
  long_term_support = true
  depends_on = [
    databricks_mws_permission_assignment.workspace_user_group
  ]
}

resource "databricks_cluster" "small" {
  cluster_name            = "small_cluster"
  provider                = databricks.workspace
  node_type_id            = data.databricks_node_type.smallest.id
  spark_version           = data.databricks_spark_version.latest_lts.id
  autotermination_minutes = 15
  num_workers             = 2

  # single_user necessary to use ML features & unity-catalog
  data_security_mode = "SINGLE_USER"
  single_user_name   = var.my_databricks_id

  depends_on = [
    databricks_group_member.add_me
  ]
}
