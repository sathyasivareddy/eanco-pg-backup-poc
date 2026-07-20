# pg-backup

Minimal container that runs `pg_dump` against a PostgreSQL server and uploads the
compressed dump (+ SHA-256 checksum) to Azure Blob Storage. Credentials are read at
runtime from Azure Key Vault via a managed identity — **no secrets are baked into the image**.

## Files
```
src/Dockerfile      # image definition (Alpine + postgresql18-client)
src/entrypoint.sh   # traps signals, runs backup.sh
src/backup.sh       # backup logic (KV secret -> pg_dump -> blob upload -> verify)
```

## Build (Azure Container Registry)
```bash
cd src
az acr build -r <registry-name> -t pg-backup:v1 .
```

## Required environment variables (set on the Container Apps Job)
| Variable | Example |
|---|---|
| `ENVIRONMENT` | `prod` |
| `PGHOST` | `myserver.postgres.database.azure.com` |
| `PGPORT` | `5432` |
| `PGUSER` | `pgadmin` |
| `PGDATABASE` | `appdb` |
| `PGSSLMODE` | `require` |
| `PG_SERVER_NAME` | `myserver` |
| `KEY_VAULT_URI` | `https://myvault.vault.azure.net` |
| `KEY_VAULT_SECRET_NAME` | `pg-admin-password` |
| `STORAGE_ACCOUNT_NAME` | `mybackupsa` |
| `STORAGE_BLOB_ENDPOINT` | `https://mybackupsa.blob.core.windows.net/` |
| `STORAGE_CONTAINER_NAME` | `backups` |
| `AZURE_CLIENT_ID` | managed identity client ID |

## Managed identity access required
- **Key Vault Secrets User** (or access-policy `get`) on the vault
- **Storage Blob Data Contributor** on the storage account
- **AcrPull** on the registry

## Run (on demand)
```bash
az containerapp job start -n <job-name> -g <resource-group>
```

Output blob path:
`<ENVIRONMENT>/<PG_SERVER_NAME>/<PGDATABASE>/<yyyy>/<mm>/<dd>/<db>_<ts>_<id>.dump`
plus a matching `.sha256`.
