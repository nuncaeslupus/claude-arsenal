#!/usr/bin/env bash
# queue_eval.sh [--surface-profile <path>]
# Emits the JSON of the next unblocked, highest-priority task eligible for the
# current surface.  Stdout is empty when no eligible task exists.
# Exit: 0 always.

QUEUE_FILE="claude-arsenal/queue/tasks.jsonl"
PROFILE="${SURFACE_PROFILE:-claude-arsenal/session/surface_profile.json}"
WORKSPACE="${LOOP_WORKSPACE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --surface-profile) PROFILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

python3 - "${QUEUE_FILE}" "${PROFILE}" "${WORKSPACE}" <<'PY' || true
import sys, json, pathlib, os

queue_path, profile_path, workspace_filter = sys.argv[1], sys.argv[2], sys.argv[3]

queue = pathlib.Path(queue_path)
if not queue.exists():
    sys.exit(0)

rows = []
for line in queue.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line:
        try:
            data = json.loads(line)
            if isinstance(data, dict):
                rows.append(data)
        except json.JSONDecodeError:
            pass

# Load surface capabilities.
# None = no profile file → no capability filtering (match all tasks).
# This allows CC Web sessions without hooks and fresh inits to pick up any task.
capabilities = None
profile = pathlib.Path(profile_path)
if profile.exists():
    try:
        data = json.loads(profile.read_text(encoding="utf-8"))
        capabilities = set(data.get("capabilities", []))
    except Exception:
        pass

# IDs of tasks that satisfy dep edges.
done_ids = {r["id"] for r in rows if r.get("status") == "done"}

candidates = []
for row in rows:
    if row.get("status") != "open":
        continue
    # Check all blocking deps are done.
    deps = [d["id"] for d in row.get("deps", []) if d.get("type") == "blocks"]
    if any(dep not in done_ids for dep in deps):
        continue
    # Check surface / service requirements only when a profile is present.
    if capabilities is not None:
        requires = row.get("requires", [])
        if requires and not all(r in capabilities for r in requires):
            continue
    candidates.append(row)

# Apply workspace filter if LOOP_WORKSPACE env var is set.
if workspace_filter.strip():
    candidates = [r for r in candidates if r.get("workspace", "") == workspace_filter.strip()]

if not candidates:
    sys.exit(0)

best = max(candidates, key=lambda r: r.get("priority", 0))
print(json.dumps(best))
PY

exit 0
