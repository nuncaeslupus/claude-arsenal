#!/usr/bin/env bash
# worker_postcheck_rescue_test.sh — regression test for #130 item 1 (P0):
# worker_postcheck.sh's restore path (`git reset --hard` + `git clean -fdq` +
# `git checkout -f`) runs in the HOST's main working tree. When the orchestrator
# cut a local branch there over genuine work-in-progress, the next postcheck
# took the restore path and discarded ~335 lines of never-staged work — no blob,
# no reflog, nothing to recover.
#
# The restore is still correct (the coordination protocol depends on it), but it
# must no longer be destructive without a way back: the tree is snapshotted to a
# permanent refs/arsenal-rescue/… ref first, the ref is printed on stderr, and
# it is appended to claude-arsenal/session/rescue_refs.
#
# Gates:
#   - a restore over a dirty tree creates a rescue ref containing BOTH the
#     tracked modification and the untracked file `git clean -fdq` deletes;
#   - the ref is reported on stderr and recorded in the session dir;
#   - a clean-tree restore creates no ref (no noise when there is nothing to save);
#   - rescue_snapshot.sh leaves the caller's index and HEAD untouched.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
QUEUE_BRANCH_SH="${BIN}/queue_branch.sh"
POSTCHECK="${BIN}/worker_postcheck.sh"
RESCUE="${BIN}/rescue_snapshot.sh"

for f in "${QUEUE_BRANCH_SH}" "${POSTCHECK}" "${RESCUE}"; do
    [[ -f "$f" ]] || { echo "SKIP: ${f} not found" >&2; exit 0; }
done

git worktree list >/dev/null 2>&1 || { echo "SKIP: git worktree unavailable" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
tmp="$(cd "${tmp}" && pwd -P)"
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

git init -q --bare "${tmp}/remote.git"
git -C "${tmp}/remote.git" symbolic-ref HEAD refs/heads/main

mkdir -p "${tmp}/work"
repo="${tmp}/work/myrepo"
git clone -q "${tmp}/remote.git" "${repo}"
cd "${repo}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
echo "base" > tracked.txt
git add tracked.txt
git commit -q -m "chore: base"
git push -q -u origin main

HOST_BRANCH="claude/web-continuation-rescue"
git checkout -q -b "${HOST_BRANCH}"
git push -q -u origin "${HOST_BRANCH}"

export ARSENAL_QUEUE_BRANCH=arsenal-queue
export ARSENAL_QUEUE_REMOTE=origin
export ARSENAL_SESSION_DIR="${repo}/claude-arsenal/session"
unset ARSENAL_DEFAULT_BRANCH || true

ARSENAL_QUEUE_DIR="$(bash "${QUEUE_BRANCH_SH}" 2>"${tmp}/qb.log")" \
    || fail "queue_branch.sh exited non-zero: $(cat "${tmp}/qb.log")"
export ARSENAL_QUEUE_DIR

# --- The reported incident, reproduced -------------------------------------
# Genuine WIP in the host's main tree: one tracked modification (never staged)
# and one untracked file. Then the orchestrator cuts a local branch in that same
# tree for a small docs PR, which is what makes the next postcheck take the
# restore path.
echo "precious work in progress" >> tracked.txt
echo "precious untracked notes" > notes.txt
git checkout -q -b arsenal/docs-pr

out="$(bash "${POSTCHECK}" 2>"${tmp}/pc.log")"
[[ "${out}" == "restored" ]] || fail "expected 'restored', got '${out}'"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "${HOST_BRANCH}" ]] \
    || fail "postcheck did not restore to '${HOST_BRANCH}'"

# The restore itself is unchanged — the tree really is reset.
[[ ! -f notes.txt ]] || fail "expected the restore to clean the untracked file"

# Gate 1: a rescue ref exists and carries BOTH pieces of work.
ref="$(git for-each-ref --format='%(refname)' 'refs/arsenal-rescue/*' | head -1)"
[[ -n "${ref}" ]] || fail "no refs/arsenal-rescue/* ref was created — work was destroyed irrecoverably"

git show "${ref}:notes.txt" 2>/dev/null | grep -q "precious untracked notes" \
    || fail "rescue ref '${ref}' does not carry the untracked file"
git show "${ref}:tracked.txt" 2>/dev/null | grep -q "precious work in progress" \
    || fail "rescue ref '${ref}' does not carry the unstaged tracked modification"
echo "PASS: restore snapshots tracked + untracked work to a rescue ref"

# Gate 2: the ref is surfaced on stderr and recorded for the orchestrator.
grep -q "${ref}" "${tmp}/pc.log" \
    || fail "rescue ref was not reported on stderr (log: $(cat "${tmp}/pc.log"))"
grep -q "${ref}" "${ARSENAL_SESSION_DIR}/rescue_refs" \
    || fail "rescue ref was not appended to ${ARSENAL_SESSION_DIR}/rescue_refs"
echo "PASS: rescue ref reported on stderr and recorded in the session dir"

# Gate 3: recovering the work actually works, from the ref alone.
git checkout -q "${ref}" -- .
grep -q "precious work in progress" tracked.txt || fail "recovery did not restore tracked.txt"
grep -q "precious untracked notes" notes.txt || fail "recovery did not restore notes.txt"
git reset -q --hard >/dev/null 2>&1
git clean -fdq >/dev/null 2>&1
echo "PASS: work is recoverable from the rescue ref"

# Gate 4: a clean tree produces no ref — no noise for the normal case.
before="$(git for-each-ref --format='%(refname)' 'refs/arsenal-rescue/*' | wc -l | tr -d ' ')"
git checkout -q -b arsenal/another-branch
out="$(bash "${POSTCHECK}" 2>/dev/null)"
[[ "${out}" == "restored" ]] || fail "expected 'restored' on the clean-tree restore, got '${out}'"
after="$(git for-each-ref --format='%(refname)' 'refs/arsenal-rescue/*' | wc -l | tr -d ' ')"
[[ "${before}" == "${after}" ]] || fail "a clean-tree restore created a rescue ref (${before} → ${after})"
echo "PASS: clean-tree restore creates no rescue ref"

# Gate 5: rescue_snapshot.sh does not disturb the caller's index or HEAD.
echo "staged change" >> tracked.txt
git add tracked.txt
echo "unstaged extra" >> tracked.txt
head_before="$(git rev-parse HEAD)"
index_before="$(git diff --cached --name-only)"
ref2="$(bash "${RESCUE}" "index safety check")"
[[ -n "${ref2}" ]] || fail "rescue_snapshot.sh returned no ref for a dirty tree"
[[ "$(git rev-parse HEAD)" == "${head_before}" ]] || fail "rescue_snapshot.sh moved HEAD"
[[ "$(git diff --cached --name-only)" == "${index_before}" ]] \
    || fail "rescue_snapshot.sh disturbed the caller's index"
grep -q "unstaged extra" tracked.txt || fail "rescue_snapshot.sh modified the working tree"
echo "PASS: rescue_snapshot.sh leaves HEAD, index, and working tree untouched"

echo "PASS: worker_postcheck_rescue_test — all gates passed"
exit 0
