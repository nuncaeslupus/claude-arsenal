#!/usr/bin/env bash
# queue_project_identity_test.sh — regression test for a follow-up to #128:
# ARSENAL_QUEUE_BRANCH is a generic literal name (`arsenal-queue` by
# default) with no built-in tie to a specific project. If that branch is
# ever fetched from the wrong remote — a stale `origin` left over from a
# template/fork, a copy-pasted ARSENAL_QUEUE_REMOTE, or two unrelated
# projects that end up sharing a remote (observed in practice: one project's
# queue silently absorbed another's task rows) — queue_branch.sh must refuse
# to hand back that worktree rather than let a different project's tasks
# land in this session's queue.
#
# queue_branch.sh now stamps a `.project-id` marker (normalized remote URL)
# on the coordination branch the first time it creates it, and refuses
# (exit 1) on every later run if the branch it fetches carries a different
# project's stamp.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin/queue_branch.sh"
[[ -f "${BIN}" ]] || { echo "SKIP: ${BIN} not found" >&2; exit 0; }

git worktree list >/dev/null 2>&1 || { echo "SKIP: git worktree unavailable" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
tmp="$(cd "${tmp}" && pwd -P)"
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

mk_remote_and_clone() {
    local name="$1" clone_dir="$2"
    git init -q --bare "${tmp}/${name}.git"
    git -C "${tmp}/${name}.git" symbolic-ref HEAD refs/heads/main
    git clone -q "${tmp}/${name}.git" "${clone_dir}"
    git -C "${clone_dir}" config user.email "test@arsenal.example"
    git -C "${clone_dir}" config user.name "Arsenal Test"
    echo base > "${clone_dir}/base.txt"
    git -C "${clone_dir}" add base.txt
    git -C "${clone_dir}" commit -q -m "chore: base"
    git -C "${clone_dir}" push -q -u origin main
}

mkdir -p "${tmp}/work"
projA="${tmp}/work/projA"
projB="${tmp}/work/projB"
mk_remote_and_clone remoteA "${projA}"
mk_remote_and_clone remoteB "${projB}"

export ARSENAL_QUEUE_BRANCH=arsenal-queue
export ARSENAL_QUEUE_REMOTE=origin

# --- Project A: first run stamps its own project identity ------------------
cd "${projA}"
export ARSENAL_QUEUE_WORKTREE="${tmp}/work/projA-arsenal-queue-wt"
wtA="$(bash "${BIN}" 2>"${tmp}/a.log")" || fail "queue_branch.sh (projA, first run) failed: $(cat "${tmp}/a.log")"
marker="${wtA}/claude-arsenal/queue/.project-id"
[[ -f "${marker}" ]] || fail "projA did not stamp a .project-id marker"
idA="$(cat "${marker}")"
[[ "${idA}" == *"remoteA" ]] || fail "projA's stamped id '${idA}' doesn't look like remoteA"
echo "PASS: queue_branch.sh stamps a project-id marker on first creation"

# A second run against the SAME project must still succeed (marker matches).
wtA2="$(bash "${BIN}" 2>"${tmp}/a2.log")" || fail "queue_branch.sh (projA, second run) failed: $(cat "${tmp}/a2.log")"
[[ "${wtA2}" == "${wtA}" ]] || fail "projA's worktree path changed between runs"
echo "PASS: a matching project-id lets queue_branch.sh proceed normally"

# --- Simulate contamination: push projA's stamped branch onto remoteB ------
# This is the failure mode reported in practice: two projects' arsenal-queue
# branches end up sharing a remote (stale origin, copy-pasted
# ARSENAL_QUEUE_REMOTE, etc.), so projB's origin ends up serving projA's
# already-stamped queue content.
git -C "${wtA}" push -q "${tmp}/remoteB.git" "arsenal-queue:arsenal-queue"

# --- Project B: fetching a branch stamped for projA must be refused --------
cd "${projB}"
export ARSENAL_QUEUE_WORKTREE="${tmp}/work/projB-arsenal-queue-wt"
if out="$(bash "${BIN}" 2>"${tmp}/b.log")"; then
    fail "queue_branch.sh (projB) succeeded despite a foreign project-id stamp (got '${out}')"
fi
grep -q "different project" "${tmp}/b.log" \
    || fail "expected a 'different project' refusal on stderr, got: $(cat "${tmp}/b.log")"
[[ ! -d "${ARSENAL_QUEUE_WORKTREE}" || ! -f "${ARSENAL_QUEUE_WORKTREE}/claude-arsenal/queue/tasks.jsonl" ]] \
    || fail "projB's worktree exposes projA's queue content despite the refusal"
echo "PASS: queue_branch.sh refuses a coordination branch stamped for a different project"

echo "PASS: queue_project_identity_test — all gates passed"
exit 0
