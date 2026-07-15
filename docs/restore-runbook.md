# Restore Runbook

Validates that a backup can be restored into a **non-production** test database.
Never target production (name checks reject `*prod*`).

## Option A — via GitHub Actions
Run the `restore-validation` workflow with:
- `test_database`: e.g. `eanco_backup_demo_restoretest`
- `blob_name`: leave blank for the latest backup

## Option B — via Azure CLI
```bash
./scripts/restore-latest-backup.sh \
  -g WW-EancoPostgreSQLBackupSolution-RG \
  -j ww-eanco-dev-pgbackup-job \
  -s <storage-account> -c postgres-backups \
  -d eanco_backup_demo_restoretest
```
This starts the job with `MODE=restore-test`, which:
1. Reads DB password from Key Vault (UAMI).
2. Downloads the latest (or specified) `.dump` + `.sha256`.
3. Verifies the checksum.
4. Drops/creates the test DB and runs `pg_restore`.
5. Runs structural + row-count validation (`004-restore-validation.sql`).

## Expected result
```
RESTORE VALIDATION PASSED: customers=3, orders=2, order_items=3, PKs=3, FKs=2, indexes>=6
```

## Evidence to capture
- Job execution name + status
- Log output (checksum verified, restore completed, validation passed)
- Blob name + sha256

## Cleanup test database
```sql
DROP DATABASE IF EXISTS eanco_backup_demo_restoretest;
```

## Only after this passes
Enable the schedule (Phase 6 of the deployment runbook).
