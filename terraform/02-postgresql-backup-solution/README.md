# State 2 — PostgreSQL Backup Solution

Creates the backup platform: identity, ACR, storage, Key Vault, monitoring,
Container Apps Environment + Job, RBAC, lifecycle, and alerts. Consumes State 1
outputs as **explicit resource IDs** (no remote-state coupling by default).

## Backend
- Key: `eanco/poc/postgresql-backup-solution.tfstate`
- Configure via `backend.hcl` (copy from `backend.hcl.example`).

## Integration with State 1
Populate these variables from `terraform output` in State 1:
`postgresql_server_id`, `postgresql_server_fqdn`, `postgresql_database_name`,
`postgresql_admin_username`, `virtual_network_id`, `container_apps_subnet_id`.

An **optional** `terraform_remote_state` example is included but disabled in
`data.tf`. Explicit IDs are preferred: State 2 never gains read access to the
full State 1 file.

## Bootstrapping the container image
State 2 may create the ACR. To resolve the ACR/image chicken-and-egg:
1. First `apply` creates ACR + identity + RBAC (+ everything else). The job is
   created using a pinned **bootstrap** public image (`job_bootstrap_image`).
2. `container-build.yml` builds and pushes the real image to the new ACR.
3. `container-deploy.yml` updates the job to the real image **by digest**
   (also settable via `container_image` + `terraform apply`).

## Usage
```bash
cd terraform/02-postgresql-backup-solution
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars   # fill State 1 output IDs

export ARM_SUBSCRIPTION_ID="dae60e3b-6b95-4e36-877f-50c54edcd377"
export ARM_TENANT_ID="<tenant-id>"

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

## Security
- Runtime UAMI gets only AcrPull, Key Vault Secrets User, Storage Blob Data
  Contributor (container scope by default).
- No secrets in outputs/state. The DB password secret **value** is created
  out-of-band by the DBA; only the secret **name** is referenced here.
- ACR admin disabled; storage shared-key disabled; TLS >= 1.2; no ingress.

## Keep schedule disabled
`enable_backup_schedule = false` until backup + restore validation pass.
