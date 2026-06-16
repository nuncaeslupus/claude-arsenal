#!/usr/bin/env bash
# release.sh <task_id> <status> [--pr <url>] [--reset-attempts]
# Updates a task's status in queue.jsonl, commits (the queue row AND the task
# payload, so any ## Failure notes / PR-URL edits land too), and pushes to the
# dedicated coordination branch (default: arsenal-queue, override
# ARSENAL_QUEUE_BRANCH). Must run on that branch — see claim.sh for why the
# shared ref is the lock.
# <status>: done | merged | open | blocked | in_progress | escalated
#   done       = PR opened + gate passed (the worker's terminal state).
#   merged     = that PR later landed on the default branch; set by
#                reconcile_merged.sh after a `gh` merge-state check.
#   escalated  = task auto-set when attempts >= max_attempts (see update_task_row.py).
# --pr <url>: optional; records the per-task PR URL/number on the queue row.
# --reset-attempts: clear the attempts counter and return the task to open,
#                   bypassing the auto-escalation cap check. Only meaningful
#                   with status open; silently ignored for other statuses.
# Exit: 0 on success, 1 after 3 failed push attempts, 2 on misconfiguration
#       (wrong branch / protected branch / no upstream).

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
QUEUE_FILE="claude-arsenal/queue/tasks.jsonl"
TASK_ID="${1:?release.sh requires <task_id>}"
NEW_STATUS="${2:?release.sh requires <status>: done|open|blocked|in_progress|escalated}"
shift 2 || true

# Resolve script dir to an absolute path now, before any cd, so UPDATE_PY
# stays valid even after we cd into the coordination worktree below.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_PY="${SCRIPT_DIR}/../scripts/update_task_row.py"

PR_URL=""
RESET_ATTEMPTS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr) PR_URL="${2:-}"; shift 2 ;;
        --reset-attempts) RESET_ATTEMPTS="1"; shift ;;
        *) shift ;;
    esac
done

case "${NEW_STATUS}" in
    done|merged|open|blocked|in_progress|escalated) ;;
    *) echo "release.sh: invalid status '${NEW_STATUS}'" >&2; exit 1 ;;
esac

# Operate from the coordination worktree when ARSENAL_QUEUE_DIR is set so the
# main working tree never needs to change branch.
if [[ -n "${ARSENAL_QUEUE_DIR:-}" ]]; then
    cd "${ARSENAL_QUEUE_DIR}" \
        || { echo "release.sh: could not cd into queue worktree '${ARSENAL_QUEUE_DIR}'" >&2; exit 2; }
fi

# Guard: a release pushed from the wrong branch diverges from the coordination
# ref and never lands. Fail loud rather than retry into a dead end.
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${current_branch}" != "${QUEUE_BRANCH}" ]]; then
    echo "release.sh: not on coordination branch '${QUEUE_BRANCH}' (HEAD=${current_branch:-unknown}); run queue_branch.sh first" >&2
    exit 2
fi

final_status="$(python3 "${UPDATE_PY}" "${TASK_ID}" "${NEW_STATUS}" "${QUEUE_FILE}" "${PR_URL}" "${RESET_ATTEMPTS}")" || exit 1

if [[ -z "${final_status}" ]]; then
    echo "release.sh: update_task_row.py returned empty status for ${TASK_ID}" >&2
    exit 1
fi

# Guard: never let a worker's residual staged changes ride onto the append-only
# coordination ledger. An in-place worker (one whose `isolation: worktree` was
# silently ignored) may have left other paths staged in the index; a plain
# `git commit` would sweep them onto the queue branch. A mixed reset clears the
# index without touching the working tree, so only the queue row + payload we
# stage below get committed. (worker_postcheck.sh should already have cleaned
# the tree; this guards the index regardless.)
git reset -q >/dev/null 2>&1 || true

# Stage the queue row AND the task payload: a release may carry ## Failure notes
# or a PR URL written into claude-arsenal/queue/<id>.md that must travel with the
# state commit rather than being lost on worktree cleanup. Stage them separately
# — a single `git add` with a non-existent payload pathspec fails atomically and
# would leave the queue change unstaged (a task may have no payload file).
git add "${QUEUE_FILE}" 2>/dev/null
if [[ -f "claude-arsenal/queue/${TASK_ID}.md" ]]; then
    git add "claude-arsenal/queue/${TASK_ID}.md" 2>/dev/null
fi

# Distinguish "already at target" from a real commit failure. The Python step
# above always sets the row to ${final_status} (updated=True), so an empty staged
# diff means the ledger already reflects the target — an idempotent no-op, not
# a recorded change. Swallowing the commit exit and pushing unchanged HEAD would
# otherwise report success when no ledger commit landed (and would push extra
# local commits — see the single-commit guard below).
if git diff --cached --quiet -- 2>/dev/null; then
    echo "release.sh: ${TASK_ID} already at ${final_status}; no new ledger commit to push" >&2
    exit 0
fi
if ! git commit -m "release: ${TASK_ID} → ${final_status}" >/dev/null 2>&1; then
    echo "release.sh: commit failed for ${TASK_ID} → ${final_status} (status NOT recorded)" >&2
    exit 1
fi

# Guard: only this single release commit may reach the coordination ledger.
# `git push HEAD:refs/heads/<branch>` publishes EVERY local commit ahead of the
# remote, so non-queue commits on a shared tree would leak onto the queue. Fetch
# the published tip and confirm exactly one commit (our release) sits on top of
# it. A rebase in the retry loop below replays only this one queue commit, so
# the invariant holds across retries; checking once here is sufficient.
git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
queue_tip="$(git rev-parse --verify --quiet "refs/remotes/${REMOTE}/${QUEUE_BRANCH}" 2>/dev/null \
    || git rev-parse --verify --quiet FETCH_HEAD 2>/dev/null || true)"
if [[ -n "${queue_tip}" ]]; then
    # The parent of our release commit must already be on the published tip — then
    # only the release commit is new. If HEAD~1 is NOT an ancestor of the tip, this
    # branch carries non-queue commits; refuse rather than leak them.
    if ! git merge-base --is-ancestor "HEAD~1" "${queue_tip}" 2>/dev/null; then
        echo "release.sh: refusing to push local commits to '${QUEUE_BRANCH}' — only single claim/release commits may land on the coordination ledger; non-queue commits are present on this branch" >&2
        exit 2
    fi
fi

# Push to the coordination ref with exponential backoff retry (up to 3
# attempts). A non-fast-forward means a concurrent claim/release landed first:
# rebase onto it and retry. Any other failure is a misconfiguration, not a
# race — fail loud immediately instead of burning all three attempts.
delay=1
for attempt in 1 2 3; do
    # LANG=C keeps error messages in English so the grep below is locale-safe.
    if push_err="$(LANG=C git push "${REMOTE}" "HEAD:refs/heads/${QUEUE_BRANCH}" 2>&1)"; then
        exit 0
    fi
    if ! printf '%s' "${push_err}" | grep -qiE 'non-fast-forward|fetch first|cannot lock ref|but expected|failed to update ref|incorrect old value'; then
        echo "release.sh: push to '${QUEUE_BRANCH}' failed (not a race): ${push_err}" >&2
        exit 2
    fi
    git pull --rebase --autostash "${REMOTE}" "${QUEUE_BRANCH}" 2>/dev/null \
        || git rebase --abort 2>/dev/null || true
    sleep "${delay}"
    delay=$((delay * 2))
done

echo "release.sh: push failed after 3 attempts for task ${TASK_ID}" >&2
exit 1
