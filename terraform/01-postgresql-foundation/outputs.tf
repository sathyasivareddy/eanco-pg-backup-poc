# =============================================================================
# STATE 1 outputs — non-sensitive only. These are the explicit inputs for STATE 2.
# =============================================================================

output "resource_group_name" {
  description = "Existing resource group name (reused)."
  value       = data.azurerm_resource_group.existing.name
}

output "location" {
  description = "Deployment region."
  value       = local.location
}

output "postgresql_server_id" {
  description = "PostgreSQL Flexible Server resource ID."
  value       = module.postgresql.server_id
}

output "postgresql_server_fqdn" {
  description = "PostgreSQL Flexible Server FQDN (no credentials)."
  value       = module.postgresql.server_fqdn
}

output "postgresql_database_name" {
  description = "POC database name."
  value       = module.postgresql.database_name
}

output "postgresql_admin_username" {
  description = "PostgreSQL administrator login name (non-secret)."
  value       = var.postgresql_admin_username
}

output "virtual_network_id" {
  description = "Virtual network resource ID."
  value       = module.network.virtual_network_id
}

output "postgresql_subnet_id" {
  description = "PostgreSQL delegated subnet resource ID."
  value       = module.network.postgresql_subnet_id
}

output "container_apps_subnet_id" {
  description = "Container Apps infrastructure subnet resource ID."
  value       = module.network.container_apps_subnet_id
}

output "postgresql_private_dns_zone_id" {
  description = "PostgreSQL private DNS zone resource ID."
  value       = module.private_dns.private_dns_zone_id
}
