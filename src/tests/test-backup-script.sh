#!/usr/bin/env bash
# Syntax + basic function tests for backup.sh.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/../backup.sh"
fail=0

# 1. Syntax check
if bash -n "$SCRIPT"; then echo "PASS: backup.sh syntax"; else echo "FAIL: backup.sh syntax"; fail=1; fi

# 2. Strict mode present
if grep -q 'set -Eeuo pipefail' "$SCRIPT"; then echo "PASS: strict mode set"; else echo "FAIL: strict mode missing"; fail=1; fi

# 3. Traps present for cleanup + signals
if grep -q 'trap cleanup EXIT' "$SCRIPT" && grep -q 'SIGTERM SIGINT' "$SCRIPT"; then
  echo "PASS: cleanup + signal traps present"
else
  echo "FAIL: traps missing"; fail=1
fi

# 4. No password echoed to logs (sanity: no 'echo $password' patterns)
if grep -Eq 'echo[[:space:]]+.*password' "$SCRIPT"; then echo "FAIL: potential password echo"; fail=1; else echo "PASS: no password echo"; fi

# 5. All categorized exit codes referenced
for code in 10 20 30 40 50 60 70 80; do
  if grep -q "die ${code} " "$SCRIPT"; then :; else echo "FAIL: exit code ${code} not used"; fail=1; fi
done
[[ "$fail" -eq 0 ]] && echo "PASS: categorized exit codes present"

exit "$fail"
