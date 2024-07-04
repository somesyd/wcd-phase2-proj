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

resource "azurerm_storage_account" "proj-sa" {
  name                      = "phase2projectstorage"
  resource_group_name       = data.azurerm_resource_group.this.name
  location                  = data.azurerm_resource_group.this.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  is_hns_enabled            = true
  shared_access_key_enabled = true

  tags = {
    environment = "dev"
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "raw-fs" {
  name               = var.raw_container_name
  storage_account_id = azurerm_storage_account.proj-sa.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "secondary-fs" {
  name               = var.second_level_container_name
  storage_account_id = azurerm_storage_account.proj-sa.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "third-fs" {
  name               = var.third_level_container_name
  storage_account_id = azurerm_storage_account.proj-sa.id
}

resource "azurerm_storage_data_lake_gen2_path" "proj-folders" {
  for_each = { for i, v in var.pg_tables : i => v }

  path               = each.value.folder
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.raw-fs.name
  storage_account_id = azurerm_storage_account.proj-sa.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "proj-pq-folder" {
  path               = var.parquet_files.folder_name
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.raw-fs.name
  storage_account_id = azurerm_storage_account.proj-sa.id
  resource           = "directory"
}