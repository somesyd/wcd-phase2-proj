variable "prefix" {
  description = "Project name prefix"
}

variable "resource_group_name" {
  description = "Project resource group name"
}

variable "depends_on_resource_group" {
  description = "Dependency value to force resource group creation"
}

variable "layer1_storage_container" {
  description = "Storage container name for raw files"
}

variable "folders" {
  description = "List of folder names for Data Lake container"
  type        = set(string)
  default     = ["business", "checkin", "tip", "user"]
}

variable "pg_tables" {
  description = "List of Postgres dataset tables"
  type = list(object({
    table  = string
    folder = string
  }))
}

variable "parquet_files" {
  description = "Config for parquet dataset files"
  type = object({
    folder_name = string
  })
}