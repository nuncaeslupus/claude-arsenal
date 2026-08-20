#!/usr/bin/env bash
# queue_hooks_test.sh — the queue transitions GitHub performs without a session.
#
# Every case runs the planner (`--dry-run`), never the API: deciding what a
# closed PR means for the board is the part that can be wrong, and it is pure.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="${SCRIPT_DIR}/../skills/init/assets/scripts/queue_hooks.py"
STATUS="${SCRIPT_DIR}/../skills/init/assets/scripts/query_status.py"

[[ -f "${HOOKS}" ]] || { echo "SKIP: queue_hooks.py not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
tasks="${tmp}/tasks"
mkdir -p "${tasks}/_history"

fail() { echo "FAIL: $*" >&2; exit 1; }

write_task() {  # write_task <id> <dir>
    cat > "$2/$1.md" <<MD
---
id: $1
title: "Task $1"
priority: 5
---

## Acceptance gate
\`\`\`bash
true
\`\`\`
MD
}
write_task t-aaaa1111 "${tasks}"
write_task t-bbbb2222 "${tasks}"

cat > "${tmp}/issues.json" <<'JSON'
[
  {"number": 10, "state": "open", "updated_at": "2026-01-01T00:00:00Z",
   "labels": [{"name": "arsenal:task"}, {"name": "arsenal:claimed"}],
   "body": "`arsenal-task: t-aaaa1111`"},
  {"number": 11, "state": "open", "updated_at": "2026-06-01T00:00:00Z",
   "labels": [{"name": "arsenal:task"}, {"name": "arsenal:claimed"}],
   "body": "`arsenal-task: t-bbbb2222`"}
]
JSON

pr_event() {  # pr_event <head-ref> <merged true|false> > file
    cat <<JSON
{"repository": {"default_branch": "main"},
 "pull_request": {"number": 5, "html_url": "https://example/pull/5",
  "merged": $2, "body": "", "head": {"ref": "$1"}, "base": {"ref": "main"}}}
JSON
}

# Gate 1: a merged task PR whose keyword never fired still closes the task.
# Without this the work lands and the board keeps the task claimed forever —
# the exact failure the queue's `Closes #N` mechanism is supposed to prevent,
# and the one that silently does nothing when the keyword is missing.
pr_event "arsenal/t-aaaa1111-do-the-thing" true > "${tmp}/event.json"
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/event.json" --dry-run)
echo "${plan}" | grep -q '"kind":"close-issue"' || fail "merged PR did not plan to close its issue: ${plan}"
echo "${plan}" | grep -q '"issue":10' || fail "closed the wrong issue: ${plan}"
echo "${plan}" | grep -q '"kind":"archive-task"' || fail "merged PR did not plan to archive its task file: ${plan}"
echo "PASS: a merged task PR closes and archives its task"

# Gate 1b: a merge into a NON-default branch completes nothing. A stacked PR
# targets the previous branch in the stack, so its work has not landed yet —
# GitHub's own `Closes` keyword has this rule, and a backstop looser than the
# mechanism it backs up would quietly undo it.
cat > "${tmp}/event.json" <<'JSON'
{"repository": {"default_branch": "main"},
 "pull_request": {"number": 6, "html_url": "https://example/pull/6", "merged": true,
   "body": "", "head": {"ref": "arsenal/t-aaaa1111-do-the-thing"},
   "base": {"ref": "arsenal/t-bbbb2222-earlier-task"}}}
JSON
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/event.json" --dry-run)
if echo "${plan}" | grep -qE '"kind":"(close-issue|archive-task)"'; then
    fail "a stacked merge completed the task before it reached the default branch: ${plan}"
fi
echo "${plan}" | grep -q '"kind":"note"' || fail "stacked merge should plan a note: ${plan}"
echo "PASS: a merge into a non-default branch completes nothing"

# Gate 2: a PR closed WITHOUT merging releases the claim. The task is not done,
# so leaving the label on would hide it from every future selector.
pr_event "arsenal/t-aaaa1111-do-the-thing" false > "${tmp}/event.json"
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/event.json" --dry-run)
echo "${plan}" | grep -q '"kind":"release-claim"' || fail "abandoned PR did not release the claim: ${plan}"
if echo "${plan}" | grep -q '"kind":"close-issue"'; then fail "abandoned PR must not close the task: ${plan}"; fi
echo "PASS: a PR closed without merging releases the claim"

# Gate 3: a PR on a non-task branch is left entirely alone.
pr_event "feat/unrelated-work" true > "${tmp}/event.json"
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/event.json" --dry-run)
echo "${plan}" | grep -q '"kind":"note"' || fail "non-task PR should plan only a note: ${plan}"
if echo "${plan}" | grep -qE '"kind":"(close-issue|release-claim)"'; then fail "non-task PR touched the queue: ${plan}"; fi
echo "PASS: a PR outside arsenal/ never touches the queue"

# Gate 4: branch matching prefers the longest task id, so a short id cannot
# swallow a branch belonging to a longer one whose name starts the same way.
write_task t-aaaa "${tasks}"
cat > "${tmp}/issues-prefix.json" <<'JSON'
[
  {"number": 10, "state": "open", "labels": [{"name": "arsenal:task"}],
   "body": "`arsenal-task: t-aaaa1111`"},
  {"number": 12, "state": "open", "labels": [{"name": "arsenal:task"}],
   "body": "`arsenal-task: t-aaaa`"}
]
JSON
pr_event "arsenal/t-aaaa1111-do-the-thing" true > "${tmp}/event.json"
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues-prefix.json" \
        --event "${tmp}/event.json" --dry-run)
echo "${plan}" | grep -q '"issue":10' || fail "prefix collision addressed the wrong task: ${plan}"
rm "${tasks}/t-aaaa.md"
echo "PASS: the longest matching task id wins a branch-name collision"

# Gate 5: a stale claim with no open PR is released; a fresh one, or one with a
# live PR behind it, is left alone. Age alone must never release work in flight.
cat > "${tmp}/prs.json" <<'JSON'
[{"head": {"ref": "arsenal/t-bbbb2222-still-working"}}]
JSON
plan=$(python3 "${HOOKS}" sweep-claims --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --prs "${tmp}/prs.json" --now "2026-06-02T00:00:00Z" --max-age-hours 24 --dry-run)
echo "${plan}" | grep -q '"issue":10' || fail "stale claim on #10 was not released: ${plan}"
if echo "${plan}" | grep -q '"issue":11'; then fail "claim with an open PR must not be released: ${plan}"; fi
echo "PASS: stale claims are released, claims with open PRs are not"

# Gate 6: a task file with no issue gets a handle planned; one already handled
# does not. This is what stops a new session from opening with queue chores.
write_task t-cccc3333 "${tasks}"
plan=$(python3 "${HOOKS}" sync-handles --tasks-dir "${tasks}" --issues "${tmp}/issues.json" --dry-run)
echo "${plan}" | grep -q '"task":"t-cccc3333"' || fail "missing handle was not planned: ${plan}"
if echo "${plan}" | grep -q '"task":"t-aaaa1111"'; then fail "already-handled task proposed again: ${plan}"; fi
echo "PASS: only task files without an issue get a handle"

# Gate 7: query_status reports completion drift in both directions. Merging is
# meant to be the single act that finishes a task; when only half of it
# happened, that has to fail a check rather than wait to be discovered.
drift="${tmp}/drift"
mkdir -p "${drift}/_history"
write_task t-dddd4444 "${drift}/_history"
printf '%s\n' "$(sed 's/^priority: 5$/priority: 5\nstatus: merged/' "${drift}/_history/t-dddd4444.md")" \
    > "${drift}/_history/t-dddd4444.md"
write_task t-eeee5555 "${drift}"
cat > "${tmp}/drift-issues.json" <<'JSON'
[
  {"number": 20, "state": "open", "labels": [{"name": "arsenal:task"}],
   "body": "`arsenal-task: t-dddd4444`"},
  {"number": 21, "state": "closed", "state_reason": "completed",
   "labels": [{"name": "arsenal:task"}], "body": "`arsenal-task: t-eeee5555`"}
]
JSON
if out=$(python3 "${STATUS}" --tasks-dir "${drift}" --issues "${tmp}/drift-issues.json" \
         --fail-on-problems 2>&1); then
    fail "query_status should fail on completion drift, exited 0: ${out}"
fi
echo "${out}" | grep -q "archived as merged but #20 is still open" \
    || fail "merged-but-issue-open drift not reported: ${out}"
echo "${out}" | grep -q "#21 is closed as completed but the task file is still live" \
    || fail "closed-but-not-archived drift not reported: ${out}"
echo "PASS: query_status fails on a task and its issue disagreeing"

# Gate 8: `create-issue` reaches the API. It is the one action with no issue
# number — it is what creates one — so a guard that validated the number before
# dispatching by kind made the whole branch unreachable and `sync-handles` could
# plan a handle it would never open. Dry-run coverage cannot see that, so this
# drives apply_action against a stub API.
python3 - "${HOOKS}" <<'PY' || fail "create-issue does not reach the API"
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("queue_hooks", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec.loader.exec_module(mod)

calls = []


class StubApi:
    repo = "o/r"

    def request(self, method, path, body=None):
        calls.append((method, path, body))
        return {"number": 99}


ok = mod.apply_action(
    {"kind": "create-issue", "task": "t-x", "title": "T", "body": "b", "labels": ["arsenal:task"]},
    StubApi(),
    tasks_dir=Path("."),
)
assert ok, "apply_action rejected a create-issue action"
assert any(m == "POST" and p.endswith("/issues") for m, p, _ in calls), calls

# And an action that genuinely needs a number is still refused without one.
assert not mod.apply_action({"kind": "close-issue", "task": "t-x", "comment": "c"},
                            StubApi(), tasks_dir=Path("."))
PY
echo "PASS: create-issue reaches the API; close-issue without a number does not"

echo "PASS: queue_hooks_test — all gates passed"
