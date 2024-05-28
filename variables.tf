variable "folders" {
  description = "List of folder names for Data Lake container"
  type        = set(string)
  default     = ["business", "checkin", "tip", "user"]
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