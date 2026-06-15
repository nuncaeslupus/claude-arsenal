#!/usr/bin/env bash
# test_attempts.sh — integration tests for per-task iteration cap and auto-escalation.
# Covers:
#   CA-ATT-01: first gate failure increments attempts, keeps status=open (cap=3)
#   CA-ATT-02: exhausting cap=2 on second failure → status=escalated, attempts=2
#   CA-ATT-03: --reset-attempts on escalated → status=open, attempts=0
#   CA-ATT-04: releasing to done never increments attempts
#   CA-ATT-05: row without max_attempts/attempts fields defaults to cap=3 / attempts=0
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE="${SCRIPT_DIR}/../skills/init/assets/bin/release.sh"
QUEUE_BRANCH="arsenal-queue"
export ARSENAL_QUEUE_BRANCH="${QUEUE_BRANCH}"

if [[ ! -f "${RELEASE}" ]]; then
    echo "SKIP: release.sh not found at ${RELEASE}" >&2; exit 0
fi

tmpremote=$(mktemp -d)
tmpwork=$(mktemp -d)
cleanup() { rm -rf "${tmpremote}" "${tmpwork}"; }
trap cleanup EXIT

git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD "refs/heads/${QUEUE_BRANCH}"

cd "${tmpwork}"
git init -q -b "${QUEUE_BRANCH}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git remote add origin "${tmpremote}"

# Seed queue with three tasks:
#   lo-t001  cap=3, attempts=0  (test CA-ATT-01)
#   lo-t002  cap=2, attempts=0  (test CA-ATT-02)
#   lo-t003  cap=3, attempts=0, no max_attempts/attempts  (test CA-ATT-05 via old-row compat)
#   lo-t004  cap=3, attempts=0  (test CA-ATT-04 with done)
mkdir -p claude-arsenal/queue
python3 - <<'PY'
import json
rows = [
    {"id":"lo-t001","title":"Cap3","status":"in_progress","priority":0,"requires":[],"deps":[],"assignee":"s","payload":"lo-t001.md","max_attempts":3,"attempts":0},
    {"id":"lo-t002","title":"Cap2","status":"in_progress","priority":0,"requires":[],"deps":[],"assignee":"s","payload":"lo-t002.md","max_attempts":2,"attempts":0},
    {"id":"lo-t003","title":"OldRow","status":"in_progress","priority":0,"requires":[],"deps":[],"assignee":"s","payload":"lo-t003.md"},
    {"id":"lo-t004","title":"Done","status":"in_progress","priority":0,"requires":[],"deps":[],"assignee":"s","payload":"lo-t004.md","max_attempts":3,"attempts":0},
]
with open("claude-arsenal/queue/tasks.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r, separators=(",",":")) + "\n")
PY
git add claude-arsenal/queue/tasks.jsonl
git commit -q -m "init: seed queue"
git push -q -u origin "${QUEUE_BRANCH}"

queue_field() {
    python3 -c "
import json, sys
for line in open('claude-arsenal/queue/tasks.jsonl'):
    r = json.loads(line)
    if r['id'] == sys.argv[1]:
        print(r.get(sys.argv[2], ''))
" "$1" "$2"
}

# --- CA-ATT-01: first failure increments attempts, stays open (cap=3) ---
if ! bash "${RELEASE}" lo-t001 open >/dev/null 2>&1; then
    echo "FAIL CA-ATT-01: release to open should succeed" >&2; exit 1
fi
if [[ "$(queue_field lo-t001 status)" != "open" ]]; then
    echo "FAIL CA-ATT-01: status should be open after first failure, got $(queue_field lo-t001 status)" >&2; exit 1
fi
if [[ "$(queue_field lo-t001 attempts)" != "1" ]]; then
    echo "FAIL CA-ATT-01: attempts should be 1, got $(queue_field lo-t001 attempts)" >&2; exit 1
fi
echo "PASS CA-ATT-01: first failure → open, attempts=1"

# --- CA-ATT-02: two failures with cap=2 → escalated on second ---
# First failure
bash "${RELEASE}" lo-t002 open >/dev/null 2>&1
if [[ "$(queue_field lo-t002 status)" != "open" ]]; then
    echo "FAIL CA-ATT-02: status should be open after first failure" >&2; exit 1
fi
if [[ "$(queue_field lo-t002 attempts)" != "1" ]]; then
    echo "FAIL CA-ATT-02: attempts should be 1 after first failure" >&2; exit 1
fi
# Need to put back in_progress for second attempt
python3 - <<'PY'
import json
rows = []
with open("claude-arsenal/queue/tasks.jsonl") as f:
    for line in f:
        r = json.loads(line)
        if r["id"] == "lo-t002":
            r["status"] = "in_progress"
            r["assignee"] = "s"
        rows.append(r)
with open("claude-arsenal/queue/tasks.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r, separators=(",",":")) + "\n")
PY
git add claude-arsenal/queue/tasks.jsonl && git commit -q -m "test: reset lo-t002 in_progress"
git push -q origin "${QUEUE_BRANCH}"

# Second failure → should escalate
bash "${RELEASE}" lo-t002 open >/dev/null 2>&1
if [[ "$(queue_field lo-t002 status)" != "escalated" ]]; then
    echo "FAIL CA-ATT-02: status should be escalated after cap exhausted, got $(queue_field lo-t002 status)" >&2; exit 1
fi
if [[ "$(queue_field lo-t002 attempts)" != "2" ]]; then
    echo "FAIL CA-ATT-02: attempts should be 2, got $(queue_field lo-t002 attempts)" >&2; exit 1
fi
echo "PASS CA-ATT-02: cap=2 exhausted → escalated, attempts=2"

# --- CA-ATT-03: --reset-attempts on escalated → open, attempts=0 ---
bash "${RELEASE}" lo-t002 open --reset-attempts >/dev/null 2>&1
if [[ "$(queue_field lo-t002 status)" != "open" ]]; then
    echo "FAIL CA-ATT-03: status should be open after reset, got $(queue_field lo-t002 status)" >&2; exit 1
fi
if [[ "$(queue_field lo-t002 attempts)" != "0" ]]; then
    echo "FAIL CA-ATT-03: attempts should be 0 after reset, got $(queue_field lo-t002 attempts)" >&2; exit 1
fi
echo "PASS CA-ATT-03: --reset-attempts → open, attempts=0"

# --- CA-ATT-04: releasing to done never increments attempts ---
bash "${RELEASE}" lo-t004 done --pr "https://example.com/pr/99" >/dev/null 2>&1
if [[ "$(queue_field lo-t004 status)" != "done" ]]; then
    echo "FAIL CA-ATT-04: status should be done, got $(queue_field lo-t004 status)" >&2; exit 1
fi
if [[ "$(queue_field lo-t004 attempts)" != "0" ]]; then
    echo "FAIL CA-ATT-04: attempts should remain 0 after done release, got $(queue_field lo-t004 attempts)" >&2; exit 1
fi
echo "PASS CA-ATT-04: done release does not increment attempts"

# --- CA-ATT-05: old row (no max_attempts/attempts) defaults to cap=3 ---
# lo-t003 starts as in_progress with no schema fields.
# Three failures should exhaust the default cap=3 and escalate.

reset_t003_inprogress() {
    python3 - <<'PY'
import json
rows = []
with open("claude-arsenal/queue/tasks.jsonl") as f:
    for line in f:
        r = json.loads(line)
        if r["id"] == "lo-t003":
            r["status"] = "in_progress"
            r["assignee"] = "s"
        rows.append(r)
with open("claude-arsenal/queue/tasks.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r, separators=(",",":")) + "\n")
PY
}

# Attempt 1: already in_progress, release directly
bash "${RELEASE}" lo-t003 open >/dev/null 2>&1
# Reset for attempt 2
reset_t003_inprogress
git add claude-arsenal/queue/tasks.jsonl && git commit -q -m "test: reset lo-t003 in_progress attempt 2"
git push -q origin "${QUEUE_BRANCH}"
# Attempt 2
bash "${RELEASE}" lo-t003 open >/dev/null 2>&1
# Reset for attempt 3
reset_t003_inprogress
git add claude-arsenal/queue/tasks.jsonl && git commit -q -m "test: reset lo-t003 in_progress attempt 3"
git push -q origin "${QUEUE_BRANCH}"
# Attempt 3 — should escalate (default cap=3)
bash "${RELEASE}" lo-t003 open >/dev/null 2>&1
if [[ "$(queue_field lo-t003 status)" != "escalated" ]]; then
    echo "FAIL CA-ATT-05: old row should escalate after 3 failures (default cap=3), got $(queue_field lo-t003 status)" >&2; exit 1
fi
echo "PASS CA-ATT-05: old row (no schema fields) defaults cap=3 → escalates on third failure"

echo ""
echo "All CA-ATT tests passed."
