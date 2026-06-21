#!/usr/bin/env bash
# worker_isolation_test.sh — covers the worktree-isolation hardening:
#   worktree_probe.sh  — verdict on git-worktree support.
#   worker_postcheck.sh — restores HEAD→queue branch + clean tree post-worker,
#                         and is a no-op when the invariant already holds.
#   release.sh          — its index-reset guard never sweeps a worker's
#                         pre-staged edits onto the coordination ledger.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
PROBE="${BIN}/worktree_probe.sh"
POSTCHECK="${BIN}/worker_postcheck.sh"
RELEASE="${BIN}/release.sh"

for f in "${PROBE}" "${POSTCHECK}" "${RELEASE}"; do
    [[ -f "$f" ]] || { echo "SKIP: ${f} not found" >&2; exit 0; }
done

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

# Bare remote + a clone with main and an arsenal-queue branch carrying the queue.
git init -q --bare "${tmp}/remote.git"
git -C "${tmp}/remote.git" symbolic-ref HEAD refs/heads/main

repo="${tmp}/repo"
git clone -q "${tmp}/remote.git" "${repo}"
cd "${repo}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
echo "base" > base.txt
git add base.txt
git commit -q -m "chore: base"
git push -q -u origin main

# Seed the coordination branch with a queue row + payload.
git checkout -q -b arsenal-queue
mkdir -p claude-arsenal/queue
printf '%s\n' '{"id":"lo-t1","title":"T1","status":"in_progress","assignee":"s1"}' \
    > claude-arsenal/queue/tasks.jsonl
echo "# T1" > claude-arsenal/queue/lo-t1.md
# Session-local files (incl. the worktree_isolation sentinel postcheck writes)
# are gitignored in production (init.py); mirror that so they don't read as a
# dirty tree here. `git clean` (no -x) leaves ignored files, so the sentinel
# persists across the postcheck restore exactly as it does in a real repo.
printf 'claude-arsenal/session/\n' > .gitignore
git add .gitignore claude-arsenal
git commit -q -m "seed queue"
git push -q -u origin arsenal-queue
QUEUE_TIP=$(git rev-parse HEAD)

export ARSENAL_QUEUE_BRANCH=arsenal-queue
export ARSENAL_QUEUE_REMOTE=origin

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- worktree_probe.sh: a normal clone supports worktrees ------------------
if out=$(bash "${PROBE}"); then
    [[ "${out}" == "available" ]] || fail "probe printed '${out}', expected 'available'"
    echo "PASS: worktree_probe reports 'available' (exit 0) in a normal repo"
else
    # Some sandboxes genuinely lack worktree support; the contract still holds.
    [[ "${out}" == "unavailable" ]] || fail "probe failed but printed '${out}'"
    echo "PASS: worktree_probe reports 'unavailable' (exit 1) — honored here"
fi

# --- worker_postcheck.sh: no-op when invariant already holds ---------------
git checkout -q arsenal-queue
out=$(bash "${POSTCHECK}")
[[ "${out}" == "ok" ]] || fail "postcheck on clean queue branch printed '${out}', expected 'ok'"
echo "PASS: worker_postcheck is a no-op ('ok') when HEAD=queue branch + clean"

# --- worker_postcheck.sh: in-place 'done' (HEAD moved to feature branch) ---
# open_task_pr.sh would leave HEAD on a feature branch with committed code.
git checkout -q -b arsenal/lo-t1-feature origin/main
echo "feature code" > feature.txt
git add feature.txt
git commit -q -m "feat: T1"
out=$(bash "${POSTCHECK}")
[[ "${out}" == "restored" ]] || fail "postcheck after in-place worker printed '${out}', expected 'restored'"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "arsenal-queue" ]] || fail "postcheck did not return HEAD to arsenal-queue"
[[ -z "$(git status --porcelain)" ]] || fail "postcheck left a dirty tree"
[[ "$(git rev-parse HEAD)" == "${QUEUE_TIP}" ]] || fail "arsenal-queue tip moved"
# The committed feature work must survive on its branch.
git rev-parse --verify --quiet arsenal/lo-t1-feature >/dev/null || fail "feature branch lost"
echo "PASS: worker_postcheck restores HEAD→arsenal-queue, keeps feature branch"

# --- worker_postcheck.sh: gate failure (uncommitted edits on queue branch) -
echo "stray gate-fail edit" >> claude-arsenal/queue/tasks.jsonl
echo "untracked" > scratch.txt
out=$(bash "${POSTCHECK}")
[[ "${out}" == "restored" ]] || fail "postcheck on dirty queue branch printed '${out}', expected 'restored'"
[[ -z "$(git status --porcelain)" ]] || fail "postcheck left uncommitted/untracked files"
[[ ! -f scratch.txt ]] || fail "postcheck left an untracked file behind"
echo "PASS: worker_postcheck discards a gate-failed worker's residual tree edits"

# --- release.sh guard: a worker's pre-staged edits never ride the ledger ---
# Simulate a stray `git add` of unrelated paths still sitting in the index.
echo "orphan" > orphan.txt
git add orphan.txt
bash "${RELEASE}" lo-t1 done --pr "branch:arsenal/lo-t1-feature" >/dev/null 2>&1 || true
# The release commit must touch ONLY the queue file (+ payload), never orphan.txt.
changed=$(git show --name-only --format= HEAD | sort | tr '\n' ' ')
case " ${changed} " in
    *" orphan.txt "*) fail "release.sh swept a pre-staged stray file onto the ledger: ${changed}" ;;
esac
[[ "${changed}" == *"claude-arsenal/queue/tasks.jsonl"* ]] || fail "release.sh did not commit the queue row (${changed})"
echo "PASS: release.sh index guard keeps stray staged edits off the ledger"

echo "PASS: worker_isolation_test — all gates passed"
exit 0
