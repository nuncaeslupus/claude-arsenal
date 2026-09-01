#!/usr/bin/env bash
# worker_postcheck_test.sh — behaviour test for worker_postcheck.sh.
#
# This script runs `git reset --hard` + `git clean -fd` in the host's own tree,
# so its two safety properties are worth pinning precisely:
#
#   1. It restores to the branch the SESSION started on — never a hardcoded
#      `main`. On Claude Code on the web a session is pinned to its own branch,
#      and resetting to `main` would throw away exactly the work it was doing.
#   2. It snapshots a dirty tree to a rescue ref BEFORE destroying anything, so
#      a wrong assumption costs a ref lookup rather than the work.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
POSTCHECK="${BIN}/worker_postcheck.sh"
[[ -f "${POSTCHECK}" ]] || { echo "SKIP: ${POSTCHECK} not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

repo="${tmp}/repo"
git init -q -b main "${repo}"
cd "${repo}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git config commit.gpgsign false
echo "seed" > README
# `/init` gitignores the session's machine-local files, and it must be in the
# SEED commit so every branch carries it. That is load-bearing, not decoration:
# host_branch is written by this very script, so on a branch where it is not
# ignored the tree looks permanently dirty and the script restores endlessly.
printf 'arsenal/session/host_branch\narsenal/session/rescue_refs\narsenal/session/worktree_isolation\n' > .gitignore
git add -A && git commit -q -m "seed"

# The session is pinned to its own branch, exactly as a web session would be.
git checkout -q -b claude/web-session-xyz
echo "session work" > session.txt
git add -A && git commit -q -m "session commit"

mkdir -p arsenal/session

# --- 1: first run records the branch it found, rather than guessing ---
out=$(bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "ok" ]] || fail "clean tree on its own branch should report ok, got '${out}'"
recorded=$(cat arsenal/session/host_branch 2>/dev/null || true)
[[ "${recorded}" == "claude/web-session-xyz" ]] \
    || fail "should record the session's own branch, recorded '${recorded}'"

# --- 2: a worker that moved HEAD is restored to THAT branch, not to main ---
git checkout -q -b arsenal/t-abc123-some-task
echo "worker residue" > residue.txt
out=$(bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "restored" ]] || fail "a moved HEAD should report restored, got '${out}'"
now=$(git rev-parse --abbrev-ref HEAD)
[[ "${now}" == "claude/web-session-xyz" ]] \
    || fail "must restore to the session's branch, not '${now}' (restoring to main loses the session's work)"
[[ -f residue.txt ]] && fail "worker residue should have been cleaned"
[[ -f session.txt ]] || fail "the session's own committed work must survive the restore"

# --- 3: a dirty tree is snapshotted before anything is destroyed ---
git checkout -q -b arsenal/t-def456-another
echo "PRECIOUS UNCOMMITTED WORK" > precious.txt
bash "${POSTCHECK}" >/dev/null 2>&1
[[ -f precious.txt ]] && fail "test setup: the file should have been cleaned"
if ! git for-each-ref --format='%(refname)' | grep -q 'arsenal-rescue'; then
    fail "a dirty tree must be snapshotted to a rescue ref before the restore"
fi
found_precious=0
for ref in $(git for-each-ref --format='%(refname)' | grep 'arsenal-rescue'); do
    if git ls-tree -r --name-only "${ref}" 2>/dev/null | grep -q 'precious.txt'; then
        found_precious=1; break
    fi
done
[[ "${found_precious}" == "1" ]] || fail "a rescue ref should contain the destroyed work"

# --- 4: an explicit override still wins, for an orchestrator that knows better ---
git checkout -q -b arsenal/t-ghi789-third
out=$(ARSENAL_DEFAULT_BRANCH=main bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "restored" ]] || fail "explicit override should restore, got '${out}'"
now=$(git rev-parse --abbrev-ref HEAD)
[[ "${now}" == "main" ]] || fail "ARSENAL_DEFAULT_BRANCH should win, HEAD is '${now}'"

# --- 5: a clean tree already on the right branch is never touched ---
git checkout -q claude/web-session-xyz
before=$(git rev-parse HEAD)
out=$(bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "ok" ]] || fail "expected ok on a clean, correct tree, got '${out}'"
[[ "$(git rev-parse HEAD)" == "${before}" ]] || fail "a clean tree must not be disturbed"

# --- #147: the positive verdict needs proof, not an unmoved branch name ------
# A worker can run in the orchestrator's tree without ever moving HEAD (a
# surface that pins pushes to one branch; a worker that fails before
# open_task_pr.sh). `available` is what permits ramping to N workers, so
# recording it on that evidence licenses the parallel-fan-out-into-one-tree the
# clamp exists to prevent.
iso_file="${repo}/arsenal/session/worktree_isolation"
SELECT="${SCRIPT_DIR}/../skills/init/assets/scripts/task_select.py"

# Clean tree, on the host branch, worker reports THIS tree → in-place.
rm -f "${iso_file}"
out=$(ARSENAL_WORKER_TOPLEVEL="$(pwd -P)" bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "ok" ]] || fail "expected ok (nothing to restore), got '${out}'"
[[ "$(cat "${iso_file}" 2>/dev/null)" == "unavailable" ]] \
    || fail "a worker in the orchestrator's own tree must record unavailable, got '$(cat "${iso_file}" 2>/dev/null)'"
echo "PASS: a worker sharing the orchestrator's tree records unavailable"

# Same state, but the worker reports a different root → genuinely isolated.
rm -f "${iso_file}"
out=$(ARSENAL_WORKER_TOPLEVEL="/some/other/worktree" bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "ok" ]] || fail "expected ok, got '${out}'"
[[ "$(cat "${iso_file}" 2>/dev/null)" == "available" ]] \
    || fail "a worker in its own worktree must record available, got '$(cat "${iso_file}" 2>/dev/null)'"
echo "PASS: a worker in a separate tree records available"

# No report at all → unproven. Recording `available` here is what the issue
# called an unproven condition recorded as proven.
rm -f "${iso_file}"
out=$(bash "${POSTCHECK}" 2>/dev/null)
[[ "${out}" == "ok" ]] || fail "expected ok, got '${out}'"
if [[ -f "${iso_file}" ]]; then
    fail "with no worker root reported, nothing may be recorded (got '$(cat "${iso_file}")')"
fi
echo "PASS: an unreported worker root records nothing rather than 'available'"

# And the selector treats that unknown as clamping, so the safe default is safe.
mkdir -p arsenal/tasks
echo '{}' > "${tmp}/state.json"
sel=$(python3 "${SELECT}" --tasks-dir arsenal/tasks --state "${tmp}/state.json" --max 4 2>&1 >/dev/null </dev/null || true)
echo "${sel}" | grep -q "batch capped at 1 task" \
    || fail "unknown isolation must clamp the batch, stderr was: ${sel}"
echo "PASS: unknown isolation clamps the batch to one worker"

# --- #299: a snapshot that FAILED must not read as "nothing to save" --------
# rescue_snapshot.sh used to report a failed snapshot exactly as it reported a
# clean tree: no ref, exit 0. This script could not tell them apart, so a
# disk-full or a permissions error during the snapshot ended with `reset --hard`
# + `clean -fdq` run over the host's dirty tree and NO ref to recover it from.
# Silent, and only on the one occasion the safety net was needed.
failbin="${tmp}/failbin"
cp -R "${BIN}" "${failbin}"
cat > "${failbin}/rescue_snapshot.sh" <<'STUB'
#!/usr/bin/env bash
# Stands in for a snapshot that could not be written (disk full, permissions,
# a git object error): no ref on stdout, non-zero exit.
exit 1
STUB

git checkout -q claude/web-session-xyz
rm -f "${iso_file}"
git checkout -q -b arsenal/t-rescue-fails
echo "PRECIOUS UNCOMMITTED WORK" > irreplaceable.txt
before_head=$(git rev-parse HEAD)
set +e
bash "${failbin}/worker_postcheck.sh" >/dev/null 2>"${tmp}/rescue.err"
code=$?
set -e

[[ ${code} -eq 3 ]] \
    || fail "a failed snapshot on a dirty tree must exit 3, got ${code}"
[[ -f irreplaceable.txt ]] \
    || fail "THE WORK WAS DESTROYED after the snapshot failed — the whole point of #299"
grep -q "Nothing was discarded" "${tmp}/rescue.err" \
    || fail "the refusal must say plainly that nothing was lost: $(cat "${tmp}/rescue.err")"
[[ "$(git rev-parse HEAD)" == "${before_head}" ]] \
    || fail "the refusal must not move HEAD either"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "arsenal/t-rescue-fails" ]] \
    || fail "the refusal must leave the branch alone"
echo "PASS: a dirty tree whose snapshot failed is refused, not reset"

# ...and the other half of the distinction: a CLEAN tree still has nothing to
# save and must go through, or every restore would now stall.
git checkout -q -- . 2>/dev/null || true
rm -f irreplaceable.txt
out=$(bash "${failbin}/worker_postcheck.sh" 2>/dev/null)
[[ "${out}" == "restored" || "${out}" == "ok" ]] \
    || fail "a clean tree must still restore even with an unusable rescue script, got '${out}'"
echo "PASS: a clean tree still restores — 'nothing to save' and 'could not save' stay distinct"

echo "PASS: worker_postcheck_test — all gates passed"
