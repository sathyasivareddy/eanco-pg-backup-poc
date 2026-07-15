# Private DNS module for PostgreSQL Flexible Server: zone (create/reuse) + VNet link.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  zone_id   = var.create_private_dns_zone ? azurerm_private_dns_zone.this[0].id : var.existing_private_dns_zone_id
  zone_name = var.create_private_dns_zone ? azurerm_private_dns_zone.this[0].name : var.dns_zone_name
  # When reusing an existing zone, link is created in that zone's RG.
  zone_rg = var.create_private_dns_zone ? var.resource_group_name : element(split("/", var.existing_private_dns_zone_id), 4)
}

resource "azurerm_private_dns_zone" "this" {
  count               = var.create_private_dns_zone ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count                 = var.create_vnet_link ? 1 : 0
  name                  = var.dns_link_name
  resource_group_name   = local.zone_rg
  private_dns_zone_name = local.zone_name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}
