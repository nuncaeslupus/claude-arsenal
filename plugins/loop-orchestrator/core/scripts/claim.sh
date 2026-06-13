#!/usr/bin/env bash
# claim.sh <task_id> [<session_id>]
# Attempts to claim an open task with optimistic git-push concurrency.
# Stdout on success : "won" then the task JSON on the next line.
# Stdout on race loss: "lost"
# Exit: 0 always.

QUEUE_FILE=".loop/state/queue.jsonl"
TASK_ID="${1:?claim.sh requires <task_id>}"
SESSION_ID="${2:-${CLAUDE_SESSION_ID:-"session-$$"}}"

_claim_json() {
    python3 - "${TASK_ID}" "${SESSION_ID}" "${QUEUE_FILE}" <<'PY'
import sys, json, pathlib

task_id, session_id, queue_path = sys.argv[1:]
path = pathlib.Path(queue_path)
if not path.exists():
    print("lost")
    sys.exit(0)

rows = []
for line in path.read_text().splitlines():
    line = line.strip()
    if line:
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            pass

target = next(
    (r for r in rows if r.get("id") == task_id and r.get("status") == "open"),
    None,
)
if target is None:
    print("lost")
    sys.exit(0)

target["status"] = "in_progress"
target["assignee"] = session_id
path.write_text(
    "\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n"
)
print("ok")
print(json.dumps(target))
PY
}

result=$(_claim_json 2>/dev/null)
first="${result%%$'\n'*}"

if [[ "${first}" != "ok" ]]; then
    echo "lost"
    exit 0
fi

task_json="${result#ok$'\n'}"

# Stage, commit, and push.
git add "${QUEUE_FILE}" 2>/dev/null || { echo "lost"; exit 0; }

if ! git commit -m "claim: ${TASK_ID} → in_progress [${SESSION_ID}]" >/dev/null 2>&1; then
    # Nothing staged or already committed — race lost locally.
    git checkout -- "${QUEUE_FILE}" 2>/dev/null || true
    echo "lost"
    exit 0
fi

if git push >/dev/null 2>&1; then
    echo "won"
    echo "${task_json}"
else
    # Push rejected — another session already pushed a claim.
    git reset --hard HEAD~1 >/dev/null 2>&1 || true
    git pull --rebase >/dev/null 2>&1 || true
    echo "lost"
fi

exit 0
