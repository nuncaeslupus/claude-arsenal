#!/usr/bin/env bash
# continue_smoke.sh — smoke test for query_task.py (the /continue skill).
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERY_PY="${SCRIPT_DIR}/../skills/continue/scripts/query_task.py"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/create_task.py"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
BUNDLE_DIR="${SCRIPT_DIR}/../skills/init/assets"

for f in "${QUERY_PY}" "${ADD_PY}" "${INIT_PY}"; do
    if [[ ! -f "${f}" ]]; then
        echo "SKIP: ${f} not found" >&2; exit 0
    fi
done

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT
cd "${tmpdir}"

# Bootstrap claude-arsenal/ so queue_eval.sh is available
echo "# Test repo" > CLAUDE.md
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${BUNDLE_DIR}" >/dev/null 2>&1

QUEUE="claude-arsenal/queue/tasks.jsonl"

# Gate 1: empty queue → query_task exits 1
if python3 "${QUERY_PY}" --queue "${QUEUE}" 2>/dev/null; then
    echo "FAIL: empty queue should exit 1" >&2; exit 1
fi

# Gate 2: add a task, query_task returns it
ID1=$(python3 "${ADD_PY}" --title "Alpha task" --priority 10 --queue "${QUEUE}")
RESULT=$(python3 "${QUERY_PY}" --queue "${QUEUE}")
if ! echo "${RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['id'] == '${ID1}'" 2>/dev/null; then
    echo "FAIL: query_task did not return task ${ID1}" >&2; exit 1
fi

# Gate 3: fuzzy search finds the task
MATCH=$(python3 "${QUERY_PY}" --queue "${QUEUE}" --search "alpha")
if ! echo "${MATCH}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['id'] == '${ID1}'" 2>/dev/null; then
    echo "FAIL: fuzzy search did not find Alpha task" >&2; exit 1
fi

# Gate 4: fuzzy search with no match exits 1
if python3 "${QUERY_PY}" --queue "${QUEUE}" --search "zzz_no_match" 2>/dev/null; then
    echo "FAIL: unmatched fuzzy search should exit 1" >&2; exit 1
fi

echo "PASS: continue_smoke — all gates passed"
exit 0
