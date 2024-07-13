output "synapse_storage_container_name" {
  description = "Name of the root storage for Synapse data"
  value       = azurerm_storage_data_lake_gen2_filesystem.this.name
}