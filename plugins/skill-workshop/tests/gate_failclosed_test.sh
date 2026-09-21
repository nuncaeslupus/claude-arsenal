#!/usr/bin/env bash
# gate_failclosed_test.sh — the skill-edit gate must not open when its own
# analyser breaks (#347), in EVERY copy of the hook that ships.
#
# The hook ran `gate_target.py … 2>/dev/null || true`, so any crash inside it —
# a NameError, a syntax error from a half-applied edit, a missing interpreter —
# produced an empty target, which the hook reads as "nothing to gate" and
# allows. Nothing in the transcript said the check had stopped running.
#
# This test originally exercised only plugins/skill-workshop/hooks/. The fix for
# #347 landed there and never reached the vendored copy under
# plugins/core/skills/init/assets/bin/ — the one `/init` installs into consumer
# repos, and the only one a cloud session can use. CI stayed green for months
# while the shipped gate failed open. So both copies are run here, and a missing
# copy is a failure rather than a skip: a skip is how that gap stayed invisible.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

COPIES=(
    "canonical:${REPO_ROOT}/plugins/skill-workshop/hooks"
    "vendored:${REPO_ROOT}/plugins/core/skills/init/assets/bin"
)

fail() { echo "FAIL: $*" >&2; exit 1; }

SKILL_WRITE='{"tool_name":"Bash","tool_input":{"command":"echo x > .claude/skills/specify/SKILL.md"},"session_id":"gfc"}'
DOCS_WRITE='{"tool_name":"Bash","tool_input":{"command":"echo x > docs/readme.md"},"session_id":"gfc"}'

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

check_copy() {
    local label="$1" hooks="$2"
    local hook="${hooks}/check_skill_workshop_loaded.sh"

    [[ -f "${hook}" ]] || fail "${label}: no hook at ${hook} — every shipped copy must be testable"
    [[ -f "${hooks}/gate_target.py" ]] || fail "${label}: no gate_target.py beside ${hook}"

    printf '%s' "${SKILL_WRITE}" | bash "${hook}" >/dev/null 2>&1
    [[ $? -eq 2 ]] || fail "${label}: a skill write is no longer blocked — the gate is broken"

    printf '%s' "${DOCS_WRITE}" | bash "${hook}" >/dev/null 2>&1
    [[ $? -eq 0 ]] || fail "${label}: a write outside any skill folder is now blocked"

    # Break the analyser. Every one of these used to exit 0 — allow.
    local breakage out rc
    for breakage in 'raise RuntimeError("boom")' 'this is not python(' 'import sys; sys.exit(3)'; do
        cp -r "${hooks}" "${tmp}/hooks"
        printf '%s\n' "${breakage}" > "${tmp}/hooks/gate_target.py"
        out="$(printf '%s' "${SKILL_WRITE}" | bash "${tmp}/hooks/check_skill_workshop_loaded.sh" 2>&1)"
        rc=$?
        [[ "${rc}" -eq 2 ]] \
            || fail "${label}: a broken gate_target.py (${breakage}) exited ${rc} — the gate FAILED OPEN"
        grep -q "gate_target.py failed" <<<"${out}" \
            || fail "${label}: the breakage was not reported: ${out}"
        rm -rf "${tmp}/hooks"
    done

    # An unparseable payload is NOT a crash — gate_target.py returns 0 for it by
    # design, and the hook must keep allowing it rather than blocking every call
    # whose payload it does not recognise.
    out="$(printf 'not json at all' | bash "${hook}" 2>&1)"; rc=$?
    [[ "${rc}" -eq 0 ]] || fail "${label}: an unparseable payload exited ${rc}, expected 0: ${out}"

    echo "PASS: ${label} copy — blocks a skill write, allows other writes, fails closed on a crash"
}

for entry in "${COPIES[@]}"; do
    check_copy "${entry%%:*}" "${entry#*:}"
done

echo "PASS: gate_failclosed_test — all gates passed, on every shipped copy"
exit 0
