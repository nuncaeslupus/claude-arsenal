#!/usr/bin/env bash
# skill_load_hook_test.sh — the PostToolUse(Skill) hook records one row per skill load.
# Exit: 0 on PASS, 1 on FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core="$(cd "${here}/.." && pwd)"
HOOK="${core}/skills/init/assets/bin/record_skill_load.sh"
fail() { echo "FAIL: skill_load_hook_test — $*" >&2; exit 1; }
[[ -f "${HOOK}" ]] || fail "${HOOK} not found"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
git -C "${tmp}" init -q

test_skill_load_hook_records_row() {
  local out
  out="$(cd "${tmp}" && printf '%s' '{"session_id":"s1","tool_name":"Skill","tool_input":{"skill":"claude-arsenal:core:execution"}}' | bash "${HOOK}" 2>&1)"
  [[ $? -eq 0 && -z "${out}" ]] || fail "hook must be silent and exit 0, got: ${out}"
  local tsv="${tmp}/tmp/arsenal-metrics/skill-loads.tsv"
  [[ -f "${tsv}" ]] || fail "no ${tsv}"
  [[ "$(wc -l <"${tsv}")" -eq 1 ]] || fail "expected one row"
  grep -Eq $'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\tclaude-arsenal:core:execution$' "${tsv}" \
    || fail "row shape wrong: $(cat "${tsv}")"
  (cd "${tmp}" && printf '%s' '{"tool_input":{"skill":"specify"}}' | bash "${HOOK}")
  [[ "$(wc -l <"${tsv}")" -eq 2 ]] || fail "second load must append"
}

test_skill_load_hook_never_fails() {
  (cd "${tmp}" && printf 'not json' | bash "${HOOK}") || fail "garbage payload must exit 0"
  (cd "${tmp}" && printf '' | bash "${HOOK}") || fail "empty payload must exit 0"
  [[ "$(wc -l <"${tmp}/tmp/arsenal-metrics/skill-loads.tsv")" -eq 2 ]] || fail "garbage must not add rows"
}

test_skill_load_hook_registered() {
  grep -q 'record_skill_load.sh' "${core}/hooks/hooks.json" || fail "not registered in core hooks.json"
  python3 - "${core}/hooks/hooks.json" <<'PY' || fail "PostToolUse Skill matcher missing"
import json, sys
h = json.load(open(sys.argv[1]))["hooks"]["PostToolUse"]
assert any(e.get("matcher") == "Skill" for e in h)
PY
}

test_skill_load_hook_records_row
test_skill_load_hook_never_fails
test_skill_load_hook_registered
echo "PASS: skill_load_hook_test — all gates passed"
