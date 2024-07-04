variable "resource_group_name" {
  description = "Project resource group name"
  type        = string
}

variable "raw_container_name" {
  description = "Container name for raw blob storage"
  type        = string
  default     = "bronze"
}

variable "second_level_container_name" {
  description = "Container name for secondary storage"
  type        = string
  default     = "silver"
}

variable "third_level_container_name" {
  description = "Container name for BI level storage"
  type        = string
  default     = "gold"
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