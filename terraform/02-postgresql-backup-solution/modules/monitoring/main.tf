terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Log Analytics workspace (create or reuse).
resource "azurerm_log_analytics_workspace" "this" {
  count               = var.create_log_analytics_workspace ? 1 : 0
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

locals {
  law_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].id : var.existing_log_analytics_workspace_id
  ag_id  = var.create_action_group ? azurerm_monitor_action_group.this[0].id : var.existing_action_group_id
}

# Action Group (create or reuse).
resource "azurerm_monitor_action_group" "this" {
  count               = var.create_action_group ? 1 : 0
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = substr(replace(var.action_group_short_name, "-", ""), 0, 12)

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Critical alerts (always on). KQL over Container Apps logs in Log Analytics.
# ---------------------------------------------------------------------------

# 1. Job execution failed (non-zero exit / failure marker in structured logs).
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "job_failed" {
  name                = "${var.name_prefix}-alert-backup-job-failed"
  resource_group_name = var.resource_group_name
  location            = var.location
  severity            = 1
  scopes              = [local.law_id]
  evaluation_frequency = "PT15M"
  window_duration      = "PT30M"

  criteria {
    query = <<-KQL
      ContainerAppConsoleLogs_CL
      | where ContainerJobName_s == "${var.job_name}"
      | where Log_s has '"status":"failed"' or Log_s has '"backup_stage":"fatal"'
      | summarize Count = count()
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [local.ag_id]
  }
  tags = var.tags
}

# 2. No successful backup within threshold.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "no_successful_backup" {
  name                 = "${var.name_prefix}-alert-no-successful-backup"
  resource_group_name  = var.resource_group_name
  location             = var.location
  severity             = 1
  scopes               = [local.law_id]
  evaluation_frequency = "PT1H"
  window_duration      = "PT${var.no_successful_backup_threshold_hours}H"

  criteria {
    query = <<-KQL
      ContainerAppConsoleLogs_CL
      | where ContainerJobName_s == "${var.job_name}"
      | where Log_s has '"status":"success"' and Log_s has '"backup_stage":"completed"'
      | summarize Count = count()
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "LessThanOrEqual"
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [local.ag_id]
  }
  tags = var.tags
}

# 3. Backup upload failed.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "upload_failed" {
  name                 = "${var.name_prefix}-alert-backup-upload-failed"
  resource_group_name  = var.resource_group_name
  location             = var.location
  severity             = 1
  scopes               = [local.law_id]
  evaluation_frequency = "PT15M"
  window_duration      = "PT30M"

  criteria {
    query = <<-KQL
      ContainerAppConsoleLogs_CL
      | where ContainerJobName_s == "${var.job_name}"
      | where Log_s has '"error_code":"70"' or Log_s has '"error_code":"80"'
      | summarize Count = count()
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [local.ag_id]
  }
  tags = var.tags
}

# 4. Job execution exceeded expected duration.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "long_running" {
  name                 = "${var.name_prefix}-alert-backup-long-running"
  resource_group_name  = var.resource_group_name
  location             = var.location
  severity             = 2
  scopes               = [local.law_id]
  evaluation_frequency = "PT15M"
  window_duration      = "PT1H"

  criteria {
    query = <<-KQL
      ContainerAppConsoleLogs_CL
      | where ContainerJobName_s == "${var.job_name}"
      | extend d = extract('"duration_seconds":([0-9]+)', 1, Log_s)
      | where isnotempty(d) and toint(d) > ${var.job_duration_alert_seconds}
      | summarize Count = count()
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [local.ag_id]
  }
  tags = var.tags
}
