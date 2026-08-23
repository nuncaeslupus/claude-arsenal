#!/usr/bin/env bash
# retrospective_user_turns_test.sh — the correction scan reads people, not the machine.
#
# Most records a transcript files under role `user` were never typed by anyone:
# tool results, skill bodies loaded through the Skill tool, `!command` escapes,
# task notifications. Scanning those for correction phrases finds the skill's
# own prose — a `## Gotchas` section reading "what goes wrong AND why" reads as
# the user saying something went wrong, and the one real correction sinks into
# a list of noise. This pins the filter that keeps that from happening.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="${SCRIPT_DIR}/../skills/session-end/scripts/query_session_history.py"
[[ -f "${SCANNER}" ]] || { echo "SKIP: ${SCANNER} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

proj="${tmpdir}/proj"
mkdir -p "${proj}"

# Every line below carries a correction phrase. Exactly one was typed by a human.
python3 - "${tmpdir}/t.jsonl" <<'PY'
import json, sys
def rec(**kw):
    base = {"type": "user", "sessionId": "s1", "timestamp": "2026-08-24T00:00:00.000Z"}
    base.update(kw); return base

def msg(text): return {"role": "user", "content": text}

rows = [
    # a skill body injected by the Skill tool
    rec(isMeta=True, turnCompanion=True,
        message={"role": "user", "content": [{"type": "text",
                 "text": "Each entry says what goes wrong AND why, not just the prohibition."}]}),
    # a tool result
    rec(toolUseResult={"stdout": "x"},
        message={"role": "user", "content": [{"type": "text", "text": "that path is wrong"}]}),
    # a !command shell escape and its output
    rec(message=msg("<bash-input>grep wrong ./notes</bash-input>")),
    rec(message=msg("<bash-stdout>don't use the old flag</bash-stdout>")),
    # a harness task notification
    rec(promptSource="system", origin={"kind": "task-notification"},
        message=msg("<task-notification>agent said the approach was wrong</task-notification>")),
    # an SDK-driven prompt — input, but not this person correcting anything
    rec(promptSource="sdk", message=msg("stop doing that")),
    # the only human turn
    rec(promptSource="typed", origin={"kind": "human"},
        message=msg("no, don't refactor the parser — I already told you")),
]
with open(sys.argv[1], "w") as fh:
    for r in rows:
        fh.write(json.dumps(r) + "\n")
PY

# The scanner locates transcripts by an encoded project path; point it at ours.
encoded=$(python3 -c "print('${proj}'.replace('/', '-'))")
store="${tmpdir}/home/.claude/projects/${encoded}"
mkdir -p "${store}"
cp "${tmpdir}/t.jsonl" "${store}/"

out=$(cd "${proj}" && HOME="${tmpdir}/home" python3 "${SCANNER}" --days 3650 --limit 10 2>/dev/null) \
    || fail "scanner exited non-zero"

count=$(printf '%s' "${out}" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["user_corrections"]))') \
    || fail "scanner output was not JSON"

[[ "${count}" == "1" ]] || fail "expected 1 correction from 7 phrase-bearing records, got ${count}"

printf '%s' "${out}" | grep -q "already told" \
    || fail "the one human correction is missing — the filter dropped a real turn"
printf '%s' "${out}" | grep -qi "goes wrong AND why" \
    && fail "a skill body was scanned as if the user had typed it"
printf '%s' "${out}" | grep -q "bash-input\|bash-stdout" \
    && fail "a shell escape was scanned as user prose"
printf '%s' "${out}" | grep -q "task-notification" \
    && fail "a task notification was scanned as user prose"

echo "PASS: retrospective_user_turns_test — only the human turn is scanned"
