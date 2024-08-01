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

resource "azurerm_storage_account" "this" {
  name                      = replace("${var.prefix}storage", "-", "")
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

resource "azurerm_role_assignment" "deployer" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_path" "proj-folders" {
  for_each = { for i, v in var.pg_tables : i => v }

  path               = each.value.folder
  filesystem_name    = var.layer1_storage_container
  storage_account_id = azurerm_storage_account.this.id
  resource           = "directory"
}

# add empty csv files to folders
resource "azurerm_storage_blob" "placeholder-files" {
  for_each = { for i, v in var.pg_tables : i => v }

  name                   = "${each.value.folder}/${each.value.folder}_csv_file"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = var.layer1_storage_container
  type                   = "Block"
  source                 = "file_uploads/${each.value.folder}.csv"

  lifecycle {
    ignore_changes = [
      content_md5
    ]
  }

  depends_on = [
    azurerm_storage_data_lake_gen2_path.proj-folders
  ]
}

resource "azurerm_storage_data_lake_gen2_path" "proj-pq-folder" {
  path               = var.parquet_files.folder_name
  filesystem_name    = var.layer1_storage_container
  storage_account_id = azurerm_storage_account.this.id
  resource           = "directory"
}