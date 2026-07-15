# Backup Runbook

## Manual backup (Azure CLI)
```bash
./scripts/start-backup.sh -g WW-EancoPostgreSQLBackupSolution-RG -j ww-eanco-dev-pgbackup-job
./scripts/get-job-status.sh -g WW-EancoPostgreSQLBackupSolution-RG -j ww-eanco-dev-pgbackup-job
```

## Manual backup (GitHub Actions)
Run the `manual-backup` workflow (workflow_dispatch) for the target environment.
It starts the job and polls until Succeeded/Failed.

## Verify the backup
```bash
./scripts/verify-latest-backup.sh -s <storage-account> -c postgres-backups
```
Confirms: latest `.dump` exists, size > 0, and `.sha256` sidecar present.

## Blob layout
```
<environment>/<server>/<database>/<yyyy>/<MM>/<dd>/<database>_<UTC-timestamp>_<execution-id>.dump
<...>.dump.sha256
```
Blob metadata: environment, database, server, execution_id, sha256, retention,
pg_dump_version.

## Structured logs
Query Log Analytics:
```kusto
ContainerAppConsoleLogs_CL
| where ContainerJobName_s == "ww-eanco-dev-pgbackup-job"
| project TimeGenerated, Log_s
| order by TimeGenerated desc
```
Fields include: execution_id, backup_stage, status, duration_seconds,
backup_size_bytes, blob_name, pg_dump_version, image_digest, error_code.

## Exit codes
`10` input · `20` Key Vault · `30` DNS/network · `40` PostgreSQL · `50` pg_dump ·
`60` checksum · `70` upload · `80` blob verify · `90` cleanup.

## Schedule
Disabled until backup + restore validation pass. Enable via
`enable_backup_schedule=true` (cron `backup_cron_expression`, UTC).
