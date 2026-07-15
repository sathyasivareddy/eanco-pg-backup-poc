# Two-State Design

## Why two states
Independent lifecycles, blast-radius isolation, and least-privilege state access.
The foundation (network + database) changes rarely and is DBA/Network owned. The
backup solution changes more often and is platform/security owned.

| Aspect | State 1 (foundation) | State 2 (backup solution) |
|--------|----------------------|---------------------------|
| Directory | `terraform/01-postgresql-foundation` | `terraform/02-postgresql-backup-solution` |
| Backend key | `eanco/poc/postgresql-foundation.tfstate` | `eanco/poc/postgresql-backup-solution.tfstate` |
| Owns | VNet, subnets, DNS, PostgreSQL, DB | UAMI, ACR, Storage, KV, LAW, ACA env+job, RBAC, alerts |
| Plan workflow | postgresql-plan.yml | backup-solution-plan.yml |
| Apply workflow | postgresql-apply.yml | backup-solution-apply.yml |
| Concurrency | terraform-postgresql-foundation-<env> | terraform-postgresql-backup-<env> |
| Owners | DBA + Network | Platform + Security |

## Integration model (default)
State 2 receives **explicit resource IDs** from State 1 outputs as variables.
State 2 does **not** read State 1's remote state by default — it never gains read
access to the entire State 1 file. An optional `terraform_remote_state` example
is included but disabled in `data.tf`.

## No circular dependency
State 1 has zero knowledge of State 2. Data flows one direction only:

```
RG (data) -> State 1 -> outputs -> State 2
```

## Separate everything
Root modules, backend keys, variables, outputs, workflows, state permissions,
docs, deployment order, and destroy procedures are all separate. See
[state-dependencies.md](state-dependencies.md).
