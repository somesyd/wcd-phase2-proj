variable "pg_schema" {
  description = "Schema name for Postgres dataset"
  type        = string
  default     = "project"
}

variable "pg_tables" {
  description = "List of Postgres dataset tables"
  type = list(object({
    table  = string
    folder = string
  }))
  default = [
    { table = "businesses", folder = "business" },
    { table = "checkin", folder = "checkin" },
    { table = "tip", folder = "tip" },
    { table = "users", folder = "user" }
  ]
}

variable "pg_host_name" {
  description = "Host name for Postgres source"
  type        = string
}

variable "pg_database_name" {
  description = "Postgres source database name"
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
  default = {
    folder_name    = "review",
    file_extension = ".parquet"
  }
}

variable "external_key_vault_resource_group" {
  description = "Name of resource group for external key vault"
}

variable "external_key_vault_name" {
  description = "Name of the external key vault"
}

variable "my_azure_login_name" {
  description = "Azure login name (probably email address)"
}
