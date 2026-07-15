variable "name" {
  type        = string
  description = "Key Vault name (globally unique)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "tenant_id" {
  type        = string
  description = "Tenant ID."
}

variable "sku_name" {
  type        = string
  description = "Key Vault SKU."
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection."
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Soft-delete retention days."
}

variable "create_private_endpoint" {
  type        = bool
  description = "Create a private endpoint."
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
