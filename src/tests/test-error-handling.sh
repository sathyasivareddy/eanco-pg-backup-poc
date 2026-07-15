#!/usr/bin/env bash
# Tests entrypoint dispatch + error handling.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRY="${HERE}/../entrypoint.sh"
BACKUP="${HERE}/../backup.sh"
fail=0

# 1. Unknown MODE -> exit 10
( export MODE=nope; bash "$ENTRY" >/dev/null 2>&1 )
if [[ "$?" -eq 10 ]]; then echo "PASS: unknown MODE exit 10"; else echo "FAIL: unknown MODE"; fail=1; fi

# 2. entrypoint syntax
if bash -n "$ENTRY"; then echo "PASS: entrypoint syntax"; else echo "FAIL: entrypoint syntax"; fail=1; fi

# 3. sanitize() removes double quotes (source backup functions)
export ENVIRONMENT=dev PGHOST=h PGPORT=5432 PGUSER=u PGDATABASE=d PGSSLMODE=require PG_SERVER_NAME=s
export KEY_VAULT_URI=https://k KEY_VAULT_SECRET_NAME=x STORAGE_ACCOUNT_NAME=a
export STORAGE_BLOB_ENDPOINT=https://a.blob/ STORAGE_CONTAINER_NAME=c AZURE_CLIENT_ID=cid
# shellcheck source=/dev/null
source "$BACKUP"
set +e
out="$(sanitize 'he said "hi"')"
if [[ "$out" != *'"'* ]]; then echo "PASS: sanitize strips quotes"; else echo "FAIL: sanitize quotes"; fail=1; fi

# 4. log() emits valid single-line JSON with required fields
line="$(log "start" "started" "" "msg")"
for field in execution_id timestamp backup_stage status error_code; do
  if [[ "$line" == *"\"$field\""* ]]; then :; else echo "FAIL: log missing $field"; fail=1; fi
done
[[ "$fail" -eq 0 ]] && echo "PASS: log JSON fields present"

exit "$fail"
