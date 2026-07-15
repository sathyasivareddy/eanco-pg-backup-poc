variable "name" {
  type        = string
  description = "Container Apps Job name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "container_app_environment_id" {
  type        = string
  description = "Container Apps Environment resource ID."
}

variable "environment" {
  type        = string
  description = "Environment name (env var)."
}

variable "container_image" {
  type        = string
  description = "Image reference by digest."
  default     = null
  nullable    = true
}

variable "cpu" {
  type        = number
  description = "CPU cores."
}

variable "memory" {
  type        = string
  description = "Memory (e.g. 1Gi)."
}

variable "replica_timeout_seconds" {
  type        = number
  description = "Replica timeout in seconds."
}

variable "replica_retry_limit" {
  type        = number
  description = "Replica retry limit."
}

variable "parallelism" {
  type        = number
  description = "Parallelism."
}

variable "replica_completion_count" {
  type        = number
  description = "Replica completion count."
}

variable "enable_schedule" {
  type        = bool
  description = "Enable cron schedule."
}

variable "cron_expression" {
  type        = string
  description = "Cron expression (UTC)."
}

variable "identity_id" {
  type        = string
  description = "User-assigned identity resource ID."
}

variable "identity_client_id" {
  type        = string
  description = "User-assigned identity client ID."
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server."
}

variable "postgresql_fqdn" {
  type        = string
  description = "PostgreSQL FQDN."
}

variable "postgresql_username" {
  type        = string
  description = "PostgreSQL username."
}

variable "postgresql_database_name" {
  type        = string
  description = "PostgreSQL database name."
}

variable "postgresql_sslmode" {
  type        = string
  description = "PostgreSQL SSL mode."
}

variable "postgresql_server_short_name" {
  type        = string
  description = "Short server name for blob paths/logs."
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI."
}

variable "password_secret_name" {
  type        = string
  description = "Key Vault secret name holding the DB password."
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name."
}

variable "storage_blob_endpoint" {
  type        = string
  description = "Storage blob endpoint."
}

variable "storage_container_name" {
  type        = string
  description = "Backup container name."
}

variable "backup_retention_label" {
  type        = string
  description = "Retention metadata label."
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
