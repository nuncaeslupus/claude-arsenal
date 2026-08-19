#!/usr/bin/env bash
# workspace_test.sh — tests for workspace support in init and task selection.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/new_task.py"
LIST_SH="${SCRIPT_DIR}/../skills/init/assets/bin/workspace_list.sh"
SELECT_PY="${SCRIPT_DIR}/../skills/init/assets/scripts/task_select.py"

for f in "${INIT_PY}" "${ADD_PY}" "${LIST_SH}" "${SELECT_PY}"; do
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
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${SCRIPT_DIR}/../skills/init/assets"

[[ -d "claude-arsenal/bin" ]] || { echo "FAIL: claude-arsenal/bin missing" >&2; exit 1; }
[[ -d "arsenal/tasks" ]] || { echo "FAIL: arsenal/tasks missing" >&2; exit 1; }
[[ -f "arsenal/session/handover.md" ]] || { echo "FAIL: session/handover.md missing" >&2; exit 1; }

# Gate 2: init --workspace creates workspace dirs
python3 "${INIT_PY}" --repo-path "${tmpdir}" --workspace FRONTEND --bundle-dir "${SCRIPT_DIR}/../skills/init/assets"

[[ -f "arsenal/project/FRONTEND/spec.md" ]] || { echo "FAIL: FRONTEND/spec.md missing" >&2; exit 1; }
[[ -f "arsenal/project/FRONTEND/plan.md" ]] || { echo "FAIL: FRONTEND/plan.md missing" >&2; exit 1; }
[[ -f "arsenal/project/FRONTEND/handover.md" ]] || { echo "FAIL: FRONTEND/handover.md missing" >&2; exit 1; }

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
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${SCRIPT_DIR}/../skills/init/assets"
MARKER_COUNT=$(grep -cF "${MARKER}" CLAUDE.md || true)
if [[ "${MARKER_COUNT}" -ne 1 ]]; then
    echo "FAIL: marker duplicated after second init (count=${MARKER_COUNT})" >&2; exit 1
fi

# Gate 6: add workspace-scoped tasks and verify LOOP_WORKSPACE filtering
ID_FE=$(python3 "${ADD_PY}" --title "FE task" --priority 10 --workspace FRONTEND --tasks-dir arsenal/tasks 2>/dev/null)
ID_BE=$(python3 "${ADD_PY}" --title "BE task" --priority 10 --workspace BACKEND --tasks-dir arsenal/tasks 2>/dev/null)

# Gate 6: a workspace-scoped selection returns only that workspace's task.
FE_RESULT=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir arsenal/tasks --workspace FRONTEND 2>/dev/null)
if ! grep -q "${ID_FE}" <<<"${FE_RESULT}"; then
    echo "FAIL: FRONTEND scope should return ${ID_FE}; got: ${FE_RESULT}" >&2; exit 1
fi
if grep -q "${ID_BE}" <<<"${FE_RESULT}"; then
    echo "FAIL: FRONTEND scope leaked the BACKEND task" >&2; exit 1
fi

BE_RESULT=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir arsenal/tasks --workspace BACKEND 2>/dev/null)
if ! grep -q "${ID_BE}" <<<"${BE_RESULT}"; then
    echo "FAIL: BACKEND scope should return ${ID_BE}; got: ${BE_RESULT}" >&2; exit 1
fi

echo "PASS: workspace_test — all gates passed"
