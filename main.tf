terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.109.0"
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

module "vault" {
  source = "./modules/vault"
}

module "storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.proj-rg.name
  pg_tables           = var.pg_tables
  parquet_files       = var.parquet_files
}

module "databricks" {
  source                   = "./modules/databricks"
  subscription_id          = data.azurerm_subscription.primary.subscription_id
  resource_group_name      = azurerm_resource_group.proj-rg.name
  databricks_account_id    = module.vault.databricks_account_id
  databricks_metastore_id  = module.vault.databricks_metastore_id
  storage_account_name     = module.storage.storage_account_name
  raw_storage_container    = module.storage.storage_container_layer1_name
  layer2_storage_container = module.storage.storage_container_layer2_name
  layer3_storage_container = module.storage.storage_container_layer3_name
  meta_storage_container   = module.storage.storage_container_meta_name
}

module "datafactory" {
  source                       = "./modules/datafactory"
  resource_group_name          = azurerm_resource_group.proj-rg.name
  location                     = azurerm_resource_group.proj-rg.location
  storage_account_id           = module.storage.storage_account_id
  storage_account_dfs_endpoint = module.storage.storage_account_dfs_endpoint
  storage_container_name       = module.storage.storage_container_layer1_name
  pg_tables                    = var.pg_tables
  pg_schema                    = var.pg_schema
  parquet_files                = var.parquet_files
  pg_host_name                 = var.pg_host_name
  pg_database_name             = var.pg_database_name
  pg_username                  = module.vault.pg_username
  pg_password                  = module.vault.pg_password
  wcd_blob_storage_account     = module.vault.wcd_blob_storage_account
  wcd_blob_storage_key         = module.vault.wcd_blob_storage_key
  wcd_blob_container           = var.wcd_blob_container
  wcd_blob_folder              = var.wcd_blob_folder
}

data "azurerm_subscription" "primary" {}

resource "azurerm_resource_group" "proj-rg" {
  name     = "phase2-project-rg"
  location = "Canada Central"
}
