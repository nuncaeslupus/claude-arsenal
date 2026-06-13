#!/usr/bin/env bash
# upgrade_roundtrip.sh — round-trip test for /loop-upgrade (T9 gate).
# Plants a sentinel in state/, runs upgrade.sh --apply, verifies:
#   1. .loop/core/ was refreshed (VERSION matches bundle)
#   2. .loop/state/sentinel.txt is intact
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPGRADE="${SCRIPT_DIR}/../skills/loop-upgrade/scripts/upgrade.sh"
BUNDLE_CORE="${SCRIPT_DIR}/../core"

if [[ ! -f "${UPGRADE}" ]]; then
    echo "SKIP: upgrade.sh not found at ${UPGRADE}" >&2; exit 0
fi

BUNDLE_VERSION=$(tr -d '[:space:]' < "${BUNDLE_CORE}/VERSION")

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

# --- Setup: copy bundle core/ to simulate an initialized host repo ---
cp -r "${BUNDLE_CORE}" "${tmpdir}/.loop_core_tmp"
mkdir -p "${tmpdir}/.loop"
mv "${tmpdir}/.loop_core_tmp" "${tmpdir}/.loop/core"
mkdir -p "${tmpdir}/.loop/state"

# --- Plant sentinel in state/ ---
echo "sentinel-value-$(date +%s)" > "${tmpdir}/.loop/state/sentinel.txt"
SENTINEL=$(cat "${tmpdir}/.loop/state/sentinel.txt")

# --- Downgrade VERSION to simulate being behind (patch-only difference) ---
# Extract major.minor, set patch to 999 so it parses as "same minor, different patch"
MAJOR_MINOR="${BUNDLE_VERSION%.*}"
echo "${MAJOR_MINOR}.999-old" > "${tmpdir}/.loop/core/VERSION"

# --- Plant a canary file in core/ to verify it gets replaced ---
echo "old-canary" > "${tmpdir}/.loop/core/CANARY_old"

# --- Run upgrade from within tmpdir ---
# upgrade.sh uses TARGET_CORE=".loop/core" relative to cwd.
# The BUNDLE_CORE path in upgrade.sh is computed relative to SCRIPT_DIR (the real scripts dir).
cd "${tmpdir}"
bash "${UPGRADE}" --apply --yes

# --- Gate 1: core/VERSION matches bundle ---
UPGRADED_VERSION=$(cat "${tmpdir}/.loop/core/VERSION")
if [[ "${UPGRADED_VERSION}" != "${BUNDLE_VERSION}" ]]; then
    echo "FAIL: core/VERSION after upgrade is ${UPGRADED_VERSION}, expected ${BUNDLE_VERSION}" >&2
    exit 1
fi

# --- Gate 2: canary file is gone (core/ was replaced) ---
if [[ -f "${tmpdir}/.loop/core/CANARY_old" ]]; then
    echo "FAIL: old canary file still present in core/ after upgrade" >&2
    exit 1
fi

# --- Gate 3: core/AGENTS.md exists (bundle contents were restored) ---
if [[ ! -f "${tmpdir}/.loop/core/AGENTS.md" ]]; then
    echo "FAIL: AGENTS.md missing from upgraded core/" >&2
    exit 1
fi

# --- Gate 4: sentinel in state/ is intact ---
if [[ ! -f "${tmpdir}/.loop/state/sentinel.txt" ]]; then
    echo "FAIL: state/sentinel.txt was deleted" >&2
    exit 1
fi
SENTINEL_AFTER=$(cat "${tmpdir}/.loop/state/sentinel.txt")
if [[ "${SENTINEL_AFTER}" != "${SENTINEL}" ]]; then
    echo "FAIL: state/sentinel.txt content changed: got '${SENTINEL_AFTER}'" >&2
    exit 1
fi

# --- Gate 5: dry-run does not modify core/ ---
echo "dry-run-canary" > "${tmpdir}/.loop/core/CANARY_dry"
bash "${UPGRADE}" --dry-run
if [[ ! -f "${tmpdir}/.loop/core/CANARY_dry" ]]; then
    echo "FAIL: dry-run modified core/ (deleted CANARY_dry)" >&2
    exit 1
fi

echo "PASS: upgrade_roundtrip — core/ refreshed, state/ sentinel intact, dry-run safe"
exit 0
