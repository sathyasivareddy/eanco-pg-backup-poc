output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = local.law_id
}

output "action_group_id" {
  description = "Action Group resource ID."
  value       = local.ag_id
}
