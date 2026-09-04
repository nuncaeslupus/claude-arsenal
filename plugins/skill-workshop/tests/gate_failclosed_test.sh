#!/usr/bin/env bash
# gate_failclosed_test.sh — the skill-edit gate must not open when its own
# analyser breaks (#347).
#
# The hook ran `gate_target.py … 2>/dev/null || true`, so any crash inside it —
# a NameError, a syntax error from a half-applied edit, a missing interpreter —
# produced an empty target, which the hook reads as "nothing to gate" and
# allows. Nothing in the transcript said the check had stopped running.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="${SCRIPT_DIR}/../hooks"
HOOK="${HOOKS}/check_skill_workshop_loaded.sh"

[[ -f "${HOOK}" ]] || { echo "SKIP: hook not found at ${HOOK}" >&2; exit 0; }

fail() { echo "FAIL: $*" >&2; exit 1; }

SKILL_WRITE='{"tool_name":"Bash","tool_input":{"command":"echo x > .claude/skills/specify/SKILL.md"},"session_id":"gfc"}'
DOCS_WRITE='{"tool_name":"Bash","tool_input":{"command":"echo x > docs/readme.md"},"session_id":"gfc"}'

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

# Baseline: the gate still works normally.
printf '%s' "${SKILL_WRITE}" | bash "${HOOK}" >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "a skill write is no longer blocked — the gate is broken"
echo "PASS: a skill write is still blocked"

printf '%s' "${DOCS_WRITE}" | bash "${HOOK}" >/dev/null 2>&1
[[ $? -eq 0 ]] || fail "a write outside any skill folder is now blocked"
echo "PASS: a write outside a skill folder is still allowed"

# Now break the analyser. Every one of these used to exit 0 — allow.
for breakage in 'raise RuntimeError("boom")' 'this is not python(' 'import sys; sys.exit(3)'; do
    cp -r "${HOOKS}" "${tmp}/hooks"
    printf '%s\n' "${breakage}" > "${tmp}/hooks/gate_target.py"
    out="$(printf '%s' "${SKILL_WRITE}" | bash "${tmp}/hooks/check_skill_workshop_loaded.sh" 2>&1)"
    rc=$?
    [[ "${rc}" -eq 2 ]] \
        || fail "a broken gate_target.py (${breakage}) exited ${rc} — the gate FAILED OPEN"
    grep -q "gate_target.py failed" <<<"${out}" \
        || fail "the breakage was not reported: ${out}"
    rm -rf "${tmp}/hooks"
done
echo "PASS: a crashing analyser fails closed, loudly, on every breakage tried"

# An unparseable payload is NOT a crash — gate_target.py returns 0 for it by
# design, and the hook must keep allowing it rather than blocking every call
# whose payload it does not recognise.
out="$(printf 'not json at all' | bash "${HOOK}" 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "an unparseable payload exited ${rc}, expected 0: ${out}"
echo "PASS: an unparseable payload is still allowed, not treated as a crash"

echo "PASS: gate_failclosed_test — all gates passed"
exit 0
