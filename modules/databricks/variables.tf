variable "subscription_id" {
  description = "The project Azure subscription id"
}

variable "resource_group_name" {
  description = "The project resource group name"
}

variable "databricks_account_id" {
  description = "Azure Databricks account id from Databricks account console"
  type        = string
}

variable "databricks_metastore_id" {
  description = "Azure Databricks metastore id"
  type        = string
}

variable "storage_account_name" {
  description = "The project storage account name"
  type        = string
}

variable "raw_storage_container" {
  description = "The project's raw data storage container name"
  type        = string
}

variable "layer2_storage_container" {
  description = "Project's second layer storage container name"
  type        = string
}

variable "layer3_storage_container" {
  description = "Project's third layer storage container name"
  type        = string
}

variable "meta_storage_container" {
  description = "Storage container name for project catalog"
  type        = string
}

variable "synapse_container" {
  description = "Storage container name for Synapse data"
  type = string
}

# variable "sources_storage_container" {
#   description = "Storage container name for dev tools and sources"
#   type = string
# }

# variable "internal_key_vault_name" {
#   description = "Name for project's internal key vault"
#   type = string
# }

# variable "depends_on_internal_vault" {
#   description = "Internal vault id must be create before resource runs"
# }

variable "my_databricks_id" {
  description = "Azure login name (probably email address)"
  sensitive   = true
}
