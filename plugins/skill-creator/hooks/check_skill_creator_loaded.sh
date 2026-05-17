#!/usr/bin/env bash
# PreToolUse hook on Edit / Write / MultiEdit.
#
# Blocks any edit inside a skill folder until skill-creator has been loaded
# this session. skill-creator owns the gate ruleset every skill change must
# pass; this hook guarantees a session that touches a skill file has loaded
# it. The companion hook mark_skill_creator_loaded.sh drops the marker after
# a successful Skill tool call.
#
# Exit codes:
#   0 — path is not in a skill folder, OR skill-creator is loaded → allow.
#   2 — path is in a skill folder and no marker is present → block + tell
#       Claude to invoke skill-creator first. Stderr is shown to Claude.
#
# Designed to be cheap: pure shell + one Python json parse, no network.

set -euo pipefail

payload="$(cat)"
file_path="$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
session_id="$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("session_id",""))' 2>/dev/null || true)"

# Empty file_path → not an edit we care about (some tools pass no path).
[[ -z "$file_path" ]] && exit 0

# Only fire for paths inside a skill folder. Skill folders live at
# .claude/skills/<name>/ or plugins/<plugin>/skills/<name>/. Match any
# descendant — references/, scripts/, evals/, assets/, plus any new
# subfolder or loose file at the skill root (notes.md, findings.md, etc.).
case "$file_path" in
  */.claude/skills/*/*) ;;
  */plugins/*/skills/*/*) ;;
  *) exit 0 ;;
esac

marker_dir="${CLAUDE_PLUGIN_DATA:-${HOME}/.cache/claude-arsenal/skill-creator}"
marker="${marker_dir}/loaded-${session_id}"
[[ -f "$marker" ]] && exit 0

cat >&2 <<EOF
BLOCKED: about to edit '$file_path', which lives inside a skill folder, but
the skill-creator skill has not been loaded this session.

skill-creator owns the gate ruleset every skill change must pass
(structural + content-quality rubrics, listing-budget audit, validate.py).
Invoke the skill-creator skill first, then re-run the edit. The skill
folder layout, naming canon, and pre-commit checks all live in its body
and references.
EOF
exit 2
