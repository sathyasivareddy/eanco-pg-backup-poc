locals {
  name_prefix = "${var.naming_prefix}-${var.environment}"
  location    = coalesce(var.location, data.azurerm_resource_group.existing.location)

  base_tags = {
    environment = var.environment
    owner       = var.owner
    costCenter  = var.cost_center
    project     = var.project_identifier
    expiryDate  = var.poc_expiry_date
    managedBy   = "terraform"
    stateRoot   = "02-postgresql-backup-solution"
  }
  tags = merge(local.base_tags, var.additional_tags)

  # Globally-unique names need to be short & lowercase alphanumeric.
  compact_prefix = lower(replace("${var.naming_prefix}${var.environment}", "-", ""))

  acr_name     = coalesce(var.acr_name, substr("${local.compact_prefix}acr", 0, 50))
  storage_name = coalesce(var.storage_account_name, substr("st${local.compact_prefix}bkp", 0, 24))
  kv_name      = coalesce(var.key_vault_name, substr("kv-${local.name_prefix}", 0, 24))
  law_name     = coalesce(var.log_analytics_workspace_name, "${local.name_prefix}-law")
  ag_name      = coalesce(var.action_group_name, "${local.name_prefix}-ag")
  uami_name    = "${local.name_prefix}-backup-uami"
  aca_env_name = "${local.name_prefix}-cae"
  job_name     = "${local.name_prefix}-pgbackup-job"

  # Effective IDs whether created or reused.
  acr_id           = var.create_acr ? module.container_registry[0].acr_id : var.existing_acr_id
  acr_login_server = var.create_acr ? module.container_registry[0].login_server : var.existing_acr_login_server
  storage_id       = var.create_storage_account ? module.storage[0].storage_account_id : var.existing_storage_account_id
  storage_name_eff = var.create_storage_account ? module.storage[0].storage_account_name : element(reverse(split("/", coalesce(var.existing_storage_account_id, "//////x"))), 0)
  kv_id            = var.create_key_vault ? module.key_vault[0].key_vault_id : var.existing_key_vault_id
  kv_uri           = var.create_key_vault ? module.key_vault[0].key_vault_uri : var.existing_key_vault_uri
  law_id           = var.create_log_analytics_workspace ? module.monitoring.log_analytics_workspace_id : var.existing_log_analytics_workspace_id
  ag_id            = var.create_action_group ? module.monitoring.action_group_id : var.existing_action_group_id
}
