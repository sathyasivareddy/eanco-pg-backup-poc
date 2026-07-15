# =============================================================================
# STATE 2 outputs — non-sensitive only. No secrets, keys, SAS, or credentials.
# =============================================================================

output "managed_identity_client_id" {
  description = "Runtime UAMI client ID (non-secret)."
  value       = module.managed_identity.client_id
}

output "managed_identity_principal_id" {
  description = "Runtime UAMI principal ID (non-secret)."
  value       = module.managed_identity.principal_id
}

output "acr_login_server" {
  description = "ACR login server."
  value       = local.acr_login_server
}

output "storage_account_name" {
  description = "Backup storage account name."
  value       = local.storage_name_eff
}

output "backup_container_name" {
  description = "Backup blob container name."
  value       = local.storage_container_eff
}

output "container_apps_environment_id" {
  description = "Container Apps Environment resource ID."
  value       = module.container_apps_environment.id
}

output "container_apps_job_name" {
  description = "Container Apps Job name (used for manual runs)."
  value       = module.container_apps_job.name
}

output "container_apps_job_id" {
  description = "Container Apps Job resource ID."
  value       = module.container_apps_job.id
}

output "key_vault_uri" {
  description = "Key Vault URI (no secret values)."
  value       = local.kv_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = local.law_id
}

output "schedule_enabled" {
  description = "Whether the backup cron schedule is enabled."
  value       = var.enable_backup_schedule
}
