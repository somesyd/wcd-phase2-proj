terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.111.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "vault" {
  source                            = "./modules/vault"
  prefix                            = var.prefix
  resource_group_name               = azurerm_resource_group.this.name
  depends_on_resource_group         = azurerm_resource_group.this.id
  external_key_vault_resource_group = var.external_key_vault_resource_group
  external_key_vault_name           = var.external_key_vault_name
}

module "storage" {
  source                    = "./modules/storage"
  prefix                    = var.prefix
  layer1_storage_container  = module.databricks.layer1_storage_container
  resource_group_name       = azurerm_resource_group.this.name
  depends_on_resource_group = azurerm_resource_group.this.id
  pg_tables                 = var.pg_tables
  parquet_files             = var.parquet_files
}

module "databricks" {
  source                     = "./modules/databricks"
  prefix                     = var.prefix
  subscription_id            = data.azurerm_subscription.primary.subscription_id
  resource_group_name        = azurerm_resource_group.this.name
  depends_on_resource_group  = azurerm_resource_group.this.id
  databricks_account_id      = var.databricks_account_id
  storage_account_name       = module.storage.storage_account_name
  depends_on_storage_account = module.storage.depends_on_storage_account
  synapse_container          = module.synapse.synapse_storage_container_name
  my_databricks_id           = var.my_azure_login_name
}

module "datafactory" {
  source                     = "./modules/datafactory"
  prefix                     = var.prefix
  resource_group_name        = azurerm_resource_group.this.name
  depends_on_resource_group  = azurerm_resource_group.this.id
  storage_account_name       = module.storage.storage_account_name
  depends_on_storage_account = module.storage.depends_on_storage_account
  storage_container_name     = module.databricks.layer1_storage_container
  pg_tables                  = var.pg_tables
  pg_schema                  = var.pg_schema
  parquet_files              = var.parquet_files
  pg_host_name               = var.pg_host_name
  pg_database_name           = var.pg_database_name
  pg_username                = module.vault.pg_username
  pg_password                = module.vault.pg_password
  wcd_blob_storage_account   = module.vault.wcd_blob_storage_account
  wcd_blob_storage_key       = module.vault.wcd_blob_storage_key
  wcd_blob_container         = var.wcd_blob_container
  wcd_blob_folder            = var.wcd_blob_folder
}

module "synapse" {
  source                            = "./modules/synapse"
  prefix                            = var.prefix
  resource_group_name               = azurerm_resource_group.this.name
  depends_on_resource_group         = azurerm_resource_group.this.id
  storage_account_name              = module.storage.storage_account_name
  depends_on_storage_account        = module.storage.depends_on_storage_account
  internal_key_vault_name           = module.vault.internal_key_vault_name
  depends_on_internal_vault         = module.vault.internal_vault_id
  external_key_vault_resource_group = var.external_key_vault_resource_group
  external_key_vault_name           = var.external_key_vault_name
  admin_login                       = var.my_azure_login_name
  ip_start_and_finish               = var.my_ip
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "${var.prefix}-rg"
  location = "Canada Central"
}
