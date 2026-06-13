#!/usr/bin/env bash
# init_loop_test.sh — integration test for init_loop.py (T6 gate).
# Verifies that after running init_loop, the host repo has:
#   .loop/core/AGENTS.md, .loop/state/queue.jsonl (empty),
#   the session-protocol marker in CLAUDE.md, and surface_profile.json.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_PY="${SCRIPT_DIR}/../skills/loop-init/scripts/init_loop.py"
BUNDLE_CORE="${SCRIPT_DIR}/../core"

if [[ ! -f "${INIT_PY}" ]]; then
    echo "SKIP: init_loop.py not found at ${INIT_PY}" >&2
    exit 0
fi

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

# Create a minimal CLAUDE.md in the scratch repo
echo "# Test repo" > "${tmpdir}/CLAUDE.md"

# Run init
python3 "${INIT_PY}" \
    --repo-path "${tmpdir}" \
    --bundle-core "${BUNDLE_CORE}"

# Gate 1: .loop/core/AGENTS.md exists
if [[ ! -f "${tmpdir}/.loop/core/AGENTS.md" ]]; then
    echo "FAIL: .loop/core/AGENTS.md missing" >&2; exit 1
fi

# Gate 2: .loop/state/queue.jsonl exists and is empty
if [[ ! -f "${tmpdir}/.loop/state/queue.jsonl" ]]; then
    echo "FAIL: .loop/state/queue.jsonl missing" >&2; exit 1
fi
QUEUE_CONTENT=$(cat "${tmpdir}/.loop/state/queue.jsonl")
if [[ -n "${QUEUE_CONTENT}" ]]; then
    echo "FAIL: queue.jsonl is not empty: ${QUEUE_CONTENT}" >&2; exit 1
fi

# Gate 3: CLAUDE.md contains the session-protocol marker
MARKER="<!-- loop-orchestrator: auto-managed -->"
if ! grep -qF "${MARKER}" "${tmpdir}/CLAUDE.md"; then
    echo "FAIL: session-protocol marker missing from CLAUDE.md" >&2; exit 1
fi

# Gate 4: idempotency — second run does not add a second marker block
python3 "${INIT_PY}" \
    --repo-path "${tmpdir}" \
    --bundle-core "${BUNDLE_CORE}"

MARKER_COUNT=$(grep -cF "${MARKER}" "${tmpdir}/CLAUDE.md" || true)
if [[ "${MARKER_COUNT}" -ne 1 ]]; then
    echo "FAIL: idempotency broken — marker count after second run: ${MARKER_COUNT}" >&2; exit 1
fi

# Gate 4b: surface_profile.json was created
if [[ ! -f "${tmpdir}/.loop/state/surface_profile.json" ]]; then
    echo "FAIL: surface_profile.json missing" >&2; exit 1
fi
SURFACE=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['surface'])" \
    "${tmpdir}/.loop/state/surface_profile.json")
if [[ "${SURFACE}" != "unknown" ]]; then
    echo "FAIL: surface_profile.json surface is '${SURFACE}', expected 'unknown'" >&2; exit 1
fi

# Gate 4c: migration — repo with old standalone import gets replaced, no duplicate
tmpdir2=$(mktemp -d)
trap "rm -rf '${tmpdir2}'" EXIT
printf "# Old repo\n@.loop/core/AGENTS.md\n" > "${tmpdir2}/CLAUDE.md"
python3 "${INIT_PY}" \
    --repo-path "${tmpdir2}" \
    --bundle-core "${BUNDLE_CORE}" 2>/dev/null
IMPORT_COUNT=$(grep -c "@.loop/core/AGENTS.md" "${tmpdir2}/CLAUDE.md" || true)
MARKER_COUNT2=$(grep -cF "${MARKER}" "${tmpdir2}/CLAUDE.md" || true)
if [[ "${IMPORT_COUNT}" -gt 2 ]]; then
    echo "FAIL: migration produced duplicate imports (${IMPORT_COUNT} occurrences)" >&2; exit 1
fi
if [[ "${MARKER_COUNT2}" -ne 1 ]]; then
    echo "FAIL: migration did not inject session-protocol block" >&2; exit 1
fi

# Gate 5: .loop/state/tasks/ directory exists
if [[ ! -d "${tmpdir}/.loop/state/tasks" ]]; then
    echo "FAIL: .loop/state/tasks/ directory missing" >&2; exit 1
fi

# Gate 6: .loop/state/handover.md exists
if [[ ! -f "${tmpdir}/.loop/state/handover.md" ]]; then
    echo "FAIL: .loop/state/handover.md missing" >&2; exit 1
fi

echo "PASS: init_loop_test — all gates passed"
exit 0
