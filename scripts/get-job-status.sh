#!/usr/bin/env bash
# =============================================================================
# get-job-status.sh — show recent Container Apps Job executions and their state.
# Usage: ./scripts/get-job-status.sh -g <rg> -j <job> [-e <execution-name>]
# =============================================================================
set -Eeuo pipefail

RG=""; JOB=""; EXECUTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RG="$2"; shift 2;;
    -j|--job) JOB="$2"; shift 2;;
    -e|--execution) EXECUTION="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done
: "${RG:?-g required}" "${JOB:?-j required}"
command -v az >/dev/null || { echo "az required"; exit 1; }

if [[ -n "$EXECUTION" ]]; then
  az containerapp job execution show -g "$RG" --name "$JOB" --job-execution-name "$EXECUTION" \
    --query "{name:name, status:properties.status, start:properties.startTime, end:properties.endTime}" -o table
else
  echo ">> Recent executions for ${JOB}"
  az containerapp job execution list -g "$RG" --name "$JOB" \
    --query "[].{name:name, status:properties.status, start:properties.startTime, end:properties.endTime}" -o table
fi
