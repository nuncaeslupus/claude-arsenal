#!/usr/bin/env bash
# release.sh <task_id> <status>
# Updates a task's status in queue.jsonl, commits, and pushes.
# <status>: done | open | blocked | in_progress
# Exit: 0 on success, 1 after 3 failed push attempts.

QUEUE_FILE=".loop/state/queue.jsonl"
TASK_ID="${1:?release.sh requires <task_id>}"
NEW_STATUS="${2:?release.sh requires <status>: done|open|blocked|in_progress}"

case "${NEW_STATUS}" in
    done|open|blocked|in_progress) ;;
    *) echo "release.sh: invalid status '${NEW_STATUS}'" >&2; exit 1 ;;
esac

python3 - "${TASK_ID}" "${NEW_STATUS}" "${QUEUE_FILE}" <<'PY' || exit 1
import sys, json, pathlib

task_id, new_status, queue_path = sys.argv[1:]
path = pathlib.Path(queue_path)

rows = []
for line in path.read_text().splitlines():
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
        updated = True

if not updated:
    print(f"release.sh: task {task_id} not found", file=sys.stderr)
    sys.exit(1)

path.write_text(
    "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n"
)
PY

git add "${QUEUE_FILE}" 2>/dev/null
git commit -m "release: ${TASK_ID} → ${NEW_STATUS}" 2>/dev/null || true

# Push with exponential backoff retry (up to 3 attempts).
delay=1
for attempt in 1 2 3; do
    if git push 2>/dev/null; then
        exit 0
    fi
    git pull --rebase 2>/dev/null || git rebase --abort 2>/dev/null || true
    sleep "${delay}"
    delay=$((delay * 2))
done

echo "release.sh: push failed after 3 attempts for task ${TASK_ID}" >&2
exit 1
