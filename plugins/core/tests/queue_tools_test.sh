#!/usr/bin/env bash
# queue_tools_test.sh — integration test for create_task.py + query_status.py.
# Verifies that /queue-add appends a valid JSONL row and /queue-status reports correct counts.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/create_task.py"
STATUS_PY="${SCRIPT_DIR}/../skills/queue-status/scripts/query_status.py"

for f in "${ADD_PY}" "${STATUS_PY}"; do
    if [[ ! -f "${f}" ]]; then
        echo "SKIP: ${f} not found" >&2; exit 0
    fi
done

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

QUEUE="${tmpdir}/queue.jsonl"

# --- Test 1: add two tasks ---
ID1=$(python3 "${ADD_PY}" --title "Task alpha" --priority 10 --queue "${QUEUE}")
ID2=$(python3 "${ADD_PY}" --title "Task beta"  --priority 5  --queue "${QUEUE}" --deps "${ID1}")

if [[ -z "${ID1}" || -z "${ID2}" ]]; then
    echo "FAIL: create_task.py did not print task IDs" >&2; exit 1
fi

# IDs must match lo-XXXX pattern
if ! echo "${ID1}" | grep -qE '^lo-[0-9a-f]{4}$'; then
    echo "FAIL: ID1 '${ID1}' does not match lo-XXXX pattern" >&2; exit 1
fi

# --- Test 2: queue file has exactly 2 rows ---
ROW_COUNT=$(wc -l < "${QUEUE}" | tr -d ' ')
if [[ "${ROW_COUNT}" -ne 2 ]]; then
    echo "FAIL: expected 2 rows in queue.jsonl, got ${ROW_COUNT}" >&2; exit 1
fi

# --- Test 3: each row is valid JSON with required fields ---
python3 - "${QUEUE}" <<'PY'
import json, sys
required = {"id","title","status","priority","requires","deps","assignee","payload"}
for i, line in enumerate(open(sys.argv[1]), 1):
    try:
        row = json.loads(line)
    except Exception as e:
        print(f"FAIL: row {i} is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    missing = required - set(row.keys())
    if missing:
        print(f"FAIL: row {i} missing fields: {missing}", file=sys.stderr)
        sys.exit(1)
print("JSON schema: OK")
PY

# --- Test 4: queue_status reports correct counts ---
STATUS=$(python3 "${STATUS_PY}" --queue "${QUEUE}")
if ! echo "${STATUS}" | grep -q "total=2"; then
    echo "FAIL: expected total=2 in status output, got: ${STATUS}" >&2; exit 1
fi
if ! echo "${STATUS}" | grep -q "open=2"; then
    echo "FAIL: expected open=2, got: ${STATUS}" >&2; exit 1
fi
if ! echo "${STATUS}" | grep -q "done=0"; then
    echo "FAIL: expected done=0, got: ${STATUS}" >&2; exit 1
fi

# --- Test 5: detail output shows IDs ---
DETAIL=$(python3 "${STATUS_PY}" --queue "${QUEUE}" --detail)
if ! echo "${DETAIL}" | grep -q "${ID1}"; then
    echo "FAIL: ID1 ${ID1} not in detail output" >&2; exit 1
fi
if ! echo "${DETAIL}" | grep -q "${ID2}"; then
    echo "FAIL: ID2 ${ID2} not in detail output" >&2; exit 1
fi

# --- Test 6: deps validation — adding dep on non-existent ID fails ---
if python3 "${ADD_PY}" --title "Orphan" --deps "lo-0000" --queue "${QUEUE}" 2>/dev/null; then
    echo "FAIL: create_task should have rejected unknown dep lo-0000" >&2; exit 1
fi

# --- Test 7: --workspace field is set in schema ---
ID3=$(python3 "${ADD_PY}" --title "Workspace task" --priority 3 --workspace FRONTEND --queue "${QUEUE}")
WS_ROW=$(python3 -c "
import json, sys
for line in open(sys.argv[1]):
    row = json.loads(line)
    if row['id'] == sys.argv[2]:
        print(row.get('workspace', ''))
" "${QUEUE}" "${ID3}")
if [[ "${WS_ROW}" != "FRONTEND" ]]; then
    echo "FAIL: workspace field not set correctly, got: '${WS_ROW}'" >&2; exit 1
fi

echo "PASS: queue_tools_test — all gates passed"
exit 0
