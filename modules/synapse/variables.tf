variable "resource_group_name" {
  description = "Project resource group name"
}

variable "data_lake_container" {
  description = "Storage container id for gold/layer3 storage"
}

variable "internal_key_vault_name" {
  description = "Name of project's internal key vault"
}

variable "depends_on_internal_vault" {
  description = "Internal vault id must be create before resource runs"
}

variable "external_key_vault_resource_group" {
  description = "Name of the resource group for external key vault"
}

variable "external_key_vault_name" {
  description = "Name of the external key vault"
}