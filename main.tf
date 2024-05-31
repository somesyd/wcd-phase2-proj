terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.89.0"
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

resource "azurerm_resource_group" "proj-rg" {
  name     = "phase2-project-rg"
  location = "Canada Central"
}

module "vault" {
  source = "./modules/vault"
}

resource "azurerm_storage_account" "proj-sa" {
  name                     = "phase2projectstorage"
  resource_group_name      = azurerm_resource_group.proj-rg.name
  location                 = azurerm_resource_group.proj-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"

  tags = {
    environment = "dev"
  }
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "blob_contributor" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "proj-fs" {
  name               = "bd-project"
  storage_account_id = azurerm_storage_account.proj-sa.id
}

resource "azurerm_storage_data_lake_gen2_path" "proj-folders" {
  for_each = { for i, v in var.pg_tables : i => v }

  path               = each.value.folder
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.proj-fs.name
  storage_account_id = azurerm_storage_account.proj-sa.id
  resource           = "directory"
}

resource "azurerm_data_factory" "proj-adf" {
  name                = "phase2-project-adf"
  location            = azurerm_resource_group.proj-rg.location
  resource_group_name = azurerm_resource_group.proj-rg.name
}

resource "azurerm_data_factory_linked_service_postgresql" "rds-postgres-ls" {
  name              = "ls_rds_pg"
  data_factory_id   = azurerm_data_factory.proj-adf.id
  connection_string = "Host=${var.pg_host_name};Port=5432;Database=${var.pg_database_name};UID=${module.vault.pg_username};EncryptionMethod=0;Password=${module.vault.pg_password}"
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "wcd-blob-storage-ls" {
  name              = "ls_wcd_blob"
  data_factory_id   = azurerm_data_factory.proj-adf.id
  connection_string = "DefaultEndpointsProtocol=https;BlobEndpoint=https://${module.vault.wcd_blob_storage_account}.blob.core.windows.net;AccountName=${module.vault.wcd_blob_storage_account};AccountKey=${module.vault.wcd_blob_storage_key}"
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "my-blob-storage-ls" {
  name              = "ls_my_blob"
  data_factory_id   = azurerm_data_factory.proj-adf.id
  connection_string = azurerm_storage_account.proj-sa.primary_connection_string
}

resource "azurerm_data_factory_dataset_postgresql" "proj_pg_dataset" {
  for_each            = { for i, v in var.pg_tables : i => v }
  name                = "ds_pg_${each.value.table}"
  data_factory_id     = azurerm_data_factory.proj-adf.id
  linked_service_name = azurerm_data_factory_linked_service_postgresql.rds-postgres-ls.name

  table_name = "${var.pg_schema}.${each.value.table}"
}

resource "azurerm_data_factory_dataset_azure_blob" "proj_my_blob_dataset" {
  for_each            = { for i, v in var.pg_tables : i => v }
  name                = "ds_my_blob_${each.value.folder}"
  data_factory_id     = azurerm_data_factory.proj-adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.my-blob-storage-ls.name

  path     = "${azurerm_storage_data_lake_gen2_filesystem.proj-fs.name}/${each.value.folder}"
  filename = "${each.value.folder}.csv"
}
