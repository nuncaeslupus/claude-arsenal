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

# A repo-controlled symlink at tmp/, tmp/arsenal-metrics/ or the tsv must not
# redirect the append; the hook skips the row and still exits 0.
test_skill_load_hook_ignores_symlinks() {
  local link repo target
  for link in tmp tmp/arsenal-metrics tmp/arsenal-metrics/skill-loads.tsv; do
    repo="$(mktemp -d "${tmp}/sym.XXXXXX")"
    git -C "${repo}" init -q
    target="$(mktemp -d "${tmp}/target.XXXXXX")"
    printf 'keep\n' >"${target}/victim"
    mkdir -p "${repo}/$(dirname "${link}")"
    case "${link}" in
      *.tsv) ln -s "${target}/victim" "${repo}/${link}" ;;
      *) ln -s "${target}" "${repo}/${link}" ;;
    esac
    (cd "${repo}" && printf '%s' '{"tool_input":{"skill":"specify"}}' | bash "${HOOK}") \
      || fail "symlinked ${link} must still exit 0"
    [[ "$(cat "${target}/victim")" == "keep" ]] || fail "symlinked ${link} redirected the append"
    [[ "$(find "${target}" -mindepth 1 | wc -l)" -eq 1 ]] || fail "symlinked ${link} wrote through the link"
  done
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
test_skill_load_hook_ignores_symlinks
test_skill_load_hook_registered
echo "PASS: skill_load_hook_test — all gates passed"
