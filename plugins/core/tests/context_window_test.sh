#!/usr/bin/env bash
# context_window_test.sh — arsenal/config.toml -> .claude/settings.json.
#
# `context-window` is the first key that reaches OUTSIDE the bundle: it is
# written into the host's own .claude/settings.json as `autoCompactWindow`,
# which Claude Code reads. That makes two failure modes worth pinning, and they
# pull in opposite directions.
#
# Writing too eagerly: settings.json is the host's file, holding things a person
# chose (a statusLine, hooks, permissions). An installer that rewrites it must
# add one key and disturb nothing else, and must never delete a value just
# because the arsenal key is unset.
#
# Writing too timidly: the whole point of #383 is that a setting which looks
# configured and reaches nothing is worse than an absent one. Once the host HAS
# set context-window, settings.json disagreeing with it is drift, not a second
# opinion — so that case overwrites, deliberately unlike statusLine.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT="${SCRIPT_DIR}/../skills/init/scripts/init.py"

[[ -f "${INIT}" ]] || { echo "SKIP: init.py not found at ${INIT}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# Drive the two functions directly. Running the whole installer would exercise
# vendoring, git and the network for a question about one key.
apply() {
    python3 - "${INIT}" "$1" <<'PY'
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("init_under_test", sys.argv[1])
init = importlib.util.module_from_spec(spec)
spec.loader.exec_module(init)
repo = Path(sys.argv[2])
init._register_context_window(repo, init._read_context_window(repo / "arsenal" / "config.toml"))
PY
}
key() { python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2],'<absent>'))" "$1" "$2"; }

repo="${tmp}/repo"
mkdir -p "${repo}/arsenal" "${repo}/.claude"

# --- unset: settings.json is not created, and an existing key is left alone ---
printf 'merge-policy = "after-ci"\n' > "${repo}/arsenal/config.toml"
apply "${repo}" || fail "unset context-window should be a no-op, not an error"
[[ ! -f "${repo}/.claude/settings.json" ]] || fail "no key set must not create settings.json"

printf '{"autoCompactWindow": 300000}\n' > "${repo}/.claude/settings.json"
apply "${repo}"
[[ "$(key "${repo}/.claude/settings.json" autoCompactWindow)" == "300000" ]] \
    || fail "opting out of the key must not delete a window the repo set by hand"
echo "PASS: context-window unset touches nothing"

# --- set: written, and the host's own settings survive it ---
cat > "${repo}/.claude/settings.json" <<'JSON'
{"statusLine": {"type": "command", "command": "mine.sh"}, "autoCompactWindow": 900000}
JSON
printf 'context-window = 200000\n' > "${repo}/arsenal/config.toml"
apply "${repo}" || fail "writing the key should succeed"
[[ "$(key "${repo}/.claude/settings.json" autoCompactWindow)" == "200000" ]] \
    || fail "config.toml is the source of truth — a stale settings value must be replaced"
grep -q "mine.sh" "${repo}/.claude/settings.json" \
    || fail "the host's statusLine must survive an autoCompactWindow write"
echo "PASS: a set key overwrites drift and preserves the rest of settings.json"

# --- set with no settings.json at all ---
rm -f "${repo}/.claude/settings.json"
apply "${repo}"
[[ "$(key "${repo}/.claude/settings.json" autoCompactWindow)" == "200000" ]] \
    || fail "settings.json should be created when the key is set"
echo "PASS: settings.json is created when absent"

# --- out-of-range values never reach settings.json ---
# Claude Code accepts 100k-1M and discards anything else, so writing an
# out-of-range value would produce a file that looks configured and is ignored.
rm -f "${repo}/.claude/settings.json"
for bad in 50 99999 1000001 true '"200000"'; do
    printf 'context-window = %s\n' "${bad}" > "${repo}/arsenal/config.toml"
    apply "${repo}"
    [[ ! -f "${repo}/.claude/settings.json" ]] || fail "context-window = ${bad} must not be written"
done
echo "PASS: out-of-range and wrong-typed values are never written"

# --- an unparseable settings.json is reported, not clobbered ---
printf 'context-window = 200000\n' > "${repo}/arsenal/config.toml"
printf 'this is not json\n' > "${repo}/.claude/settings.json"
out=$(apply "${repo}" 2>&1) || fail "an unparseable settings.json must not abort the install"
grep -qi "unparseable" <<<"${out}" || fail "the skip should be reported: ${out}"
grep -q "not json" "${repo}/.claude/settings.json" \
    || fail "an unparseable settings.json must be left for its owner, not overwritten"
echo "PASS: unparseable settings.json is skipped and preserved"

echo "PASS: context_window_test — config.toml reaches settings.json, and nothing else"
exit 0
