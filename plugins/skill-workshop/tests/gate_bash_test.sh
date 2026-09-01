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

# --- the two escapes that made this gate skippable (#300, #263) ------------
# Both were total misses rather than partial ones: `bash_target` returned "" and
# the hook allowed the call outright.
#
#   #300 — a newline is a command separator in bash, and the tokeniser dropped
#          it. `echo starting` then became the only simple command the gate
#          looked at, and the `rm` on the next line was never examined.
#   #263 — `(` was an unconditional separator, so the paren of a call split
#          `write_text` away from the `(` that `WRITERS` needs beside it, and
#          the path into a fragment carrying no write signal. Every
#          `obj.method(...)` write inside a heredoc went through, which is the
#          exact route the module docstring names as its reason to exist.
newline_rm=$(printf 'echo starting\nrm -rf plugins/core/skills/specify')
[ "$(probe "$newline_rm")" = blocked ] \
    || fail "#300: a command after a newline was never examined"

heredoc_write=$(printf 'python3 - <<%s\nimport pathlib\np = pathlib.Path("%s")\np.write_text("x", encoding="utf-8")\nPYEOF' "'PYEOF'" "$SKILL")
[ "$(probe "$heredoc_write")" = blocked ] \
    || fail "#263: a heredoc write through obj.method(...) went through"

heredoc_rmtree=$(printf 'python3 - <<%s\nimport shutil\nshutil.rmtree("plugins/core/skills/specify")\nPYEOF' "'PYEOF'")
[ "$(probe "$heredoc_rmtree")" = blocked ] \
    || fail "#263: a heredoc rmtree of a skill folder went through"
echo "PASS: a newline-separated write and a heredoc obj.method(...) write are blocked"

# ...and neither fix may cost a read. A line continuation is removed by bash, so
# splitting on it would report `cp SKILL` — a read — as a write.
continuation=$(printf 'cp %s \\\n    /tmp/backup' "$SKILL")
[ "$(probe "$continuation")" = allowed ] \
    || fail "a line-continued cp OUT of a skill was reported as a write"
[ "$(probe "( cd /tmp && ls )")" = allowed ] || fail "blocked a harmless subshell"
[ "$(probe "python3 -c \"print(open('$SKILL').read())\"")" = allowed ] \
    || fail "blocked an interpreter READ of a skill file"
echo "PASS: line continuations, subshells and interpreter reads stay allowed"

# --- git, and open() by its mode (#265) ------------------------------------
# `git` was absent from the utility table entirely, so the two commands a
# session reaches for to undo an edit went straight through. And WRITERS keyed
# on the write call, so `open(path, "w").close()` — which truncates the file to
# nothing without ever writing a byte — was invisible.
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    [ "$(probe "$cmd")" = blocked ] || fail "should have blocked: $cmd"
done <<CMDS
git restore $SKILL
git checkout -- $SKILL
git checkout HEAD~1 -- $SKILL
git rm $SKILL
git clean -fd plugins/core/skills/specify
git -C /somewhere/repo restore $SKILL
python3 -c "open('$SKILL', 'w').close()"
python3 -c "open('$SKILL', mode='a').close()"
python3 -c "open('$SKILL', 'r+b').close()"
git restore $ABS
CMDS
echo "PASS: git writes and open() write-modes are blocked"

# The other half: git's read plumbing and a read-mode open must stay allowed.
# A gate that blocks reads gets routed around instead of through.
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    [ "$(probe "$cmd")" = allowed ] || fail "should have allowed: $cmd"
done <<CMDS
git diff $SKILL
git log -- $SKILL
git show HEAD:$SKILL
git status --short
git add $SKILL
python3 -c "print(open('$SKILL').read())"
python3 -c "open('$SKILL', 'r').read()"
python3 -c "open('$SKILL', 'rb').read()"
python3 -c "open('$SKILL', encoding='utf-8').read()"
git checkout some-branch
CMDS
echo "PASS: git reads and open() read-modes stay allowed"

# --- interpreter source: the polarity is inverted (#337) -------------------
# WRITERS is a list of ways to write a file, and that list cannot be finished.
# Each line below reaches the SKILL.md without matching any name in it — through
# `os`, through a shell-out, through a string built at runtime, or through
# `Path.open`, which takes its mode FIRST and so never has the comma the
# `open(path, "w")` pattern needs. Every one of them returned "" before.
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    [ "$(probe "$cmd")" = blocked ] || fail "should have blocked: $cmd"
done <<CMDS
python3 -c "from pathlib import Path; Path('$SKILL').open('w').writelines(['x'])"
python3 -c "import json; from pathlib import Path; json.dump({}, Path('$SKILL').open('w'))"
python3 -c "import os; os.remove('$SKILL')"
python3 -c "import os; os.truncate('$SKILL', 0)"
python3 -c "import fileinput; fileinput.input('$SKILL', inplace=True)"
python3 -c "import os; os.system('rm $SKILL')"
python3 -c "import subprocess; subprocess.run(['rm', '$SKILL'])"
python3 -c "from pathlib import Path; Path('/tmp/x').replace('$SKILL')"
python3 -c "exec('import os; os.remove(' + repr('$SKILL') + ')')"
python3 -c "open('$SKILL', 'w').writelines(['x'])"
python3 -c "import json; json.dump({}, open('$SKILL', 'w'))"
python3 -c "print('x', file=open('$SKILL', 'w'))"
perl -pi -e s/a/b/ $SKILL
uv run python3 -c "import os; os.remove('$SKILL')"
node -e require('fs').writeFileSync('$SKILL','x')
perl -E unlink "$SKILL"
echo "from pathlib import Path; Path('$SKILL').write_bytes(b'x')" | python3
CMDS
echo "PASS: 17 interpreter writes blocked — os, shell-out, exec, Path.open, uv run, a pipe"

# The heredoc route is the one the module docstring names as its reason to
# exist, and it is the one the tokeniser makes hardest: an unquoted newline is a
# command separator, so each body line ends up standing alone, nowhere near the
# `python3` that gives it meaning.
heredoc_writelines=$(printf 'python3 - <<%s\nopen("%s", "w").writelines(["x"])\nPYEOF' "'PYEOF'" "$SKILL")
[ "$(probe "$heredoc_writelines")" = blocked ] \
    || fail "#337: a heredoc writelines went through"
heredoc_remove=$(printf 'python3 - <<%s\nimport os\nos.remove("%s")\nPYEOF' "'PYEOF'" "$SKILL")
[ "$(probe "$heredoc_remove")" = blocked ] \
    || fail "#337: a heredoc os.remove went through"
echo "PASS: heredoc writelines and os.remove are blocked"

# ...and inverting the polarity may not cost the reads. The last two lines are
# the flag vocabulary, which is per-interpreter: perl's `-E` carries a program,
# so `perl -E unlink …` above must block, but python's means "ignore the
# environment" and a script file follows it, and `-m` names a module whose
# arguments come after — both of those read a skill folder rather than writing
# to it. This is the whole reason
# the inversion is written as "strip the read-only uses, then look for a path
# left standing" rather than "an interpreter naming a skill path is a write":
# under-listing a read only ever blocks more, and over-blocking is how a gate
# gets routed around instead of through.
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    [ "$(probe "$cmd")" = allowed ] || fail "should have allowed: $cmd"
done <<CMDS
python3 -c "from pathlib import Path; print(Path('$SKILL').read_text())"
python3 -c "from pathlib import Path; print(Path('$SKILL').open('r').read())"
python3 -c "import json; print(json.load(open('$SKILL')))"
python3 -c "from pathlib import Path; print(Path('$SKILL').exists())"
uv run python3 scripts/audit_library.py plugins/core/skills/specify
python3 plugins/core/skills/specify/scripts/helper.py --check
python3 -m pytest plugins/core/skills/specify/tests
python3 -E scripts/audit_library.py plugins/core/skills/specify
CMDS
heredoc_read=$(printf 'python3 - <<%s\nprint(open("%s").read())\nPYEOF' "'PYEOF'" "$SKILL")
[ "$(probe "$heredoc_read")" = allowed ] || fail "blocked a heredoc READ of a skill file"
echo "PASS: interpreter reads, a script file argument and a heredoc read stay allowed"

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
