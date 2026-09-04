#!/usr/bin/env bash
# board_freshness_test.sh — the board says when it was computed from a stale
# tree (#351), and the selector refuses an --issues file it cannot read (#345).
#
# Both are the same failure shape: a check that answers without looking. A tree
# behind the remote reports every merged task as open, and an unreadable issue
# file leaves an empty state map that is indistinguishable from a healthy new
# board — so the selector hands out a task that is already finished.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets/scripts"
QUERY="${ASSETS}/query_status.py"
SELECT="${ASSETS}/task_select.py"

for f in "${QUERY}" "${SELECT}"; do
    [[ -f "$f" ]] || { echo "SKIP: $f not found" >&2; exit 0; }
done

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp=$(mktemp -d)
remote="${tmp}/remote.git"; work="${tmp}/work"; other="${tmp}/other"
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

_seed_task() {  # $1 = tasks dir, $2 = id
    mkdir -p "$1"
    printf -- '---\nid: %s\ntitle: "%s"\npriority: 1\n---\n\n## Acceptance gate\n```bash\ntrue\n```\n' \
        "$2" "$2" > "$1/$2.md"
}

git init -q --bare "${remote}"
git -C "${remote}" symbolic-ref HEAD refs/heads/main
git init -q -b main "${work}"
git -C "${work}" config user.email "test@arsenal.example"
git -C "${work}" config user.name "Arsenal Test"
git -C "${work}" remote add origin "${remote}"
_seed_task "${work}/arsenal/tasks" t1
git -C "${work}" add -A
git -C "${work}" commit -q -m "chore: seed"
git -C "${work}" push -q -u origin main 2>/dev/null

TASKS="${work}/arsenal/tasks"

# --- current tree: silent -----------------------------------------------------
out="$(cd "${work}" && python3 "${QUERY}" --tasks-dir "${TASKS}" 2>&1)"
grep -qE "behind|does not contain" <<<"${out}" \
    && fail "an up-to-date tree was reported stale: ${out}"
echo "PASS: an up-to-date tree draws no freshness warning"

# --- the remote moves on ------------------------------------------------------
git clone -q "${remote}" "${other}" 2>/dev/null
git -C "${other}" config user.email "test@arsenal.example"
git -C "${other}" config user.name "Arsenal Test"
for i in 1 2 3; do
    echo "$i" > "${other}/f${i}"
    git -C "${other}" add -A
    git -C "${other}" commit -q -m "chore: c${i}"
done
git -C "${other}" push -q origin main 2>/dev/null

# Un-fetched: the tip is not an object we hold, so the count is unknowable and
# the warning has to say that rather than claim the tree is current.
out="$(cd "${work}" && python3 "${QUERY}" --tasks-dir "${TASKS}" 2>&1)"
grep -q "does not contain origin/main" <<<"${out}" \
    || fail "a tree missing the remote tip was not reported: ${out}"
echo "PASS: a tree that does not hold the remote tip is reported"

# --json returns before the warning list is rendered, so the freshness line has
# to be printed on that path too — a host check reading JSON is exactly the
# caller that cannot notice a stale board for itself.
out="$(cd "${work}" && python3 "${QUERY}" --tasks-dir "${TASKS}" --json 2>&1)"
grep -qE "behind|does not contain" <<<"${out}" \
    || fail "--json suppressed the freshness warning: ${out}"
echo "PASS: --json still reports a stale tree"

# Fetched but not merged: now it is countable.
git -C "${work}" fetch -q origin main
out="$(cd "${work}" && python3 "${QUERY}" --tasks-dir "${TASKS}" 2>&1)"
grep -q "3 commit(s) behind origin/main" <<<"${out}" \
    || fail "the behind-count was wrong or missing: ${out}"
echo "PASS: a fetched-but-behind tree reports its exact distance"

# --- the check is skippable and fails open ------------------------------------
out="$(cd "${work}" && python3 "${QUERY}" --tasks-dir "${TASKS}" --no-remote-check 2>&1)"
grep -qE "behind|does not contain" <<<"${out}" \
    && fail "--no-remote-check still ran the remote check: ${out}"
echo "PASS: --no-remote-check skips it"

# A remote that cannot be reached must not turn a usable board into an error:
# the surfaces with no network still have task files on disk.
out="$(cd "${work}" && python3 "${QUERY}" --tasks-dir "${TASKS}" --remote nope 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "an unreachable remote exited ${rc}, expected 0 (fail open)"
grep -qE "behind|does not contain" <<<"${out}" \
    && fail "an unreachable remote produced a freshness claim: ${out}"
echo "PASS: an unreachable remote fails open, silently"

# Outside a git repo at all — the same fail-open path.
plain="${tmp}/plain"; _seed_task "${plain}/tasks" t9
out="$(cd "${plain}" && python3 "${QUERY}" --tasks-dir "${plain}/tasks" 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "a non-repo tasks dir exited ${rc}, expected 0"
echo "PASS: a tasks dir outside any repo fails open"

# --- #345: task_select must refuse an --issues file it cannot read ------------
# query_status already returns 2 for each of these; task_select caught only
# JSONDecodeError, so a missing path raised FileNotFoundError and a truncated
# envelope raised TypeError — both out of the documented exit contract.
out="$(python3 "${SELECT}" --tasks-dir "${TASKS}" --issues "${tmp}/absent.json" 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] || fail "a missing --issues path exited ${rc}, expected 2"
grep -q "cannot read --issues" <<<"${out}" || fail "missing --issues not explained: ${out}"
grep -q "Traceback" <<<"${out}" && fail "a missing --issues path still raises: ${out}"
echo "PASS: task_select refuses an --issues path that does not exist"

for bad in 'null' '5' '{"issues": null}' '{"issues": 7}' '"text"'; do
    printf '%s' "${bad}" > "${tmp}/bad.json"
    out="$(python3 "${SELECT}" --tasks-dir "${TASKS}" --issues "${tmp}/bad.json" 2>&1)"; rc=$?
    [[ "${rc}" -eq 2 ]] || fail "--issues ${bad} exited ${rc}, expected 2"
    grep -q "Traceback" <<<"${out}" && fail "--issues ${bad} raised: ${out}"
    grep -q "is not an issue list" <<<"${out}" || fail "--issues ${bad} not explained: ${out}"
done
echo "PASS: task_select refuses an --issues payload that is not an issue list"

printf '%s' 'not json at all' > "${tmp}/bad.json"
out="$(python3 "${SELECT}" --tasks-dir "${TASKS}" --issues "${tmp}/bad.json" 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] || fail "invalid JSON exited ${rc}, expected 2"
grep -q "not valid JSON" <<<"${out}" || fail "invalid JSON not explained: ${out}"
echo "PASS: task_select still reports invalid JSON distinctly"

# The good path is unchanged: a real issue list still resolves and selects.
printf '%s' '[{"number":1,"state":"open","body":"`arsenal-task: t1`"}]' > "${tmp}/ok.json"
out="$(python3 "${SELECT}" --tasks-dir "${TASKS}" --issues "${tmp}/ok.json" 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "a valid issue list exited ${rc}, expected 0: ${out}"
grep -q '"id":"t1"' <<<"${out}" || fail "a valid issue list did not select the task: ${out}"
echo "PASS: a valid --issues file still selects"

echo "PASS: board_freshness_test — all gates passed"
exit 0
