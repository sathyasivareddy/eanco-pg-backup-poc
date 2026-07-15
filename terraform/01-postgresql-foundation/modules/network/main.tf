# Network module: VNet (create or reuse), PostgreSQL delegated subnet, Container Apps subnet.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  create_vnet = var.create_virtual_network
  # When reusing, parse the provided VNet id for name/rg to attach subnets.
  reused_vnet_name = local.create_vnet ? null : element(reverse(split("/", var.existing_virtual_network_id)), 0)
  reused_vnet_rg   = local.create_vnet ? null : element(split("/", var.existing_virtual_network_id), 4)

  vnet_id   = local.create_vnet ? azurerm_virtual_network.this[0].id : var.existing_virtual_network_id
  vnet_name = local.create_vnet ? azurerm_virtual_network.this[0].name : local.reused_vnet_name
  vnet_rg   = local.create_vnet ? var.resource_group_name : local.reused_vnet_rg
}

resource "azurerm_virtual_network" "this" {
  count               = local.create_vnet ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# PostgreSQL delegated subnet — dedicated, delegated to flexibleServers.
resource "azurerm_subnet" "postgresql" {
  count                = var.create_postgresql_subnet ? 1 : 0
  name                 = var.postgresql_subnet_name
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.postgresql_subnet_cidr]

  delegation {
    name = "fs-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Container Apps infrastructure subnet — dedicated exclusively to the ACA environment.
resource "azurerm_subnet" "container_apps" {
  count                = var.create_container_apps_subnet ? 1 : 0
  name                 = var.container_apps_subnet_name
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.container_apps_subnet_cidr]
}

resource "azurerm_subnet_network_security_group_association" "postgresql" {
  count                     = var.create_postgresql_subnet && var.postgresql_subnet_nsg_id != null ? 1 : 0
  subnet_id                 = azurerm_subnet.postgresql[0].id
  network_security_group_id = var.postgresql_subnet_nsg_id
}

resource "azurerm_subnet_network_security_group_association" "container_apps" {
  count                     = var.create_container_apps_subnet && var.container_apps_subnet_nsg_id != null ? 1 : 0
  subnet_id                 = azurerm_subnet.container_apps[0].id
  network_security_group_id = var.container_apps_subnet_nsg_id
}

resource "azurerm_management_lock" "vnet" {
  count      = local.create_vnet && var.enable_resource_locks ? 1 : 0
  name       = "${var.vnet_name}-lock"
  scope      = azurerm_virtual_network.this[0].id
  lock_level = "CanNotDelete"
  notes      = "Protected: managed by Terraform state 01-postgresql-foundation."
}
