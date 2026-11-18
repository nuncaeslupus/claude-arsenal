#!/usr/bin/env bash
# vendor_on_init_test.sh — /init produces a repo that works on every surface:
# skills committed where a cloud session can read them, and the skill-edit gate
# wired into settings.json because plugin hooks do not travel with vendoring.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

repo="$tmp/repo"; mkdir -p "$repo/.claude"
# a consumer arriving from v1.0.0–v1.1.0, whose settings declare the plugins
cat > "$repo/.claude/settings.json" <<'JSON'
{
  "extraKnownMarketplaces": {"claude-arsenal": {"source": {"source": "github", "repo": "nuncaeslupus/claude-arsenal", "ref": "v1.1.0"}}},
  "enabledPlugins": {"core@claude-arsenal": true, "skill-workshop@claude-arsenal": true}
}
JSON
# a skill the consumer wrote — never ours to touch
mkdir -p "$repo/.claude/skills/mine" && echo "x" > "$repo/.claude/skills/mine/SKILL.md"

python3 "$init_py" --repo-path "$repo" >/dev/null 2>&1 || fail "init exited non-zero"

[ -f "$repo/.claude/skills/init/SKILL.md" ] || fail "skills were not vendored"
[ -f "$repo/.claude/skills/specify/.arsenal-vendored" ] || fail "vendor marker missing"
[ -f "$repo/.claude/skills/mine/SKILL.md" ] || fail "clobbered a skill the consumer authored"
[ ! -f "$repo/.claude/skills/mine/.arsenal-vendored" ] || fail "marked a skill we do not own"
echo "PASS: skills vendored, consumer's own skill untouched"

# #589: Claude Code's built-in /init shadows the installer, so the same skill ships
# under a name nothing else uses — vendored with core, and out of the model's
# listing (disable-model-invocation) so it adds nothing to every session's context.
alias_md="$repo/.claude/skills/arsenal-init/SKILL.md"
[ -f "$alias_md" ] || fail "#589: /arsenal-init was not vendored"
grep -qx 'name: arsenal-init' "$alias_md" || fail "#589: arsenal-init has the wrong name"
grep -qx 'disable-model-invocation: true' "$alias_md" || fail "#589: arsenal-init is in the model's listing"
grep -q '`init` skill' "$alias_md" || fail "#589: arsenal-init does not hand over to the init skill"
grep -q '^section:\|^  section:' "$alias_md" && fail "#589: arsenal-init must be core, installed by every profile"
echo "PASS: /arsenal-init is vendored as a non-colliding, listing-free name for init"

python3 - "$repo/.claude/settings.json" <<'PY' || fail "settings.json is wrong after init"
import json, sys
s = json.load(open(sys.argv[1]))
assert "extraKnownMarketplaces" not in s, "plugin declaration not retired"
assert "enabledPlugins" not in s, "enabledPlugins not retired"
pre = s["hooks"]["PreToolUse"][0]
assert pre["matcher"] == "Edit|Write|MultiEdit|Bash", pre
assert "check_skill_workshop_loaded.sh" in pre["hooks"][0]["command"], pre
PY
echo "PASS: plugin declaration retired, gate hook registered"

# the gate must actually fire from the bundle it just installed
[ -x "$repo/claude-arsenal/bin/check_skill_workshop_loaded.sh" ] || fail "gate script not installed"
[ -f "$repo/claude-arsenal/bin/gate_target.py" ] || fail "gate_target.py not installed"
export CLAUDE_PLUGIN_DATA="$tmp/markers"
payload='{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ .claude/skills/specify/SKILL.md"}}'
# A HOME of our own: whether the gate blocks depends on whether skill-workshop is
# reachable, and the machine running this test may have it in its plugin cache.
mkdir -p "$tmp/home"
gate() { (cd "$repo" && HOME="$tmp/home" CLAUDE_PROJECT_DIR="$repo" bash claude-arsenal/bin/check_skill_workshop_loaded.sh); }

# #586: init vendors core only, so with no skill-workshop anywhere the gate's key
# does not exist. It must not block behind a skill the session cannot load.
printf '%s' "$payload" | gate >/dev/null 2>&1 \
    || fail "#586: the vendored gate blocked a skill edit although no skill-workshop is reachable"
echo "PASS: the vendored gate is advisory where skill-workshop cannot be loaded"

mkdir -p "$repo/.claude/skills/skill-workshop" && echo x > "$repo/.claude/skills/skill-workshop/SKILL.md"
if printf '%s' "$payload" | gate >/dev/null 2>&1; then
    fail "the vendored gate allowed a skill edit with no marker"
fi
mkdir -p "$tmp/home/.claude/plugins/cache/m/skill-workshop/1/skills/skill-workshop"
rm -rf "$repo/.claude/skills/skill-workshop"
touch "$tmp/home/.claude/plugins/cache/m/skill-workshop/1/skills/skill-workshop/SKILL.md"
if printf '%s' "$payload" | gate >/dev/null 2>&1; then
    fail "the vendored gate allowed a skill edit while skill-workshop is in the plugin cache"
fi
rm -rf "$tmp/home/.claude"
echo "PASS: the vendored gate blocks a Bash skill edit once skill-workshop is reachable"

# #468: the registered command, run as settings.json runs it, must still work
# once the session's cwd has moved into a subdirectory.
gate_cmd=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["hooks"][0]["command"])' "$repo/.claude/settings.json")
case "$gate_cmd" in *CLAUDE_PROJECT_DIR*) ;; *) fail "#468: gate hook is not anchored at \$CLAUDE_PROJECT_DIR: $gate_cmd" ;; esac
allow='{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls"}}'
printf '%s' "$allow" | (cd "$repo/claude-arsenal/bin" && CLAUDE_PROJECT_DIR="$repo" bash -c "$gate_cmd") >/dev/null 2>&1 \
    || fail "#468: the gate hook fails from a subdirectory"
echo "PASS: the gate hook runs from a subdirectory of the project"

# #468: an entry written relative by an earlier init is upgraded, not duplicated
python3 - "$repo/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p))
s["hooks"]["PreToolUse"][0]["hooks"][0]["command"] = "bash claude-arsenal/bin/check_skill_workshop_loaded.sh"
json.dump(s, open(p, "w"))
PY
python3 "$init_py" --repo-path "$repo" >/dev/null 2>&1 || fail "re-run exited non-zero"
python3 - "$repo/.claude/settings.json" <<'PY' || fail "#468: legacy relative gate hook was not upgraded in place"
import json, sys
pre = json.load(open(sys.argv[1]))["hooks"]["PreToolUse"]
cmds = [h["command"] for e in pre for h in e["hooks"] if "check_skill_workshop_loaded" in h["command"]]
assert len(cmds) == 1 and "CLAUDE_PROJECT_DIR" in cmds[0], cmds
PY
echo "PASS: a relative gate hook from an earlier init is upgraded in place"

# re-running is idempotent, and prunes a skill we no longer ship
mkdir -p "$repo/.claude/skills/retired" && touch "$repo/.claude/skills/retired/.arsenal-vendored"
python3 "$init_py" --repo-path "$repo" >/dev/null 2>&1 || fail "re-run exited non-zero"
[ ! -d "$repo/.claude/skills/retired" ] || fail "stale vendored skill not pruned"
[ -f "$repo/.claude/skills/mine/SKILL.md" ] || fail "re-run clobbered the consumer's skill"
echo "PASS: re-run prunes what we no longer ship, keeps what we never owned"

# Everything /init writes must be covered by the git-add the docs hand out.
# A path missing there is committed by nobody and fails silently later — the
# queue workflow simply never runs, and nothing says so.
# A glob into an array, not `ls` piped into word-splitting: the paths /init
# writes happen to be tame today, but a name with a space would silently split
# into two entries that both "match" nothing and pass.
shopt -s dotglob nullglob
written=()
for entry in "$repo"/*; do
    name="$(basename "$entry")"
    [ "$name" = ".git" ] && continue
    written+=("$name")
done
shopt -u dotglob nullglob
[ ${#written[@]} -gt 0 ] || fail "/init wrote nothing into the repo"
checked=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    checked=$((checked + 1))
    doc_paths=" ${line#git add } "
    for top in "${written[@]}"; do
        case "$doc_paths" in
            *" $top "*) ;;
            *) fail "/init writes '$top', omitted by: $line" ;;
        esac
    done
done <<LINES
$(grep -ho 'git add [^&]*' "$here/../../../README.md" "$here/../../../docs/INSTALL.md")
LINES
[ "$checked" -ge 3 ] || fail "expected at least 3 documented 'git add' commands, found $checked"
echo "PASS: all $checked documented git add commands cover everything /init writes"

echo "=== vendor_on_init_test: all passed ==="
