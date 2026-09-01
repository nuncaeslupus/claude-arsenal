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

# Gate 8b (#239): the unattended planner does not CREATE an ambiguous handle.
# Two task files folding to one unresolved issue's loose title means that issue
# is the handle for at most one of them, and this caller has nobody to ask. It
# reports the collision and creates nothing; a session reading the same rows can
# still weigh it.
ambi="${tmp}/ambi"
mkdir -p "${ambi}"
for _pair in "t-ambi0001:Add A/B" "t-ambi0002:Add AB" "t-solo0001:Something else"; do
    cat > "${ambi}/${_pair%%:*}.md" <<MD
---
id: ${_pair%%:*}
title: "${_pair#*:}"
priority: 5
---

## Acceptance gate
\`\`\`bash
true
\`\`\`
MD
done
cat > "${tmp}/issues-ambi.json" <<'JSON'
[{"number": 60, "state": "open", "labels": [{"name": "arsenal:task"}], "title": "Add A-B"}]
JSON
python3 - "${HOOKS}" "${ambi}" "${tmp}/issues-ambi.json" <<'AMBI' || fail "ambiguous handles must be reported, not created"
import importlib.util, json, sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("queue_hooks", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec.loader.exec_module(mod)

tasks, _ = mod.load_tasks(Path(sys.argv[2]))
issues = json.loads(Path(sys.argv[3]).read_text())
actions = mod.plan_sync_handles(tasks, issues)
created = {a["task"] for a in actions if a["kind"] == "create-issue"}
notes = " ".join(a["message"] for a in actions if a["kind"] == "note")
assert created == {"t-solo0001"}, created
assert "t-ambi0001" in notes and "t-ambi0002" in notes, notes
assert "#60" in notes, notes
AMBI
echo "PASS: an ambiguous handle is reported by the unattended planner, never created"

# Gate 9 (#146): a board carrying both priority conventions is reported. Neither
# scale is wrong alone; the mix is, because a rank scale's floor sits above the
# size scale's ceiling, so every rank-encoded task outranks every sized one
# regardless of intent and dispatch order comes to reflect authorship date.
mixed="${tmp}/mixed"
mkdir -p "${mixed}"
write_task t-size1 "${mixed}"
write_task t-rank1 "${mixed}"
sed -i.bak 's/^priority: 5$/priority: 95/' "${mixed}/t-rank1.md" && rm -f "${mixed}"/*.bak
out=$(python3 "${STATUS}" --tasks-dir "${mixed}" 2>&1 >/dev/null)
echo "${out}" | grep -q "mixed-priority-convention" || fail "a mixed board was not reported: ${out}"
# A board on one scale throughout stays clean — the finding is about the mix.
sed -i.bak 's/^priority: 95$/priority: 10/' "${mixed}/t-rank1.md" && rm -f "${mixed}"/*.bak
out=$(python3 "${STATUS}" --tasks-dir "${mixed}" 2>&1 >/dev/null)
if echo "${out}" | grep -q "mixed-priority-convention"; then
    fail "a single-convention board must not be reported: ${out}"
fi
echo "PASS: a board mixing size and rank priorities is reported; one scale is not"

# Gate 10 (#171): --json exposes the DERIVED terminal state, so a host's gate
# verifier stops reading the payload's `status:` and being wrong about every
# task whose issue closed without the file being stamped. Terminality is the
# union: either source saying finished is a fact.
derived="${tmp}/derived"
mkdir -p "${derived}/_history"
write_task t-arch "${derived}/_history"
printf -- '---\nid: t-arch\ntitle: "archived"\npriority: 5\nstatus: merged\n---\n\n```bash\ntrue\n```\n' \
    > "${derived}/_history/t-arch.md"
write_task t-live "${derived}"
cat > "${tmp}/derived-issues.json" <<'JSON'
[{"number":30,"state":"open","body":"`arsenal-task: t-arch`"},
 {"number":31,"state":"closed","state_reason":"completed","body":"`arsenal-task: t-live`"}]
JSON
rows=$(python3 "${STATUS}" --tasks-dir "${derived}" --issues "${tmp}/derived-issues.json" --json 2>/dev/null)
echo "${rows}" | grep -q '"id":"t-arch".*"terminal":true' \
    || fail "a file-archived task must read terminal even with an open issue: ${rows}"
echo "${rows}" | grep -q '"id":"t-live".*"terminal":true' \
    || fail "a task whose issue closed as completed must read terminal without a status: field: ${rows}"
echo "${rows}" | grep -q '"issue":31' || fail "--json should carry the issue number: ${rows}"
echo "PASS: --json reports terminality derived from either the issue or the file"

# Gate 12: the unattended caller surfaces what it held back. `missing_handles`
# takes a warnings list, and this planner passed none — so in the scheduled
# `sync-handles` job a task held back as a near-match produced no action, no
# diagnostic, and a "nothing to do" summary. The warning existed and was
# reachable only from the interactive path, where somebody is already watching.
near="${tmp}/near"
mkdir -p "${near}"
cat > "${near}/t-9999aaaa.md" <<'MD'
---
id: t-9999aaaa
title: "Broaden the corpus — annotations/<offer_id>.json, >=6 job families"
priority: 5
---

## Acceptance gate
```bash
true
```
MD
cat > "${tmp}/near-issues.json" <<'JSON'
[{"number": 70, "state": "open", "labels": [{"name": "arsenal:task"}],
  "title": "Broaden the corpus - annotations/.json, \u22656 job families"}]
JSON
plan=$(python3 "${HOOKS}" sync-handles --tasks-dir "${near}" --issues "${tmp}/near-issues.json" --dry-run)
if echo "${plan}" | grep -q '"task":"t-9999aaaa"'; then
    fail "a near-match must still not draw a second handle: ${plan}"
fi
echo "${plan}" | grep -q '"kind":"note"' \
    || fail "holding a task back unattended must produce a note, not silence: ${plan}"
echo "${plan}" | grep -q '#70' || fail "the note must name the issue to fix: ${plan}"
echo "PASS: a suppressed handle is reported by the unattended planner"

# --- a fork PR decides nothing about this queue (#265, #302) ----------------
# The workflow calling this runs on `pull_request_target` with `issues: write`,
# and task identity comes from `head.ref` and the PR body — both of which a fork
# author writes. Without a head-repo check, a fork PR closed without merging
# reaches `release-claim` and strips a claim another session legitimately holds.
# An `arsenal/*` head ref proves nothing: fork authors name their own branches.
cat > "${tmp}/fork-event.json" <<'JSON'
{"repository": {"default_branch": "main", "full_name": "owner/repo"},
 "pull_request": {"number": 7, "html_url": "https://example/pull/7", "merged": false,
   "body": "`arsenal-task: t-aaaa1111`",
   "head": {"ref": "arsenal/t-aaaa1111-do-the-thing",
            "repo": {"full_name": "attacker/repo"}},
   "base": {"ref": "main", "repo": {"full_name": "owner/repo"}}}}
JSON
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/fork-event.json" --dry-run)
if echo "${plan}" | grep -qE '"kind":"(release-claim|close-issue|archive-task)"'; then
    fail "a FORK PR reached a queue mutation: ${plan}"
fi
echo "${plan}" | grep -q 'opened from fork' || fail "the fork refusal does not say why: ${plan}"

# ...and the same PR from the repo itself still works, so the check is a fork
# check and not a blanket refusal.
cat > "${tmp}/same-event.json" <<'JSON'
{"repository": {"default_branch": "main", "full_name": "owner/repo"},
 "pull_request": {"number": 8, "html_url": "https://example/pull/8", "merged": false,
   "body": "", "head": {"ref": "arsenal/t-aaaa1111-do-the-thing",
            "repo": {"full_name": "owner/repo"}},
   "base": {"ref": "main", "repo": {"full_name": "owner/repo"}}}}
JSON
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/same-event.json" --dry-run)
echo "${plan}" | grep -q '"kind":"release-claim"' \
    || fail "a same-repo PR must still release its claim: ${plan}"
# A deleted or newly-private fork is sent as `head.repo: null`, which is not
# proof of a same-repo PR — it is the same fork with its provenance missing. A
# check keyed on the head repo being *present* fails open on exactly the payload
# an attacker can produce on demand by deleting their fork after opening the PR.
cat > "${tmp}/gone-fork-event.json" <<'JSON'
{"repository": {"default_branch": "main", "full_name": "owner/repo"},
 "pull_request": {"number": 9, "html_url": "https://example/pull/9", "merged": false,
   "body": "`arsenal-task: t-aaaa1111`",
   "head": {"ref": "arsenal/t-aaaa1111-do-the-thing", "repo": null},
   "base": {"ref": "main", "repo": {"full_name": "owner/repo"}}}}
JSON
plan=$(python3 "${HOOKS}" pr-closed --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
        --event "${tmp}/gone-fork-event.json" --dry-run)
if echo "${plan}" | grep -qE '"kind":"(release-claim|close-issue|archive-task)"'; then
    fail "a fork PR with a deleted head repo reached a queue mutation: ${plan}"
fi

echo "PASS: a fork PR cannot close or release a task; a same-repo PR still can"

# --- the closing keyword must name THIS task's issue (#302, #265) -----------
# Accepting any `Closes #N` let a task PR pass the guard while pointing at an
# unrelated issue: that issue closed on merge and the task's own one stayed open
# and claimed — the drift the guard exists to prevent, with a green check on it.
guard() {  # guard <body> <commits-json> -> prints verdict, returns exit code
    cat > "${tmp}/guard-event.json" <<JSON
{"repository": {"default_branch": "main", "full_name": "owner/repo"},
 "pull_request": {"number": 9, "html_url": "https://example/pull/9",
   "body": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"),
   "head": {"ref": "arsenal/t-aaaa1111-do-the-thing",
            "repo": {"full_name": "owner/repo"}},
   "base": {"ref": "main", "repo": {"full_name": "owner/repo"}}}}
JSON
    printf '%s' "$2" > "${tmp}/guard-commits.json"
    python3 "${HOOKS}" keyword-guard --tasks-dir "${tasks}" \
        --issues "${tmp}/issues.json" --event "${tmp}/guard-event.json" \
        --commits "${tmp}/guard-commits.json" 2>&1
}

guard "Closes #10" '[]' >/dev/null || fail "a PR closing its own issue (#10) must pass"
out=$(guard "Closes #99" '[]') && fail "a PR closing an UNRELATED issue must not pass: ${out}"
grep -q '#10' <<<"${out}" || fail "the refusal must name the right issue: ${out}"
grep -q '#99' <<<"${out}" || fail "the refusal must name what was referenced instead: ${out}"

out=$(guard "no keyword here" '[]') && fail "a PR with no closing keyword must not pass"
grep -q 'Closes #10' <<<"${out}" || fail "the refusal must say what to add: ${out}"

# A stacked PR carries its keyword in a commit message rather than the body.
guard "" '["chore: wip", "feat: the thing\n\nCloses #10"]' >/dev/null \
    || fail "a keyword in a commit message must satisfy the guard"

# A branch that is not a known task is not this guard's business.
cat > "${tmp}/guard-event.json" <<'JSON'
{"repository": {"default_branch": "main", "full_name": "owner/repo"},
 "pull_request": {"number": 9, "html_url": "https://example/pull/9", "body": "",
   "head": {"ref": "arsenal/not-a-task", "repo": {"full_name": "owner/repo"}},
   "base": {"ref": "main", "repo": {"full_name": "owner/repo"}}}}
JSON
echo '[]' > "${tmp}/guard-commits.json"
python3 "${HOOKS}" keyword-guard --tasks-dir "${tasks}" --issues "${tmp}/issues.json" \
    --event "${tmp}/guard-event.json" --commits "${tmp}/guard-commits.json" >/dev/null 2>&1 \
    || fail "an unknown branch must pass the guard, not fail it"
echo "PASS: the closing keyword must name the task's own issue"

echo "PASS: queue_hooks_test — all gates passed"
