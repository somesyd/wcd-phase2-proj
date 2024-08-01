variable "prefix" {
  description = "Project prefix for resource naming"
}

variable "resource_group_name" {
  description = "Project resource group name"
}

variable "depends_on_resource_group" {
  description = "Dependency value to force resource group creation"
}

variable "storage_account_name" {
  description = "Project storage account name"
}

variable "depends_on_storage_account" {
  description = "Dependency value to force storage account creation"
}

variable "storage_container_name" {
  description = "Container name for Data Lake blob storage"
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