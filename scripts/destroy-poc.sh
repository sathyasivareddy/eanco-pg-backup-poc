#!/usr/bin/env bash
# =============================================================================
# destroy-poc.sh — guided, SAFE teardown of the POC in the correct order.
# Does NOT delete: the existing Resource Group, the Terraform backend, shared
# resources, or retained backups. Requires explicit confirmation flags.
#
# Order: disable schedule -> (preserve evidence) -> destroy State 2 ->
#        destroy State 1 (after DBA approval).
#
# Usage:
#   ./scripts/destroy-poc.sh --confirm-state2            # destroy backup solution
#   ./scripts/destroy-poc.sh --confirm-state1 --dba-approved   # destroy foundation
# =============================================================================
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S1="${HERE}/../terraform/01-postgresql-foundation"
S2="${HERE}/../terraform/02-postgresql-backup-solution"

CONFIRM_S1="false"; CONFIRM_S2="false"; DBA="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm-state2) CONFIRM_S2="true"; shift;;
    --confirm-state1) CONFIRM_S1="true"; shift;;
    --dba-approved) DBA="true"; shift;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done

echo "!! This will DESTROY POC infrastructure. It will NOT delete the resource group,"
echo "!! the Terraform backend, shared resources, or retained backups."
echo

if [[ "$CONFIRM_S2" == "true" ]]; then
  echo ">> Step 1: ensure schedule disabled + evidence preserved (manual check)."
  echo ">> Step 2: terraform destroy State 2 (backup solution)"
  ( cd "$S2" && terraform init -backend-config=backend.hcl -input=false \
      && terraform destroy -auto-approve )
  echo "State 2 destroyed. Verify Container Apps + backup resources are gone."
fi

if [[ "$CONFIRM_S1" == "true" ]]; then
  if [[ "$DBA" != "true" ]]; then
    echo "Refusing to destroy State 1 without --dba-approved."; exit 1
  fi
  echo ">> Destroying State 1 (foundation) — PostgreSQL + network"
  ( cd "$S1" && terraform init -backend-config=backend.hcl -input=false \
      && terraform destroy -auto-approve )
  echo "State 1 destroyed. Resource Group and backend remain intact."
fi

if [[ "$CONFIRM_S1" == "false" && "$CONFIRM_S2" == "false" ]]; then
  echo "Nothing to do. Pass --confirm-state2 and/or --confirm-state1 --dba-approved."
fi
