#!/usr/bin/env bash
# session_start.sh — the deterministic half of AGENTS.md's session-start protocol.
#
# The protocol used to be nine prose steps the model re-derived every session.
# Everything in it that is a computation (bundle refresh, capability map, channel
# detection, the board, missing handles, filed-issue import) is here, and the
# output is a few lines. What stays with the session is only what needs ITS
# GitHub tools or a user: those are printed as `ACTION:` lines.
#
#   session_start.sh           everything; fetches issues itself when channel is `gh`
#   session_start.sh --board   steps from the board on, from issue files the session
#                              wrote (the `rest`/`none` channels)
#
# Files (all under ${TMPDIR:-/tmp}): arsenal-issues.json, arsenal-unfiled.json,
# arsenal-import.json. Exits 0 even when a step reports a problem — it is a report.

set -uo pipefail

MODE="${1:-all}"
B=claude-arsenal
T="${TMPDIR:-/tmp}"
ISSUES="$T/arsenal-issues.json"; UNFILED="$T/arsenal-unfiled.json"; IMPORT="$T/arsenal-import.json"
INIT=.claude/skills/init/scripts/init.py

if [[ "$MODE" != "--board" ]]; then
    # 0a. Update check. INERT (non-subtree install) is the expected answer: one line.
    if [[ -x "$B/bin/check_update.sh" || -f "$B/bin/check_update.sh" ]]; then
        out="$(bash "$B/bin/check_update.sh" --check-only 2>&1)"
        if [[ "$out" == *INERT* ]]; then echo "update: INERT (non-subtree install; nothing to do)"
        elif [[ -n "$out" ]]; then echo "update: $out"; fi
    fi
    # 0b. Refresh (skipped when the update check says the vendored skill is behind).
    if [[ -f "$INIT" && "${out:-}" != *"VENDORED SKILL BEHIND BUNDLE"* ]]; then
        python3 "$INIT" --repo-path . --silent 2>&1
    fi
    # 0c. Capability map.
    [[ -f "$INIT" ]] && python3 "$INIT" --list-sections 2>&1

    channel="$(bash "$B/bin/github_channel.sh" --detect 2>/dev/null || echo none)"
    echo "channel: $channel"
    if [[ "$channel" == "gh" ]]; then
        # Narrow fetch: no `body` (the import fetch is the one exception).
        label="$(python3 "$B/scripts/arsenal_config.py" --get import-label 2>/dev/null || echo arsenal:queue)"
        gh issue list --label arsenal:task --state all --limit 1000 \
            --json number,title,state,labels,assignees >"$ISSUES" || echo "gh issue fetch failed (task issues)"
        gh issue list --state open --limit 1000 --json number,title,labels \
            --jq "[.[] | select(all(.labels[]; .name != \"arsenal:task\" and .name != \"$label\")) | {number,title}]" \
            >"$UNFILED" || echo "gh issue fetch failed (unfiled)"
        gh issue list --label "$label" --state open --limit 1000 \
            --json number,title,body,labels >"$IMPORT" || echo "gh issue fetch failed (import)"
    else
        label="$(python3 "$B/scripts/arsenal_config.py" --get import-label 2>/dev/null || echo arsenal:queue)"
        cat <<EOF
ACTION: no scriptable GitHub channel. With your own GitHub tools write these files, then run \`bash $B/bin/session_start.sh --board\`:
  $ISSUES   issues labelled arsenal:task, open AND closed: number,title,state,labels,assignees (no body)
  $UNFILED  open issues with neither arsenal:task nor $label: number,title
  $IMPORT   open issues labelled $label: number,title,body,labels
EOF
        exit 0
    fi
fi

for f in "$ISSUES" "$UNFILED" "$IMPORT"; do
    [[ -s "$f" ]] || { echo "ACTION: $f missing or empty; treat the board as unverified"; exit 0; }
done

# 3. Board. A failed fetch makes the counts unverified; say so.
git fetch --quiet origin 2>/dev/null || echo "git fetch origin failed: board counts unverified"
python3 "$B/scripts/query_status.py" --issues "$ISSUES" --open-issues "$UNFILED"

# 4. Missing handles, 4b. filed-issue import. Both print a status line when there is
# nothing to do; any other line is a row the session must act on with its own tools.
handles="$(python3 "$B/scripts/handle_sync.py" --issues "$ISSUES" 2>&1)"
echo "$handles"
if grep -qv '^handle_sync:' <<<"$handles"; then
    echo "ACTION: create each issue above (every label listed, plus a visible \`arsenal-task: <id>\` body line; resolve any 'ambiguous' row first). See $B/references/queue-seeding.md"
fi
imp="$(python3 "$B/scripts/issue_import.py" --issues "$IMPORT" --apply 2>&1)"
echo "$imp"
if grep -qv '^issue_import:' <<<"$imp"; then
    echo "ACTION: apply every change printed above and commit the new task files. See $B/references/queue-seeding.md"
fi
