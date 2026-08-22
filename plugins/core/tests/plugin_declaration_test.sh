#!/usr/bin/env bash
# plugin_declaration_test.sh — init.py declares the marketplace in the host
# repo's .claude/settings.json, and never removes a vendored skill unasked.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; mkdir -p "$repo"
ver="$(cat "$here/../skills/init/assets/.bundle-version")"

fail() { echo "FAIL: $1" >&2; exit 1; }

# a vendored skill (marker) and one the consumer authored (no marker)
mkdir -p "$repo/.claude/skills/specify" "$repo/.claude/skills/mine"
touch "$repo/.claude/skills/specify/.arsenal-vendored"

python3 "$init_py" --repo-path "$repo" >"$tmp/out1" 2>&1 || fail "init exited non-zero"

python3 - "$repo/.claude/settings.json" "$ver" <<'PY' || fail "settings.json not written as expected"
import json, sys
s = json.load(open(sys.argv[1]))
src = s["extraKnownMarketplaces"]["claude-arsenal"]["source"]
assert src["source"] == "github", src
assert src["ref"] == f"v{sys.argv[2]}", src
assert s["enabledPlugins"]["core@claude-arsenal"] is True
assert s["enabledPlugins"]["skill-creator@claude-arsenal"] is True
PY
echo "PASS: marketplace declared and pinned to v$ver"

grep -q "ASK THE USER" "$tmp/out1" || fail "should have asked about vendored copies"
[ -d "$repo/.claude/skills/specify" ] || fail "vendored skill removed without consent"
echo "PASS: vendored copies survive a run with no decision, and the user is asked"

# --migrate-plugins yes prunes only what carries the marker
python3 "$init_py" --repo-path "$repo" --migrate-plugins yes >"$tmp/out2" 2>&1
[ ! -d "$repo/.claude/skills/specify" ] || fail "vendored skill not pruned on 'yes'"
[ -d "$repo/.claude/skills/mine" ] || fail "pruned a skill the consumer authored"
grep -q 'plugin-migration = "yes"' "$repo/arsenal/config.toml" || fail "decision not recorded"
echo "PASS: 'yes' prunes marked copies only, and records the decision"

# the recorded decision must leave config.toml parseable — arsenal_config.py
# raises ConfigError on a config it cannot parse, so a bare `yes` would break
# every later config read in the repo that just answered the question
python3 -c "
import tomllib, sys
tomllib.loads(open('$repo/arsenal/config.toml').read())
" || fail "config.toml is not valid TOML after recording the decision"
echo "PASS: config.toml stays valid TOML after the decision is recorded"

# a symlinked skill dir carrying the marker must be left alone: shutil.rmtree
# refuses a symlink and would abort the prune half-done
mkdir -p "$tmp/elsewhere/linked"
touch "$tmp/elsewhere/linked/.arsenal-vendored"
mkdir -p "$repo/.claude/skills/still-vendored"
touch "$repo/.claude/skills/still-vendored/.arsenal-vendored"
ln -s "$tmp/elsewhere/linked" "$repo/.claude/skills/linked"

python3 "$init_py" --repo-path "$repo" --migrate-plugins yes >"$tmp/out3" 2>&1   || fail "prune aborted on a symlinked skill dir"
[ -L "$repo/.claude/skills/linked" ] || fail "removed a symlink the consumer wired up"
[ -d "$tmp/elsewhere/linked" ] || fail "deleted through a symlink"
[ ! -d "$repo/.claude/skills/still-vendored" ] || fail "real vendored dir not pruned"
echo "PASS: symlinks are skipped, real vendored dirs still pruned"

# an existing declaration is never rewritten (a consumer's own pin is theirs)
python3 - "$repo/.claude/settings.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
s["extraKnownMarketplaces"]["claude-arsenal"]["source"]["ref"] = "v0.0.1"
json.dump(s, open(sys.argv[1], "w"), indent=2)
PY
python3 "$init_py" --repo-path "$repo" >/dev/null 2>&1
python3 - "$repo/.claude/settings.json" <<'PY' || exit 1
import json, sys
s = json.load(open(sys.argv[1]))
assert s["extraKnownMarketplaces"]["claude-arsenal"]["source"]["ref"] == "v0.0.1", "clobbered a consumer's pin"
PY
echo "PASS: an existing marketplace pin is left alone"

echo "=== plugin_declaration_test: all passed ==="
