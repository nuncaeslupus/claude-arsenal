#!/usr/bin/env bash
# gate_bash_test.sh — the gate must cover Bash writes to a skill folder without
# blocking Bash reads of one. Over-blocking is not the safe direction: a gate
# that fires on `grep … > out` gets routed around instead of through.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$here/../hooks/check_skill_workshop_loaded.sh"
# Assigned before export: `export X="$(mktemp -d)"` masks a mktemp failure, and
# the hook would then fall back to the real ~/.cache marker dir — where this
# test would happily create a session marker and report a false pass.
marker_root="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
export CLAUDE_PLUGIN_DATA="$marker_root"
trap 'rm -rf "$marker_root"' EXIT
SESSION="gate-bash-test"
fail() { echo "FAIL: $1" >&2; exit 1; }

probe() {  # probe <command> -> prints "blocked" or "allowed"
    printf '%s' "{\"session_id\":\"${SESSION}\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")}}" \
        | bash "$CHECK" >/dev/null 2>&1 && echo allowed || echo blocked
}

SKILL="plugins/core/skills/specify/SKILL.md"
# Absolute paths are the common case in practice — a session usually names a
# file by full path — so both forms are pinned. A relative-only pattern is a
# gate that misses nearly every real edit.
ABS="/somewhere/repo/plugins/core/skills/specify/SKILL.md"

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
printf x >| $SKILL
rm -rf plugins/core/skills/specify
cp /tmp/other $SKILL
mv $SKILL /tmp/elsewhere
printf x > $ABS
sed -i s/a/b/ $ABS
rm -rf /somewhere/repo/plugins/core/skills/specify
tee $ABS < /tmp/x
sed -i s/a/b/ "/Users/First Last/repo/plugins/core/skills/specify/SKILL.md"
CMDS
echo "PASS: 17 write forms blocked — relative, absolute, spaced, >| and folder rm"

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
cp $SKILL /tmp/backup
diff $SKILL /tmp/other
cat $ABS
cp $ABS /tmp/backup
CMDS
echo "PASS: reads of a skill file stay allowed, including redirect-to-elsewhere"

# --- unrelated paths are none of the gate's business ------------------------
[ "$(probe "sed -i 's/a/b/' README.md")" = allowed ] || fail "blocked a non-skill path"
[ "$(probe "rm -rf /tmp/scratch")" = allowed ] || fail "blocked an unrelated command"
# near-misses: the marker must sit on a path boundary, or an unrelated tree
# whose name merely ends in "plugins" gets caught by a gate it has nothing to
# do with — the kind of false block that teaches people to work around it
[ "$(probe "sed -i s/a/b/ notplugins/core/skills/demo/SKILL.md")" = allowed ] \
    || fail "blocked notplugins/… — marker matched off a path boundary"
[ "$(probe "python3 -c \"import pathlib; pathlib.Path('notplugins/core/skills/demo/SKILL.md').write_text('x')\"")" = allowed ] \
    || fail "blocked notplugins/… inside an interpreter argument"
echo "PASS: non-skill paths are untouched, including notplugins/ near-misses"

# --- with the marker present, writes are allowed ---------------------------
mkdir -p "$CLAUDE_PLUGIN_DATA" && touch "${CLAUDE_PLUGIN_DATA}/loaded-${SESSION}"
[ "$(probe "sed -i 's/a/b/' $SKILL")" = allowed ] || fail "still blocked after the skill loaded"
echo "PASS: once skill-workshop is loaded, Bash writes go through"

# gate_target.py ships in the core bundle too, because plugin hooks do not
# travel with vendored skills. sync_duplicates.py only scans *.sh and a skill's
# own scripts/, so this pair would drift unnoticed without an explicit check.
canonical="$here/../hooks/gate_target.py"
shipped="$here/../../core/skills/init/assets/bin/gate_target.py"
if ! cmp -s "$canonical" "$shipped"; then
    fail "gate_target.py has drifted from its copy in the core bundle"
fi
echo "PASS: the bundled copy of gate_target.py matches the canonical one"

echo "=== gate_bash_test: all passed ==="
