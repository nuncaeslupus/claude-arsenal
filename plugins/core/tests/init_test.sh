#!/usr/bin/env bash
# init_test.sh — integration test for init.py.
# Verifies that after running init, the host repo has:
#   claude-arsenal/AGENTS.md, claude-arsenal/queue/tasks.jsonl (empty),
#   the session-protocol marker in CLAUDE.md, and surface_profile.json.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
BUNDLE_DIR="${SCRIPT_DIR}/../skills/init/assets"

if [[ ! -f "${INIT_PY}" ]]; then
    echo "SKIP: init.py not found at ${INIT_PY}" >&2
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
    --bundle-dir "${BUNDLE_DIR}"

# Gate 1: claude-arsenal/AGENTS.md exists
if [[ ! -f "${tmpdir}/claude-arsenal/AGENTS.md" ]]; then
    echo "FAIL: claude-arsenal/AGENTS.md missing" >&2; exit 1
fi

# Gate 2: claude-arsenal/queue/tasks.jsonl exists and is empty
if [[ ! -f "${tmpdir}/claude-arsenal/queue/tasks.jsonl" ]]; then
    echo "FAIL: claude-arsenal/queue/tasks.jsonl missing" >&2; exit 1
fi
QUEUE_CONTENT=$(cat "${tmpdir}/claude-arsenal/queue/tasks.jsonl")
if [[ -n "${QUEUE_CONTENT}" ]]; then
    echo "FAIL: tasks.jsonl is not empty: ${QUEUE_CONTENT}" >&2; exit 1
fi

# Gate 3: CLAUDE.md contains the session-protocol marker
MARKER="<!-- claude-arsenal: auto-managed -->"
if ! grep -qF "${MARKER}" "${tmpdir}/CLAUDE.md"; then
    echo "FAIL: session-protocol marker missing from CLAUDE.md" >&2; exit 1
fi

# Gate 4: idempotency — second run does not add a second marker block
python3 "${INIT_PY}" \
    --repo-path "${tmpdir}" \
    --bundle-dir "${BUNDLE_DIR}"

MARKER_COUNT=$(grep -cF "${MARKER}" "${tmpdir}/CLAUDE.md" || true)
if [[ "${MARKER_COUNT}" -ne 1 ]]; then
    echo "FAIL: idempotency broken — marker count after second run: ${MARKER_COUNT}" >&2; exit 1
fi

# Gate 4b: surface_profile.json was created
if [[ ! -f "${tmpdir}/claude-arsenal/session/surface_profile.json" ]]; then
    echo "FAIL: surface_profile.json missing" >&2; exit 1
fi
SURFACE=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['surface'])" \
    "${tmpdir}/claude-arsenal/session/surface_profile.json")
if [[ "${SURFACE}" != "unknown" ]]; then
    echo "FAIL: surface_profile.json surface is '${SURFACE}', expected 'unknown'" >&2; exit 1
fi

# Gate 5: claude-arsenal/session/handover.md exists
if [[ ! -f "${tmpdir}/claude-arsenal/session/handover.md" ]]; then
    echo "FAIL: claude-arsenal/session/handover.md missing" >&2; exit 1
fi

# Gate 6: .gitignore has surface_profile.json entry
if ! grep -q "claude-arsenal/session/surface_profile.json" "${tmpdir}/.gitignore" 2>/dev/null; then
    echo "FAIL: .gitignore missing surface_profile.json entry" >&2; exit 1
fi

echo "PASS: init_test — all gates passed"
exit 0
