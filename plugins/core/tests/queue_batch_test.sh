#!/usr/bin/env bash
# queue_batch_test.sh — unit test for queue_batch.sh (parallel fan-out selector).
# Asserts: the QIC-6 double-dispatch clamp (single task until isolation is
# confirmed), --max cap, priority order, blocking-dep exclusion (a task whose dep
# is not done never appears), and LOOP_TAGS × LOOP_WORKSPACE AND-filtering.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH="${SCRIPT_DIR}/../skills/init/assets/bin/queue_batch.sh"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/create_task.py"

for f in "${BATCH}" "${ADD_PY}"; do
    if [[ ! -f "${f}" ]]; then
        echo "SKIP: ${f} not found" >&2; exit 0
    fi
done

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT
cd "${tmpdir}"

mkdir -p claude-arsenal/queue
Q="claude-arsenal/queue/tasks.jsonl"

# DAG:
#   A prio10 CLI/FRONTEND  (no deps)
#   B prio 9 CLI/FRONTEND  (deps A → blocked while A is open)
#   C prio 8 CLI/BACKEND   (no deps)
#   D prio 7 WEB/FRONTEND  (no deps)
A=$(python3 "${ADD_PY}" --title "A task" --priority 10 --tag CLI --workspace FRONTEND --queue "${Q}")
B=$(python3 "${ADD_PY}" --title "B task" --priority 9  --tag CLI --workspace FRONTEND --deps "${A}" --queue "${Q}")
C=$(python3 "${ADD_PY}" --title "C task" --priority 8  --tag CLI --workspace BACKEND  --queue "${Q}")
D=$(python3 "${ADD_PY}" --title "D task" --priority 7  --tag WEB --workspace FRONTEND --queue "${Q}")

ids() { python3 -c "import json,sys; [print(json.loads(l)['id']) for l in sys.stdin if l.strip()]"; }

# Gate 0 (QIC-6): without ARSENAL_ISOLATION_CONFIRMED the batch is clamped to a
# single task regardless of --max — the mechanical double-dispatch guard. This
# must hold BEFORE we opt into multi-task batching for the gates below.
COUNT=$(ARSENAL_ISOLATION_CONFIRMED="" bash "${BATCH}" --max 5 | grep -c .)
if [[ "${COUNT}" -ne 1 ]]; then
    echo "FAIL: unconfirmed isolation must clamp the batch to 1, got ${COUNT}" >&2; exit 1
fi
echo "PASS: double-dispatch guard clamps to 1 until isolation is confirmed"

# Remaining gates test the multi-task selector, which is only reached once a
# worker has proven real worktree isolation — so opt in for the rest of the run.
export ARSENAL_ISOLATION_CONFIRMED=1

# Gate 1: --max 5 global → A, C, D (B excluded: dep A still open); A first by priority.
OUT=$(bash "${BATCH}" --max 5 | ids)
EXPECT=$(printf '%s\n%s\n%s\n' "${A}" "${C}" "${D}")
if [[ "${OUT}" != "${EXPECT}" ]]; then
    echo "FAIL: global batch expected [A C D] in priority order, got:" >&2
    echo "${OUT}" >&2; exit 1
fi
echo "PASS: global batch excludes dep-blocked B and orders by priority"

# Gate 2: --max 2 → exactly two, highest priority (A, C).
COUNT=$(bash "${BATCH}" --max 2 | grep -c .)
if [[ "${COUNT}" -ne 2 ]]; then
    echo "FAIL: --max 2 should return 2 tasks, got ${COUNT}" >&2; exit 1
fi
echo "PASS: --max caps the batch size"

# Gate 3: LOOP_TAGS=CLI → A and C only (D is WEB, B dep-blocked).
OUT=$(LOOP_TAGS=CLI bash "${BATCH}" --max 5 | ids | sort)
EXPECT=$(printf '%s\n%s\n' "${A}" "${C}" | sort)
if [[ "${OUT}" != "${EXPECT}" ]]; then
    echo "FAIL: LOOP_TAGS=CLI expected [A C], got:" >&2; echo "${OUT}" >&2; exit 1
fi
echo "PASS: LOOP_TAGS filters by tag"

# Gate 4: LOOP_TAGS=CLI + LOOP_WORKSPACE=FRONTEND → A only (AND of both axes).
OUT=$(LOOP_TAGS=CLI LOOP_WORKSPACE=FRONTEND bash "${BATCH}" --max 5 | ids)
if [[ "${OUT}" != "${A}" ]]; then
    echo "FAIL: tag CLI AND workspace FRONTEND expected [A], got: '${OUT}'" >&2; exit 1
fi
echo "PASS: LOOP_TAGS × LOOP_WORKSPACE AND together"

# Gate 5: two tags ANDed with no task carrying both → empty.
OUT=$(LOOP_TAGS="CLI WEB" bash "${BATCH}" --max 5 | grep -c . || true)
if [[ "${OUT}" -ne 0 ]]; then
    echo "FAIL: LOOP_TAGS='CLI WEB' should match nothing, got ${OUT} lines" >&2; exit 1
fi
echo "PASS: multiple tags AND (no task has both → empty)"

# Gate 6: once A is done, B becomes eligible.
python3 - "${Q}" "${A}" <<'PY'
import sys, json, pathlib
path = pathlib.Path(sys.argv[1]); target = sys.argv[2]
rows = [json.loads(l) for l in path.read_text().splitlines() if l.strip()]
for r in rows:
    if r["id"] == target:
        r["status"] = "done"
path.write_text("\n".join(json.dumps(r, separators=(",", ":")) for r in rows) + "\n")
PY
if ! bash "${BATCH}" --max 5 | ids | grep -qx "${B}"; then
    echo "FAIL: B should be eligible once its dep A is done" >&2; exit 1
fi
echo "PASS: dep-blocked task becomes eligible when its blocker is done"

echo "PASS: queue_batch_test — all gates passed"
exit 0
