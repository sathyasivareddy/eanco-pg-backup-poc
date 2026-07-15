output "storage_account_id" {
  description = "Storage account resource ID."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint (no credentials)."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "backup_container_name" {
  description = "Backup container name."
  value       = azurerm_storage_container.backups.name
}

output "backup_container_resource_manager_id" {
  description = "Container ARM resource ID for RBAC scoping."
  value       = azurerm_storage_container.backups.resource_manager_id
}
