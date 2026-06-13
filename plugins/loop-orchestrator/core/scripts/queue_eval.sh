#!/usr/bin/env bash
# queue_eval.sh [--surface-profile <path>]
# Emits the JSON of the next unblocked, highest-priority task eligible for the
# current surface.  Stdout is empty when no eligible task exists.
# Exit: 0 always.

QUEUE_FILE=".loop/state/queue.jsonl"
PROFILE="${SURFACE_PROFILE:-.loop/state/surface_profile.json}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --surface-profile) PROFILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

python3 - "${QUEUE_FILE}" "${PROFILE}" <<'PY' 2>/dev/null || true
import sys, json, pathlib

queue_path, profile_path = sys.argv[1:]

queue = pathlib.Path(queue_path)
if not queue.exists():
    sys.exit(0)

rows = []
for line in queue.read_text().splitlines():
    line = line.strip()
    if line:
        try:
            data = json.loads(line)
            if isinstance(data, dict):
                rows.append(data)
        except json.JSONDecodeError:
            pass

# Load surface capabilities (empty set → match tasks with no requirements).
capabilities: set[str] = set()
profile = pathlib.Path(profile_path)
if profile.exists():
    try:
        data = json.loads(profile.read_text())
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
    # Check surface / service requirements.
    requires = row.get("requires", [])
    if requires and not all(r in capabilities for r in requires):
        continue
    candidates.append(row)

if not candidates:
    sys.exit(0)

best = max(candidates, key=lambda r: r.get("priority", 0))
print(json.dumps(best))
PY

exit 0
