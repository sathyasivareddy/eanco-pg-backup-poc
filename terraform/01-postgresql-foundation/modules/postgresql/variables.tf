variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "server_name" {
  type        = string
  description = "PostgreSQL server name."
}

variable "postgresql_version" {
  type        = string
  description = "PostgreSQL major version."
}

variable "sku_name" {
  type        = string
  description = "Flexible Server SKU name."
}

variable "storage_mb" {
  type        = number
  description = "Storage in MB."
}

variable "storage_tier" {
  type        = string
  description = "Storage performance tier (optional)."
  default     = null
  nullable    = true
}

variable "backup_retention_days" {
  type        = number
  description = "Native backup retention in days."
}

variable "geo_redundant_backup_enabled" {
  type        = bool
  description = "Enable geo-redundant native backups."
}

variable "high_availability_enabled" {
  type        = bool
  description = "Enable zone-redundant HA."
}

variable "delegated_subnet_id" {
  type        = string
  description = "Delegated subnet resource ID for private access."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone resource ID."
}

variable "administrator_login" {
  type        = string
  description = "Administrator login."
}

variable "administrator_password" {
  type        = string
  description = "Administrator password (Option A only)."
  default     = null
  nullable    = true
  sensitive   = true
}

variable "password_auth_enabled" {
  type        = bool
  description = "Enable password authentication."
}

variable "entra_auth_enabled" {
  type        = bool
  description = "Enable Microsoft Entra authentication."
}

variable "entra_tenant_id" {
  type        = string
  description = "Entra tenant ID for AAD auth."
  default     = null
  nullable    = true
}

variable "entra_admin_object_id" {
  type        = string
  description = "Entra admin object ID."
  default     = null
  nullable    = true
}

variable "entra_admin_principal_name" {
  type        = string
  description = "Entra admin principal name."
  default     = null
  nullable    = true
}

variable "database_name" {
  type        = string
  description = "POC database name."
}

variable "database_charset" {
  type        = string
  description = "Database charset."
}

variable "database_collation" {
  type        = string
  description = "Database collation."
}

variable "maintenance_window" {
  type = object({
    day_of_week  = number
    start_hour   = number
    start_minute = number
  })
  description = "Maintenance window."
  default     = null
  nullable    = true
}

variable "enable_diagnostics" {
  type        = bool
  description = "Enable diagnostic settings."
  default     = false
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostics."
  default     = null
  nullable    = true
}

variable "enable_resource_locks" {
  type        = bool
  description = "Apply CanNotDelete lock."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
