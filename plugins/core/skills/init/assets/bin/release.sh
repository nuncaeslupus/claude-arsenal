#!/usr/bin/env bash
# release.sh <task_id> <status> [--pr <url>]
# Updates a task's status in queue.jsonl, commits (the queue row AND the task
# payload, so any ## Failure notes / PR-URL edits land too), and pushes to the
# dedicated coordination branch (default: arsenal-queue, override
# ARSENAL_QUEUE_BRANCH). Must run on that branch — see claim.sh for why the
# shared ref is the lock.
# <status>: done | open | blocked | in_progress
# --pr <url>: optional; records the per-task PR URL/number on the queue row.
# Exit: 0 on success, 1 after 3 failed push attempts, 2 on misconfiguration
#       (wrong branch / protected branch / no upstream).

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
QUEUE_FILE="claude-arsenal/queue/tasks.jsonl"
TASK_ID="${1:?release.sh requires <task_id>}"
NEW_STATUS="${2:?release.sh requires <status>: done|open|blocked|in_progress}"
shift 2 || true

PR_URL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr) PR_URL="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done

case "${NEW_STATUS}" in
    done|open|blocked|in_progress) ;;
    *) echo "release.sh: invalid status '${NEW_STATUS}'" >&2; exit 1 ;;
esac

# Guard: a release pushed from the wrong branch diverges from the coordination
# ref and never lands. Fail loud rather than retry into a dead end.
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${current_branch}" != "${QUEUE_BRANCH}" ]]; then
    echo "release.sh: not on coordination branch '${QUEUE_BRANCH}' (HEAD=${current_branch:-unknown}); run queue_branch.sh first" >&2
    exit 2
fi

python3 - "${TASK_ID}" "${NEW_STATUS}" "${QUEUE_FILE}" "${PR_URL}" <<'PY' || exit 1
import sys, json, pathlib

task_id, new_status, queue_path, pr_url = sys.argv[1:5]
path = pathlib.Path(queue_path)

rows = []
for line in path.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line:
        try:
            data = json.loads(line)
            if isinstance(data, dict):
                rows.append(data)
        except json.JSONDecodeError:
            pass

updated = False
for row in rows:
    if row.get("id") == task_id:
        row["status"] = new_status
        if new_status not in ("in_progress",):
            row["assignee"] = None
        if pr_url:
            row["pr"] = pr_url
        updated = True

if not updated:
    print(f"release.sh: task {task_id} not found", file=sys.stderr)
    sys.exit(1)

path.write_text(
    "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n",
    encoding="utf-8",
)
PY

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
git commit -m "release: ${TASK_ID} → ${NEW_STATUS}" 2>/dev/null || true

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
    if ! printf '%s' "${push_err}" | grep -qiE 'non-fast-forward|fetch first|cannot lock ref|but expected|failed to update ref'; then
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
