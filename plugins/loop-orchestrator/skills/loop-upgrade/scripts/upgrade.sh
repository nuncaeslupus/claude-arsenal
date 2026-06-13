#!/usr/bin/env bash
# upgrade.sh [--dry-run | --apply] [--yes]
# Upgrades .loop/core/ from the plugin bundle.
# Semver gate: MAJOR mismatch → abort; MINOR behind → confirm (or --yes); PATCH → silent.
# .loop/state/ is NEVER modified.
#
# Inputs : none (reads .loop/core/VERSION and bundle VERSION automatically)
# Outputs: upgraded .loop/core/ on --apply; diff on --dry-run
# Exit   : 0 on success, 1 on abort (version mismatch, missing files, user cancel)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# scripts/ -> loop-upgrade/ -> skills/ -> loop-orchestrator/
PLUGIN_ROOT="${SCRIPT_DIR}/../../.."
BUNDLE_CORE="${PLUGIN_ROOT}/core"
TARGET_CORE=".loop/core"

DRY_RUN=false
APPLY=false
YES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --apply)   APPLY=true;   shift ;;
        --yes)     YES=true;     shift ;;
        *) echo "upgrade.sh: unknown flag '$1'" >&2; exit 1 ;;
    esac
done

if ! "${DRY_RUN}" && ! "${APPLY}"; then
    echo "upgrade.sh: specify --dry-run or --apply" >&2
    exit 1
fi

if [[ ! -d "${BUNDLE_CORE}" ]]; then
    echo "upgrade.sh: plugin bundle core/ not found at ${BUNDLE_CORE}" >&2
    exit 1
fi

UPSTREAM=$(tr -d '[:space:]' < "${BUNDLE_CORE}/VERSION" 2>/dev/null || true)
if [[ -z "${UPSTREAM}" ]]; then
    echo "upgrade.sh: bundle VERSION missing" >&2
    exit 1
fi

if [[ ! -d "${TARGET_CORE}" ]]; then
    echo "upgrade.sh: ${TARGET_CORE} not found — run /loop-init first" >&2
    exit 1
fi

CURRENT=$(tr -d '[:space:]' < "${TARGET_CORE}/VERSION" 2>/dev/null || true)
if [[ -z "${CURRENT}" ]]; then
    echo "upgrade.sh: current VERSION missing in ${TARGET_CORE}" >&2
    exit 1
fi

_major() { echo "${1%%.*}"; }
_minor() { local r="${1#*.}"; echo "${r%%.*}"; }

CURR_MAJOR=$(_major "${CURRENT}")
CURR_MINOR=$(_minor "${CURRENT}")
UPS_MAJOR=$(_major "${UPSTREAM}")
UPS_MINOR=$(_minor "${UPSTREAM}")

echo "upgrade.sh: current=${CURRENT} → upstream=${UPSTREAM}"

if [[ "${CURR_MAJOR}" != "${UPS_MAJOR}" ]]; then
    echo "upgrade.sh: MAJOR version mismatch (${CURRENT} → ${UPSTREAM})." >&2
    echo "  Manual migration required. See release notes for v${UPS_MAJOR}.x." >&2
    exit 1
fi

if [[ "${CURR_MINOR}" != "${UPS_MINOR}" ]]; then
    if "${DRY_RUN}"; then
        echo "upgrade.sh (dry-run): MINOR upgrade ${CURRENT} → ${UPSTREAM}."
        diff -rq "${TARGET_CORE}" "${BUNDLE_CORE}" 2>/dev/null || true
        echo "  Run with --apply [--yes] to proceed."
        exit 0
    fi
    if ! "${YES}"; then
        read -r -p "upgrade.sh: MINOR upgrade ${CURRENT} → ${UPSTREAM}. Proceed? [y/N] " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            echo "upgrade.sh: aborted." >&2
            exit 1
        fi
    fi
fi

if "${DRY_RUN}"; then
    echo "upgrade.sh (dry-run): would replace ${TARGET_CORE}/ with bundle ${UPSTREAM}:"
    diff -rq "${TARGET_CORE}" "${BUNDLE_CORE}" 2>/dev/null || true
    exit 0
fi

rm -rf "${TARGET_CORE}"
cp -r "${BUNDLE_CORE}" "${TARGET_CORE}"
echo "upgrade.sh: .loop/core/ upgraded to ${UPSTREAM}"
