# POC Cleanup

Safe teardown that preserves shared and stateful assets.

## Destruction order
1. **Disable the schedule** (`enable_backup_schedule=false` + apply).
2. **Preserve required backup evidence** (download/verify any needed backups).
3. **Destroy State 2** (backup solution).
4. **Validate** Container Apps + backup resources are removed.
5. **Destroy State 1** (foundation) — only after **DBA approval**.
6. Do **not** delete the existing Resource Group.
7. Do **not** delete the Terraform backend.
8. Do **not** delete shared resources (reused ACR/KV/Storage/LAW/AG).
9. Do **not** delete retained backups without explicit approval.

## Commands
```bash
# 1. Disable schedule
cd terraform/02-postgresql-backup-solution
terraform apply -var="enable_backup_schedule=false"

# 3. Destroy State 2
../../scripts/destroy-poc.sh --confirm-state2

# 5. Destroy State 1 (requires DBA approval)
../../scripts/destroy-poc.sh --confirm-state1 --dba-approved
```

## Safety
- The Resource Group remains **unmanaged** by Terraform (data source only).
- If `enable_resource_locks=true`, remove locks before destroy (deliberate step).
- Production resources should keep `prevent_destroy`, resource locks, protected
  environments, and disabled automatic destroy.

## Post-cleanup checklist
- ☐ Schedule disabled and job removed
- ☐ Evidence archived
- ☐ State 2 destroyed; shared services intact
- ☐ State 1 destroyed (DBA-approved) or intentionally retained
- ☐ RG + backend + backups preserved
