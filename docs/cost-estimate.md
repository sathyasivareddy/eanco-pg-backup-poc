# Cost Estimate (POC)

Indicative only. Confirm with the Azure Pricing Calculator for your region and
current rates. Figures are rough monthly USD for a low-usage POC.

| Resource | Config | Est. monthly |
|----------|--------|--------------|
| PostgreSQL Flexible Server | Burstable B1ms, 32 GiB, HA off | ~$15–25 |
| PostgreSQL storage + backups | 32 GiB + 7-day native backup | ~$4–8 |
| Container Apps Job | Consumption, scale-to-zero, short daily runs | ~$0–2 |
| Container Apps Environment | Consumption (no min replicas) | ~$0 idle |
| Storage (backups) | LRS Hot, small volume, 7-day delete | ~$1–3 |
| Azure Container Registry | Basic | ~$5 |
| Key Vault | Standard, few operations | ~$0–1 |
| Log Analytics | Low ingestion, 30-day retention | ~$2–5 |
| **Total** | | **~$30–50/month** |

## Cost drivers
1. PostgreSQL compute (largest) — reduce with stop/start automation if allowed.
2. Log Analytics ingestion — keep logs concise; avoid verbose debug.
3. Storage growth — lifecycle deletes after 7 days for POC.

## Cost controls in place
- Scale-to-zero job; no idle compute.
- LRS + Hot + short retention.
- Basic ACR; reuse shared services when available.
- POC expiry tag drives cleanup ([poc-cleanup.md](poc-cleanup.md)).

## Sizing caveat
**B1ms is for POC/dev only.** Production sizing requires workload, performance,
availability, RPO, and RTO assessment. The backup solution itself follows
production-grade standards regardless of the POC database size.
