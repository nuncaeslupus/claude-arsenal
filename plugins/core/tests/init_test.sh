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

# Gate 7: ARSENAL_HOME relocates the host tree, and the config it writes is the
# config the readers read. Every runtime script resolves the host tree that way
# — `arsenal_config.py` included — while init hardcoded `arsenal/`, so a
# relocated host was scaffolded where nothing looks and every setting silently
# stayed at its default.
relocated="${tmpdir}/relocated"
mkdir -p "${relocated}"
echo "# Relocated repo" > "${relocated}/CLAUDE.md"
ARSENAL_HOME=hosttree python3 "${INIT_PY}" \
    --repo-path "${relocated}" --bundle-dir "${BUNDLE_DIR}" --silent
if [[ ! -f "${relocated}/hosttree/config.toml" ]]; then
    echo "FAIL: ARSENAL_HOME=hosttree did not scaffold hosttree/config.toml" >&2; exit 1
fi
if [[ -d "${relocated}/arsenal" ]]; then
    echo "FAIL: init scaffolded arsenal/ as well as the relocated tree" >&2; exit 1
fi
read_back=$(ARSENAL_HOME=hosttree python3 \
    "${SCRIPT_DIR}/../skills/init/assets/scripts/arsenal_config.py" \
    --repo-root "${relocated}" --get merge-policy)
[[ -n "${read_back}" ]] \
    || { echo "FAIL: arsenal_config.py read nothing back from the relocated config" >&2; exit 1; }
echo "PASS: ARSENAL_HOME relocates the tree init creates, and the readers agree"

# Gate 8: an existing default tree that ARSENAL_HOME would orphan stops init.
# The tasks and config stay on disk while every script reads past them, which is
# the silent half of the same mismatch.
orphan="${tmpdir}/orphan"
mkdir -p "${orphan}/arsenal/tasks"
echo "# Orphan repo" > "${orphan}/CLAUDE.md"
if ARSENAL_HOME=elsewhere python3 "${INIT_PY}" \
        --repo-path "${orphan}" --bundle-dir "${BUNDLE_DIR}" --silent >/dev/null 2>"${tmpdir}/orphan.err"; then
    echo "FAIL: init scaffolded a second host tree beside an existing one" >&2; exit 1
fi
if ! grep -q "would leave the existing tasks and config" "${tmpdir}/orphan.err"; then
    echo "FAIL: the refusal must say what is at stake: $(cat "${tmpdir}/orphan.err")" >&2; exit 1
fi
if [[ -d "${orphan}/elsewhere" ]]; then
    echo "FAIL: the refusal still created the relocated tree" >&2; exit 1
fi
echo "PASS: init refuses to orphan an existing host tree"

echo "PASS: init_test — all gates passed"
exit 0
