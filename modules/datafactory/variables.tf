variable "resource_group_name" {
  description = "Project resource group name"
  type        = string
}

variable "location" {
  description = "Project resource group location"
  type        = string
}

variable "storage_account_id" {
  description = "Project storage account id for Data Lake"
  type        = string
}

variable "storage_account_dfs_endpoint" {
  description = "Project storage account Data Lake endpoint"
  type        = string
}

variable "storage_container_name" {
  description = "Container name for Data Lake blob storage"
  type        = string
}

variable "pg_tables" {
  description = "List of Postgres dataset tables"
  type = list(object({
    table  = string
    folder = string
  }))
}

variable "pg_host_name" {
  description = "Host name for Postgres source"
  type        = string
}

variable "pg_database_name" {
  description = "Postgres source database name"
  type        = string
}

variable "pg_schema" {
  description = "Schema name for Postgres dataset"
  type        = string
}

variable "wcd_blob_container" {
  description = "WCD blob storage container name"
  type        = string
}

variable "wcd_blob_folder" {
  description = "WCD blob storage folder name"
  type        = string
}

variable "parquet_files" {
  description = "Config for parquet dataset files"
  type = object({
    folder_name = string
  })
}

variable "pg_username" {
  description = "User name for Postgres source database"
  type        = string
  sensitive   = true
}

variable "pg_password" {
  description = "Password for Postgres source database access"
  type        = string
  sensitive   = true
}

variable "wcd_blob_storage_account" {
  description = "WCD blob storage account name"
  type        = string
  sensitive   = true
}

variable "wcd_blob_storage_key" {
  description = "WCD blob storage account key"
  type        = string
  sensitive   = true
}