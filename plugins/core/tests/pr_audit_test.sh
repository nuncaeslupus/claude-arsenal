#!/usr/bin/env bash
# pr_audit_test.sh — the two shortcuts that merge a fleet on no evidence.
#
# Every session that merged used to write its own `gh ... --jq` for "is this
# head green, gated and read?", and the bugs were not random. Both are the
# reading the shell makes easy:
#
#   * no failing checks read as green, when what the repo produced was NO
#     CHECKS AT ALL — during a runner outage that merges everything;
#   * a review's summary state read as the finding list, when a bot reports
#     "review completed" with three threads still open.
#
# A third came from the fleet: conditions evaluated against the PR rather than
# against its HEAD, so a check run and a review from two pushes ago both counted.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="${SCRIPT_DIR}/../skills/init/assets/scripts/pr_audit.py"
[[ -f "${AUDIT}" ]] || { echo "SKIP: pr_audit.py not found at ${AUDIT}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

HEAD=1111111111111111111111111111111111111111
OLD=2222222222222222222222222222222222222222

# `--repo-root` points at an empty dir so no stray arsenal/config.toml is read.
run() { python3 "${AUDIT}" --repo-root "${tmp}/empty" --prs "${tmp}/prs.json" "$@"; }
mkdir -p "${tmp}/empty"

pr() {  # pr <extra-json-fields>
    cat > "${tmp}/prs.json" <<JSON
[{"number":7,"title":"T12","created_at":"2026-09-14T00:00:00Z",
  "head":{"sha":"${HEAD}","ref":"arsenal/task/T12"}, $1}]
JSON
}
state() { python3 -c "import json,sys;d=json.load(sys.stdin)['prs'][0];print(d[sys.argv[1]])" "$1"; }

# --- absent is not green -----------------------------------------------------
# A repo out of runner minutes, with no workflows, or whose jobs die before a
# runner is assigned has produced no evidence. "No failures" is not a pass.
pr '"checks":[],"reviews":[],"threads":[]'
[[ "$(run --policy after-ci --json | state ci)" == "absent" ]] \
    || fail "zero checks must report absent, not green"
run --policy after-ci --require-ready >/dev/null 2>&1
[[ $? -eq 1 ]] || fail "a PR with no checks must not be ready under after-ci"
run --policy after-ci | grep -qi "absent is not green" \
    || fail "the report should say why no checks blocks"
echo "PASS: no checks at all is blocked, not green"

# --- a check that reported on an earlier push is about that push -------------
pr "\"checks\":[{\"name\":\"ci\",\"status\":\"completed\",\"conclusion\":\"success\",\"head_sha\":\"${OLD}\"}],\"reviews\":[],\"threads\":[]"
[[ "$(run --policy after-ci --json | state ci)" == "stale" ]] \
    || fail "a check run on an older sha must not count as green on the head"
echo "PASS: checks are evidence about the sha they ran on"

# --- pending is not green, and a failure names itself ------------------------
pr "\"checks\":[{\"name\":\"ci\",\"status\":\"in_progress\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
[[ "$(run --policy after-ci --json | state ci)" == "pending" ]] || fail "a running check is pending"
pr "\"checks\":[{\"name\":\"lint\",\"status\":\"completed\",\"conclusion\":\"failure\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
[[ "$(run --policy after-ci --json | state ci)" == "failing" ]] || fail "a failed check is failing"
run --policy after-ci | grep -q "lint" || fail "the next action should name the failing check"
# ...but `skipped` and `neutral` are how a matrix job says "not applicable".
pr "\"checks\":[{\"name\":\"win\",\"status\":\"completed\",\"conclusion\":\"skipped\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
[[ "$(run --policy after-ci --json | state ci)" == "green" ]] \
    || fail "skipped/neutral must not read as a red PR forever"
echo "PASS: pending, failing, skipped each read as themselves"

# --- a summary line is not the finding list ----------------------------------
pr "\"checks\":[],\"reviews\":[{\"state\":\"APPROVED\",\"commit_id\":\"${HEAD}\"}],\"threads\":[{\"id\":\"t1\",\"resolved\":false}]"
[[ "$(run --policy after-review --json | state review)" == "unresolved" ]] \
    || fail "an approval over an open thread must not read as clear"
run --policy after-review --require-ready >/dev/null 2>&1
[[ $? -eq 1 ]] || fail "an open thread is an unmet policy, not a judgement call"
echo "PASS: open threads beat an approval"

# --- a review of an earlier tree is not a review of this one -----------------
pr "\"checks\":[],\"reviews\":[{\"state\":\"APPROVED\",\"commit_id\":\"${OLD}\"}],\"threads\":[]"
[[ "$(run --policy after-review --json | state review)" == "stale" ]] \
    || fail "a review on an older sha must report stale"
run --policy after-review | grep -q "claim_review.sh" \
    || fail "the next action for a stale review should point at the review claim"
echo "PASS: review evidence is bound to the head it was given"

# --- a COMMENTED review is somebody talking, not a verdict -------------------
pr "\"checks\":[],\"reviews\":[{\"state\":\"COMMENTED\",\"commit_id\":\"${HEAD}\"}],\"threads\":[]"
[[ "$(run --policy after-review --json | state review)" == "absent" ]] \
    || fail "a COMMENTED review must not satisfy after-review"
echo "PASS: only APPROVED/CHANGES_REQUESTED count as a review"

# --- an unfetchable field is not an unsatisfiable gate -----------------------
# Thread resolution is GraphQL-only. On a REST-or-nothing surface `threads` is
# absent, and a condition no channel here can satisfy is a wall, not a gate —
# that is exactly the `review_reader check` failure this queue already has.
# It must still SAY so, or the report is quietly claiming something it did not
# check.
pr "\"checks\":[],\"reviews\":[{\"state\":\"APPROVED\",\"commit_id\":\"${HEAD}\"}]"
[[ "$(run --policy after-review --json | state review)" == "clear" ]] \
    || fail "an absent threads key must not block forever"
run --policy after-review | grep -qi "thread state unavailable" \
    || fail "an unread thread list must be reported as unread"
# ...while an EMPTY list is a real answer and carries no caveat.
pr "\"checks\":[],\"reviews\":[{\"state\":\"APPROVED\",\"commit_id\":\"${HEAD}\"}],\"threads\":[]"
run --policy after-review | grep -qi "thread state unavailable" \
    && fail "an empty thread list is an answer, not a missing one"
echo "PASS: absent threads is reported, not counted as zero and not a wall"

# --- policy routing ----------------------------------------------------------
pr "\"checks\":[{\"name\":\"ci\",\"status\":\"completed\",\"conclusion\":\"failure\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
run --policy always --require-ready >/dev/null 2>&1
[[ $? -eq 0 ]] || fail "under `always` the gates open_task_pr.sh ran are the whole gate"
run --policy after-review --require-ready >/dev/null 2>&1
[[ $? -eq 1 ]] || fail "after-review still needs a review"
pr "\"checks\":[{\"name\":\"ci\",\"status\":\"completed\",\"conclusion\":\"success\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
run --policy after-ci --require-ready >/dev/null 2>&1
[[ $? -eq 0 ]] || fail "after-ci must not consult reviews"
# `never` is the host saying no agent merges here — not a verdict about the PR.
# Reporting it as "not ready" sends a session off to fix conditions already met.
run --policy never --require-ready >/dev/null 2>&1
[[ $? -eq 3 ]] || fail "merge-policy never should exit 3, distinct from not-ready"
echo "PASS: each policy consults exactly what it names"

# --- a draft and a conflict outrank everything else --------------------------
pr "\"draft\":true,\"checks\":[{\"name\":\"ci\",\"status\":\"completed\",\"conclusion\":\"success\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
run --policy after-ci | grep -qi "draft" || fail "a green draft's next action is to un-draft it"
pr "\"mergeable\":false,\"checks\":[{\"name\":\"ci\",\"status\":\"completed\",\"conclusion\":\"success\",\"head_sha\":\"${HEAD}\"}],\"reviews\":[],\"threads\":[]"
run --policy after-ci | grep -qi "conflict" || fail "a conflict must be the named next action"
run --policy after-ci --require-ready >/dev/null 2>&1
[[ $? -eq 1 ]] || fail "a conflicted PR is not ready however green it is"
echo "PASS: draft and conflict are reported before the gates"

# --- claims nothing is working on -------------------------------------------
# A sandboxed session cannot delete a claim ref, so the ref outlives the work
# and nothing anywhere says "claimed, and no session is on it".
pr "\"checks\":[],\"reviews\":[],\"threads\":[]"
cat > "${tmp}/claims.json" <<'JSON'
[{"ref":"arsenal/claims/T12","task_id":"T12","created_at":"2020-01-01T00:00:00Z"},
 {"ref":"arsenal/claims/T99","task_id":"T99","created_at":"2020-01-01T00:00:00Z"},
 {"ref":"arsenal/claims/T50","task_id":"T50","created_at":"2999-01-01T00:00:00Z"}]
JSON
# Read the JSON, not the table: the PR row prints its own title, so grepping the
# whole report for a task id finds the PR and reports a stale claim that is not.
named=$(run --policy after-ci --claims "${tmp}/claims.json" --json \
    | python3 -c "import json,sys;print(' '.join(c['task_id'] for c in json.load(sys.stdin)['stale_claims']))")
[[ "${named}" == "T99" ]] \
    || fail "only the old claim with no open PR is stale, got '${named}'"
run --policy after-ci --claims "${tmp}/claims.json" | grep -q "no open PR" \
    || fail "the table should carry the stale-claim section too"
echo "PASS: stale claims are the ones with no open PR and no recency"

# --- bad input is an error, not an empty report ------------------------------
printf 'not json\n' > "${tmp}/prs.json"
run --policy after-ci >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "unparseable input should exit 2"
printf '{"number":1}\n' > "${tmp}/prs.json"
run --policy after-ci >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "a JSON object is not an array of PR records"
echo "PASS: bad payloads exit 2"

echo "PASS: pr_audit_test — conditions are evaluated against the head, once"
exit 0
