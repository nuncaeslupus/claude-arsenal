#!/usr/bin/env bash
# queue_batch.sh [--max N] [--surface-profile <path>]
# Emits up to N unblocked, highest-priority tasks eligible for the current
# surface, as JSONL (one compact JSON object per line). Stdout is empty when no
# eligible task exists. This is the canonical task selector; queue_eval.sh
# delegates to it with --max 1 for the single-task case.
#
# Selection (mirrors queue_eval.sh's filters, then adds batching):
#   - status == open
#   - all blocking deps are done
#   - surface capability requirements satisfied (only when a profile is present)
#   - matches LOOP_WORKSPACE if set (exact)
#   - carries every tag in LOOP_TAGS if set (AND; comma/space separated)
#   - highest priority first; up to N, with no task in the batch blocking
#     another task in the batch (intra-batch dep exclusion)
#
# Env: ARSENAL_MAX_WORKERS (default 2) sets N when --max is omitted.
#      LOOP_WORKSPACE, LOOP_TAGS — selection filters.
# Exit: 0 always.

QUEUE_FILE="claude-arsenal/queue/tasks.jsonl"
PROFILE="${SURFACE_PROFILE:-claude-arsenal/session/surface_profile.json}"
WORKSPACE="${LOOP_WORKSPACE:-}"
TAGS="${LOOP_TAGS:-}"
MAX="${ARSENAL_MAX_WORKERS:-2}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max) MAX="$2"; shift 2 ;;
        --surface-profile) PROFILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

python3 - "${QUEUE_FILE}" "${PROFILE}" "${WORKSPACE}" "${TAGS}" "${MAX}" <<'PY' || true
import sys, json, pathlib

queue_path, profile_path, workspace_filter, tags_filter, max_raw = sys.argv[1:6]

try:
    max_n = int(max_raw)
except ValueError:
    max_n = 2
if max_n < 1:
    max_n = 1

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

# Requested tags: comma- or space-separated; a candidate must carry them all.
requested_tags = {t for t in tags_filter.replace(",", " ").split() if t}
workspace_filter = workspace_filter.strip()

# IDs of tasks that satisfy dep edges.
done_ids = {r["id"] for r in rows if r.get("status") == "done"}

candidates = []
for row in rows:
    if row.get("status") != "open":
        continue
    # Check all blocking deps are done.
    deps = [d["id"] for d in (row.get("deps") or []) if d.get("type") == "blocks"]
    if any(dep not in done_ids for dep in deps):
        continue
    # Check surface / service requirements only when a profile is present.
    if capabilities is not None:
        requires = row.get("requires", [])
        if requires and not all(r in capabilities for r in requires):
            continue
    # Workspace filter (exact) if LOOP_WORKSPACE is set.
    if workspace_filter and row.get("workspace", "") != workspace_filter:
        continue
    # Tag filter (AND) if LOOP_TAGS is set.
    if requested_tags and not requested_tags.issubset(set(row.get("tags") or [])):
        continue
    candidates.append(row)

# Highest priority first; ties keep queue order (stable sort).
candidates.sort(key=lambda r: r.get("priority", 0), reverse=True)

# Greedily fill the batch, skipping any task whose blocking-dep edge points at
# a task already in the batch (or vice versa). Candidates already have all deps
# done, so this is a defensive guard against intra-batch ordering hazards.
batch: list[dict] = []
batch_ids: set[str] = set()
for row in candidates:
    if len(batch) >= max_n:
        break
    row_id = row.get("id")
    dep_ids = {d["id"] for d in (row.get("deps") or []) if d.get("type") == "blocks"}
    if dep_ids & batch_ids:
        continue  # this task blocks on one already in the batch
    if any(
        row_id in {d["id"] for d in (b.get("deps") or []) if d.get("type") == "blocks"}
        for b in batch
    ):
        continue  # this task blocks one already in the batch
    batch.append(row)
    if row_id is not None:
        batch_ids.add(row_id)

for row in batch:
    print(json.dumps(row, separators=(",", ":")))
PY

exit 0
