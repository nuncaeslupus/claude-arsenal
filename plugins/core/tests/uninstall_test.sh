#!/usr/bin/env bash
# uninstall_test.sh — `init.py --uninstall` (#600) removes what /init wrote and
# nothing else: a dry run by default, only files still exactly as init wrote them,
# never the host's arsenal/ tree, and never a host's own hook, skill or prose.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
export HOME="$tmp/home" ARSENAL_UPSTREAM_CHECK=0
mkdir -p "$HOME"

repo="$tmp/repo"; git init -q "$repo"
printf '# Project\n\nOur own notes.\n' > "$repo/CLAUDE.md"
printf '# Project\n\nSome readme.\n' > "$repo/README.md"
mkdir -p "$repo/.claude/skills/mine" && echo x > "$repo/.claude/skills/mine/SKILL.md"
cat > "$repo/.claude/settings.json" <<'JSON'
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash mine.sh"}]}]}}
JSON
python3 "$init_py" --repo-path "$repo" --no-branch-protection >/dev/null 2>&1 || fail "init exited non-zero"
[ -f "$repo/claude-arsenal/AGENTS.md" ] && [ -f "$repo/.claude/skills/init/SKILL.md" ] \
    || fail "init did not install what this test removes"

# A file the host edited, and one it added, inside init's trees.
echo "# local edit" >> "$repo/claude-arsenal/references/worker-loop.md"
echo "mine" > "$repo/claude-arsenal/bin/my_helper.sh"
echo "edited" >> "$repo/.claude/skills/specify/SKILL.md"

snapshot() { (cd "$repo" && find . -path ./.git -prune -o -type f -print | sort | xargs cksum); }
before="$(snapshot)"
out="$(python3 "$init_py" --repo-path "$repo" --uninstall 2>&1)" || fail "dry run exited non-zero: $out"
[[ "$(snapshot)" == "$before" ]] || fail "the dry run changed files"
grep -q "DRY RUN" <<<"$out" || fail "the dry run did not say so: $out"
grep -q "remove: claude-arsenal/AGENTS.md" <<<"$out" || fail "dry run does not list the bundle: $out"
grep -q "keep:   claude-arsenal/references/worker-loop.md (differs" <<<"$out" \
    || fail "an edited bundle file is not listed as kept: $out"
grep -q "keep:   .claude/skills/specify/ (differs" <<<"$out" || fail "an edited skill is not listed as kept"
echo "PASS: --uninstall is a dry run that lists removals and the edited files it keeps"

python3 "$init_py" --repo-path "$repo" --uninstall --apply >/dev/null 2>&1 || fail "--apply exited non-zero"
[ ! -e "$repo/claude-arsenal/AGENTS.md" ] || fail "an untouched bundle file survived"
[ ! -e "$repo/.claude/skills/init" ] || fail "an untouched vendored skill survived"
[ ! -e "$repo/.github/workflows/arsenal-queue.yml" ] || fail "the shipped queue workflow survived"
[ -f "$repo/claude-arsenal/references/worker-loop.md" ] || fail "deleted a bundle file the host edited"
[ -f "$repo/claude-arsenal/bin/my_helper.sh" ] || fail "deleted a file the host added"
[ -f "$repo/.claude/skills/specify/SKILL.md" ] || fail "deleted a vendored skill the host edited"
[ -f "$repo/.claude/skills/mine/SKILL.md" ] || fail "deleted the host's own skill"
[ -f "$repo/arsenal/config.toml" ] || fail "deleted the host's arsenal/ tree"
grep -q "claude-arsenal" "$repo/CLAUDE.md" && fail "the CLAUDE.md protocol block survived"
grep -q "Our own notes." "$repo/CLAUDE.md" || fail "removed the host's own CLAUDE.md text"
grep -q "claude-arsenal" "$repo/README.md" && fail "the README badge survived"
grep -q "Some readme." "$repo/README.md" || fail "removed the host's own README text"
python3 - "$repo/.claude/settings.json" <<'PY' || fail "settings.json is wrong after uninstall"
import json, sys
s = json.load(open(sys.argv[1]))
text = json.dumps(s)
assert "claude-arsenal/bin" not in text, s
assert "statusLine" not in s, s
assert s["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "bash mine.sh", s
PY
echo "PASS: --apply removes only what is still as init wrote it, and keeps the host's own"
echo "=== uninstall_test: all passed ==="
