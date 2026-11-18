#!/usr/bin/env bash
# skill_workshop_scripts_test.sh — behaviour of the scripts no other test named (#612):
# validate_memory.py, init_skill.py, audit_alignment.py and the slash-command hook
# mark_skill_workshop_loaded_from_prompt.sh. One decision each.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SC="${HERE}/skills/skill-workshop/scripts"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- validate_memory.py: an absolute home path in CLAUDE.md is a blocking finding ---
mkdir "${tmp}/mem"
printf 'See /Users/bob/.claude/notes.md\n' > "${tmp}/mem/CLAUDE.md"
out=$(python3 "${SC}/validate_memory.py" --root "${tmp}/mem" --json); rc=$?
[[ ${rc} -eq 1 ]] || fail "validate_memory: a home path must exit 1, got ${rc}"
grep -q "memory.home-path" <<<"${out}" || fail "validate_memory did not name the check: ${out}"
printf 'Plain, portable memory.\n' > "${tmp}/mem/CLAUDE.md"
python3 "${SC}/validate_memory.py" --root "${tmp}/mem" >/dev/null 2>&1 || fail "validate_memory flagged a clean CLAUDE.md"
echo "PASS: validate_memory blocks absolute home paths and passes clean memory"

# --- init_skill.py: scaffolds a skill with a canary; refuses to clobber ------------
mkdir "${tmp}/lib"
python3 "${SC}/init_skill.py" my-skill --library "${tmp}/lib" >/dev/null || fail "init_skill failed"
grep -q "^name: my-skill" "${tmp}/lib/my-skill/SKILL.md" || fail "init_skill: frontmatter name missing"
grep -q "my-skill-loaded-" "${tmp}/lib/my-skill/evals/loading_verification.json" || fail "init_skill: no canary seeded"
python3 "${SC}/init_skill.py" my-skill --library "${tmp}/lib" >/dev/null 2>&1 \
    && fail "init_skill overwrote an existing skill without --force"
python3 "${SC}/init_skill.py" Bad_Name --library "${tmp}/lib" >/dev/null 2>&1 \
    && fail "init_skill accepted a non-kebab-case name"
echo "PASS: init_skill scaffolds once, with a canary, and validates the name"

# --- audit_alignment.py: one prompt block per skill, written to --output-dir -------
python3 "${SC}/audit_alignment.py" "${tmp}/lib" --output-dir "${tmp}/prompts" >/dev/null || fail "audit_alignment failed"
[[ -s "${tmp}/prompts/my-skill.prompt.md" ]] || fail "audit_alignment wrote no prompt for the skill"
grep -q "Semantic review prompt — my-skill" "${tmp}/prompts/my-skill.prompt.md" || fail "audit_alignment prompt lacks its header"
echo "PASS: audit_alignment emits a prompt per skill"

# --- mark_skill_workshop_loaded_from_prompt.sh: marker only for the slash command ---
HOOK="${HERE}/hooks/mark_skill_workshop_loaded_from_prompt.sh"
export CLAUDE_PLUGIN_DATA="${tmp}/data"
printf '{"session_id":"s1","prompt":"/skill-workshop:skill-workshop edit it"}' | bash "${HOOK}" || fail "hook must always exit 0"
[[ -f "${tmp}/data/loaded-s1" ]] || fail "hook did not drop the marker for the slash command"
printf '{"session_id":"s2","prompt":"please explain the skill-workshop plugin"}' | bash "${HOOK}" || fail "hook must always exit 0"
[[ ! -e "${tmp}/data/loaded-s2" ]] || fail "hook dropped a marker for prose that merely mentions the skill"
echo "PASS: the prompt hook marks only a real /skill-workshop invocation"
