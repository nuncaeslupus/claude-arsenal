#!/usr/bin/env bash
# reclaim.sh [--lease-secs N] [--dry-run]
# Reclaim crashed/stranded claims: reset in_progress tasks whose claimed_at lease
# has expired (or is missing) back to open, then commit+push to the coordination
# branch. This is the recovery half of the claimed_at lease — claim.sh stamps the
# lease, queue_doctor.py flags an expired one (stale-lease / no-lease), and this
# script is what actually frees the task so another session can pick it up.
#
# Reuses update_task_row.py's open transition, so each reclaim increments the
# task's attempt counter and auto-escalates at the cap — a task that keeps
# stranding sessions surfaces for human recovery instead of being reclaimed
# forever.
#
# Must run on the coordination branch (default arsenal-queue) — see claim.sh for
# why the shared ref is the lock. Resolves the queue inside ARSENAL_QUEUE_DIR
# when set (like claim.sh / release.sh) so the main working tree never switches.
#
# Env:
#   ARSENAL_QUEUE_BRANCH  coordination branch (default arsenal-queue)
#   ARSENAL_QUEUE_REMOTE  remote (default origin)
#   ARSENAL_QUEUE_DIR     coordination worktree; optional
#   ARSENAL_LEASE_SECS    lease window in seconds (default 7200); --lease-secs wins
# Flags:
#   --lease-secs N  override the lease window
#   --dry-run       print which tasks WOULD be reclaimed; make no changes
# Exit: 0 on success (including "nothing to reclaim"), 1 after failed pushes,
#       2 on misconfiguration (wrong branch / protected branch / no upstream).

set -uo pipefail

QUEUE_BRANCH="${ARSENAL_QUEUE_BRANCH:-arsenal-queue}"
REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
QUEUE_FILE="claude-arsenal/queue/tasks.jsonl"
LEASE_SECS="${ARSENAL_LEASE_SECS:-7200}"
DRY_RUN=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_PY="${SCRIPT_DIR}/../scripts/update_task_row.py"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lease-secs) LEASE_SECS="${2:-7200}"; shift 2 ;;
        --dry-run) DRY_RUN="1"; shift ;;
        *) shift ;;
    esac
done

# Operate from the coordination worktree when set so the main tree never moves.
if [[ -n "${ARSENAL_QUEUE_DIR:-}" ]]; then
    cd "${ARSENAL_QUEUE_DIR}" \
        || { echo "reclaim.sh: could not cd into queue worktree '${ARSENAL_QUEUE_DIR}'" >&2; exit 2; }
fi

if [[ ! -f "${QUEUE_FILE}" ]]; then
    echo "reclaim.sh: queue file not found at ${QUEUE_FILE}" >&2
    exit 2
fi

# Identify expired/missing-lease in_progress tasks (same lease logic as the
# doctor). Prints one task id per line; empty when nothing is stale.
stale_ids="$(python3 - "${QUEUE_FILE}" "${LEASE_SECS}" <<'PY'
import sys, json, pathlib
from datetime import datetime, timezone

queue_path, lease_raw = sys.argv[1:3]
try:
    lease_secs = int(lease_raw)
except ValueError:
    lease_secs = 7200

now = datetime.now(timezone.utc)
path = pathlib.Path(queue_path)
for line in path.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        row = json.loads(line)
    except json.JSONDecodeError:
        continue
    if not isinstance(row, dict) or row.get("status") != "in_progress":
        continue
    claimed_at = row.get("claimed_at")
    expired = True  # missing lease counts as stale
    if claimed_at:
        try:
            ts = datetime.fromisoformat(str(claimed_at))
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            expired = (now - ts).total_seconds() > lease_secs
        except (ValueError, TypeError):
            expired = True  # unparseable lease — treat as stale
    if expired and row.get("id"):
        print(row["id"])
PY
)" || { echo "reclaim.sh: failed to scan queue for stale leases" >&2; exit 2; }

if [[ -z "${stale_ids}" ]]; then
    echo "reclaim.sh: no expired leases to reclaim (lease ${LEASE_SECS}s)"
    exit 0
fi

if [[ -n "${DRY_RUN}" ]]; then
    echo "reclaim.sh: would reclaim (dry-run):"
    printf '  %s\n' ${stale_ids}
    exit 0
fi

# Guard: a reclaim pushed from the wrong branch never lands. Fail loud.
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${current_branch}" != "${QUEUE_BRANCH}" ]]; then
    echo "reclaim.sh: not on coordination branch '${QUEUE_BRANCH}' (HEAD=${current_branch:-unknown}); run queue_branch.sh first" >&2
    exit 2
fi

reclaimed=()
for tid in ${stale_ids}; do
    # update_task_row.py open: increments attempts, auto-escalates at the cap,
    # clears assignee + claimed_at. Atomic write keeps the ledger consistent.
    final_status="$(python3 "${UPDATE_PY}" "${tid}" open "${QUEUE_FILE}" "" "")" || {
        echo "reclaim.sh: failed to reset ${tid}" >&2
        exit 1
    }
    reclaimed+=("${tid}:${final_status}")
done

# Guard the index (a residual staged path would otherwise ride onto the ledger).
git reset -q >/dev/null 2>&1 || true
git add "${QUEUE_FILE}" 2>/dev/null

if git diff --cached --quiet -- 2>/dev/null; then
    echo "reclaim.sh: ledger already reflects the reclaim; nothing to push"
    exit 0
fi
if ! git commit -m "reclaim: ${reclaimed[*]}" >/dev/null 2>&1; then
    echo "reclaim.sh: commit failed (status NOT recorded)" >&2
    exit 1
fi

# Single-commit guard: only this one reclaim commit may reach the ledger.
git fetch "${REMOTE}" "${QUEUE_BRANCH}" >/dev/null 2>&1 || true
queue_tip="$(git rev-parse --verify --quiet "refs/remotes/${REMOTE}/${QUEUE_BRANCH}" 2>/dev/null \
    || git rev-parse --verify --quiet FETCH_HEAD 2>/dev/null || true)"
if [[ -n "${queue_tip}" ]]; then
    if ! git merge-base --is-ancestor "HEAD~1" "${queue_tip}" 2>/dev/null; then
        echo "reclaim.sh: refusing to push local commits to '${QUEUE_BRANCH}' — only single queue commits may land on the coordination ledger; non-queue commits are present on this branch" >&2
        exit 2
    fi
fi

# Push with exponential backoff; rebase on a race, fail loud on anything else.
delay=1
for attempt in 1 2 3; do
    if push_err="$(LANG=C git push "${REMOTE}" "HEAD:refs/heads/${QUEUE_BRANCH}" 2>&1)"; then
        echo "reclaim.sh: reclaimed ${reclaimed[*]}"
        exit 0
    fi
    if ! printf '%s' "${push_err}" | grep -qiE 'non-fast-forward|fetch first|cannot lock ref|but expected|failed to update ref|incorrect old value'; then
        echo "reclaim.sh: push to '${QUEUE_BRANCH}' failed (not a race): ${push_err}" >&2
        exit 2
    fi
    git pull --rebase --autostash "${REMOTE}" "${QUEUE_BRANCH}" 2>/dev/null \
        || git rebase --abort 2>/dev/null || true
    sleep "${delay}"
    delay=$((delay * 2))
done

echo "reclaim.sh: push failed after 3 attempts" >&2
exit 1
