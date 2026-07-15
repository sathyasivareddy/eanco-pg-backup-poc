# Database Initialization

The POC database is created by Terraform (State 1), but **schema + sample data**
are applied by SQL migrations, not by Terraform provisioners.

> A public GitHub-hosted runner **cannot** reach the private PostgreSQL server.
> Use one of the connectivity options below.

## Connectivity options
1. **Approved VNet-connected self-hosted GitHub runner** (recommended for CI).
2. **Temporary one-time Container Apps initialization job** (kept disabled by
   default; do not create a permanent extra resource).
3. **Approved jump host** in the VNet.
4. **Manual DBA execution** from a VNet-connected workstation.

## Steps (option 1/3/4)
```bash
export KV_NAME=<key-vault-name>
export KV_SECRET=postgresql-backup-password
export PGHOST=<postgresql-fqdn>
export PGUSER=eanco_pgadmin
export PGDATABASE=eanco_backup_demo
./scripts/initialize-database.sh
```
This applies, in order:
- `database/001-create-schema.sql` (schema `eanco_demo`: customers, orders, order_items)
- `database/002-insert-sample-data.sql` (idempotent: 3 customers, 2 orders, 3 items)
- `database/003-validate-data.sql` (tables, counts, PK/FK, indexes, RI, join)

## Expected validation output
```
VALIDATION PASSED: customers=3, orders=2, order_items=3
```

## Notes
- All SQL is idempotent; re-runs do not duplicate rows.
- Password is read from Key Vault into a 0600 PGPASSFILE and never logged.
- The password secret **value** must already exist in Key Vault (created
  out-of-band by the DBA).
