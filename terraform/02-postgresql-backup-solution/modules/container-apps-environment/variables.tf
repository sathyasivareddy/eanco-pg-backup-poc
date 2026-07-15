variable "name" {
  type        = string
  description = "Container Apps Environment name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace resource ID."
}

variable "infrastructure_subnet_id" {
  type        = string
  description = "Container Apps infrastructure subnet ID (dedicated)."
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
