# =============================================================================
# STATE 2 variables — PostgreSQL backup solution.
# Consumes State 1 outputs as EXPLICIT resource IDs (default integration model).
# =============================================================================

# ---- Azure subscription / tenant ----
variable "subscription_id" {
  description = "Azure Subscription ID. Prefer ARM_SUBSCRIPTION_ID env var."
  type        = string
  default     = null
  nullable    = true
}

variable "tenant_id" {
  description = "Azure Tenant ID. Prefer ARM_TENANT_ID env var."
  type        = string
  default     = null
  nullable    = true
}

# ---- Existing Resource Group ----
variable "resource_group_name" {
  description = "Existing resource group to reuse (read-only)."
  type        = string
}

variable "location" {
  description = "Azure region. Defaults to the existing RG location when null."
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
  description = "Naming prefix, e.g. 'ww-eanco'."
  type        = string
  default     = "ww-eanco"
}

variable "project_identifier" {
  description = "Application/project identifier tag."
  type        = string
  default     = "eanco-pgbackup"
}

variable "owner" {
  description = "Resource owner for the owner tag."
  type        = string
}

variable "cost_center" {
  description = "Cost centre."
  type        = string
}

variable "poc_expiry_date" {
  description = "POC expiry date (YYYY-MM-DD)."
  type        = string
  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.poc_expiry_date))
    error_message = "poc_expiry_date must be YYYY-MM-DD."
  }
}

variable "additional_tags" {
  description = "Additional tags merged onto the mandatory tag set."
  type        = map(string)
  default     = {}
}

variable "enable_resource_locks" {
  description = "Apply CanNotDelete locks to protectable resources."
  type        = bool
  default     = false
}

# ---- State 1 integration (explicit resource IDs) ----
variable "postgresql_server_id" {
  description = "PostgreSQL Flexible Server resource ID (from State 1)."
  type        = string
}

variable "postgresql_server_fqdn" {
  description = "PostgreSQL server FQDN (from State 1)."
  type        = string
}

variable "postgresql_database_name" {
  description = "POC database name (from State 1)."
  type        = string
}

variable "postgresql_admin_username" {
  description = "PostgreSQL backup/admin login used by the job (non-secret)."
  type        = string
}

variable "virtual_network_id" {
  description = "VNet resource ID (from State 1)."
  type        = string
}

variable "container_apps_subnet_id" {
  description = "Container Apps infrastructure subnet resource ID (from State 1)."
  type        = string
}

# Optional remote-state escape hatch (disabled by default).
variable "use_remote_state_foundation" {
  description = "Read State 1 outputs via terraform_remote_state instead of explicit IDs (NOT recommended)."
  type        = bool
  default     = false
}

variable "foundation_backend_resource_group_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Backend RG for State 1 remote state (only if use_remote_state_foundation)."
}

variable "foundation_backend_storage_account_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Backend storage account for State 1 remote state."
}

variable "foundation_backend_container_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Backend container for State 1 remote state."
}

# ---- Feature flags: create vs reuse shared services ----
variable "create_acr" {
  description = "Create a new Azure Container Registry (false to reuse existing_acr_id)."
  type        = bool
  default     = true
}

variable "create_storage_account" {
  description = "Create a new Storage Account (false to reuse existing_storage_account_id)."
  type        = bool
  default     = true
}

variable "create_key_vault" {
  description = "Create a new Key Vault (false to reuse existing_key_vault_id)."
  type        = bool
  default     = true
}

variable "create_log_analytics_workspace" {
  description = "Create a new Log Analytics workspace (false to reuse existing_log_analytics_workspace_id)."
  type        = bool
  default     = true
}

variable "create_action_group" {
  description = "Create a new Action Group (false to reuse existing_action_group_id)."
  type        = bool
  default     = true
}

variable "create_storage_private_endpoint" {
  description = "Create a private endpoint for Storage (only if policy requires)."
  type        = bool
  default     = false
}

variable "create_key_vault_private_endpoint" {
  description = "Create a private endpoint for Key Vault (only if policy requires)."
  type        = bool
  default     = false
}

variable "create_acr_private_endpoint" {
  description = "Create a private endpoint for ACR (only if policy requires)."
  type        = bool
  default     = false
}

# ---- Existing resource IDs (used when create_* = false) ----
variable "existing_acr_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing ACR resource ID to reuse."
}

variable "existing_acr_login_server" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing ACR login server (required when reusing ACR)."
}

variable "existing_storage_account_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing storage account resource ID to reuse."
}

variable "existing_key_vault_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing Key Vault resource ID to reuse."
}

variable "existing_key_vault_uri" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing Key Vault URI (required when create_key_vault = false)."
}

variable "existing_log_analytics_workspace_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing Log Analytics workspace resource ID to reuse."
}

variable "existing_action_group_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing Action Group resource ID to reuse."
}

# ---- Private endpoint DNS ----
variable "storage_private_dns_zone_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Private DNS zone ID for blob storage private endpoint."
}

variable "key_vault_private_dns_zone_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Private DNS zone ID for Key Vault private endpoint."
}

variable "acr_private_dns_zone_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Private DNS zone ID for ACR private endpoint."
}

variable "private_endpoint_subnet_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Subnet ID for private endpoints (if enabled). Must NOT be the ACA subnet."
}

# ---- ACR ----
variable "acr_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Override ACR name (globally unique). Null derives from prefix."
}

variable "acr_sku" {
  type        = string
  default     = "Basic"
  description = "ACR SKU."
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard or Premium."
  }
}

# ---- Storage ----
variable "storage_account_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Override storage account name (globally unique). Null derives from prefix."
}

variable "storage_account_replication" {
  type        = string
  default     = "LRS"
  description = "Storage redundancy (LRS for POC)."
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.storage_account_replication)
    error_message = "Invalid storage replication type."
  }
}

variable "backup_container_name" {
  type        = string
  default     = "postgres-backups"
  description = "Blob container for backups."
}

variable "storage_soft_delete_retention_days" {
  type        = number
  default     = 7
  description = "Blob soft-delete retention in days."
  validation {
    condition     = var.storage_soft_delete_retention_days >= 1 && var.storage_soft_delete_retention_days <= 365
    error_message = "storage_soft_delete_retention_days must be 1-365."
  }
}

variable "enable_blob_versioning" {
  type        = bool
  default     = false
  description = "Enable blob versioning."
}

variable "enable_infrastructure_encryption" {
  type        = bool
  default     = false
  description = "Enable storage infrastructure (double) encryption."
}

variable "enable_immutability" {
  type        = bool
  default     = false
  description = "Enable immutable (WORM) storage on the container."
}

variable "immutability_period_days" {
  type        = number
  default     = 7
  description = "Immutability retention period in days (if enabled)."
}

# ---- Storage lifecycle ----
variable "lifecycle_tier_to_cool_days" {
  type        = number
  default     = null
  nullable    = true
  description = "Days after which to move blobs Hot->Cool (null disables)."
}

variable "lifecycle_tier_to_cold_days" {
  type        = number
  default     = null
  nullable    = true
  description = "Days after which to move blobs Cool->Cold (null disables)."
}

variable "lifecycle_tier_to_archive_days" {
  type        = number
  default     = null
  nullable    = true
  description = "Days after which to archive (null disables; confirm restore-time costs)."
}

variable "lifecycle_delete_after_days" {
  type        = number
  default     = 7
  description = "Days after which to delete backups (POC default 7)."
  validation {
    condition     = var.lifecycle_delete_after_days >= 1
    error_message = "lifecycle_delete_after_days must be >= 1."
  }
}

# ---- Key Vault ----
variable "key_vault_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Override Key Vault name (globally unique). Null derives from prefix."
}

variable "key_vault_sku" {
  type        = string
  default     = "standard"
  description = "Key Vault SKU."
}

variable "key_vault_purge_protection_enabled" {
  type        = bool
  default     = false
  description = "Enable purge protection (recommended true for production)."
}

variable "key_vault_soft_delete_retention_days" {
  type        = number
  default     = 7
  description = "Key Vault soft-delete retention days."
}

variable "postgresql_password_secret_name" {
  type        = string
  default     = "postgresql-backup-password"
  description = "Name of the Key Vault secret holding the backup DB password (value created out-of-band by DBA)."
}

# ---- Log Analytics / monitoring ----
variable "log_analytics_workspace_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Override Log Analytics workspace name."
}

variable "log_analytics_retention_days" {
  type        = number
  default     = 30
  description = "Log Analytics retention in days."
}

variable "action_group_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Override Action Group name."
}

variable "alert_email_receivers" {
  type = list(object({
    name  = string
    email = string
  }))
  default     = []
  description = "Email receivers for the Action Group (Teams/ITSM configured separately)."
}

# ---- Alerts (critical always on; others optional) ----
variable "enable_alert_backup_size_anomaly" {
  type        = bool
  default     = false
  description = "Optional: backup-size anomaly alert."
}

variable "enable_alert_private_dns_failure" {
  type        = bool
  default     = false
  description = "Optional: private DNS resolution failure alert."
}

variable "enable_alert_image_pull_failure" {
  type        = bool
  default     = false
  description = "Optional: image pull failure alert."
}

variable "enable_alert_repeated_retries" {
  type        = bool
  default     = false
  description = "Optional: repeated retries alert."
}

variable "no_successful_backup_threshold_hours" {
  type        = number
  default     = 26
  description = "Hours without a successful backup before alerting."
}

variable "job_duration_alert_seconds" {
  type        = number
  default     = 1800
  description = "Job duration threshold (seconds) for the long-running alert."
}

# ---- Container Apps job ----
variable "container_image" {
  description = "Full backup image reference by DIGEST, e.g. <acr>/<repo>@sha256:<digest>. Set during deploy."
  type        = string
  default     = null
  nullable    = true
}

variable "job_bootstrap_image" {
  description = <<-EOT
    Pinned public bootstrap image used ONLY to create the job resource on the
    first apply (when the real ACR image digest is not yet available). The
    container-deploy workflow replaces it with the real image by digest.
    Not 'latest'. Override if this MCR tag is not approved.
  EOT
  type        = string
  default     = "mcr.microsoft.com/cbl-mariner/busybox:2.0"
}

variable "job_cpu" {
  type        = number
  default     = 0.5
  description = "Job CPU cores."
}

variable "job_memory" {
  type        = string
  default     = "1Gi"
  description = "Job memory."
}

variable "job_replica_timeout_seconds" {
  type        = number
  default     = 1800
  description = "Replica timeout in seconds (30 min)."
}

variable "job_replica_retry_limit" {
  type        = number
  default     = 2
  description = "Replica retry limit."
}

variable "job_parallelism" {
  type        = number
  default     = 1
  description = "Job parallelism."
}

variable "job_replica_completion_count" {
  type        = number
  default     = 1
  description = "Replica completion count."
}

variable "enable_backup_schedule" {
  type        = bool
  default     = false
  description = "Enable the cron schedule (keep false until restore validation passes)."
}

variable "backup_cron_expression" {
  type        = string
  default     = "0 2 * * *"
  description = "Cron expression for scheduled backups (UTC)."
}

variable "backup_schedule_timezone" {
  type        = string
  default     = "Etc/UTC"
  description = "Documentation of the intended schedule timezone (ACA cron is UTC)."
}

variable "enable_restore_validation" {
  type        = bool
  default     = false
  description = "Enable restore-validation tooling/job wiring."
}

variable "postgresql_sslmode" {
  type        = string
  default     = "require"
  description = "PostgreSQL SSL mode used by the job."
  validation {
    condition     = contains(["require", "verify-ca", "verify-full"], var.postgresql_sslmode)
    error_message = "postgresql_sslmode must be require, verify-ca or verify-full."
  }
}

variable "backup_retention_label" {
  type        = string
  default     = "poc-7d"
  description = "Metadata label applied to backup blobs."
}

# ---- RBAC scope ----
variable "storage_blob_rbac_scope" {
  type        = string
  default     = "container"
  description = "Scope for Storage Blob Data Contributor: 'container' (preferred) or 'account'."
  validation {
    condition     = contains(["container", "account"], var.storage_blob_rbac_scope)
    error_message = "storage_blob_rbac_scope must be 'container' or 'account'."
  }
}
