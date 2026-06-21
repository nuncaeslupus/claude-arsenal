#!/usr/bin/env bash
# reclaim_test.sh — integration test for reclaim.sh (claimed_at lease recovery).
# Asserts:
#   1. --dry-run reports the stale task and changes nothing.
#   2. A real run resets the expired-lease task to open (assignee + claimed_at
#      cleared, attempts incremented) and pushes it to the coordination ref,
#      while a fresh-lease task in_progress is left untouched.
#   3. "Nothing to reclaim" exits 0 without a commit.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECLAIM="${SCRIPT_DIR}/../skills/init/assets/bin/reclaim.sh"
QUEUE_BRANCH="arsenal-queue"
export ARSENAL_QUEUE_BRANCH="${QUEUE_BRANCH}"

if [[ ! -f "${RECLAIM}" ]]; then
    echo "SKIP: reclaim.sh not found at ${RECLAIM}" >&2; exit 0
fi

tmpremote=$(mktemp -d)
git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD "refs/heads/${QUEUE_BRANCH}"

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}" "${tmpremote}"; }
trap cleanup EXIT

cd "${tmpdir}"
git init -q -b "${QUEUE_BRANCH}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git remote add origin "${tmpremote}"
mkdir -p claude-arsenal/queue
Q="claude-arsenal/queue/tasks.jsonl"

OLD_TS="2000-01-01T00:00:00+00:00"
NOW_TS="$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).isoformat())')"
printf '%s\n%s\n' \
    "{\"id\":\"lo-stale\",\"title\":\"crashed\",\"status\":\"in_progress\",\"priority\":0,\"requires\":[],\"deps\":[],\"assignee\":\"sess-x\",\"claimed_at\":\"${OLD_TS}\",\"attempts\":0,\"max_attempts\":3,\"payload\":\"lo-stale.md\"}" \
    "{\"id\":\"lo-live\",\"title\":\"running\",\"status\":\"in_progress\",\"priority\":0,\"requires\":[],\"deps\":[],\"assignee\":\"sess-y\",\"claimed_at\":\"${NOW_TS}\",\"attempts\":0,\"max_attempts\":3,\"payload\":\"lo-live.md\"}" \
    > "${Q}"
git add "${Q}"
git commit -q -m "init: seed queue"
git push -q -u origin "${QUEUE_BRANCH}"

row_field() { python3 -c "
import json,sys
for l in open(sys.argv[1]):
    r=json.loads(l)
    if r['id']==sys.argv[2]: print(r.get(sys.argv[3], '<unset>'))
" "${Q}" "$1" "$2"; }

# --- Gate 1: --dry-run reports lo-stale and changes nothing. ---
OUT=$(bash "${RECLAIM}" --dry-run 2>&1)
if ! printf '%s' "${OUT}" | grep -q "lo-stale"; then
    echo "FAIL: dry-run should list lo-stale, got: ${OUT}" >&2; exit 1
fi
if printf '%s' "${OUT}" | grep -q "lo-live"; then
    echo "FAIL: dry-run should NOT list the fresh-lease lo-live, got: ${OUT}" >&2; exit 1
fi
if [[ "$(row_field lo-stale status)" != "in_progress" ]]; then
    echo "FAIL: dry-run must not modify the ledger" >&2; exit 1
fi
echo "PASS: --dry-run reports the stale task and changes nothing"

# --- Gate 2: real run resets lo-stale, leaves lo-live in_progress. ---
bash "${RECLAIM}" >/dev/null 2>&1
if [[ "$(row_field lo-stale status)" != "open" ]]; then
    echo "FAIL: lo-stale should be reset to open, got '$(row_field lo-stale status)'" >&2; exit 1
fi
if [[ "$(row_field lo-stale assignee)" != "None" ]]; then
    echo "FAIL: lo-stale assignee should be cleared, got '$(row_field lo-stale assignee)'" >&2; exit 1
fi
if [[ "$(row_field lo-stale claimed_at)" != "<unset>" ]]; then
    echo "FAIL: lo-stale claimed_at should be cleared, got '$(row_field lo-stale claimed_at)'" >&2; exit 1
fi
if [[ "$(row_field lo-stale attempts)" != "1" ]]; then
    echo "FAIL: reclaim should increment attempts to 1, got '$(row_field lo-stale attempts)'" >&2; exit 1
fi
if [[ "$(row_field lo-live status)" != "in_progress" ]]; then
    echo "FAIL: fresh-lease lo-live must stay in_progress" >&2; exit 1
fi
# The reset must have been pushed to the coordination ref.
git fetch -q origin "${QUEUE_BRANCH}"
if ! git show "origin/${QUEUE_BRANCH}:${Q}" | grep -q '"id":"lo-stale","title":"crashed","status":"open"'; then
    echo "FAIL: reclaim did not push the reset to the coordination ref" >&2; exit 1
fi
echo "PASS: real run reclaims the stale task and pushes it; leaves the live one"

# --- Gate 3: nothing left to reclaim → exit 0, no new commit. ---
before=$(git rev-parse HEAD)
set +e
bash "${RECLAIM}" >/dev/null 2>&1; rc=$?
set -e
if [[ "${rc}" -ne 0 ]]; then
    echo "FAIL: a no-op reclaim should exit 0, got ${rc}" >&2; exit 1
fi
if [[ "$(git rev-parse HEAD)" != "${before}" ]]; then
    echo "FAIL: a no-op reclaim should not create a commit" >&2; exit 1
fi
echo "PASS: no expired leases → exit 0 with no commit"

echo "PASS: reclaim_test — all gates passed"
exit 0
