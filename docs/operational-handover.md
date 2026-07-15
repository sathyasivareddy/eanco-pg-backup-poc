# Operational Handover

## Ownership
| Area | Owner |
|------|-------|
| PostgreSQL + network (State 1) | DBA + Network team |
| Backup solution (State 2) | Platform Engineering |
| Security / RBAC / secrets | Security team |
| Alerts / on-call | Platform on-call |

## Routine operations
- **Scheduled backups:** cron (UTC) via Container Apps Job; scale-to-zero.
- **Manual backup:** `manual-backup` workflow or `scripts/start-backup.sh`.
- **Verify:** `scripts/verify-latest-backup.sh`.
- **Restore test:** monthly (or per policy) via `restore-validation` workflow.

## Monitoring
Critical alerts (always on): job failed, no successful backup within threshold,
upload failed, long-running. Optional alerts via feature flags. Action Group
routes to configured email (extend to Teams/ITSM as approved).

## Key parameters
| Setting | Variable | POC default |
|---------|----------|-------------|
| Schedule | `backup_cron_expression` | `0 2 * * *` (UTC) |
| Schedule enabled | `enable_backup_schedule` | `false` until validated |
| Retention (delete) | `lifecycle_delete_after_days` | 7 |
| No-backup alert | `no_successful_backup_threshold_hours` | 26 |
| Job timeout | `job_replica_timeout_seconds` | 1800 |

## Secrets
DB password lives only in Key Vault (`postgresql-backup-password`), created and
rotated by the DBA. No secrets in repo/state (Option B/C) or logs.

## Escalation
1. Check Log Analytics (`ContainerAppConsoleLogs_CL`) + exit code.
2. Follow [troubleshooting.md](troubleshooting.md).
3. Escalate to the relevant owner above.

## Records to keep
- Restore-test evidence (date, blob, checksum, result).
- Approval to enable schedule.
- Any POC exception vs production standard.
