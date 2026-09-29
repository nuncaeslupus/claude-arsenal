#!/usr/bin/env bash
# fast_gate.sh [--full] [--base <ref>]
# Run the repo's gate at the level a step needs — the cheap one by default.
#
# Two levels, both host-declared in arsenal/config.toml (#463):
#
#   preflight-gate  fast, change-scoped: lint/typecheck the changed files, run
#                   the tests the change selects. What every review round after
#                   the first runs, on the delta. (default)
#   host-gate       the full suite. Once before the PR opens (open_task_pr.sh
#                   runs it), and once more before merge if commits landed
#                   since. (--full)
#
# Re-running the full suite on every review round is the bill this exists to
# stop: rounds x a push per fix x a full suite per push. A round's fix touches a
# handful of files, and the full gate already passed on everything else.
#
# The command sees the change it is scoped to:
#   ARSENAL_GATE_BASE      the merge-base with <ref> (default: origin's HEAD
#                          branch, else origin/main)
#   ARSENAL_CHANGED_FILES  files changed since that base, committed or not,
#                          deletions excluded, one per line. Empty means the
#                          command should fall back to checking everything, so
#                          `ruff check $ARSENAL_CHANGED_FILES` degrades safely.
#
# With no preflight-gate declared, the default level runs host-gate instead and
# says so: slower, never weaker. With neither, it prints `gate: none`.
#
# SECURITY: both commands run verbatim, like host-gate in open_task_pr.sh. They
# come from arsenal/config.toml, which is host-owned and reviewed like any other
# file in the repo — but they are code, not data.
#
# Exit: the gate's own exit status; 0 when nothing is declared; 2 on usage or
#       an unreadable config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v cygpath >/dev/null 2>&1 && SCRIPT_DIR="$(cygpath -m "${SCRIPT_DIR}")"
BUNDLE_SCRIPTS="${SCRIPT_DIR}/../scripts"

FULL=0
BASE_REF=""
while (( $# )); do
    case "$1" in
        --full) FULL=1; shift ;;
        --base) BASE_REF="${2:?--base needs a ref}"; shift 2 ;;
        -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "fast_gate: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

_toplevel="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${_toplevel}" ]]; then
    echo "fast_gate: not inside a git repository — refusing to run" >&2
    exit 2
fi
cd "${_toplevel}"

read_key() {  # read_key <key> — errors are refusals, never an empty "no gate"
    local out
    if ! out="$(python3 "${BUNDLE_SCRIPTS}/arsenal_config.py" --repo-root "$(pwd)" --get "$1" 2>&1)"; then
        echo "fast_gate: could not read $1 from arsenal/config.toml: ${out}" >&2
        exit 2
    fi
    printf '%s' "${out}"
}

host_gate="$(read_key host-gate)"
level="host-gate"
gate="${host_gate}"
if (( ! FULL )); then
    preflight_gate="$(read_key preflight-gate)"
    if [[ -n "${preflight_gate}" ]]; then
        level="preflight-gate"
        gate="${preflight_gate}"
    elif [[ -n "${host_gate}" ]]; then
        echo "fast_gate: no preflight-gate declared — running the full host-gate instead. Declare a change-scoped one in arsenal/config.toml so review rounds stop paying for the whole suite." >&2
    fi
fi
if [[ -z "${gate}" ]]; then
    echo "gate: none"
    echo "fast_gate: neither preflight-gate nor host-gate is declared — nothing ran" >&2
    exit 0
fi

if [[ -z "${BASE_REF}" ]]; then
    BASE_REF="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ -n "${BASE_REF}" ]] || BASE_REF="origin/main"
fi
ARSENAL_GATE_BASE="$(git merge-base HEAD "${BASE_REF}" 2>/dev/null || true)"
changed=""
if [[ -n "${ARSENAL_GATE_BASE}" ]]; then
    changed="$( { git diff --name-only --diff-filter=d "${ARSENAL_GATE_BASE}" HEAD
                  git diff --name-only --diff-filter=d HEAD
                  git ls-files --others --exclude-standard; } | sort -u)"
else
    echo "fast_gate: no merge-base with ${BASE_REF} — ARSENAL_CHANGED_FILES is empty, so the gate checks everything" >&2
fi
export ARSENAL_GATE_BASE ARSENAL_CHANGED_FILES="${changed}"

n=0
[[ -n "${changed}" ]] && n="$(grep -c . <<<"${changed}")"
echo "fast_gate: running ${level} over ${n} changed file(s) since ${BASE_REF}: ${gate}" >&2
rc=0
bash -c "${gate}" || rc=$?
echo "gate: ${level} $([[ ${rc} -eq 0 ]] && echo passed || echo "failed (exit ${rc})")"
exit "${rc}"
