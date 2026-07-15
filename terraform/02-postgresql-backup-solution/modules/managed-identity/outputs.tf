output "id" {
  description = "UAMI resource ID."
  value       = azurerm_user_assigned_identity.this.id
}

output "principal_id" {
  description = "UAMI principal (object) ID."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "UAMI client ID."
  value       = azurerm_user_assigned_identity.this.client_id
}
