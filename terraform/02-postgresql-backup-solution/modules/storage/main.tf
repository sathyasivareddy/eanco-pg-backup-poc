terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.replication_type

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # shared-key disabled; use Azure AD
  public_network_access_enabled   = var.create_private_endpoint ? false : true
  infrastructure_encryption_enabled = var.enable_infrastructure_encryption

  blob_properties {
    versioning_enabled = var.enable_blob_versioning

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }
    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "backups" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Immutability (WORM) policy — optional.
resource "azurerm_storage_container_immutability_policy" "backups" {
  count                                 = var.enable_immutability ? 1 : 0
  storage_container_resource_manager_id = azurerm_storage_container.backups.resource_manager_id
  immutability_period_in_days           = var.immutability_period_days
  protected_append_writes_all_enabled   = false
}

# Lifecycle management policy — tiering + deletion driven by variables.
resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "backup-lifecycle"
    enabled = true

    filters {
      prefix_match = [var.container_name]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.tier_to_cool_days
        tier_to_cold_after_days_since_modification_greater_than    = var.tier_to_cold_days
        tier_to_archive_after_days_since_modification_greater_than = var.tier_to_archive_days
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }
    }
  }
}

resource "azurerm_private_endpoint" "blob" {
  count               = var.create_private_endpoint ? 1 : 0
  name                = "${var.name}-blob-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != null ? [1] : []
    content {
      name                 = "blob-dns"
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}

resource "azurerm_management_lock" "storage" {
  count      = var.enable_resource_locks ? 1 : 0
  name       = "${var.name}-lock"
  scope      = azurerm_storage_account.this.id
  lock_level = "CanNotDelete"
  notes      = "Protected: backup storage."
}
