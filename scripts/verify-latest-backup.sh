#!/usr/bin/env bash
# =============================================================================
# verify-latest-backup.sh — list the most recent backup blob and confirm its
# checksum sidecar exists. Uses AAD auth (--auth-mode login). Read-only.
# Usage: ./scripts/verify-latest-backup.sh -s <storage-account> -c <container> [-p <prefix>]
# =============================================================================
set -Eeuo pipefail

SA=""; CONTAINER=""; PREFIX=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--storage-account) SA="$2"; shift 2;;
    -c|--container) CONTAINER="$2"; shift 2;;
    -p|--prefix) PREFIX="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done
: "${SA:?-s required}" "${CONTAINER:?-c required}"
command -v az >/dev/null || { echo "az required"; exit 1; }

echo ">> Finding latest .dump blob"
latest="$(az storage blob list --account-name "$SA" --container-name "$CONTAINER" \
  --auth-mode login --prefix "$PREFIX" \
  --query "sort_by([?ends_with(name, '.dump')], &properties.lastModified)[-1].name" -o tsv)"

[[ -n "$latest" && "$latest" != "None" ]] || { echo "FAIL: no backup blobs found"; exit 1; }
echo "Latest backup: ${latest}"

size="$(az storage blob show --account-name "$SA" --container-name "$CONTAINER" --auth-mode login \
  --name "$latest" --query "properties.contentLength" -o tsv)"
echo "Size (bytes): ${size}"
[[ "${size:-0}" -gt 0 ]] || { echo "FAIL: backup size is zero"; exit 1; }

echo ">> Checking checksum sidecar"
if az storage blob exists --account-name "$SA" --container-name "$CONTAINER" --auth-mode login \
     --name "${latest}.sha256" --query exists -o tsv | grep -qi true; then
  echo "PASS: checksum sidecar present for ${latest}"
else
  echo "FAIL: missing checksum sidecar for ${latest}"; exit 1
fi
