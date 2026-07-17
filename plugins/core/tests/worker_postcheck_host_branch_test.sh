#!/usr/bin/env bash
# worker_postcheck_host_branch_test.sh — regression test for #128:
# worker_postcheck.sh used to compare the main tree's branch against
# `${ARSENAL_DEFAULT_BRANCH:-main}` to decide whether a worker moved HEAD.
# On Claude Code on the web a session is commonly pinned to its OWN
# designated branch (e.g. `claude/web-continuation-xxx`), not `main` — so
# that comparison always failed and worker_postcheck.sh force-recovered
# (`git reset --hard` + `git clean -fdq` + `git checkout -f main`) a main
# tree that was never actually touched, destroying any uncommitted work on
# the session's real branch.
#
# queue_branch.sh now persists the main tree's actual branch to
# claude-arsenal/session/host_branch once it settles; worker_postcheck.sh
# reads that instead of assuming `main`. This test covers both directions:
#   - main tree still on the recorded host branch (real isolation held) →
#     `ok`, no reset, no branch switch.
#   - main tree moved off the recorded host branch (isolation silently
#     ignored) → `restored`, back to the recorded host branch — NOT `main`.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
QUEUE_BRANCH_SH="${BIN}/queue_branch.sh"
POSTCHECK="${BIN}/worker_postcheck.sh"

for f in "${QUEUE_BRANCH_SH}" "${POSTCHECK}"; do
    [[ -f "$f" ]] || { echo "SKIP: ${f} not found" >&2; exit 0; }
done

git worktree list >/dev/null 2>&1 || { echo "SKIP: git worktree unavailable" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
# Canonicalize (see queue_branch_reuse_test.sh): avoids /var vs /private/var
# mismatches between queue_branch.sh's stdout and our expectations.
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
echo base > base.txt
git add base.txt
git commit -q -m "chore: base"
git push -q -u origin main

# Simulate a Claude Code on the web session pinned to its own feature branch
# rather than main.
HOST_BRANCH="claude/web-continuation-bv66s5"
git checkout -q -b "${HOST_BRANCH}"
git push -q -u origin "${HOST_BRANCH}"

export ARSENAL_QUEUE_BRANCH=arsenal-queue
export ARSENAL_QUEUE_REMOTE=origin
export ARSENAL_SESSION_DIR="${repo}/claude-arsenal/session"
unset ARSENAL_DEFAULT_BRANCH || true

# --- queue_branch.sh: sets up the coordination worktree without moving the
#     main tree, and records the main tree's actual branch. ------------------
ARSENAL_QUEUE_DIR="$(bash "${QUEUE_BRANCH_SH}" 2>"${tmp}/qb.log")" \
    || fail "queue_branch.sh exited non-zero: $(cat "${tmp}/qb.log")"
export ARSENAL_QUEUE_DIR

[[ "$(git rev-parse --abbrev-ref HEAD)" == "${HOST_BRANCH}" ]] \
    || fail "queue_branch.sh moved the main tree off '${HOST_BRANCH}'"

host_branch_file="${ARSENAL_SESSION_DIR}/host_branch"
[[ -f "${host_branch_file}" ]] || fail "queue_branch.sh did not write '${host_branch_file}'"
recorded="$(cat "${host_branch_file}")"
[[ "${recorded}" == "${HOST_BRANCH}" ]] \
    || fail "recorded host_branch is '${recorded}', expected '${HOST_BRANCH}'"
echo "PASS: queue_branch.sh records the main tree's actual branch, not 'main'"

# --- worker_postcheck.sh: main tree untouched, real isolation held ---------
# An uncommitted (not-yet-pushed) edit on the host branch must survive: this
# is exactly what #128 reported as destroyed by the false-positive reset.
echo "uncommitted host-branch work" > untracked_work.txt
out=$(bash "${POSTCHECK}")
[[ "${out}" == "ok" ]] \
    || fail "postcheck on untouched main tree (host branch != main) printed '${out}', expected 'ok'"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "${HOST_BRANCH}" ]] \
    || fail "postcheck switched the main tree off '${HOST_BRANCH}'"
[[ -f untracked_work.txt ]] \
    || fail "postcheck destroyed uncommitted work on the host branch"
rm -f untracked_work.txt
echo "PASS: worker_postcheck reports 'ok' and leaves the host branch alone"

# --- worker_postcheck.sh: isolation silently ignored, worker moved HEAD ----
git checkout -q -b arsenal/some-feature main
out=$(bash "${POSTCHECK}")
[[ "${out}" == "restored" ]] \
    || fail "postcheck after HEAD moved off host branch printed '${out}', expected 'restored'"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "${HOST_BRANCH}" ]] \
    || fail "postcheck restored to '$(git rev-parse --abbrev-ref HEAD)', expected recorded host branch '${HOST_BRANCH}' (not 'main')"
echo "PASS: worker_postcheck restores to the recorded host branch, not 'main'"

echo "PASS: worker_postcheck_host_branch_test — all gates passed"
exit 0
