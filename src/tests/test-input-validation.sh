#!/usr/bin/env bash
# Tests input validation exit codes by running backup.sh as a subprocess.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/../backup.sh"
fail=0

base_env() {
  export ENVIRONMENT=dev PGHOST=pg.example PGPORT=5432 PGUSER=u PGDATABASE=db
  export PGSSLMODE=require PG_SERVER_NAME=pg
  export KEY_VAULT_URI="https://kv.vault.azure.net" KEY_VAULT_SECRET_NAME=secret
  export STORAGE_ACCOUNT_NAME=st STORAGE_BLOB_ENDPOINT="https://st.blob.core.windows.net/" STORAGE_CONTAINER_NAME=c
  export AZURE_CLIENT_ID=00000000-0000-0000-0000-000000000000
}

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: ${desc} (exit ${actual})"
  else
    echo "FAIL: ${desc} expected ${expected} got ${actual}"; fail=1
  fi
}

# 1. Non-numeric PGPORT -> exit 10
( base_env; export PGPORT=abc; bash "$SCRIPT" >/dev/null 2>&1 )
assert_exit "non-numeric PGPORT" 10 "$?"

# 2. Invalid PGSSLMODE -> exit 10
( base_env; export PGSSLMODE=none; bash "$SCRIPT" >/dev/null 2>&1 )
assert_exit "invalid PGSSLMODE" 10 "$?"

# 3. Missing required env var -> non-zero (bash :? => 1)
( unset ENVIRONMENT; export PGHOST=x; bash "$SCRIPT" >/dev/null 2>&1 )
rc=$?
if [[ "$rc" -ne 0 ]]; then echo "PASS: missing env fails (exit ${rc})"; else echo "FAIL: missing env did not fail"; fail=1; fi

exit "$fail"
