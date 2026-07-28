#!/usr/bin/env bash
# skill_gate_namespace_test.sh — regression test for #130 item 5:
# mark_skill_creator_loaded.sh compared the Skill tool's `skill` input against
# the bare name `skill-creator`. The harness invokes plugin skills namespaced
# (`skill-creator:skill-creator`), so the equality failed, the marker was never
# written, and check_skill_creator_loaded.sh then blocked EVERY edit inside a
# skill folder for the whole session — skill authoring was impossible, and the
# only way through was to bypass the PreToolUse hook with shell writes.
#
# The mark hook strips the namespace prefix. This pins that behaviour, and the
# gate it controls, in both directions.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="${SCRIPT_DIR}/../hooks"
MARK="${HOOKS}/mark_skill_creator_loaded.sh"
CHECK="${HOOKS}/check_skill_creator_loaded.sh"

for f in "${MARK}" "${CHECK}"; do
    [[ -f "$f" ]] || { echo "SKIP: ${f} not found" >&2; exit 0; }
done
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required by the hooks" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

export CLAUDE_PLUGIN_DATA="${tmp}/marker-dir"
SESSION="sess-$$"
EDIT_PAYLOAD="{\"session_id\":\"${SESSION}\",\"tool_input\":{\"file_path\":\"/repo/plugins/demo/skills/thing/SKILL.md\"}}"

# Gate 1: with no marker, a skill-folder edit is blocked (the gate works).
if printf '%s' "${EDIT_PAYLOAD}" | bash "${CHECK}" >/dev/null 2>&1; then
    fail "check hook allowed a skill-folder edit with no marker present"
fi
echo "PASS: skill-folder edit is blocked before skill-creator loads"

# Gate 2: the namespaced invocation — how the harness actually calls it —
# writes the marker.
printf '%s' "{\"session_id\":\"${SESSION}\",\"tool_input\":{\"skill\":\"skill-creator:skill-creator\"}}" \
    | bash "${MARK}" >/dev/null 2>&1 || fail "mark hook exited non-zero (it must never block)"
[[ -f "${CLAUDE_PLUGIN_DATA}/loaded-${SESSION}" ]] \
    || fail "namespaced skill name 'skill-creator:skill-creator' did not write the session marker"
echo "PASS: namespaced 'skill-creator:skill-creator' writes the marker"

# Gate 3: with the marker, the same edit is allowed.
printf '%s' "${EDIT_PAYLOAD}" | bash "${CHECK}" >/dev/null 2>&1 \
    || fail "check hook still blocked the edit after skill-creator was marked loaded"
echo "PASS: skill-folder edit is allowed once the marker exists"

# Gate 4: the bare name still works (CLI/unnamespaced invocation).
SESSION2="sess-bare-$$"
printf '%s' "{\"session_id\":\"${SESSION2}\",\"tool_input\":{\"skill\":\"skill-creator\"}}" \
    | bash "${MARK}" >/dev/null 2>&1 || fail "mark hook exited non-zero for the bare name"
[[ -f "${CLAUDE_PLUGIN_DATA}/loaded-${SESSION2}" ]] \
    || fail "bare skill name 'skill-creator' did not write the session marker"
echo "PASS: bare 'skill-creator' still writes the marker"

# Gate 5: an unrelated skill must NOT unlock the gate.
SESSION3="sess-other-$$"
printf '%s' "{\"session_id\":\"${SESSION3}\",\"tool_input\":{\"skill\":\"core:specify\"}}" \
    | bash "${MARK}" >/dev/null 2>&1 || fail "mark hook exited non-zero for an unrelated skill"
[[ ! -f "${CLAUDE_PLUGIN_DATA}/loaded-${SESSION3}" ]] \
    || fail "an unrelated skill ('core:specify') unlocked the skill-creator gate"
echo "PASS: an unrelated skill does not unlock the gate"

echo "PASS: skill_gate_namespace_test — all gates passed"
exit 0
