locals {
  # Canonical naming: ww-eanco-<env>-<type>
  name_prefix = "${var.naming_prefix}-${var.environment}"

  # Location comes from the existing RG unless explicitly overridden.
  location = coalesce(var.location, data.azurerm_resource_group.existing.location)

  # Mandatory tags merged with any caller-provided tags. Environment-specific.
  base_tags = {
    environment = var.environment
    owner       = var.owner
    costCenter  = var.cost_center
    project     = var.project_identifier
    expiryDate  = var.poc_expiry_date
    managedBy   = "terraform"
    stateRoot   = "01-postgresql-foundation"
  }
  tags = merge(local.base_tags, var.additional_tags)

  # Derived resource names (override individually via variables if needed).
  vnet_name        = coalesce(var.virtual_network_name, "${local.name_prefix}-vnet")
  pg_server_name   = coalesce(var.postgresql_server_name, "${local.name_prefix}-pg")
  dns_zone_name    = var.postgresql_private_dns_zone_name
  dns_link_name    = "${local.name_prefix}-pg-dnslink"
}
