#!/usr/bin/env bash
# init_loop_test.sh — integration test for init_loop.py (T6 gate).
# Verifies that after running init_loop, the host repo has:
#   .loop/core/AGENTS.md, .loop/state/queue.jsonl (empty), and
#   exactly one new import line in CLAUDE.md.
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

# Gate 3: CLAUDE.md has exactly one new import line
IMPORT_COUNT=$(grep -c "@.loop/core/AGENTS.md" "${tmpdir}/CLAUDE.md" || true)
if [[ "${IMPORT_COUNT}" -ne 1 ]]; then
    echo "FAIL: expected exactly 1 import line in CLAUDE.md, got ${IMPORT_COUNT}" >&2; exit 1
fi

# Gate 4: idempotency — second run does not add a second import line
python3 "${INIT_PY}" \
    --repo-path "${tmpdir}" \
    --bundle-core "${BUNDLE_CORE}"

IMPORT_COUNT2=$(grep -c "@.loop/core/AGENTS.md" "${tmpdir}/CLAUDE.md" || true)
if [[ "${IMPORT_COUNT2}" -ne 1 ]]; then
    echo "FAIL: idempotency broken — import count after second run: ${IMPORT_COUNT2}" >&2; exit 1
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
