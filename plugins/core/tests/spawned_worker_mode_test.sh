#!/usr/bin/env bash
# spawned_worker_mode_test.sh — the bundle must not tell a spawned worker to do
# what a spawned worker structurally cannot (#246), and must say what a dispatch
# has to carry (#250).
#
# A session spawned by another carries no `mcp__*` tools. On a surface where REST
# is also refused, its only channel to GitHub is plain `git`: enough to fetch,
# read claim refs and push a branch; not enough to read issues, claim, open a PR
# or merge. Three workers blocked on exactly this because the protocol block
# `/init` injects into the host CLAUDE.md told every session to fetch the board
# and open PRs, and a spawned child reads that file like any other session.
#
# These are documentation invariants, so they are asserted as such: the point is
# that the three files cannot drift back to promising the impossible without the
# build going red.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
WORKER="${ASSETS}/agents/worker.md"
TICK="${ASSETS}/references/orchestrator-tick.md"
OPEN_PR="${ASSETS}/bin/open_task_pr.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- the injected protocol block ------------------------------------------
# This is the file a spawned child actually reads, and the one a consumer
# cannot fix locally: /init rewrites it by checksum on every run.
[[ -f "${INIT_PY}" ]] || fail "init.py not found at ${INIT_PY}"

template="$(python3 - "${INIT_PY}" <<'PY'
import ast, sys
tree = ast.parse(open(sys.argv[1], encoding="utf-8").read())
for node in tree.body:
    if isinstance(node, ast.Assign) and any(
        getattr(t, "id", "") == "_CLAUDE_MD_TEMPLATE" for t in node.targets
    ):
        print(ast.literal_eval(node.value))
        break
PY
)" || fail "could not read _CLAUDE_MD_TEMPLATE out of init.py"

[[ -n "${template}" ]] || fail "_CLAUDE_MD_TEMPLATE is empty — the block /init injects is the whole point of this test"

grep -qi "spawned" <<<"${template}" \
    || fail "the injected block never mentions a spawned session, so a child reads every step as its own (#246)"
grep -q 'open_task_pr.sh' <<<"${template}" \
    || fail "the injected block does not name the helper a spawned worker ends on"
grep -q 'branch:<name>' <<<"${template}" \
    || fail "the injected block does not name the push-only outcome, so it reads as a failure"
echo "PASS: the injected protocol block tells a spawned session which steps are not its own"

# The unconditional opener was the bug: "Every session, without waiting to be
# asked" sat above a numbered list whose steps 2-5 all need the API. It may
# still appear — but never before the spawned-session carve-out.
if grep -qi "every session, without waiting" <<<"${template}"; then
    spawned_at="$(grep -n -i "spawned" <<<"${template}" | head -1 | cut -d: -f1)"
    every_at="$(grep -ni "every session, without waiting" <<<"${template}" | head -1 | cut -d: -f1)"
    [[ -n "${spawned_at}" && -n "${every_at}" && "${spawned_at}" -lt "${every_at}" ]] \
        || fail "the 'every session' opener comes BEFORE the spawned-session carve-out (line ${every_at} vs ${spawned_at}) — a child reads the steps as its own before reaching the exception"
    echo "PASS: the spawned-session carve-out precedes the unconditional opener"
fi

grep -q 'ARSENAL_TASK_ISSUE' <<<"${template}" \
    || fail "the injected block does not say a dispatch must pass ARSENAL_TASK_ISSUE (#246/#250)"
echo "PASS: the dispatch step names what a spawned worker cannot resolve for itself"

# --- open_task_pr.sh's push-only exit --------------------------------------
# The behaviour the docs above now promise. `branch:<name>` on stdout with
# exit 0 is a completed handoff; if this ever became a non-zero exit, every
# worker following the docs would report a failure it did not have.
[[ -f "${OPEN_PR}" ]] || fail "open_task_pr.sh not found"
push_only="$(grep -n 'branch:\${BRANCH}' "${OPEN_PR}" | head -1 | cut -d: -f1)"
[[ -n "${push_only}" ]] \
    || fail "open_task_pr.sh no longer prints branch:<name> — the push-only handoff the docs promise is gone"
tail -n +"${push_only}" "${OPEN_PR}" | grep -qE '^exit 0' \
    || fail "the push-only outcome does not exit 0, so a successful handoff reports as a failure"
echo "PASS: the push-only handoff is exit 0 with branch:<name> on stdout"

# --- the worker agent ------------------------------------------------------
[[ -f "${WORKER}" ]] || fail "agents/worker.md not found"
grep -q 'separate' "${WORKER}" \
    || fail "worker.md does not distinguish a Task-tool subagent from a separate session (#246)"
grep -q 'branch:<name>' "${WORKER}" \
    || fail "worker.md does not name the push-only outcome"
echo "PASS: worker.md says how far a worker gets on each surface"

# --- the orchestrator tick -------------------------------------------------
# #250: all three dispatch requirements, each a measured failure.
[[ -f "${TICK}" ]] || fail "references/orchestrator-tick.md not found"
for needle in \
    'repository, explicitly' \
    'ARSENAL_TASK_ISSUE' \
    'arsenal/claims/' \
    '201' \
    'one worker per message'; do
    grep -qi -- "${needle}" "${TICK}" \
        || fail "orchestrator-tick.md no longer covers '${needle}' — a dispatch requirement went missing (#250)"
done
echo "PASS: orchestrator-tick.md carries all three dispatch requirements"

# The 201 is the part that makes this expensive rather than annoying: nothing in
# a successful-looking response distinguishes a worker that got a repository
# from one that did not.
grep -qi 'refus' "${TICK}" \
    || fail "orchestrator-tick.md does not explain that a worker's refusal is correct behaviour, so a reader will treat it as the signal to rely on"
echo "PASS: the tick reference says why a worker's refusal cannot be the signal"

echo "PASS: spawned_worker_mode_test — all gates passed"
exit 0
