#!/usr/bin/env bash
# query_status_handles_test.sh — the handle check distinguishes "no handle" from
# "I did not ask".
#
# `query_status.py` resolves a task's issue handle from the `--issues` JSON the
# caller fetched. When no such file is passed it used to report every task as
# `no issue handle`, which is not an answer: nothing was consulted. That made
# the handle check simultaneously unfailable and unpassable for any caller
# without a GitHub channel — including `make queue-doctor`, whose whole purpose
# is to run this audit locally, and which therefore could never go green once
# the board held a single task.
#
# Three cases, one per reachable answer:
#   no --issues   → skipped, reported as skipped, exit 0
#   --issues, hit → handle found, exit 0
#   --issues, miss→ handle genuinely missing, exit 1
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
qs="$here/../skills/init/assets/scripts/query_status.py"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

tasks="$tmp/tasks"; mkdir -p "$tasks"
cat > "$tasks/t-11112222.md" <<'TASK'
---
id: t-11112222
title: A task with a real gate
priority: 5
---

## Acceptance gate

```bash
true
```
TASK

# --- no --issues: the check is skipped and says so --------------------------
out="$(python3 "$qs" --tasks-dir "$tasks" --detail --fail-on-problems 2>&1)"
rc=$?
[ "$rc" -eq 0 ] || fail "no --issues: exited $rc; an unasked question is not a problem"
grep -q "handles and issue state not checked" <<<"$out" \
    || fail "no --issues: skipping the check was not reported"
grep -q "no issue handle" <<<"$out" \
    && fail "no --issues: reported a missing handle it never looked for"
grep -q "handle?" <<<"$out" || fail "no --issues: detail row not marked 'handle?'"
echo "PASS: no --issues — handle check skipped, reported, exit 0"

# --- --issues that carries the handle ---------------------------------------
cat > "$tmp/hit.json" <<'JSON'
[{"number": 7, "title": "A task with a real gate", "state": "open", "labels": [], "assignees": [],
  "body": "`arsenal-task: t-11112222`"}]
JSON
out="$(python3 "$qs" --tasks-dir "$tasks" --detail --fail-on-problems --issues "$tmp/hit.json" 2>&1)"
rc=$?
[ "$rc" -eq 0 ] || fail "handle present: exited $rc — $out"
grep -q "handle?" <<<"$out" && fail "handle present: still marked 'handle?' with issues supplied"
echo "PASS: --issues with the handle — clean, exit 0"

# --- --issues that does NOT carry it: a real, failing finding ----------------
echo '[{"number": 9, "title": "Something else", "state": "open", "labels": [], "assignees": []}]' \
    > "$tmp/miss.json"
out="$(python3 "$qs" --tasks-dir "$tasks" --detail --fail-on-problems --issues "$tmp/miss.json" 2>&1)"
rc=$?
[ "$rc" -eq 1 ] || fail "handle missing: exited $rc, expected 1 — the check must still bite"
grep -q "no issue handle" <<<"$out" || fail "handle missing: finding not reported"
echo "PASS: --issues without the handle — reported, exit 1"

echo "PASS: query_status_handles_test.sh"

# --- an archived task whose PR has not merged is not drift ------------------
# `open_task_pr.sh` archives the task file in the SAME diff that closes its
# issue, so between opening a PR and merging it every task that PR finishes
# reads archived-with-an-open-issue. Reporting that as drift makes the
# documented workflow unable to produce a green PR — the same shape as
# reporting a missing handle nobody looked for.
archived="$tmp/archived"; mkdir -p "$archived"
cat > "$archived/t-33334444.md" <<'TASK'
---
id: t-33334444
title: A task archived by a PR still in flight
priority: 5
status: merged
---

## Acceptance gate

```bash
true
```
TASK
cat > "$tmp/open.json" <<'JSON'
[{"number": 42, "title": "A task archived by a PR still in flight", "state": "open",
  "labels": [], "assignees": [], "body": "`arsenal-task: t-33334444`"}]
JSON

out="$(python3 "$qs" --tasks-dir "$archived" --detail --fail-on-problems --issues "$tmp/open.json" 2>&1)"
rc=$?
[ "$rc" -eq 1 ] || fail "on the default branch, archived-but-open must still be drift (got $rc)"
grep -q "the PR merged without closing it" <<<"$out" || fail "the drift was not reported"

out="$(python3 "$qs" --tasks-dir "$archived" --detail --fail-on-problems --pending-merge \
    --issues "$tmp/open.json" 2>&1)"
rc=$?
[ "$rc" -eq 0 ] || fail "--pending-merge: the in-flight state must not fail the build (got $rc)"
grep -q "expected until this branch merges" <<<"$out" \
    || fail "--pending-merge silently dropped the observation instead of noting it"
echo "PASS: --pending-merge — in flight is a note, on main it is still drift"
