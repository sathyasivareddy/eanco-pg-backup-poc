# =============================================================================
# STATE 1 variables — PostgreSQL foundation (network + database).
# Every environment-dependent value is a variable. Example values live in
# terraform.tfvars.example and are placeholders to override.
# =============================================================================

# ---- Azure subscription / tenant ----
variable "subscription_id" {
  description = "Azure Subscription ID. Prefer supplying via ARM_SUBSCRIPTION_ID env var; leave null to use ambient auth."
  type        = string
  default     = null
  nullable    = true
}

variable "tenant_id" {
  description = "Azure Tenant ID. Prefer supplying via ARM_TENANT_ID env var; leave null to use ambient auth."
  type        = string
  default     = null
  nullable    = true
}

# ---- Existing Resource Group (reused, never created) ----
variable "resource_group_name" {
  description = "Name of the EXISTING resource group to reuse (read-only)."
  type        = string
  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "location" {
  description = "Azure region for new resources. Defaults to the existing RG location when null."
  type        = string
  default     = null
  nullable    = true
}

# ---- Naming / environment / tags ----
variable "environment" {
  description = "Environment name (e.g. dev, poc)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.environment))
    error_message = "environment must be 2-12 lowercase alphanumeric characters."
  }
}

variable "naming_prefix" {
  description = "Naming prefix per WinWire convention, e.g. 'ww-eanco'."
  type        = string
  default     = "ww-eanco"
}

variable "project_identifier" {
  description = "Application/project identifier tag value."
  type        = string
  default     = "eanco-pgbackup"
}

variable "owner" {
  description = "Resource owner (email/team) for the owner tag."
  type        = string
}

variable "cost_center" {
  description = "Cost centre for billing allocation."
  type        = string
}

variable "poc_expiry_date" {
  description = "POC expiry date (YYYY-MM-DD) for governance/cleanup."
  type        = string
  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.poc_expiry_date))
    error_message = "poc_expiry_date must be in YYYY-MM-DD format."
  }
}

variable "additional_tags" {
  description = "Additional tags merged onto the mandatory tag set."
  type        = map(string)
  default     = {}
}

variable "enable_resource_locks" {
  description = "Apply a CanNotDelete lock to protectable resources (recommended for production)."
  type        = bool
  default     = false
}

# ---- Feature flags: create vs reuse ----
variable "create_virtual_network" {
  description = "Create a new VNet (true) or reuse an existing one via existing_virtual_network_id (false)."
  type        = bool
  default     = true
  validation {
    # Enforce exactly one of: create new VNet OR supply an existing VNet ID.
    condition     = (var.create_virtual_network ? 1 : 0) + (var.existing_virtual_network_id != null ? 1 : 0) == 1
    error_message = "Set exactly one of create_virtual_network = true OR existing_virtual_network_id = <resource id>."
  }
}

variable "create_postgresql_subnet" {
  description = "Create the PostgreSQL delegated subnet."
  type        = bool
  default     = true
}

variable "create_container_apps_subnet" {
  description = "Create the Container Apps infrastructure subnet."
  type        = bool
  default     = true
}

variable "create_private_dns_zone" {
  description = "Create the PostgreSQL private DNS zone (false to reuse existing_private_dns_zone_id)."
  type        = bool
  default     = true
}

variable "create_private_dns_vnet_link" {
  description = "Create the private DNS VNet link."
  type        = bool
  default     = true
}

# ---- Existing resource IDs (used when create_* flags are false) ----
variable "existing_virtual_network_id" {
  description = "Resource ID of an approved existing VNet (required when create_virtual_network = false)."
  type        = string
  default     = null
  nullable    = true
}

variable "existing_private_dns_zone_id" {
  description = "Resource ID of an existing PostgreSQL private DNS zone (when create_private_dns_zone = false)."
  type        = string
  default     = null
  nullable    = true
}

# ---- Networking ----
variable "virtual_network_name" {
  description = "Override name for the VNet. Null uses the derived name."
  type        = string
  default     = null
  nullable    = true
}

variable "vnet_address_space" {
  description = "Approved VNet address space (Network-team confirmed, non-overlapping)."
  type        = list(string)
  default     = ["10.59.0.0/22"]
  validation {
    condition     = length(var.vnet_address_space) > 0
    error_message = "vnet_address_space must contain at least one CIDR."
  }
}

variable "postgresql_subnet_name" {
  description = "Name of the PostgreSQL delegated subnet."
  type        = string
  default     = "snet-postgresql"
}

variable "postgresql_subnet_cidr" {
  description = "CIDR for the PostgreSQL delegated subnet (dedicated, delegated to flexibleServers)."
  type        = string
  default     = "10.59.0.0/24"
  validation {
    condition     = can(cidrhost(var.postgresql_subnet_cidr, 0))
    error_message = "postgresql_subnet_cidr must be a valid CIDR."
  }
}

variable "container_apps_subnet_name" {
  description = "Name of the Container Apps infrastructure subnet (dedicated)."
  type        = string
  default     = "snet-containerapps"
}

variable "container_apps_subnet_cidr" {
  description = "CIDR for the Container Apps subnet (/27 or larger; /24 approved for this POC)."
  type        = string
  default     = "10.59.1.0/24"
  validation {
    condition     = can(cidrhost(var.container_apps_subnet_cidr, 0))
    error_message = "container_apps_subnet_cidr must be a valid CIDR."
  }
}

variable "postgresql_subnet_nsg_id" {
  description = "Optional NSG resource ID to associate with the PostgreSQL subnet."
  type        = string
  default     = null
  nullable    = true
}

variable "container_apps_subnet_nsg_id" {
  description = "Optional NSG resource ID to associate with the Container Apps subnet."
  type        = string
  default     = null
  nullable    = true
}

# ---- Private DNS ----
variable "postgresql_private_dns_zone_name" {
  description = "Private DNS zone name for PostgreSQL Flexible Server."
  type        = string
  default     = "privatelink.postgres.database.azure.com"
}

# ---- PostgreSQL ----
variable "postgresql_server_name" {
  description = "Override name for the PostgreSQL server. Null uses derived name."
  type        = string
  default     = null
  nullable    = true
}

variable "postgresql_version" {
  description = "PostgreSQL major version approved for the POC."
  type        = string
  default     = "16"
}

variable "postgresql_sku_name" {
  description = "Flexible Server SKU (e.g. B_Standard_B1ms for Burstable POC)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB (32768 = 32 GiB)."
  type        = number
  default     = 32768
}

variable "postgresql_storage_tier" {
  description = "Storage performance tier. Null lets Azure pick the default for the size."
  type        = string
  default     = null
  nullable    = true
}

variable "postgresql_backup_retention_days" {
  description = "Native automated backup retention in days."
  type        = number
  default     = 7
  validation {
    condition     = var.postgresql_backup_retention_days >= 7 && var.postgresql_backup_retention_days <= 35
    error_message = "postgresql_backup_retention_days must be between 7 and 35."
  }
}

variable "postgresql_geo_redundant_backup" {
  description = "Enable geo-redundant native backups (disabled for POC)."
  type        = bool
  default     = false
}

variable "postgresql_high_availability" {
  description = "Enable zone-redundant HA (disabled for POC)."
  type        = bool
  default     = false
}

variable "postgresql_admin_username" {
  description = "PostgreSQL administrator login name."
  type        = string
  default     = "eanco_pgadmin"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{2,62}$", var.postgresql_admin_username))
    error_message = "postgresql_admin_username must be a valid PostgreSQL role name."
  }
}

variable "postgresql_admin_password" {
  description = <<-EOT
    PostgreSQL administrator password (OPTION A only). Leave null to avoid storing
    the password in Terraform state. If set, it WILL be persisted in state even
    when marked sensitive. Prefer supplying via TF_VAR_postgresql_admin_password
    env var sourced from Key Vault at plan/apply time, or use Entra auth (Option B).
  EOT
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "postgresql_entra_admin_enabled" {
  description = "Enable Microsoft Entra authentication for PostgreSQL (Option B)."
  type        = bool
  default     = false
}

variable "postgresql_password_auth_enabled" {
  description = "Enable PostgreSQL password authentication."
  type        = bool
  default     = true
}

variable "postgresql_entra_admin_object_id" {
  description = "Object ID of the Entra admin principal (required when postgresql_entra_admin_enabled = true)."
  type        = string
  default     = null
  nullable    = true
}

variable "postgresql_entra_admin_principal_name" {
  description = "Display/UPN of the Entra admin principal."
  type        = string
  default     = null
  nullable    = true
}

variable "database_name" {
  description = "Name of the POC database."
  type        = string
  default     = "eanco_backup_demo"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must be a valid PostgreSQL identifier."
  }
}

variable "database_charset" {
  description = "Database character set."
  type        = string
  default     = "UTF8"
}

variable "database_collation" {
  description = "Database collation."
  type        = string
  default     = "en_US.utf8"
}

variable "postgresql_maintenance_window" {
  description = "Maintenance window (day_of_week 0-6, start_hour, start_minute). Null for system-managed."
  type = object({
    day_of_week  = number
    start_hour   = number
    start_minute = number
  })
  default = null
  nullable = true
}

variable "enable_postgresql_diagnostics" {
  description = "Send PostgreSQL diagnostics to a Log Analytics workspace (only if required)."
  type        = bool
  default     = false
}

variable "diagnostics_log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for PostgreSQL diagnostics (required if enable_postgresql_diagnostics = true)."
  type        = string
  default     = null
  nullable    = true
}
