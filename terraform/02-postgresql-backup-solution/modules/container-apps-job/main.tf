terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  # Common non-secret environment variables. The DB password is NEVER set here;
  # the entrypoint fetches it from Key Vault at runtime using the UAMI.
  base_env = [
    { name = "ENVIRONMENT", value = var.environment },
    { name = "PGHOST", value = var.postgresql_fqdn },
    { name = "PGPORT", value = "5432" },
    { name = "PGUSER", value = var.postgresql_username },
    { name = "PGDATABASE", value = var.postgresql_database_name },
    { name = "PGSSLMODE", value = var.postgresql_sslmode },
    { name = "PG_SERVER_NAME", value = var.postgresql_server_short_name },
    { name = "KEY_VAULT_URI", value = var.key_vault_uri },
    { name = "KEY_VAULT_SECRET_NAME", value = var.password_secret_name },
    { name = "STORAGE_ACCOUNT_NAME", value = var.storage_account_name },
    { name = "STORAGE_BLOB_ENDPOINT", value = var.storage_blob_endpoint },
    { name = "STORAGE_CONTAINER_NAME", value = var.storage_container_name },
    { name = "BACKUP_RETENTION_LABEL", value = var.backup_retention_label },
    { name = "IMAGE_DIGEST", value = var.container_image },
    # AZURE_CLIENT_ID lets DefaultAzureCredential pick the user-assigned identity.
    { name = "AZURE_CLIENT_ID", value = var.identity_client_id },
  ]
}

resource "azurerm_container_app_job" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = var.container_app_environment_id
  workload_profile_name        = "Consumption"

  replica_timeout_in_seconds = var.replica_timeout_seconds
  replica_retry_limit        = var.replica_retry_limit

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  # Pull images from ACR using the user-assigned identity (no admin creds).
  registry {
    server   = var.acr_login_server
    identity = var.identity_id
  }

  # Scheduled trigger when enabled; otherwise manual. Manual start via
  # `az containerapp job start` works regardless of the trigger type.
  dynamic "schedule_trigger_config" {
    for_each = var.enable_schedule ? [1] : []
    content {
      cron_expression          = var.cron_expression
      parallelism              = var.parallelism
      replica_completion_count = var.replica_completion_count
    }
  }

  dynamic "manual_trigger_config" {
    for_each = var.enable_schedule ? [] : [1]
    content {
      parallelism              = var.parallelism
      replica_completion_count = var.replica_completion_count
    }
  }

  template {
    container {
      name   = "pgbackup"
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = local.base_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.container_image != null && var.container_image != ""
      error_message = "container_image must be set to an image digest before applying the job (deploy step)."
    }
  }
}
