variable "prefix" {
  description = "Project prefix for naming resources"
}

variable "subscription_id" {
  description = "The project Azure subscription id"
}

variable "resource_group_name" {
  description = "The project resource group name"
}

variable "depends_on_resource_group" {
  description = "Dependency value to force resource group creation"
}

variable "databricks_account_id" {
  description = "Azure Databricks account id from Databricks account console"
}

variable "storage_account_name" {
  description = "The project storage account name"
}

variable "depends_on_storage_account" {
  description = "Dependency value to force storage account creation"
}

variable "medallion" {
  description = "The medallion layer name assignments for the project"
  default = {
    root = {
      container_name    = "meta"
      external_loc_name = "meta"
      catalog_name      = "unity_catalog"
    }
    layer1 = {
      container_name    = "bronze"
      external_loc_name = "bronze_layer"
      schema_name       = "bronze"
    }
    layer2 = {
      container_name    = "silver"
      external_loc_name = "silver_layer"
      schema_name       = "silver"
    }
    layer3 = {
      container_name    = "gold"
      external_loc_name = "gold_layer"
      schema_name       = "gold"
    }
  }
}

variable "volume" {
  description = "Naming assignments for Databricks volumes"
  default = {
    source = {
      container_name      = "sources"
      external_loc_name   = "sources"
      schema_name         = "sources"
      landing_folder_name = "landing"
    }
    synapse = {
      external_loc_name   = "synapse"
      schema_name         = "synapse"
      landing_folder_name = "data"
    }

  }
}

variable "group_name" {
  description = "Databricks group name for high level admin"
  default     = "Data Engineering"
}

variable "synapse_container" {
  description = "Storage container name for Synapse data"
  type        = string
}

variable "my_databricks_id" {
  description = "Azure login name (probably email address)"
  sensitive   = true
}
