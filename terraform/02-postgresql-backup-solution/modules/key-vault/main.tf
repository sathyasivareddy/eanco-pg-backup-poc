terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  enable_rbac_authorization     = true # RBAC data-plane, no access policies
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = var.create_private_endpoint ? false : true

  network_acls {
    bypass         = "AzureServices"
    default_action = var.create_private_endpoint ? "Deny" : "Allow"
  }

  tags = var.tags
}

# Terraform manages the SECRET NAME reference only (no value). The real secret
# value is created out-of-band by an authorized DBA/operator. We do not create
# azurerm_key_vault_secret with a value here to avoid persisting it in state.

resource "azurerm_private_endpoint" "kv" {
  count               = var.create_private_endpoint ? 1 : 0
  name                = "${var.name}-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-psc"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != null ? [1] : []
    content {
      name                 = "kv-dns"
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}

resource "azurerm_management_lock" "kv" {
  count      = var.enable_resource_locks ? 1 : 0
  name       = "${var.name}-lock"
  scope      = azurerm_key_vault.this.id
  lock_level = "CanNotDelete"
  notes      = "Protected: backup Key Vault."
}
