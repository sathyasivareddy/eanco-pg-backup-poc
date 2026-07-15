#!/usr/bin/env bash
# =============================================================================
# start-backup.sh — trigger a manual Container Apps Job execution (control plane).
# Creates no data-plane connection; the job runs privately in the VNet.
# Usage: ./scripts/start-backup.sh -g <rg> -j <job-name>
# =============================================================================
set -Eeuo pipefail

RG=""; JOB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RG="$2"; shift 2;;
    -j|--job) JOB="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done
: "${RG:?-g required}" "${JOB:?-j required}"

command -v az >/dev/null || { echo "az required"; exit 1; }

echo ">> Starting job ${JOB}"
exec_name="$(az containerapp job start -g "$RG" -n "$JOB" --query name -o tsv)"
echo "Started execution: ${exec_name}"
echo "Check status with: ./scripts/get-job-status.sh -g ${RG} -j ${JOB} -e ${exec_name}"
