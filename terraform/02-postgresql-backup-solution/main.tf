# =============================================================================
# STATE 2 root — backup solution. Consumes State 1 outputs as explicit IDs.
# =============================================================================

locals {
  # Derive a short server name from the FQDN (first label) for blob paths/logs.
  pg_server_short_name = element(split(".", var.postgresql_server_fqdn), 0)

  # Effective backup image: real digest when provided, else the bootstrap image
  # (used only to create the job the first time; replaced by container-deploy).
  effective_image = coalesce(var.container_image, var.job_bootstrap_image)

  # Blob endpoint whether storage is created or reused.
  storage_blob_endpoint = var.create_storage_account ? module.storage[0].primary_blob_endpoint : "https://${local.storage_name_eff}.blob.core.windows.net/"
  storage_container_eff = var.create_storage_account ? module.storage[0].backup_container_name : var.backup_container_name
  storage_container_rm_id = var.create_storage_account ? module.storage[0].backup_container_resource_manager_id : var.existing_storage_account_id
}

# ---- Managed Identity (always created) ----
module "managed_identity" {
  source              = "./modules/managed-identity"
  name                = local.uami_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  tags                = local.tags
}

# ---- ACR (create or reuse) ----
module "container_registry" {
  count               = var.create_acr ? 1 : 0
  source              = "./modules/container-registry"
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  sku                 = var.acr_sku

  create_private_endpoint    = var.create_acr_private_endpoint
  private_endpoint_subnet_id = var.private_endpoint_subnet_id
  private_dns_zone_id        = var.acr_private_dns_zone_id

  tags = local.tags
}

# ---- Storage (create or reuse) ----
module "storage" {
  count               = var.create_storage_account ? 1 : 0
  source              = "./modules/storage"
  name                = local.storage_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  replication_type    = var.storage_account_replication
  container_name      = var.backup_container_name

  soft_delete_retention_days       = var.storage_soft_delete_retention_days
  enable_blob_versioning           = var.enable_blob_versioning
  enable_infrastructure_encryption = var.enable_infrastructure_encryption
  enable_immutability              = var.enable_immutability
  immutability_period_days         = var.immutability_period_days

  tier_to_cool_days    = var.lifecycle_tier_to_cool_days
  tier_to_cold_days    = var.lifecycle_tier_to_cold_days
  tier_to_archive_days = var.lifecycle_tier_to_archive_days
  delete_after_days    = var.lifecycle_delete_after_days

  create_private_endpoint    = var.create_storage_private_endpoint
  private_endpoint_subnet_id = var.private_endpoint_subnet_id
  private_dns_zone_id        = var.storage_private_dns_zone_id

  enable_resource_locks = var.enable_resource_locks
  tags                  = local.tags
}

# ---- Key Vault (create or reuse) ----
module "key_vault" {
  count               = var.create_key_vault ? 1 : 0
  source              = "./modules/key-vault"
  name                = local.kv_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  tenant_id           = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name            = var.key_vault_sku

  purge_protection_enabled   = var.key_vault_purge_protection_enabled
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days

  create_private_endpoint    = var.create_key_vault_private_endpoint
  private_endpoint_subnet_id = var.private_endpoint_subnet_id
  private_dns_zone_id        = var.key_vault_private_dns_zone_id

  enable_resource_locks = var.enable_resource_locks
  tags                  = local.tags
}

# ---- Monitoring (LAW + Action Group + critical alerts) ----
module "monitoring" {
  source              = "./modules/monitoring"
  name_prefix         = local.name_prefix
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = local.location
  job_name            = local.job_name

  create_log_analytics_workspace      = var.create_log_analytics_workspace
  log_analytics_workspace_name        = local.law_name
  log_analytics_retention_days        = var.log_analytics_retention_days
  existing_log_analytics_workspace_id = var.existing_log_analytics_workspace_id

  create_action_group      = var.create_action_group
  action_group_name        = local.ag_name
  existing_action_group_id = var.existing_action_group_id
  alert_email_receivers    = var.alert_email_receivers

  no_successful_backup_threshold_hours = var.no_successful_backup_threshold_hours
  job_duration_alert_seconds           = var.job_duration_alert_seconds

  tags = local.tags
}

# ---- Container Apps Environment ----
module "container_apps_environment" {
  source                     = "./modules/container-apps-environment"
  name                       = local.aca_env_name
  resource_group_name        = data.azurerm_resource_group.existing.name
  location                   = local.location
  log_analytics_workspace_id = local.law_id
  infrastructure_subnet_id   = var.container_apps_subnet_id
  tags                       = local.tags
}

# ---- RBAC for the runtime identity (must exist before the job pulls/reads) ----
module "role_assignments" {
  source       = "./modules/role-assignments"
  principal_id = module.managed_identity.principal_id

  acr_id                                = local.acr_id
  key_vault_id                          = local.kv_id
  storage_account_id                    = local.storage_id
  storage_container_resource_manager_id = local.storage_container_rm_id
  storage_blob_rbac_scope               = var.storage_blob_rbac_scope
}

# ---- Container Apps Job ----
module "container_apps_job" {
  source                       = "./modules/container-apps-job"
  name                         = local.job_name
  resource_group_name          = data.azurerm_resource_group.existing.name
  location                     = local.location
  container_app_environment_id = module.container_apps_environment.id
  environment                  = var.environment

  container_image          = local.effective_image
  cpu                      = var.job_cpu
  memory                   = var.job_memory
  replica_timeout_seconds  = var.job_replica_timeout_seconds
  replica_retry_limit      = var.job_replica_retry_limit
  parallelism              = var.job_parallelism
  replica_completion_count = var.job_replica_completion_count

  enable_schedule = var.enable_backup_schedule
  cron_expression = var.backup_cron_expression

  identity_id        = module.managed_identity.id
  identity_client_id = module.managed_identity.client_id
  acr_login_server   = local.acr_login_server

  postgresql_fqdn              = var.postgresql_server_fqdn
  postgresql_username          = var.postgresql_admin_username
  postgresql_database_name     = var.postgresql_database_name
  postgresql_sslmode           = var.postgresql_sslmode
  postgresql_server_short_name = local.pg_server_short_name

  key_vault_uri        = local.kv_uri
  password_secret_name = var.postgresql_password_secret_name

  storage_account_name   = local.storage_name_eff
  storage_blob_endpoint  = local.storage_blob_endpoint
  storage_container_name = local.storage_container_eff
  backup_retention_label = var.backup_retention_label

  tags = local.tags

  # Ensure RBAC is in place before the job (so first run can pull/read).
  depends_on = [module.role_assignments]
}
