#!/usr/bin/env bash
# open_task_pr_stale_base_test.sh — regression test for #130 item 2:
# a worker's worktree is cut from the orchestrator's arsenal-queue HEAD, which
# can predate the current default branch (an earlier task's PR merged since).
# `git checkout -b <branch> FETCH_HEAD` then refuses — "local changes would be
# overwritten" — and open_task_pr.sh hard-failed, leaving the worker to save a
# patch, reset, re-branch, and reapply by hand.
#
# It now replays the worker's uncommitted edits onto the fresh base (what a
# rebase would have done), after snapshotting them to a refs/arsenal-rescue/…
# ref so even an unresolvable conflict leaves the work on a ref.
#
# The test runs the helper inside a REAL linked worktree, which doubles as the
# #130-item-4 gate: derived isolation permits `git add -A` with no env var set.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
HELPER="${BIN}/open_task_pr.sh"

[[ -f "${HELPER}" ]] || { echo "SKIP: open_task_pr.sh not found at ${HELPER}" >&2; exit 0; }
[[ -f "${BIN}/rescue_snapshot.sh" ]] || { echo "SKIP: rescue_snapshot.sh not found" >&2; exit 0; }
git worktree list >/dev/null 2>&1 || { echo "SKIP: git worktree unavailable" >&2; exit 0; }
if command -v gh >/dev/null 2>&1; then
    echo "SKIP: gh present — this test exercises the no-PR-backend path" >&2; exit 0
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
tmp="$(cd "${tmp}" && pwd -P)"
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

git init -q --bare "${tmp}/remote.git"
git -C "${tmp}/remote.git" symbolic-ref HEAD refs/heads/main

# Seed main: a 20-line file both sides will touch, in distant regions.
seed="${tmp}/seed"
git clone -q "${tmp}/remote.git" "${seed}" 2>/dev/null
cd "${seed}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
for i in $(seq 1 20); do echo "line ${i}"; done > shared.txt
git add shared.txt
git commit -q -m "chore: base"
git push -q -u origin main
stale_sha="$(git rev-parse HEAD)"

# The default branch moves on (an earlier task's PR merged) — line 1 changes and
# a new file appears. The worker's worktree, cut before this, is now stale.
sed -i.bak 's/^line 1$/line 1 (updated on main)/' shared.txt && rm -f shared.txt.bak
echo "added by a merged PR" > newer.txt
git add -A
git commit -q -m "feat: advance main"
git push -q origin main
fresh_sha="$(git rev-parse HEAD)"

# The worker's clone + its own linked worktree, cut from the STALE commit.
work="${tmp}/work"
git clone -q "${tmp}/remote.git" "${work}"
cd "${work}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
wt="${tmp}/worker-wt"
git worktree add -q --detach "${wt}" "${stale_sha}" 2>/dev/null \
    || fail "could not create the worker worktree"
cd "${wt}"

# The worker implements its task: an uncommitted edit to the far end of the
# same file the base advanced in.
sed -i.bak 's/^line 20$/line 20 (worker edit)/' shared.txt && rm -f shared.txt.bak
echo "worker artifact" > worker_new.txt

# Sanity: this is exactly the situation that used to hard-fail.
if git checkout -b probe-would-fail "${fresh_sha}" >/dev/null 2>&1; then
    fail "test setup is wrong — checkout onto the fresh base did not refuse"
fi

# --- The helper, with NO isolation env var: the linked worktree IS the proof --
# ARSENAL_TASK_ISSUE stands in for the issue handle: the helper refuses to open a
# PR it cannot link, and this test is about the stale base, not the handle.
out="$(ARSENAL_TASK_ISSUE=99 ARSENAL_COAUTHOR="Test Bot <noreply@anthropic.com>" \
       bash "${HELPER}" lo-stale "Stale base task" 2>"${tmp}/err.log")" \
    || fail "open_task_pr.sh failed on a stale base: $(cat "${tmp}/err.log")"

EXPECT_BRANCH="arsenal/lo-stale-stale-base-task"
[[ "${out}" == "branch:${EXPECT_BRANCH}" ]] \
    || fail "expected 'branch:${EXPECT_BRANCH}' on stdout, got '${out}'"
echo "PASS: stale base no longer hard-fails — branch opened"

# Gate: derived isolation permitted git add -A with no ARSENAL_SURFACE set.
grep -q "git add -A refused" "${tmp}/err.log" \
    && fail "linked worktree was refused by the shared-checkout guard"
echo "PASS: a real linked worktree needs no env var to pass the guard"

# Gate: the branch is cut off the FRESH default branch, not the stale base.
parent="$(git rev-parse 'HEAD^')"
[[ "${parent}" == "${fresh_sha}" ]] \
    || fail "branch parent is ${parent}, expected the fresh base ${fresh_sha}"
echo "PASS: branch cut off the fresh default-branch tip"

# Gate: both sides survive — main's newer content AND the worker's edit.
grep -q "^line 1 (updated on main)$" shared.txt || fail "main's newer line was lost"
grep -q "^line 20 (worker edit)$" shared.txt || fail "the worker's edit was lost"
[[ -f newer.txt ]] || fail "the file added on main is missing from the worker's branch"
git show "HEAD:worker_new.txt" >/dev/null 2>&1 || fail "the worker's new file was not committed"
echo "PASS: worker edits replayed onto the fresh base, nothing lost"

# Gate: the pre-replay snapshot is on a permanent ref.
ref="$(git for-each-ref --format='%(refname)' 'refs/arsenal-rescue/*' | head -1)"
[[ -n "${ref}" ]] || fail "no rescue ref was created before the replay"
git show "${ref}:worker_new.txt" >/dev/null 2>&1 \
    || fail "rescue ref '${ref}' does not carry the worker's pre-replay tree"
grep -q "${ref}" "${tmp}/err.log" || fail "the rescue ref was not reported on stderr"
echo "PASS: pre-replay snapshot kept on a rescue ref and reported"

echo "PASS: open_task_pr_stale_base_test — all gates passed"
exit 0
