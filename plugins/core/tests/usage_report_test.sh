#!/usr/bin/env bash
# usage_report_test.sh — the retrospective half of the token story.
#
# budget_check.sh answers "may I dispatch?" from a percentage. This script
# answers "where did the window go?" from the transcripts, and the day that
# produced it had nine sessions read 438M tokens while every visible setting
# read as correct. So the tests here are mostly about the ways such a report can
# be confidently wrong:
#
#   * counting only the orchestrator, because a dispatched subagent's turns live
#     a directory deeper than a flat `*/*.jsonl` glob reaches;
#   * counting a resumed session's history twice, because forking copies it;
#   * counting output when the thing that costs money is context.
#
# Each of those produces a plausible number, which is what makes them worth
# pinning: nobody re-derives a report that looks fine.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="${SCRIPT_DIR}/../skills/init/assets/scripts/usage_report.py"

[[ -f "${REPORT}" ]] || { echo "SKIP: usage_report.py not found at ${REPORT}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

proj="${tmp}/projects/-home-user-demo"
mkdir -p "${proj}/sess-a/subagents"

# One orchestrator turn: 10 input + 90 cache read + 100 cache creation = 200 ctx.
cat > "${proj}/sess-a.jsonl" <<'JSONL'
{"type":"user","uuid":"u1","sessionId":"sess-a","timestamp":"2026-09-14T10:05:00.000Z"}
{"type":"assistant","uuid":"a1","sessionId":"sess-a","isSidechain":false,"timestamp":"2026-09-14T10:05:01.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":10,"cache_read_input_tokens":90,"cache_creation_input_tokens":100,"output_tokens":7}}}
{"type":"assistant","uuid":"a2","sessionId":"sess-a","isSidechain":false,"timestamp":"2026-09-15T11:00:00.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":0,"cache_read_input_tokens":40,"cache_creation_input_tokens":0,"output_tokens":3}}}
JSONL

# A dispatched worker, one level deeper, carrying the PARENT's sessionId.
cat > "${proj}/sess-a/subagents/agent-x.jsonl" <<'JSONL'
{"type":"assistant","uuid":"s1","sessionId":"sess-a","isSidechain":true,"timestamp":"2026-09-14T10:06:00.000Z","message":{"model":"claude-sonnet-5","usage":{"input_tokens":5,"cache_read_input_tokens":45,"cache_creation_input_tokens":0,"output_tokens":2}}}
JSONL

run() { python3 "${REPORT}" --projects-dir "${tmp}/projects" "$@"; }

# --- the dispatched half is counted at all ---
# This is the regression that matters most: a flat glob reports the orchestrator
# only, which is both the cheap half and the half nobody was asking about.
out=$(run --json) || fail "report should exit 0"
turns=$(python3 -c "import json,sys;print(json.load(sys.stdin)['total']['turns'])" <<<"${out}")
[[ "${turns}" == "3" ]] || fail "expected 3 turns including the subagent's, got ${turns}"
side=$(python3 -c "import json,sys;print(json.load(sys.stdin)['sidechain']['turns'])" <<<"${out}")
[[ "${side}" == "1" ]] || fail "expected 1 dispatched turn, got ${side}"
grep -q "claude-sonnet-5" <<<"$(run)" || fail "the worker's model must appear in the model table"
echo "PASS: subagent turns nested under <session>/subagents are counted and named"

# --- context is input + cache read + cache creation, not output ---
ctx=$(python3 -c "import json,sys;print(json.load(sys.stdin)['by_model']['claude-opus-5']['context'])" <<<"${out}")
[[ "${ctx}" == "240" ]] || fail "opus context should be 200+40=240, got ${ctx}"
echo "PASS: context counts everything handed to the model, output counted apart"

# --- a fork does not double the bill ---
# Resuming copies prior turns verbatim into a second transcript. Without a dedupe
# on uuid the same expensive day reports twice and reads as a worse day.
cp "${proj}/sess-a.jsonl" "${proj}/sess-a-resumed.jsonl"
turns=$(run --json | python3 -c "import json,sys;print(json.load(sys.stdin)['total']['turns'])")
[[ "${turns}" == "3" ]] || fail "a copied transcript must not be counted twice, got ${turns}"
echo "PASS: duplicate uuids across transcripts are counted once"

# --- date bounds ---
turns=$(run --since 2026-09-14 --until 2026-09-14 --json \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['total']['turns'])")
[[ "${turns}" == "2" ]] || fail "one-day window should hold 2 turns, got ${turns}"
echo "PASS: --since/--until bound the window inclusively"

# --- peak hour names the busiest hour, and the sessions live in it ---
peak=$(run --json | python3 -c "import json,sys;print(json.load(sys.stdin)['peak_hour'])")
[[ "${peak}" == "2026-09-14T10:00Z" ]] || fail "peak hour should be 2026-09-14T10:00Z, got ${peak}"
echo "PASS: peak hour is reported in UTC"

# --- a turn that cannot prove it is in the window is not counted against it ---
cat > "${proj}/sess-b.jsonl" <<'JSONL'
{"type":"assistant","uuid":"b1","sessionId":"sess-b","timestamp":"not-a-date","message":{"model":"claude-opus-5","usage":{"input_tokens":999,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":1}}}
JSONL
bounded=$(run --since 2026-09-14 --json | python3 -c "import json,sys;print(json.load(sys.stdin)['total']['turns'])")
[[ "${bounded}" == "3" ]] || fail "an undateable turn must stay out of a bounded report, got ${bounded}"
unbounded=$(run --json | python3 -c "import json,sys;print(json.load(sys.stdin)['total']['turns'])")
[[ "${unbounded}" == "4" ]] || fail "an undateable turn still belongs in an unbounded report"
echo "PASS: undateable turns are kept out of bounded windows, not dropped entirely"

# --- malformed input degrades, it does not abort ---
printf 'not json at all\n{"type":"assistant"}\n{"type":"assistant","message":{"usage":"nope"}}\n' \
    > "${proj}/sess-c.jsonl"
run >/dev/null 2>&1 || fail "a malformed transcript must not abort the whole report"
echo "PASS: unparseable lines are skipped"

# --- a missing directory is an error, not an empty report ---
python3 "${REPORT}" --projects-dir "${tmp}/nope" >/dev/null 2>&1
[[ "$?" == "2" ]] || fail "a missing projects dir should exit 2"
echo "PASS: missing projects directory exits 2"

echo "PASS: usage_report_test — per-session, per-model, and the dispatched half"
exit 0
