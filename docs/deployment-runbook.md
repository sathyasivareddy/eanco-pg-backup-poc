# Deployment Runbook

Follow the phases in order. Nothing deploys automatically; approvals gate each apply.

## Phase 0 — Bootstrap backend (one-time)
```bash
./scripts/bootstrap-backend.sh -g WW-Eanco-tfstate-RG -s steancotfstatedev -c tfstate -l eastus2 --create-rg
# Populate backend.hcl in both terraform roots from the printed values.
```

## Phase 1 — Dependency approval
Complete [approvals-required.md](approvals-required.md). Confirm subscription, RG,
CIDRs, shared reuse, OIDC, backend, DB auth option (A/B/C), budget/expiry.

## Phase 2 — Deploy State 1 (foundation)
```bash
cd terraform/01-postgresql-foundation
cp backend.hcl.example backend.hcl && cp terraform.tfvars.example terraform.tfvars   # edit
export ARM_SUBSCRIPTION_ID=dae60e3b-6b95-4e36-877f-50c54edcd377
export ARM_TENANT_ID=<tenant-id>
# Option A only:
# export TF_VAR_postgresql_admin_password="$(az keyvault secret show --vault-name <kv> --name <secret> --query value -o tsv)"

terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan          # review; get manual approval
terraform apply tfplan
terraform output -json > state1-outputs.json
```
Validate:
```bash
# From a VNet-connected host:
./scripts/validate-private-dns.sh "$(terraform output -raw postgresql_server_fqdn)"
```

## Phase 2b — Initialize + validate sample DB
See [database-initialization.md](database-initialization.md). Then confirm row counts.

## Phase 3 — Deploy State 2 (backup solution)
```bash
cd ../02-postgresql-backup-solution
cp backend.hcl.example backend.hcl && cp terraform.tfvars.example terraform.tfvars
# Fill State 1 output IDs into terraform.tfvars (see state-dependencies.md).
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=tfplan          # manual approval
terraform apply tfplan              # creates ACR + everything; job uses bootstrap image
```

## Phase 3b — Build, push, deploy image by digest
Run `container-build.yml` (builds+scans+pushes), then `container-deploy.yml`
with the digest, OR:
```bash
terraform plan -var="container_image=<acr>.azurecr.io/eanco-pg-backup@sha256:<digest>" -out=tfplan
terraform apply tfplan
```

## Phase 4 — Backup validation
See [backup-runbook.md](backup-runbook.md). Run one manual backup; verify blob.

## Phase 5 — Restore validation
See [restore-runbook.md](restore-runbook.md). Restore into a non-prod test DB.

## Phase 6 — Enable schedule (only after 4 + 5 pass)
```bash
terraform plan -var="enable_backup_schedule=true" -out=tfplan
terraform apply tfplan
```
Record approval + operational owner in [operational-handover.md](operational-handover.md).
