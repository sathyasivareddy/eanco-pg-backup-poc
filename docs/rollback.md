# Rollback

## Principles
- Prefer forward-fix. Roll back only failed applies.
- Never auto-destroy. Never delete the Resource Group, backend, shared resources,
  or retained backups.

## Roll back a bad image deploy
Re-run `container-deploy` with the previous known-good digest:
```bash
az containerapp job update -g <rg> -n <job> --image <acr>/eanco-pg-backup@sha256:<previous-digest>
```
Container Apps Jobs keep revisions of configuration; reverting the image is safe
and does not affect existing backups.

## Roll back a State 2 change
```bash
cd terraform/02-postgresql-backup-solution
git checkout <last-good-commit> -- .
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan   # review carefully
terraform apply tfplan
```

## Roll back a State 1 change
State 1 owns the database — be cautious.
- Networking/DNS changes: revert code + apply.
- Do **not** taint/replace the PostgreSQL server without DBA approval (data loss risk).
- Use resource locks (`enable_resource_locks=true`) to prevent accidental deletion.

## Disable the schedule quickly (stop backups)
```bash
terraform apply -var="enable_backup_schedule=false"
# or, immediately:
az containerapp job update -g <rg> -n <job> --replace-trigger-type Manual  # if supported
```

## If a bad backup was produced
- Backups are immutable content; delete only with approval.
- Soft delete retains deleted blobs for the configured window.
