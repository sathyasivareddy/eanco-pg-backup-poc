# PostgreSQL Flexible Server module: private-access server + POC database.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  # authentication block: password and/or Entra.
  password_auth = var.password_auth_enabled
  entra_auth    = var.entra_auth_enabled
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.postgresql_version

  sku_name   = var.sku_name
  storage_mb = var.storage_mb
  # storage_tier is optional; only set when provided.
  storage_tier = var.storage_tier

  # Private access (VNet integration). Public network access disabled implicitly
  # when delegated_subnet_id + private_dns_zone_id are set.
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  # Administrator credentials only when password auth is enabled.
  administrator_login    = local.password_auth ? var.administrator_login : null
  administrator_password = local.password_auth ? var.administrator_password : null

  authentication {
    password_auth_enabled         = var.password_auth_enabled
    active_directory_auth_enabled = var.entra_auth_enabled
    tenant_id                     = var.entra_auth_enabled ? var.entra_tenant_id : null
  }

  dynamic "high_availability" {
    for_each = var.high_availability_enabled ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.password_auth_enabled || var.entra_auth_enabled
      error_message = "At least one authentication method (password or Entra) must be enabled."
    }
    precondition {
      condition     = !var.password_auth_enabled || var.administrator_password != null
      error_message = "administrator_password is required when password_auth_enabled = true (Option A). Supply via TF_VAR_postgresql_admin_password sourced from Key Vault, or use Entra auth."
    }
    # Prevent accidental credential rotation triggering replacement noise.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "entra" {
  count               = var.entra_auth_enabled && var.entra_admin_object_id != null ? 1 : 0
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.entra_tenant_id
  object_id           = var.entra_admin_object_id
  principal_name      = var.entra_admin_principal_name
  principal_type      = "User"
}

resource "azurerm_postgresql_flexible_server_database" "poc" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = var.database_charset
  collation = var.database_collation

  lifecycle {
    prevent_destroy = false
  }
}

# Enforce TLS on the server.
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "ON"
}

resource "azurerm_monitor_diagnostic_setting" "pg" {
  count                      = var.enable_diagnostics && var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "${var.server_name}-diag"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }
  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_management_lock" "pg" {
  count      = var.enable_resource_locks ? 1 : 0
  name       = "${var.server_name}-lock"
  scope      = azurerm_postgresql_flexible_server.this.id
  lock_level = "CanNotDelete"
  notes      = "Protected: managed by Terraform state 01-postgresql-foundation."
}
