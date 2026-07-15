#!/usr/bin/env bash
# =============================================================================
# bootstrap-backend.sh — one-time creation of the Terraform backend storage.
# Creates: backend RG (optional), StorageV2 account (shared-key disabled after
# init is possible, but init needs AAD), and the state container. Enables
# versioning + soft delete. Run MANUALLY by an authorized operator.
#
# This script is NOT executed by CI automatically. Review before running.
# Usage:
#   ./scripts/bootstrap-backend.sh -g <rg> -s <storage> -c <container> -l <location> [--create-rg]
# =============================================================================
set -Eeuo pipefail

RG=""; SA=""; CONTAINER="tfstate"; LOCATION=""; CREATE_RG="false"

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RG="$2"; shift 2;;
    -s|--storage-account) SA="$2"; shift 2;;
    -c|--container) CONTAINER="$2"; shift 2;;
    -l|--location) LOCATION="$2"; shift 2;;
    --create-rg) CREATE_RG="true"; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

: "${RG:?--resource-group required}" "${SA:?--storage-account required}" "${LOCATION:?--location required}"

command -v az >/dev/null || { echo "Azure CLI (az) is required"; exit 1; }

echo ">> Using subscription: $(az account show --query name -o tsv)"

if [[ "$CREATE_RG" == "true" ]]; then
  echo ">> Creating resource group ${RG} in ${LOCATION}"
  az group create -n "$RG" -l "$LOCATION" -o none
fi

echo ">> Creating StorageV2 account ${SA}"
az storage account create \
  --name "$SA" --resource-group "$RG" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --https-only true \
  --allow-blob-public-access false \
  --allow-shared-key-access true \
  -o none

echo ">> Enabling blob versioning + soft delete"
az storage account blob-service-properties update \
  --account-name "$SA" --resource-group "$RG" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 \
  -o none

echo ">> Creating state container ${CONTAINER} (AAD auth)"
az storage container create \
  --name "$CONTAINER" --account-name "$SA" --auth-mode login -o none

cat <<EOF

Backend ready. Populate backend.hcl files:

  resource_group_name  = "${RG}"
  storage_account_name = "${SA}"
  container_name       = "${CONTAINER}"
  use_azuread_auth     = true

State keys (already set in backend.tf):
  State 1: eanco/poc/postgresql-foundation.tfstate
  State 2: eanco/poc/postgresql-backup-solution.tfstate

NOTE: Consider disabling shared-key access after confirming AAD-based state
access works for all operators/CI:
  az storage account update -n ${SA} -g ${RG} --allow-shared-key-access false
EOF
