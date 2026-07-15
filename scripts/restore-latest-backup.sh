#!/usr/bin/env bash
# =============================================================================
# restore-latest-backup.sh — trigger the restore-validation job (MODE=restore-test)
# against a NON-PRODUCTION test database, targeting the latest backup blob.
# Requires the job to be configured for restore validation (enable_restore_validation).
# Usage:
#   ./scripts/restore-latest-backup.sh -g <rg> -j <job> -s <storage> -c <container> \
#       -d <test-db-name> [-b <blob-name>]
# =============================================================================
set -Eeuo pipefail

RG=""; JOB=""; SA=""; CONTAINER=""; TESTDB=""; BLOB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RG="$2"; shift 2;;
    -j|--job) JOB="$2"; shift 2;;
    -s|--storage-account) SA="$2"; shift 2;;
    -c|--container) CONTAINER="$2"; shift 2;;
    -d|--test-db) TESTDB="$2"; shift 2;;
    -b|--blob) BLOB="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done
: "${RG:?-g}" "${JOB:?-j}" "${SA:?-s}" "${CONTAINER:?-c}" "${TESTDB:?-d}"
command -v az >/dev/null || { echo "az required"; exit 1; }

case "$TESTDB" in *prod*|*production*) echo "Refusing production-looking target"; exit 1;; esac

if [[ -z "$BLOB" ]]; then
  echo ">> Resolving latest backup blob"
  BLOB="$(az storage blob list --account-name "$SA" --container-name "$CONTAINER" --auth-mode login \
    --query "sort_by([?ends_with(name, '.dump')], &properties.lastModified)[-1].name" -o tsv)"
fi
[[ -n "$BLOB" && "$BLOB" != "None" ]] || { echo "No backup blob found"; exit 1; }
echo "Restoring blob: ${BLOB} into ${TESTDB}"

# Start the job overriding MODE + restore env vars for this execution.
az containerapp job start -g "$RG" -n "$JOB" \
  --env-vars "MODE=restore-test" "RESTORE_TEST_DATABASE=${TESTDB}" "RESTORE_BLOB_NAME=${BLOB}" \
  --query name -o tsv
echo "Started restore-validation execution. Check logs with get-job-status.sh."
