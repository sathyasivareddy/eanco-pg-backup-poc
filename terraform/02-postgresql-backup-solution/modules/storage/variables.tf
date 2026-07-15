variable "name" {
  type        = string
  description = "Storage account name (globally unique, 3-24 lowercase alphanumeric)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "replication_type" {
  type        = string
  description = "Replication type (LRS for POC)."
}

variable "container_name" {
  type        = string
  description = "Blob container name."
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Soft-delete retention days."
}

variable "enable_blob_versioning" {
  type        = bool
  description = "Enable blob versioning."
  default     = false
}

variable "enable_infrastructure_encryption" {
  type        = bool
  description = "Enable infrastructure encryption."
  default     = false
}

variable "enable_immutability" {
  type        = bool
  description = "Enable immutable storage."
  default     = false
}

variable "immutability_period_days" {
  type        = number
  description = "Immutability period days."
  default     = 7
}

variable "tier_to_cool_days" {
  type        = number
  description = "Days before Hot->Cool (null disables)."
  default     = null
  nullable    = true
}

variable "tier_to_cold_days" {
  type        = number
  description = "Days before Cool->Cold (null disables)."
  default     = null
  nullable    = true
}

variable "tier_to_archive_days" {
  type        = number
  description = "Days before archive (null disables)."
  default     = null
  nullable    = true
}

variable "delete_after_days" {
  type        = number
  description = "Days before deletion."
}

variable "create_private_endpoint" {
  type        = bool
  description = "Create a blob private endpoint."
  default     = false
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet for the private endpoint."
  default     = null
  nullable    = true
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone for the private endpoint."
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
