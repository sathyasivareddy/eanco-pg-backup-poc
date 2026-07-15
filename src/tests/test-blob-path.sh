#!/usr/bin/env bash
# Tests blob path construction + sanitization by sourcing backup.sh functions.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/../backup.sh"
fail=0

# Provide env so the top-of-file guards pass, then source (main is guarded out).
export ENVIRONMENT="dev" PGHOST="pg.example" PGPORT=5432 PGUSER=u PGDATABASE="eanco_backup_demo"
export PGSSLMODE=require PG_SERVER_NAME="ww-eanco-dev-pg"
export KEY_VAULT_URI="https://kv.vault.azure.net" KEY_VAULT_SECRET_NAME=secret
export STORAGE_ACCOUNT_NAME=st STORAGE_BLOB_ENDPOINT="https://st.blob.core.windows.net/" STORAGE_CONTAINER_NAME=c
export AZURE_CLIENT_ID=00000000-0000-0000-0000-000000000000

# shellcheck source=/dev/null
source "$SCRIPT"
set +e  # allow assertions to continue

# 1. sanitize_path_segment strips unsafe chars
out="$(sanitize_path_segment 'a/b c;rm-x..$(x)')"
if [[ "$out" == "abcrm-x.." ]]; then echo "PASS: sanitize_path_segment"; else echo "FAIL: sanitize_path_segment got '$out'"; fail=1; fi

# 2. build_blob_name matches expected structure
blob="$(build_blob_name)"
if [[ "$blob" =~ ^dev/ww-eanco-dev-pg/eanco_backup_demo/[0-9]{4}/[0-9]{2}/[0-9]{2}/eanco_backup_demo_[0-9]{8}T[0-9]{6}Z_.*\.dump$ ]]; then
  echo "PASS: build_blob_name structure"
else
  echo "FAIL: build_blob_name got '$blob'"; fail=1
fi

# 3. No path traversal segments in output
if [[ "$blob" == *"../"* ]]; then echo "FAIL: blob contains traversal"; fail=1; else echo "PASS: no traversal in blob path"; fi

exit "$fail"
