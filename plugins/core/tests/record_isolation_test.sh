#!/usr/bin/env bash
# record_isolation_test.sh — the third writer of the isolation sentinel (#247).
#
# `available` had exactly one writer: worker_postcheck.sh, observing a returned
# worker's toplevel. A worker dispatched as a SEPARATE SESSION never returns
# through it, so the sentinel stayed `unknown` forever and task_select.py
# clamped every batch to one task — permanently, on the one surface where
# separate sessions are the only working shape.
#
# What this pins is the safety property, not just the happy path: the recorder
# gates a clamp, so its vocabulary must be CLOSED. An orchestrator may attest a
# mechanism the bundle knows and may not invent a reason.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
REC="${ASSETS}/bin/record_isolation.sh"
SELECT="${ASSETS}/scripts/task_select.py"

[[ -f "${REC}" ]] || { echo "SKIP: record_isolation.sh not found" >&2; exit 0; }

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp="$(mktemp -d)"
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

_run() {  # $1 = mechanism (may be empty); echoes exit code
    ARSENAL_SESSION_DIR="${tmp}/session" bash "${REC}" ${1:+"$1"} >/dev/null 2>&1
    echo $?
}

# --- the closed vocabulary is the safety property --------------------------
for bad in "nonsense" "separate" "available" "--force" "separate-session-x"; do
    rm -rf "${tmp}/session"
    rc="$(_run "${bad}")"
    [[ "${rc}" -eq 2 ]] \
        || fail "mechanism '${bad}' returned ${rc}, expected 2 — an unknown name must be refused, never recorded"
    [[ ! -f "${tmp}/session/worktree_isolation" ]] \
        || fail "mechanism '${bad}' was refused but STILL wrote the sentinel — a refusal that records is not a refusal"
done
echo "PASS: an unknown mechanism is refused and writes nothing"

rm -rf "${tmp}/session"
rc="$(_run "")"
[[ "${rc}" -eq 2 ]] || fail "no mechanism at all returned ${rc}, expected 2"
[[ ! -f "${tmp}/session/worktree_isolation" ]] \
    || fail "a bare invocation with no mechanism wrote the sentinel"
echo "PASS: a bare invocation records nothing"

# --- a known mechanism records, and records provenance ---------------------
rm -rf "${tmp}/session"
rc="$(_run "separate-session")"
[[ "${rc}" -eq 0 ]] || fail "separate-session returned ${rc}, expected 0"

verdict="$(cat "${tmp}/session/worktree_isolation" 2>/dev/null)"
[[ "${verdict}" == "available" ]] \
    || fail "the sentinel holds '${verdict}', expected exactly 'available' — task_select.py reads it with a bare strip()"

why="${tmp}/session/worktree_isolation.why"
[[ -f "${why}" ]] || fail "no provenance sidecar — an attestation with no record of its grounds is what this replaced"
grep -q 'basis: attested-dispatch-mechanism' "${why}" \
    || fail "the provenance does not distinguish an attestation from a measurement"
grep -q 'mechanism: separate-session' "${why}" \
    || fail "the provenance does not name the mechanism attested"
echo "PASS: a known mechanism records 'available' plus its provenance"

# --- the selector actually lifts the clamp ---------------------------------
# The whole point. If task_select.py does not read this back as `available`,
# the deadlock is not broken and everything above is decoration.
if [[ -f "${SELECT}" ]]; then
    got="$(cd "${ASSETS}/scripts" && python3 -c "
import sys
from pathlib import Path
sys.path.insert(0, '.')
import task_select
print(task_select.isolation_verdict(Path('${tmp}/session/worktree_isolation')))
" 2>/dev/null)"
    [[ "${got}" == "available" ]] \
        || fail "task_select.isolation_verdict read '${got}' back, so the batch stays clamped and the deadlock is intact"
    echo "PASS: task_select reads the recorded verdict as available — the clamp lifts"
fi

# --- separate-clone is the other supported mechanism -----------------------
rm -rf "${tmp}/session"
rc="$(_run "separate-clone")"
[[ "${rc}" -eq 0 ]] || fail "separate-clone returned ${rc}, expected 0"
grep -q 'mechanism: separate-clone' "${tmp}/session/worktree_isolation.why" \
    || fail "separate-clone did not record its own mechanism"
echo "PASS: separate-clone records too"

# --- --list must stay honest ------------------------------------------------
# The refusal message prints this list, so it is what a blocked operator reads.
listing="$(bash "${REC}" --list 2>&1)"
grep -q 'separate-session' <<<"${listing}" \
    || fail "--list does not name separate-session"
grep -q 'separate-clone' <<<"${listing}" \
    || fail "--list does not name separate-clone"
echo "PASS: --list names every mechanism the script accepts"

# --- the sidecar must not be committable ------------------------------------
# It is an observation about this machine and this session. init.py seeds the
# consumer's ignore entries; this repo keeps its own in step.
if grep -q 'worktree_isolation.why' "${SCRIPT_DIR}/../skills/init/scripts/init.py"; then
    echo "PASS: /init seeds an ignore entry for the provenance sidecar"
else
    fail "init.py does not ignore worktree_isolation.why — machine-local state would be committable in every consumer"
fi

echo "PASS: record_isolation_test — all gates passed"
exit 0
