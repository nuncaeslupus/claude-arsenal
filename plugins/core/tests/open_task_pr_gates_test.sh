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

# --- 6: there is no way to skip the gates ---
#     An escape hatch would be reached for exactly when the repo is red, which
#     is the case the refusal exists for.
out=$(ARSENAL_SKIP_GATES=1 ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-red "Try to skip" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "no environment variable may skip a failing gate"
grep -q "no PR opened" <<<"${out}" || fail "a skip attempt must still be refused: ${out}"
grep -rq "ARSENAL_SKIP_GATES" "${HELPER}" && fail "the helper must carry no skip flag at all"

# --- 7: gate output never reaches stdout ---
#     This script's stdout is a contract — callers parse `branch:…` and the PR
#     URL out of it, and a `gate: passed` line in front of that breaks them.
write_task t-gate-out "true"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
sout=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-out "Clean stdout" 2>/dev/null || true)
grep -q "^gate:" <<<"${sout}" && fail "gate chatter must not appear on stdout: ${sout}"

# --- 8: a broken config refuses, rather than reading as "no gate declared" ---
#     Suppressing the config error would move the silent skip one layer out:
#     enforcement would quietly stop for a repo that declares a gate.
write_task t-gate-cfg "true"
printf 'merge-policy = "not-a-real-policy"\n' > arsenal/config.toml
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-cfg "Broken config" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "an unreadable config must not silently skip the host gate"
grep -q "could not read host-gate" <<<"${out}" || fail "the refusal should name the config: ${out}"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml

# --- 9: the config is found from a subdirectory ---
#     arsenal_config.py resolves the config relative to --repo-root, defaulting
#     to the cwd; this script is routinely run from a worktree or subdirectory.
mkdir -p sub/dir
printf 'host-gate = "exit 4"\n' > arsenal/config.toml
out=$(cd sub/dir && ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-cfg "From subdir" 2>&1); rc=$?
grep -q "host gate failed" <<<"${out}" \
    || fail "the host gate must be found when run from a subdirectory: ${out}"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml

# --- 10: the gate certifies the tree that is actually committed (#220) ---
#     The host gate ran, and THEN the task file was archived into _history/ —
#     so any host measurement over the repo's own files (a file count, a
#     coverage denominator) was stale by exactly that file in every PR this
#     script opened, and the host's next run failed on a branch whose gate had
#     just passed. The gate now re-runs over the archived tree; a refusal there
#     must leave the task file where it started.
# The earlier cases all refuse before git is touched; this one has to get as
# far as cutting a branch, which needs a default ref to branch off.
git update-ref refs/remotes/origin/main HEAD
write_task t-gate-archive "true"
printf 'host-gate = "test ! -e arsenal/tasks/_history"\n' > arsenal/config.toml
out=$(ARSENAL_TASK_ISSUE=42 ARSENAL_ALLOW_SHARED_ADD=1 ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-archive "Archived tree" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a host gate that fails over the archived tree must stop the PR"
grep -q "re-running host gate" <<<"${out}" \
    || fail "the host gate should re-run once the archive is in the tree: ${out}"
[[ -f "arsenal/tasks/t-gate-archive.md" ]] \
    || fail "the refused run left the task file archived: it must be restored"
[[ -e "arsenal/tasks/_history/t-gate-archive.md" ]] \
    && fail "the archived copy survived a refusal"
git status --porcelain | grep -q "^D.*t-gate-archive" \
    && fail "the index still stages the archive's deletion after the undo"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
git checkout -q main 2>/dev/null || true
echo "PASS: the host gate re-runs over the archived tree, and a refusal restores it"

echo "PASS: open_task_pr_gates_test — all gates passed"
