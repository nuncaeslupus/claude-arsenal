#!/usr/bin/env bash
# session_start_test.sh — session_start.sh is the whole deterministic half of the
# session-start protocol, so every consumer session depends on it. Pinned here, per
# channel: with no scriptable channel (`none`, and `rest`) it hands the session the
# exact files to write and clears last session's copies; --board turns those files
# into the board; on `gh` (a fake `gh` serving canned JSON) it fetches the three
# lists itself with the narrow field sets, filters the stray list, imports filed
# issues, and is safe to run twice. It never commits, works from a subdirectory,
# and a failed fetch is loud (exit 1), not a silent empty board.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${HERE}/../skills/init/assets"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

repo="$tmp/repo"; mkdir -p "$repo/sub" "$tmp/t" "$tmp/bin"
cd "$repo" && git init -q . && ln -s "$ASSETS" claude-arsenal \
    && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
export ARSENAL_ISSUES_JSON="$tmp/t/arsenal-issues.json"
I="$tmp/t/arsenal-issues.json"; U="$tmp/t/arsenal-unfiled.json"; M="$tmp/t/arsenal-import.json"
# python3's dir first: on CI git lives in /usr/bin beside an older system python3.
BASEPATH="$(dirname "$(command -v python3)"):$(dirname "$(command -v git)"):$(dirname "$(command -v bash)"):/usr/bin:/bin"
run() { out="$(cd "$repo/sub" && env -u GH_TOKEN -u GITHUB_TOKEN "$@" bash ../claude-arsenal/bin/session_start.sh ${args[@]+"${args[@]}"} 2>&1)"; rc=$?; }  # bash 3.2: empty array + set -u

# --- none: no gh, no token. Stale files from a previous session are cleared. ---
echo stale >"$I"
args=(); run PATH="$BASEPATH"
[[ $rc -eq 0 ]] || fail "none: exit $rc: $out"
grep -q '^channel: none' <<<"$out" || fail "channel line missing: $out"
grep -q 'ACTION: no scriptable GitHub channel' <<<"$out" || fail "no ACTION for the session's own GitHub tools"
grep -q 'session_start.sh --board' <<<"$out" || fail "rerun command not named"
grep -q "$I" <<<"$out" || fail "ACTION does not name ARSENAL_ISSUES_JSON ($I): $out"
[[ -e "$I" ]] && fail "none: last session's issue file left for --board to read"

grep -q '^update: INERT (non-subtree install' <<<"$out" || fail "non-subtree INERT not shortened: $out"

# A subtree install with only its remote missing is also "INERT", but it is not
# nothing-to-do: the fix (add the remote) must reach the session, not be collapsed.
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty \
    -m $'Add claude-arsenal\n\ngit-subtree-dir: claude-arsenal\ngit-subtree-split: 0000000000000000000000000000000000000000'
args=(); run PATH="$BASEPATH"
grep -q 'non-subtree install; nothing to do' <<<"$out" && fail "subtree-without-remote collapsed to nothing-to-do: $out"
grep -q 'IS a git subtree here' <<<"$out" || fail "subtree-without-remote hint lost: $out"

# --- rest: a token the probe accepts (fake curl) still means the session fetches. ---
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 200
EOF
chmod +x "$tmp/bin/curl"
args=(); run PATH="$tmp/bin:$BASEPATH" GH_TOKEN=x
grep -q '^channel: rest' <<<"$out" || fail "rest not detected: $out"
grep -q 'ACTION: no scriptable GitHub channel' <<<"$out" || fail "rest: no ACTION"
rm "$tmp/bin/curl"

# --- --board from files the session wrote. ---
echo '[]' | tee "$I" "$U" >"$M"
args=(--board); run PATH="$BASEPATH"
[[ $rc -eq 0 ]] || fail "--board: exit $rc: $out"
grep -q '^tasks: 0' <<<"$out" || fail "board not printed: $out"
grep -q '^ACTION' <<<"$out" && fail "ACTION printed with nothing to do: $out"
rm "$M"
args=(--board); run PATH="$BASEPATH"
grep -q 'missing or empty' <<<"$out" || fail "missing issue file not reported"
[[ $rc -eq 1 ]] || fail "missing issue file exited $rc, want 1"
# A step that crashes is a failure, not a row to act on: no ACTION from its error text.
# Simulated with a python3 too old for tomllib (what CI's system python once was).
echo '[]' >"$M"; mkdir -p "$tmp/oldpy"
cat >"$tmp/oldpy/python3" <<EOF
#!/usr/bin/env bash
case "\$1" in -c|-) exec "$(command -v python3)" "\$@" ;; esac
exec "$(command -v python3)" -c 'import runpy, sys; sys.modules["tomllib"] = None; f = sys.argv[1]; sys.argv = sys.argv[1:]; runpy.run_path(f, run_name="__main__")' "\$@"
EOF
chmod +x "$tmp/oldpy/python3"
args=(--board); run PATH="$tmp/oldpy:$BASEPATH"
[[ $rc -eq 1 ]] || fail "crashed steps exited $rc, want 1: $out"
grep -q 'handle_sync.py exited' <<<"$out" || fail "handle_sync failure not named: $out"
grep -q 'issue_import.py exited' <<<"$out" || fail "issue_import failure not named: $out"
grep -q '^ACTION' <<<"$out" && fail "a crashed step's error text became an ACTION: $out"
args=(--bogus); run PATH="$BASEPATH"
[[ $rc -eq 2 ]] || fail "unknown argument exited $rc, want 2"

# --- gh: a fake gh on PATH serving canned JSON; every call is logged. ---
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_GH_LOG"
[[ "$1 $2" == "auth status" ]] && exit 0
[[ -n "${FAKE_GH_FAIL:-}" ]] && exit 1
case "$*" in
  *"--label arsenal:task"*) echo '[{"number":1,"title":"Closed thing","state":"CLOSED","labels":[{"name":"arsenal:task"}],"assignees":[]}]' ;;
  *"--label arsenal:queue"*) echo '[{"number":7,"title":"Filed bug","body":"repro steps","labels":[{"name":"arsenal:queue"}]}]' ;;
  *) echo '[{"number":9,"title":"stray","labels":[]},{"number":1,"title":"x","labels":[{"name":"arsenal:task"}]},{"number":7,"title":"Filed bug","labels":[{"name":"arsenal:queue"}]}]' ;;
esac
EOF
chmod +x "$tmp/bin/gh"
log="$tmp/gh.log"; head0="$(git -C "$repo" rev-parse HEAD)"
args=(); run PATH="$tmp/bin:$BASEPATH" FAKE_GH_LOG="$log"
[[ $rc -eq 0 ]] || fail "gh: exit $rc: $out"
grep -q '^channel: gh' <<<"$out" || fail "gh not detected: $out"
grep -q -- '--label arsenal:task --state all --json number,title,state,labels,assignees ' "$log" \
    || fail "task fetch is not open+closed with the narrow field set: $(cat "$log")"
grep -- '--label arsenal:task' "$log" | grep -q body && fail "task fetch asks for body"
grep -q -- '--label arsenal:queue --state open --json number,title,body,labels' "$log" \
    || fail "import fetch lacks body: $(cat "$log")"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1])) == [{"number": 9, "title": "stray"}]' "$U" \
    || fail "stray list is not exactly the issue with neither label: $(cat "$U")"
grep -q '^tasks: ' <<<"$out" || fail "gh: board not printed: $out"
grep -q '#9' <<<"$out" || fail "gh: stray issue #9 not flagged: $out"
grep -q '"issue":7' <<<"$out" || fail "gh: filed issue #7 not imported: $out"
grep -q 'ACTION: apply every change' <<<"$out" || fail "gh: no ACTION for the import row"
ls "$repo"/arsenal/tasks/t-*.md >/dev/null 2>&1 || fail "gh: no task file written for #7"
[[ "$(git -C "$repo" rev-parse HEAD)" == "$head0" ]] || fail "the script committed"

# Twice, before the session applied the relabel: #7 is the new task's handle
# already, so no second issue is proposed for it.
args=(); run PATH="$tmp/bin:$BASEPATH" FAKE_GH_LOG="$log"
[[ $rc -eq 0 ]] || fail "gh rerun: exit $rc: $out"
grep -q 'ACTION: create each issue' <<<"$out" && fail "rerun proposes a duplicate handle: $out"
[[ $(ls "$repo"/arsenal/tasks/t-*.md | wc -l) -eq 1 ]] || fail "rerun wrote a second task file"

# A failed fetch is loud and leaves no stale file behind to be read as this session's.
args=(); run PATH="$tmp/bin:$BASEPATH" FAKE_GH_LOG="$log" FAKE_GH_FAIL=1
[[ $rc -eq 1 ]] || fail "failed gh fetch exited $rc, want 1: $out"
grep -q 'failed: board counts unverified' <<<"$out" || fail "failed fetch not reported: $out"
[[ -e "$I" ]] && fail "failed fetch kept the previous issue file"
grep -q '^tasks: ' <<<"$out" && fail "board printed from a failed fetch"
echo "PASS: session_start"
