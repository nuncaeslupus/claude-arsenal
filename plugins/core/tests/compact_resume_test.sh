#!/usr/bin/env bash
# Compaction resume: the notes template's Resume block, the SessionStart(compact)
# hook that re-injects it, and the AGENTS.md line that says it is the state.
#
#   bash compact_resume_test.sh [template|hook|agents]   (default: all)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core="$(cd "${here}/.." && pwd)"
assets="${core}/skills/init/assets"
HOOK="${assets}/bin/compact_resume.sh"
TEMPLATE="${core}/skills/execution/references/template.md"
which="${1:-all}"

fail() { echo "FAIL: compact_resume_test — $*" >&2; exit 1; }
want() { [ "$which" = all ] || [ "$which" = "$1" ]; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

if want template; then
  grep -q '^## Resume$' "$TEMPLATE" || fail "template has no '## Resume' section"
  for k in 'Decided' 'Ruled out' 'Next step'; do
    grep -q "^- \*\*${k}\*\*" "$TEMPLATE" || fail "Resume block lacks '${k}'"
  done
  grep -q 'Resume' "${core}/skills/execution/SKILL.md" \
    || fail "execution SKILL.md does not say to keep the Resume block current"
fi

if want hook; then
  [ -x "$HOOK" ] || fail "compact_resume.sh missing or not executable"
  repo="${scratch}/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  run() { (cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$HOOK" </dev/null); }

  # No notes: silent, exit 0.
  out="$(run)" || fail "hook exited non-zero with no tmp/"
  [ -z "$out" ] || fail "hook not silent without notes: $out"

  # A notes file: its Resume block (minus the guidance quote) and git status.
  mkdir -p "${repo}/tmp"
  cp "$TEMPLATE" "${repo}/tmp/t-1234abcd-notes.md"
  echo x > "${repo}/changed.txt"
  out="$(run)" || fail "hook exited non-zero with notes"
  echo "$out" | grep -q 'tmp/t-1234abcd-notes.md' || fail "notes path not printed"
  echo "$out" | grep -q 'Next step' || fail "Resume block not printed"
  echo "$out" | grep -q '^>' && fail "guidance blockquote leaked into output"
  echo "$out" | grep -q 'Gate & failing check' && fail "printed past the Resume section"
  echo "$out" | grep -q 'changed.txt' || fail "git status not printed"

  # The newest notes file wins; a stale one (>7 days) is ignored.
  printf '## Resume\n- **Next step**: `newest`\n' > "${repo}/tmp/t-9999ffff-notes.md"
  touch -t 202001010000 "${repo}/tmp/t-1234abcd-notes.md"
  out="$(run)"
  echo "$out" | grep -q 'newest' || fail "did not pick the newest notes file"
  touch -t 202001010000 "${repo}/tmp/t-9999ffff-notes.md"
  out="$(run)"
  [ -z "$out" ] || fail "stale notes not ignored: $out"

  # A notes file with no Resume section says so rather than printing nothing.
  printf '# notes\n' > "${repo}/tmp/t-0000aaaa-notes.md"
  out="$(run)"
  echo "$out" | grep -q 'no Resume section' || fail "missing Resume section not flagged"

  # /init registers it once, under SessionStart/compact, and re-running does not duplicate.
  target="${scratch}/host"
  mkdir -p "$target"
  git -C "$target" init -q
  python3 "${core}/skills/init/scripts/init.py" --repo-path "$target" --silent >/dev/null 2>&1 \
    || fail "init.py failed"
  python3 "${core}/skills/init/scripts/init.py" --repo-path "$target" --silent >/dev/null 2>&1
  python3 - "$target/.claude/settings.json" <<'EOF' || fail "init did not register the compact hook once"
import json, sys
s = json.load(open(sys.argv[1]))
hits = [e for e in s["hooks"].get("SessionStart", []) if "compact_resume.sh" in json.dumps(e)]
assert len(hits) == 1 and hits[0].get("matcher") == "compact", hits
EOF
  [ -x "$target/claude-arsenal/bin/compact_resume.sh" ] || fail "hook not vendored executable"

  python3 - "${core}/hooks/hooks.json" <<'EOF' || fail "core hooks.json does not register it"
import json, sys
s = json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
assert all("hooks" in e for e in s), "every entry needs a hooks list"
assert any(e.get("matcher") == "compact" and "compact_resume.sh" in json.dumps(e) for e in s)
EOF
fi

if want agents; then
  grep -q 'After compaction mid-task' "${assets}/AGENTS.md" \
    || fail "AGENTS.md does not say how to resume after compaction"
fi

echo "PASS: compact_resume_test (${which})"
