terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.109.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.51.0"
    }
    azapi = {
      source = "Azure/azapi"
      version = "1.13.1"
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
  name                      = "phase2projectstorage"
  resource_group_name       = azurerm_resource_group.proj-rg.name
  location                  = azurerm_resource_group.proj-rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  is_hns_enabled            = true
  shared_access_key_enabled = true

  tags = {
    environment = "dev"
  }
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}


resource "azurerm_storage_data_lake_gen2_filesystem" "proj-fs" {
  name               = var.my_blob_container
  storage_account_id = azurerm_storage_account.proj-sa.id
}

resource "azurerm_storage_data_lake_gen2_path" "proj-folders" {
  for_each = { for i, v in var.pg_tables : i => v }

  path               = each.value.folder
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.proj-fs.name
  storage_account_id = azurerm_storage_account.proj-sa.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "proj-pq-folder" {
  path               = var.parquet_files.folder_name
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.proj-fs.name
  storage_account_id = azurerm_storage_account.proj-sa.id
  resource           = "directory"
}

resource "azurerm_data_factory" "proj-adf" {
  name                = "phase2-project-adf"
  location            = azurerm_resource_group.proj-rg.location
  resource_group_name = azurerm_resource_group.proj-rg.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "adf_blob_contributor" {
  principal_id         = azurerm_data_factory.proj-adf.identity[0].principal_id
  scope                = azurerm_storage_account.proj-sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_type       = "ServicePrincipal"
}

resource "azurerm_databricks_workspace" "proj-db-ws" {
  name                = "phase2-project-db"
  resource_group_name = azurerm_resource_group.proj-rg.name
  location            = azurerm_resource_group.proj-rg.location
  sku                 = "standard"
}

resource "azurerm_databricks_access_connector" "proj-db-ac" {
  name                = "databricks-access-connector"
  resource_group_name = azurerm_resource_group.proj-rg.name
  location            = azurerm_resource_group.proj-rg.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "databricks-blob-contributor" {
  scope                = azurerm_storage_account.proj-sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.proj-db-ac.identity[0].principal_id
}

# ********** RDS-POSTGRES-LINKED-SERVICE ****************************
resource "azapi_resource" "rds-postgres-ls" {
  type = "Microsoft.DataFactory/factories/linkedservices@2018-06-01"
  parent_id = azurerm_data_factory.proj-adf.id
  name = "ls_rds_pg"
  body = {
    properties = {
      type = "PostgreSqlV2"
      typeProperties = {
        server = var.pg_host_name
        port = 5432
        database = var.pg_database_name
        username = module.vault.pg_username
        password =  {
          type = "SecureString"
          value = module.vault.pg_password
        }
        authenticationType = "Basic"
      }
    }
  }
  schema_validation_enabled = false
  response_export_values    = ["*"]
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "wcd-blob-storage-ls" {
  name              = "ls_wcd_blob"
  data_factory_id   = azurerm_data_factory.proj-adf.id
  connection_string = "DefaultEndpointsProtocol=https;BlobEndpoint=https://${module.vault.wcd_blob_storage_account}.blob.core.windows.net;AccountName=${module.vault.wcd_blob_storage_account};AccountKey=${module.vault.wcd_blob_storage_key}"
}

resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "my-data-lake-storage-ls" {
  name                 = "ls_my_data_lake"
  data_factory_id      = azurerm_data_factory.proj-adf.id
  url                  = azurerm_storage_account.proj-sa.primary_dfs_endpoint
  use_managed_identity = true
}

resource "azapi_resource" "proj_pg_dataset" {
  for_each = { for i, v in var.pg_tables : i => v }
  type      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name = "ds_pg_${each.value.table}"
  parent_id = azurerm_data_factory.proj-adf.id
  body = {
    properties = {
      type = "PostgreSqlV2Table"
      linkedServiceName = {
        referenceName = "ls_rds_pg"
        type = "LinkedServiceReference"
      }
      typeProperties = {
        schema = var.pg_schema
        table = each.value.table
      }
    }
  }
  depends_on = [ azapi_resource.rds-postgres-ls ]
}

resource "azurerm_data_factory_dataset_delimited_text" "proj_my_blob_dataset" {
  for_each            = { for i, v in var.pg_tables : i => v }
  name                = "ds_my_data_lake_${each.value.folder}"
  data_factory_id     = azurerm_data_factory.proj-adf.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.my-data-lake-storage-ls.name

  azure_blob_storage_location {
    container = azurerm_storage_data_lake_gen2_filesystem.proj-fs.name
    path      = each.value.folder
    filename  = "${each.value.folder}.csv"
  }

  column_delimiter    = ","
  row_delimiter       = "\n"
  first_row_as_header = true
}

resource "azurerm_data_factory_dataset_parquet" "proj_wcd_blob_dataset" {
  name                = "ds_wcd_blob_pq"
  data_factory_id     = azurerm_data_factory.proj-adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.wcd-blob-storage-ls.name
  compression_codec   = "snappy"

  azure_blob_storage_location {
    container = var.wcd_blob_container
    path      = var.wcd_blob_folder
  }
}

resource "azurerm_data_factory_dataset_parquet" "proj_my_blob_pq_dataset" {
  name                = "ds_my_data_lake_pq"
  data_factory_id     = azurerm_data_factory.proj-adf.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.my-data-lake-storage-ls.name
  compression_codec   = "snappy"

  azure_blob_storage_location {
    container = var.my_blob_container
    path      = var.parquet_files.folder_name
  }

}


#********* COPY-ONCE-A-WEEK PIPELINE ACTIVITIES **************
locals {
  create_dependency1 = azurerm_data_factory_dataset_delimited_text.proj_my_blob_dataset
  create_dependency2 = azapi_resource.proj_pg_dataset

  weekly_copy_activities = [
    for tbl in var.pg_tables : {  
      name = "copy_${tbl.table}"
      type = "Copy"
      dependsOn = [
        {
          activity = "delete_${tbl.folder}_files"
          dependencyConditions = ["Succeeded"]
        }
      ]
      inputs = [
        {
          referenceName = "ds_pg_${tbl.table}"
          type = "DatasetReference"
        }
      ]
      outputs = [
        {
          referenceName = "ds_my_data_lake_${tbl.folder}"
          type = "DatasetReference"
        }
      ]
      typeProperties = {
        source = {
          type = "PostgreSqlV2Source"
          query = "SELECT * FROM ${var.pg_schema}.${tbl.table}"
          linkedServiceName = azapi_resource.rds-postgres-ls.name
        }
        sink = {
          type = "DelimitedTextSink"
          writeBehavior = "overwrite"
          linkedServiceName = azurerm_data_factory_linked_service_data_lake_storage_gen2.my-data-lake-storage-ls.name
        }
      }
    }
  ]

  weekly_delete_activities = [
      for tbl in var.pg_tables : {
      name = "delete_${tbl.folder}_files"
      type = "Delete"
      typeProperties = {
        dataset = {
          referenceName = "ds_my_data_lake_${tbl.folder}"
          type = "DatasetReference"
        }
        enableLogging = false
      }
    }
  ]
}

# ********* COPY-ONCE-A-WEEK PIPELINE **************
resource "azapi_resource" "pipeline" {
  type      = "Microsoft.DataFactory/factories/pipelines@2018-06-01"
  parent_id = azurerm_data_factory.proj-adf.id
  name      = "copyOnceWeek"
  body = {
    properties = {
      activities = concat(local.weekly_copy_activities, local.weekly_delete_activities)
    }
  }
  schema_validation_enabled = false
  response_export_values    = ["*"]

   depends_on = [ 
    azapi_resource.rds-postgres-ls,
    azapi_resource.proj_pg_dataset
    ]
}

# ********* COPY-DAILY PIPELINE ACTIVITIES **************
locals {
  daily_activities = [
    {
      name = "copy_${replace(var.wcd_blob_container, "-", "_")}"
      type = "Copy"
      dependsOn = [
        {
          activity             = "delete_${var.parquet_files.folder_name}_files"
          dependencyConditions = ["Succeeded"]
        }
      ]
      inputs = [
        {
          referenceName = azurerm_data_factory_dataset_parquet.proj_wcd_blob_dataset.name
          type          = "DatasetReference"
        }
      ]
      outputs = [
        {
          referenceName = azurerm_data_factory_dataset_parquet.proj_my_blob_pq_dataset.name
          type          = "DatasetReference"
        }
      ]
      typeProperties = {
        source = {
          type = "ParquetSource"
          storeSettings = {
            type               = "AzureBlobStorageReadSettings",
            recursive          = true,
            wildcardFolderPath = var.wcd_blob_folder,
            wildcardFileName   = "*.parquet"
          }
        }
        sink = {
          type = "ParquetSink"
        }
      }
    },
    {
      name = "delete_${var.parquet_files.folder_name}_files"
      type = "Delete"
      typeProperties = {
        dataset = {
          referenceName = azurerm_data_factory_dataset_parquet.proj_my_blob_pq_dataset.name
          type          = "DatasetReference"
        }
        enableLogging = false
      }
    }
  ]
}

# ******** COPY-DAILY PIPELINE *************
resource "azurerm_data_factory_pipeline" "proj-pl-daily" {
  name            = "copyDaily"
  data_factory_id = azurerm_data_factory.proj-adf.id

  activities_json = jsonencode(local.daily_activities)
}