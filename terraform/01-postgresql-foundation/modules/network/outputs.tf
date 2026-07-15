output "virtual_network_id" {
  description = "VNet resource ID."
  value       = local.vnet_id
}

output "virtual_network_name" {
  description = "VNet name."
  value       = local.vnet_name
}

output "postgresql_subnet_id" {
  description = "PostgreSQL delegated subnet resource ID."
  value       = var.create_postgresql_subnet ? azurerm_subnet.postgresql[0].id : null
}

output "container_apps_subnet_id" {
  description = "Container Apps subnet resource ID."
  value       = var.create_container_apps_subnet ? azurerm_subnet.container_apps[0].id : null
}
