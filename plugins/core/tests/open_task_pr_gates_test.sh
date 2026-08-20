#!/usr/bin/env bash
# open_task_pr_gates_test.sh — the PR helper refuses over a red repo.
#
# worker.md step 4 asked a worker to run the host lint gate and the payload gate
# and to open no PR if either failed, and AGENTS.md stated the payload gate was
# "a hard precondition" because this script re-runs it. Neither ran anything:
# both were instructions with no data path behind them, which this project
# already names as the thing that makes a step not happen. A worker that forgot
# step 4 — or ran only the `make lint` the prose gives as its example, in a repo
# whose real gate is five commands — opened a perfectly valid PR over a red repo.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
HELPER="${BIN}/open_task_pr.sh"
[[ -f "${HELPER}" ]] || { echo "SKIP: open_task_pr.sh not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="${tmp}/repo"
mkdir -p "${REPO}/arsenal/tasks"
cd "${REPO}"
git init -q -b main .
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
git commit -q --allow-empty -m init
git remote add origin https://github.com/o/r.git

write_task() {  # $1 = id, $2 = gate command
    cat > "arsenal/tasks/$1.md" <<EOF
---
id: $1
title: "Gate fixture"
priority: 1
---

## Acceptance gate
\`\`\`bash
$2
\`\`\`
EOF
}

# The helper needs an uncommitted change to have something to open a PR for.
touch work.txt

# --- 1: a failing payload gate opens no PR ---
write_task t-gate-red "exit 7"
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-red "Red gate" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a failing payload gate must stop the PR"
grep -q "no PR opened" <<<"${out}" || fail "the refusal should say no PR was opened: ${out}"
git rev-parse --verify --quiet "arsenal/t-gate-red" >/dev/null 2>&1 \
    && fail "no branch should exist after a refused gate"

# --- 2: a failing HOST gate opens no PR, and is named ---
#     This is the half that was prose only. The consumer whose real gate is
#     `make lint test evidence verify-subtree verify-gates` had four of five
#     enforced by nobody.
write_task t-gate-host "true"
mkdir -p arsenal
printf 'host-gate = "exit 3"\n' > arsenal/config.toml
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-host "Host gate" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a failing host gate must stop the PR"
grep -q "host gate failed" <<<"${out}" || fail "the refusal should name the host gate: ${out}"

# --- 3: no host-gate configured is not a failure ---
#     A repo that declares none must be unaffected; the default is empty.
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-host "No host gate" 2>&1); rc=$?
grep -q "host gate failed" <<<"${out}" && fail "an absent host-gate must not fail: ${out}"

# --- 4: the gate runs BEFORE git is touched ---
#     Refusing after a branch was cut would leave the worker's tree moved.
write_task t-gate-order "exit 1"
before="$(git rev-parse HEAD)"
ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-order "Order" >/dev/null 2>&1
[[ "$(git rev-parse HEAD)" == "${before}" ]] || fail "a refused gate must not move HEAD"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "a refused gate must not switch branches"

# --- 5: an unmeasured/could-not-run gate (exit 3) also refuses ---
#     Exit 3 means nothing was verified, which is not a pass.
write_task t-gate-127 "definitely-not-a-real-command-xyz"
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-127 "Could not run" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a gate that could not run must not open a PR"
grep -q "nothing was verified" <<<"${out}" \
    || fail "exit 3 should be reported as nothing verified, not as a plain failure: ${out}"

# --- 6: the opt-out exists, and announces itself ---
#     Deliberate, loud, and never silent — the same shape as the stale-claim
#     override rather than a quiet skip.
out=$(ARSENAL_SKIP_GATES=1 ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-red "Skipped" 2>&1)
grep -q "ARSENAL_SKIP_GATES=1" <<<"${out}" || fail "the opt-out must announce itself: ${out}"

echo "PASS: open_task_pr_gates_test — all gates passed"
