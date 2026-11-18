#!/usr/bin/env bash
# session_start_test.sh — session_start.sh is the whole deterministic half of the
# session-start protocol. Pin the two things a consumer's session depends on: with no
# scriptable GitHub channel it hands the session the exact files to write (instead of
# silently skipping the board), and --board turns those files into the board report.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${HERE}/../skills/init/assets"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

cd "$tmp" && git init -q . && ln -s "$ASSETS" claude-arsenal && mkdir t
# A PATH with no gh and no token: channel is `none`.
out="$(env -u GH_TOKEN -u GITHUB_TOKEN PATH="$(dirname "$(command -v git)"):$(dirname "$(command -v python3)"):$(dirname "$(command -v bash)"):/usr/bin:/bin" TMPDIR="$tmp/t" bash claude-arsenal/bin/session_start.sh 2>&1)"
grep -q '^channel: none' <<<"$out" || fail "channel line missing: $out"
grep -q 'ACTION: no scriptable GitHub channel' <<<"$out" || fail "no ACTION for the session's own GitHub tools"
grep -q 'session_start.sh --board' <<<"$out" || fail "rerun command not named"

echo '[]' | tee t/arsenal-issues.json t/arsenal-unfiled.json >t/arsenal-import.json
out="$(TMPDIR="$tmp/t" bash claude-arsenal/bin/session_start.sh --board 2>&1)"
grep -q '^tasks: 0' <<<"$out" || fail "board not printed: $out"
grep -q '^ACTION' <<<"$out" && fail "ACTION printed with nothing to do: $out"

rm t/arsenal-import.json
out="$(TMPDIR="$tmp/t" bash claude-arsenal/bin/session_start.sh --board 2>&1)"
grep -q 'missing or empty' <<<"$out" || fail "missing issue file not reported"
echo "PASS: session_start"
