#!/usr/bin/env bash
# workspace_test.sh — tests for workspace support in init and queue_eval.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/create_task.py"
LIST_SH="${SCRIPT_DIR}/../bundle/bin/workspace_list.sh"
EVAL_SH="${SCRIPT_DIR}/../bundle/bin/queue_eval.sh"

for f in "${INIT_PY}" "${ADD_PY}" "${LIST_SH}" "${EVAL_SH}"; do
    if [[ ! -f "${f}" ]]; then
        echo "SKIP: ${f} not found" >&2; exit 0
    fi
done

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT
cd "${tmpdir}"

# Gate 1: init creates claude-arsenal/ structure
echo "# Test repo" > CLAUDE.md
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${SCRIPT_DIR}/../bundle"

[[ -d "claude-arsenal/bin" ]] || { echo "FAIL: claude-arsenal/bin missing" >&2; exit 1; }
[[ -f "claude-arsenal/queue/tasks.jsonl" ]] || { echo "FAIL: tasks.jsonl missing" >&2; exit 1; }
[[ -f "claude-arsenal/session/handover.md" ]] || { echo "FAIL: session/handover.md missing" >&2; exit 1; }

# Gate 2: init --workspace creates workspace dirs
python3 "${INIT_PY}" --repo-path "${tmpdir}" --workspace FRONTEND --bundle-dir "${SCRIPT_DIR}/../bundle"

[[ -f "claude-arsenal/project/FRONTEND/spec.md" ]] || { echo "FAIL: FRONTEND/spec.md missing" >&2; exit 1; }
[[ -f "claude-arsenal/project/FRONTEND/plan.md" ]] || { echo "FAIL: FRONTEND/plan.md missing" >&2; exit 1; }
[[ -f "claude-arsenal/project/FRONTEND/handover.md" ]] || { echo "FAIL: FRONTEND/handover.md missing" >&2; exit 1; }

# Gate 3: workspace_list.sh lists FRONTEND
WS_LIST=$(bash "${LIST_SH}")
if ! echo "${WS_LIST}" | grep -q "FRONTEND"; then
    echo "FAIL: workspace_list.sh did not list FRONTEND; got: ${WS_LIST}" >&2; exit 1
fi

# Gate 4: CLAUDE.md has session-protocol marker
MARKER="<!-- claude-arsenal: auto-managed -->"
if ! grep -qF "${MARKER}" CLAUDE.md; then
    echo "FAIL: session-protocol marker missing from CLAUDE.md" >&2; exit 1
fi

# Gate 5: idempotency — second full init does not duplicate marker
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${SCRIPT_DIR}/../bundle"
MARKER_COUNT=$(grep -cF "${MARKER}" CLAUDE.md || true)
if [[ "${MARKER_COUNT}" -ne 1 ]]; then
    echo "FAIL: marker duplicated after second init (count=${MARKER_COUNT})" >&2; exit 1
fi

# Gate 6: add workspace-scoped tasks and verify LOOP_WORKSPACE filtering
ID_FE=$(python3 "${ADD_PY}" --title "FE task" --priority 10 --workspace FRONTEND --queue claude-arsenal/queue/tasks.jsonl)
ID_BE=$(python3 "${ADD_PY}" --title "BE task" --priority 10 --workspace BACKEND --queue claude-arsenal/queue/tasks.jsonl)

FE_RESULT=$(LOOP_WORKSPACE=FRONTEND bash "${EVAL_SH}" 2>/dev/null || true)
if ! echo "${FE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['workspace']=='FRONTEND'" 2>/dev/null; then
    echo "FAIL: LOOP_WORKSPACE=FRONTEND did not return FE task; got: ${FE_RESULT}" >&2; exit 1
fi

BE_RESULT=$(LOOP_WORKSPACE=BACKEND bash "${EVAL_SH}" 2>/dev/null || true)
if ! echo "${BE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['workspace']=='BACKEND'" 2>/dev/null; then
    echo "FAIL: LOOP_WORKSPACE=BACKEND did not return BE task; got: ${BE_RESULT}" >&2; exit 1
fi

# Gate 7: .gitignore has surface_profile.json entry
if ! grep -q "claude-arsenal/session/surface_profile.json" .gitignore 2>/dev/null; then
    echo "FAIL: .gitignore missing surface_profile.json entry" >&2; exit 1
fi

echo "PASS: workspace_test — all gates passed"
exit 0
