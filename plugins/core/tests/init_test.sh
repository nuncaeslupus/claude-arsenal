#!/usr/bin/env bash
# init_test.sh — integration test for init.py.
# Verifies that after running init, the host repo has:
#   claude-arsenal/AGENTS.md (upstream), the arsenal/ host tree with its
#   config.toml, the session-protocol marker in CLAUDE.md, and
#   surface_profile.json — plus the property that matters most: a re-run must
#   never overwrite anything host-owned.
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

# Gate 2: the host-owned tree is scaffolded, with a config a consumer can edit
if [[ ! -d "${tmpdir}/arsenal/tasks" ]]; then
    echo "FAIL: arsenal/tasks/ missing" >&2; exit 1
fi
if [[ ! -f "${tmpdir}/arsenal/config.toml" ]]; then
    echo "FAIL: arsenal/config.toml missing" >&2; exit 1
fi
if ! grep -q 'merge-policy' "${tmpdir}/arsenal/config.toml"; then
    echo "FAIL: arsenal/config.toml carries no merge-policy" >&2; exit 1
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
if [[ ! -f "${tmpdir}/arsenal/session/surface_profile.json" ]]; then
    echo "FAIL: surface_profile.json missing" >&2; exit 1
fi
SURFACE=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['surface'])" \
    "${tmpdir}/arsenal/session/surface_profile.json")
if [[ "${SURFACE}" != "unknown" ]]; then
    echo "FAIL: surface_profile.json surface is '${SURFACE}', expected 'unknown'" >&2; exit 1
fi

# Gate 5: arsenal/session/handover.md exists
if [[ ! -f "${tmpdir}/arsenal/session/handover.md" ]]; then
    echo "FAIL: arsenal/session/handover.md missing" >&2; exit 1
fi

# Gate 5b: a re-run must NOT overwrite host-owned session/handover.md (data loss).
SENTINEL="REAL-HANDOVER-DO-NOT-CLOBBER-$$"
echo "${SENTINEL}" > "${tmpdir}/arsenal/session/handover.md"
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${BUNDLE_DIR}" --silent
if ! grep -qF "${SENTINEL}" "${tmpdir}/arsenal/session/handover.md"; then
    echo "FAIL: init re-run clobbered host-owned session/handover.md (data loss)" >&2; exit 1
fi
echo "PASS: re-run preserves host-owned session/handover.md (no data loss)"

# Gate 6: .gitignore has surface_profile.json entry
if ! grep -q "arsenal/session/surface_profile.json" "${tmpdir}/.gitignore" 2>/dev/null; then
    echo "FAIL: .gitignore missing surface_profile.json entry" >&2; exit 1
fi

echo "PASS: init_test — all gates passed"
exit 0
