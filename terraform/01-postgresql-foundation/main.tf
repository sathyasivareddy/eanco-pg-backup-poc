# =============================================================================
# STATE 1 root — wires network, private DNS and PostgreSQL modules.
# Guardrail for "create vs reuse VNet" is enforced by variable validation on
# create_virtual_network in variables.tf (exactly one of create/reuse).
# =============================================================================

module "network" {
  source = "./modules/network"

  create_virtual_network      = var.create_virtual_network
  existing_virtual_network_id = var.existing_virtual_network_id

  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  vnet_name           = local.vnet_name
  vnet_address_space  = var.vnet_address_space

  create_postgresql_subnet     = var.create_postgresql_subnet
  postgresql_subnet_name       = var.postgresql_subnet_name
  postgresql_subnet_cidr       = var.postgresql_subnet_cidr
  postgresql_subnet_nsg_id     = var.postgresql_subnet_nsg_id

  create_container_apps_subnet = var.create_container_apps_subnet
  container_apps_subnet_name   = var.container_apps_subnet_name
  container_apps_subnet_cidr   = var.container_apps_subnet_cidr
  container_apps_subnet_nsg_id = var.container_apps_subnet_nsg_id

  enable_resource_locks = var.enable_resource_locks
  tags                  = local.tags
}

module "private_dns" {
  source = "./modules/private-dns"

  create_private_dns_zone      = var.create_private_dns_zone
  existing_private_dns_zone_id = var.existing_private_dns_zone_id
  create_vnet_link             = var.create_private_dns_vnet_link

  resource_group_name = data.azurerm_resource_group.existing.name
  dns_zone_name       = var.postgresql_private_dns_zone_name
  dns_link_name       = local.dns_link_name
  virtual_network_id  = module.network.virtual_network_id

  tags = local.tags
}

module "postgresql" {
  source = "./modules/postgresql"

  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  server_name         = local.pg_server_name

  postgresql_version              = var.postgresql_version
  sku_name                        = var.postgresql_sku_name
  storage_mb                      = var.postgresql_storage_mb
  storage_tier                    = var.postgresql_storage_tier
  backup_retention_days           = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled    = var.postgresql_geo_redundant_backup
  high_availability_enabled       = var.postgresql_high_availability

  delegated_subnet_id  = module.network.postgresql_subnet_id
  private_dns_zone_id  = module.private_dns.private_dns_zone_id

  administrator_login          = var.postgresql_admin_username
  administrator_password       = var.postgresql_admin_password
  password_auth_enabled        = var.postgresql_password_auth_enabled
  entra_auth_enabled           = var.postgresql_entra_admin_enabled
  entra_admin_object_id        = var.postgresql_entra_admin_object_id
  entra_admin_principal_name   = var.postgresql_entra_admin_principal_name

  database_name      = var.database_name
  database_charset   = var.database_charset
  database_collation = var.database_collation

  maintenance_window = var.postgresql_maintenance_window

  enable_diagnostics             = var.enable_postgresql_diagnostics
  log_analytics_workspace_id     = var.diagnostics_log_analytics_workspace_id

  enable_resource_locks = var.enable_resource_locks
  tags                  = local.tags

  depends_on = [module.private_dns]
}
