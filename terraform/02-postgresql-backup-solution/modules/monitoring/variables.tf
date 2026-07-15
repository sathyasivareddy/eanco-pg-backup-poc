variable "name_prefix" {
  type        = string
  description = "Naming prefix for alert rules."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "job_name" {
  type        = string
  description = "Container Apps Job name (used in KQL filters)."
}

variable "create_log_analytics_workspace" {
  type        = bool
  description = "Create the Log Analytics workspace."
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Retention in days."
}

variable "existing_log_analytics_workspace_id" {
  type        = string
  description = "Existing workspace ID (when reusing)."
  default     = null
  nullable    = true
}

variable "create_action_group" {
  type        = bool
  description = "Create the Action Group."
}

variable "action_group_name" {
  type        = string
  description = "Action Group name."
}

variable "action_group_short_name" {
  type        = string
  description = "Action Group short name."
  default     = "eancobkp"
}

variable "existing_action_group_id" {
  type        = string
  description = "Existing Action Group ID (when reusing)."
  default     = null
  nullable    = true
}

variable "alert_email_receivers" {
  type = list(object({
    name  = string
    email = string
  }))
  description = "Email receivers."
  default     = []
}

variable "no_successful_backup_threshold_hours" {
  type        = number
  description = "Hours without success before alerting."
}

variable "job_duration_alert_seconds" {
  type        = number
  description = "Long-running threshold in seconds."
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default     = {}
}
