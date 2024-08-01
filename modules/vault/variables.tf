variable "prefix" {
  description = "Prefix for naming project resources"
}

variable "external_key_vault_resource_group" {
  description = "Name of resource group for external key vault"
}

variable "external_key_vault_name" {
  description = "Name of the external key vault"
}

variable "resource_group_name" {
  description = "Project resource group name"
}

variable "depends_on_resource_group" {
  description = "Dependency value to force resource group creation"
}