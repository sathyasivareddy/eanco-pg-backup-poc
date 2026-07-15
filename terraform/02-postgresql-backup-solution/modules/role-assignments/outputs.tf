output "acr_pull_role_assignment_id" {
  description = "AcrPull role assignment ID."
  value       = azurerm_role_assignment.acr_pull.id
}

output "kv_secrets_user_role_assignment_id" {
  description = "Key Vault Secrets User role assignment ID."
  value       = azurerm_role_assignment.kv_secrets_user.id
}

output "blob_contributor_role_assignment_id" {
  description = "Storage Blob Data Contributor role assignment ID."
  value       = azurerm_role_assignment.blob_contributor.id
}
