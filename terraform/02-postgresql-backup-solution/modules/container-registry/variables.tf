variable "name" {
  type        = string
  description = "ACR name (globally unique)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "sku" {
  type        = string
  description = "ACR SKU."
}

variable "create_private_endpoint" {
  type        = bool
  description = "Create a private endpoint for ACR."
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

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
