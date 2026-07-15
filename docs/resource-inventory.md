# Resource Inventory

## State 1 — foundation
| Resource | Type | Notes |
|----------|------|-------|
| Resource Group | data source | REUSED, never owned |
| Virtual Network | `azurerm_virtual_network` | create or reuse |
| PostgreSQL subnet | `azurerm_subnet` | delegated to flexibleServers |
| Container Apps subnet | `azurerm_subnet` | dedicated |
| Private DNS zone | `azurerm_private_dns_zone` | privatelink.postgres.database.azure.com |
| DNS VNet link | `azurerm_private_dns_zone_virtual_network_link` | registration disabled |
| PostgreSQL server | `azurerm_postgresql_flexible_server` | private, TLS required |
| POC database | `azurerm_postgresql_flexible_server_database` | eanco_backup_demo |
| TLS config | `azurerm_postgresql_flexible_server_configuration` | require_secure_transport=ON |

## State 2 — backup solution
| Resource | Type | Notes |
|----------|------|-------|
| UAMI | `azurerm_user_assigned_identity` | runtime identity |
| ACR | `azurerm_container_registry` | admin disabled; create or reuse |
| Storage account | `azurerm_storage_account` | StorageV2, shared-key disabled |
| Blob container | `azurerm_storage_container` | private |
| Lifecycle policy | `azurerm_storage_management_policy` | tiering + delete |
| Key Vault | `azurerm_key_vault` | RBAC; create or reuse |
| Log Analytics | `azurerm_log_analytics_workspace` | create or reuse |
| Action Group | `azurerm_monitor_action_group` | create or reuse |
| Alerts (x4 critical) | `azurerm_monitor_scheduled_query_rules_alert_v2` | job failed / no backup / upload failed / long-running |
| ACA Environment | `azurerm_container_app_environment` | Consumption, internal |
| ACA Job | `azurerm_container_app_job` | schedule + manual |
| RBAC (x3) | `azurerm_role_assignment` | AcrPull, KV Secrets User, Blob Data Contributor |
| Locks (optional) | `azurerm_management_lock` | when enable_resource_locks |

## Repository tree
```
.
├── README.md  Makefile  .gitignore  .dockerignore  .editorconfig
├── CODEOWNERS  SECURITY.md  CONTRIBUTING.md  CHANGELOG.md
├── docs/ (architecture, runbooks, security, cost, threat model, ...)
├── database/ (001-004 SQL)
├── src/ (Dockerfile, entrypoint.sh, backup.sh, restore-test.sh, health-check.sh, tests/)
├── terraform/01-postgresql-foundation/ (+ modules: network, private-dns, postgresql)
├── terraform/02-postgresql-backup-solution/ (+ modules: managed-identity, container-registry,
│     storage, key-vault, container-apps-environment, container-apps-job, monitoring, role-assignments)
├── scripts/ (bootstrap, validate, initialize, start/status/verify/restore, destroy)
└── .github/ (dependabot, PR template, 9 workflows)
```
