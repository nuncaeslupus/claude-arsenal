#!/usr/bin/env bash
# gate_bash_test.sh — the gate must cover Bash writes to a skill folder without
# blocking Bash reads of one. Over-blocking is not the safe direction: a gate
# that fires on `grep … > out` gets routed around instead of through.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$here/../hooks/check_skill_workshop_loaded.sh"
export CLAUDE_PLUGIN_DATA="$(mktemp -d)"
trap 'rm -rf "$CLAUDE_PLUGIN_DATA"' EXIT
SESSION="gate-bash-test"
fail() { echo "FAIL: $1" >&2; exit 1; }

probe() {  # probe <command> -> prints "blocked" or "allowed"
    printf '%s' "{\"session_id\":\"${SESSION}\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")}}" \
        | bash "$CHECK" >/dev/null 2>&1 && echo allowed || echo blocked
}

SKILL="plugins/core/skills/specify/SKILL.md"

# --- writes that must be blocked (each one bypassed the gate before) --------
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    [ "$(probe "$cmd")" = blocked ] || fail "should have blocked: $cmd"
done <<CMDS
sed -i 's/a/b/' $SKILL
cat > $SKILL <<'X'
echo hi >> $SKILL
tee $SKILL < /tmp/x
cp /tmp/other $SKILL
mv /tmp/other $SKILL
rm $SKILL
python3 -c "import pathlib; pathlib.Path('$SKILL').write_text('x')"
CMDS
echo "PASS: 8 Bash write forms are blocked without the marker"

# --- reads that must stay allowed ------------------------------------------
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    [ "$(probe "$cmd")" = allowed ] || fail "should have allowed: $cmd"
done <<CMDS
cat $SKILL
grep -n description $SKILL
grep -n description $SKILL > /tmp/out.txt
wc -l $SKILL
sed -n '1,5p' $SKILL
CMDS
echo "PASS: reads of a skill file stay allowed, including redirect-to-elsewhere"

# --- unrelated paths are none of the gate's business ------------------------
[ "$(probe "sed -i 's/a/b/' README.md")" = allowed ] || fail "blocked a non-skill path"
[ "$(probe "rm -rf /tmp/scratch")" = allowed ] || fail "blocked an unrelated command"
echo "PASS: non-skill paths are untouched"

# --- with the marker present, writes are allowed ---------------------------
mkdir -p "$CLAUDE_PLUGIN_DATA" && touch "${CLAUDE_PLUGIN_DATA}/loaded-${SESSION}"
[ "$(probe "sed -i 's/a/b/' $SKILL")" = allowed ] || fail "still blocked after the skill loaded"
echo "PASS: once skill-workshop is loaded, Bash writes go through"

echo "=== gate_bash_test: all passed ==="
