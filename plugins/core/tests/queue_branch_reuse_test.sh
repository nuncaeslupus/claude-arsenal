#!/usr/bin/env bash
# queue_branch_reuse_test.sh — covers queue_branch.sh reusing an existing
# arsenal-queue worktree that lives at a path other than the computed
# repo-name-scoped default (e.g. a worktree left at the old shared
# `../arsenal-queue-wt` path from before #122 namespaced it). Without this,
# `git worktree add` fails outright ("already used by worktree at ...") and
# queue_branch.sh hard-errors instead of reusing the existing checkout.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin/queue_branch.sh"
[[ -f "${BIN}" ]] || { echo "SKIP: ${BIN} not found" >&2; exit 0; }

git worktree list >/dev/null 2>&1 || { echo "SKIP: git worktree unavailable" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
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
echo base > base.txt
git add base.txt
git commit -q -m "chore: base"
git push -q -u origin main

# Simulate a legacy worktree checked out at the old, non-namespaced default
# path (a sibling of the work dir, not of the repo).
legacy_wt="${tmp}/work/arsenal-queue-wt"
git branch arsenal-queue main
git worktree add -q "${legacy_wt}" arsenal-queue
git -C "${legacy_wt}" push -q -u origin arsenal-queue

export ARSENAL_QUEUE_BRANCH=arsenal-queue
export ARSENAL_QUEUE_REMOTE=origin

out="$(bash "${BIN}" 2>"${tmp}/err.log")" || fail "queue_branch.sh exited non-zero: $(cat "${tmp}/err.log")"

[[ "${out}" == "${legacy_wt}" ]] \
    || fail "expected reuse of legacy worktree '${legacy_wt}', got '${out}'"
grep -q "reusing it" "${tmp}/err.log" \
    || fail "expected a 'reusing it' notice on stderr, got: $(cat "${tmp}/err.log")"

namespaced_default="${repo}-arsenal-queue-wt"
[[ ! -e "${namespaced_default}" ]] \
    || fail "queue_branch.sh created a second worktree at the namespaced default '${namespaced_default}' instead of reusing the legacy one"

echo "PASS: queue_branch.sh reuses an existing worktree checked out at a non-default path"
exit 0
