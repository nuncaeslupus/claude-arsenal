#!/usr/bin/env bash
# review_sources_test.sh — what CI and the review bots did, and what that leaves
# for the local review to do.
#
# One PR ran eight review rounds because a bot that never reviewed it kept the
# loop at `waiting`: the bot had posted a skip notice (or nothing), the loop read
# silence as "not yet", and every tick paid for another look. These cases pin the
# classifier to the evidence — a notice is a state, silence has a deadline, a
# trigger is sent once — and pin decide() to the verification table.
#
# Data comes from --fixture (the gh JSON as files); posting goes through a fake
# `gh` on PATH that logs its arguments. Time is pinned with REVIEW_SOURCES_NOW.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RS="${SCRIPT_DIR}/../skills/init/assets/scripts/review_sources.py"
QPS="${SCRIPT_DIR}/../skills/github/scripts/query_pr_state.py"
[[ -f "${RS}" ]] || { echo "FAIL: review_sources.py not found at ${RS}" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

HEAD=1111111111111111111111111111111111111111
NEW=3333333333333333333333333333333333333333
PUSH="2026-10-01T10:00:00Z"
at() { python3 -c "import datetime,sys;t=datetime.datetime(2026,10,1,10,0,tzinfo=datetime.UTC)+datetime.timedelta(minutes=int(sys.argv[1]));print(t.strftime('%Y-%m-%dT%H:%M:%SZ'))" "$1"; }

# --- a fake gh: serves the fixture for reads, logs every write ---------------
mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/gh" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "${GH_LOG}"
fx="${GH_FIXTURE}"
case "$*" in
  "pr comment"*|*requested_reviewers*) exit 0 ;;
  "repo view"*) echo '{"nameWithOwner":"acme/app"}' ;;
  "pr view"*) cat "${fx}/pr_view.json" ;;
  *"/reactions"*) echo '[]' ;;
  *"/check-runs"*) cat "${fx}/check_runs.json" 2>/dev/null || echo '[]' ;;
  *"/statuses"*) cat "${fx}/statuses.json" 2>/dev/null || echo '[]' ;;
  *"/commits/"*) cat "${fx}/commit.json" ;;
  *"issues/7/comments"*) cat "${fx}/issue_comments.json" 2>/dev/null || echo '[]' ;;
  *"pulls/7/comments"*) cat "${fx}/review_comments.json" 2>/dev/null || echo '[]' ;;
  *"pulls/7/reviews"*) cat "${fx}/reviews.json" 2>/dev/null || echo '[]' ;;
  *"pulls/7/files"*) cat "${fx}/files.json" 2>/dev/null || echo '[]' ;;
  *"pulls/7"*) cat "${fx}/pr.json" ;;
  *) echo "fake gh: unhandled $*" >&2; exit 1 ;;
esac
SH
chmod +x "${tmp}/bin/gh"
export PATH="${tmp}/bin:${PATH}" GH_LOG="${tmp}/gh.log"
: > "${GH_LOG}"

# fixture <dir> <head-sha>: a PR with green CI, one small code file, no bot activity.
fixture() {
    local d="$1" sha="$2"
    rm -rf "${d}"; mkdir -p "${d}"
    cat > "${d}/pr.json" <<JSON
{"number":7,"head":{"sha":"${sha}","ref":"feat/x"},"requested_reviewers":[]}
JSON
    cat > "${d}/commit.json" <<JSON
{"sha":"${sha}","commit":{"committer":{"date":"${PUSH}"}}}
JSON
    cat > "${d}/check_runs.json" <<JSON
[{"name":"test","status":"completed","conclusion":"success","head_sha":"${sha}",
  "started_at":"${PUSH}","app":{"slug":"github-actions"}}]
JSON
    echo '[]' > "${d}/statuses.json"
    echo '[]' > "${d}/reviews.json"
    echo '[]' > "${d}/review_comments.json"
    echo '[]' > "${d}/issue_comments.json"
    cat > "${d}/files.json" <<'JSON'
[{"filename":"src/app.py","additions":10,"deletions":2,"changes":12}]
JSON
    cat > "${d}/pr_view.json" <<JSON
{"state":"OPEN","mergeable":"MERGEABLE","headRefOid":"${sha}",
 "statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}],
 "reviews":[],"commits":[{"committedDate":"${PUSH}"}]}
JSON
}

# A consumer-shaped repo root: config, and where trigger state is written.
repo="${tmp}/repo"; mkdir -p "${repo}/arsenal"
config() { printf '%s\n' "$@" > "${repo}/arsenal/config.toml"; }
config 'review-bots = ["coderabbitai[bot]"]'

rs() {  # rs <fixture-dir> <minutes-after-push> [args...]
    local d="$1" m="$2"; shift 2
    (cd "${repo}" && GH_FIXTURE="${d}" REVIEW_SOURCES_NOW="$(at "${m}")" \
        python3 "${RS}" --pr 7 --fixture "${d}" "$@")
}
line() { grep -E "^$1[[:space:]]" | head -1; }

# --- test_classify_skip_notice_returns_skipped -------------------------------
# The status is SUCCESS; the description is the notice. Read the description.
fx="${tmp}/fx-skip"; fixture "${fx}" "${HEAD}"
cat > "${fx}/statuses.json" <<JSON
[{"context":"CodeRabbit","state":"success","created_at":"$(at 1)",
  "description":"Review skipped: manual review required for this OSS repository",
  "creator":{"login":"coderabbitai[bot]"}}]
JSON
out=$(rs "${fx}" 5) || fail "skip fixture: exit $?"
line "bot:coderabbitai" <<<"${out}" | grep -q "skipped" \
    || fail "a SUCCESS status saying 'Review skipped' must classify skipped:
${out}"
line "ci" <<<"${out}" | grep -q " ok " || fail "the bot's own status is not CI:
${out}"
# ...and the same notice arriving as an EDIT of an older summary comment.
fx2="${tmp}/fx-skip-edit"; fixture "${fx2}" "${HEAD}"
cat > "${fx2}/issue_comments.json" <<JSON
[{"id":5929979667,"user":{"login":"coderabbitai[bot]"},"created_at":"2026-09-30T08:00:00Z",
  "updated_at":"$(at 2)","body":"<!-- summary -->\nThis repository does not receive automatic reviews."}]
JSON
out=$(rs "${fx2}" 5) || fail "edited-comment fixture: exit $?"
line "bot:coderabbitai" <<<"${out}" | grep -q 'skipped .*5929979667' \
    || fail "an edited summary comment carrying a skip notice must classify skipped:
${out}"
echo "PASS: test_classify_skip_notice_returns_skipped"

# --- test_classify_in_progress_is_pending_then_bounded --------------------------
# A summary comment rewritten to "review in progress" is pending, on the same
# clock as silence: still in progress past bot-wait-min ends as absent.
fx="${tmp}/fx-progress"; fixture "${fx}" "${HEAD}"
cat > "${fx}/issue_comments.json" <<JSON
[{"id":7,"user":{"login":"coderabbitai[bot]"},"created_at":"2026-09-30T08:00:00Z",
  "updated_at":"$(at 2)","body":"<!-- This is an auto-generated comment: review in progress by coderabbit.ai -->\nCurrently processing new changes in this PR."}]
JSON
out=$(rs "${fx}" 5) || fail "in-progress fixture: exit $?"
line "bot:coderabbitai" <<<"${out}" | grep -q "pending" \
    || fail "a review-in-progress summary must classify pending:
${out}"
out=$(rs "${fx}" 40) || fail "stale in-progress fixture: exit $?"
line "bot:coderabbitai" <<<"${out}" | grep -q "absent" \
    || fail "in progress past bot-wait-min must end as absent:
${out}"
echo "PASS: test_classify_in_progress_is_pending_then_bounded"

# --- test_classify_rate_limit_returns_rate_limited ---------------------------
config 'review-bots = ["gemini-code-assist[bot]"]'
fx="${tmp}/fx-limit"; fixture "${fx}" "${HEAD}"
cat > "${fx}/issue_comments.json" <<JSON
[{"id":42,"user":{"login":"gemini-code-assist[bot]"},"created_at":"$(at 3)",
  "updated_at":"$(at 3)","body":"You have reached your daily quota limit. Please try again later."}]
JSON
out=$(rs "${fx}" 5) || fail "rate-limit fixture: exit $?"
line "bot:gemini-code-assist" <<<"${out}" | grep -q "rate-limited" \
    || fail "a quota notice must classify rate-limited:
${out}"
# A review on an OLDER head is not a review of this one (gemini does not re-review on push).
fx="${tmp}/fx-old-review"; fixture "${fx}" "${NEW}"
cat > "${fx}/reviews.json" <<JSON
[{"id":9,"user":{"login":"gemini-code-assist[bot]"},"state":"COMMENTED",
  "commit_id":"${HEAD}","submitted_at":"2026-09-30T09:00:00Z","body":"looks fine"}]
JSON
out=$(rs "${fx}" 5) || fail "old-review fixture: exit $?"
line "bot:gemini-code-assist" <<<"${out}" | grep -q " ok " \
    && fail "a review of an older head must not count as ok for this head:
${out}"
echo "PASS: test_classify_rate_limit_returns_rate_limited"

# --- test_classify_silence_past_wait_returns_absent --------------------------
config 'review-bots = ["coderabbitai[bot]"]' 'bot-wait-min = 20'
fx="${tmp}/fx-silent"; fixture "${fx}" "${HEAD}"
out=$(rs "${fx}" 10) || fail "silent fixture: exit $?"
line "bot:coderabbitai" <<<"${out}" | grep -q "pending" \
    || fail "10 min of silence under a 20 min wait is still pending:
${out}"
out=$(rs "${fx}" 25) || fail "silent fixture: exit $?"
line "bot:coderabbitai" <<<"${out}" | grep -q "absent" \
    || fail "25 min of silence under a 20 min wait must be absent:
${out}"
# A bot check that finished neutral with no output is a timeout, not a review.
config 'review-bots = ["claude[bot]"]' 'bot-wait-min = 20'
fx="${tmp}/fx-neutral"; fixture "${fx}" "${HEAD}"
cat > "${fx}/check_runs.json" <<JSON
[{"name":"test","status":"completed","conclusion":"success","head_sha":"${HEAD}","started_at":"${PUSH}"},
 {"name":"Claude Code Review","status":"completed","conclusion":"neutral","head_sha":"${HEAD}",
  "started_at":"${PUSH}","app":{"slug":"claude"},"output":{"title":null,"summary":null}}]
JSON
out=$(rs "${fx}" 5) || fail "neutral fixture: exit $?"
line "bot:claude" <<<"${out}" | grep -q "absent" \
    || fail "a neutral bot check with no output must classify absent:
${out}"
echo "PASS: test_classify_silence_past_wait_returns_absent"

# --- test_decide_ci_ok_bot_ok_low_risk_returns_none --------------------------
got=$(python3 -c "
import sys; sys.path.insert(0, '$(dirname "${RS}")')
import review_sources as r
print(*r.decide('balanced', 'ok', ['ok'], False, False)[:2])")
[[ "${got}" == "none skip" ]] || fail "balanced, CI ok, bot ok, low risk → none/skip, got '${got}'"
got=$(python3 -c "
import sys; sys.path.insert(0, '$(dirname "${RS}")')
import review_sources as r
print(*r.decide('balanced', 'ok', ['absent'], False, False)[:2])")
[[ "${got}" == "diff skip" ]] || fail "balanced, CI ok, no bot ok → diff/skip, got '${got}'"
got=$(python3 -c "
import sys; sys.path.insert(0, '$(dirname "${RS}")')
import review_sources as r
print(*r.decide('balanced', 'absent', ['ok'], True, False)[:2])")
[[ "${got}" == "full run" ]] || fail "balanced, CI absent, high risk → full/run, got '${got}'"
# End to end: a review on this head plus green CI.
config 'review-bots = ["coderabbitai[bot]"]'
fx="${tmp}/fx-ok"; fixture "${fx}" "${HEAD}"
cat > "${fx}/reviews.json" <<JSON
[{"id":10,"user":{"login":"coderabbitai[bot]"},"state":"COMMENTED",
  "commit_id":"${HEAD}","submitted_at":"$(at 4)","body":"Actionable comments posted: 0"}]
JSON
out=$(rs "${fx}" 5) || fail "ok fixture: exit $?"
line "decision" <<<"${out}" | grep -q "local-review=none  full-suite=skip" \
    || fail "CI ok + bot reviewed this head + small diff must decide none/skip:
${out}"
echo "PASS: test_decide_ci_ok_bot_ok_low_risk_returns_none"

# --- test_trigger_posts_once_per_head ----------------------------------------
config 'review-bots = ["coderabbitai[bot]"]' 'bot-triggers = ["coderabbitai[bot]=@coderabbitai review"]'
fx="${tmp}/fx-skip"  # the skipped-status fixture from above, head ${HEAD}
: > "${GH_LOG}"
rs "${fx}" 5 --trigger >/dev/null || fail "first --trigger run failed"
rs "${fx}" 6 --trigger >/dev/null || fail "second --trigger run failed"
n=$(grep -c '^pr comment 7' "${GH_LOG}")
[[ "${n}" -eq 1 ]] || fail "two --trigger runs on one head must post once, posted ${n}:
$(cat "${GH_LOG}")"
grep -q -- '--body @coderabbitai review' "${GH_LOG}" || fail "the configured comment was not posted:
$(cat "${GH_LOG}")"
fx3="${tmp}/fx-skip-new"; fixture "${fx3}" "${NEW}"; cp "${fx}/statuses.json" "${fx3}/"
rs "${fx3}" 5 --trigger >/dev/null || fail "--trigger on a new head failed"
n=$(grep -c '^pr comment 7' "${GH_LOG}")
[[ "${n}" -eq 2 ]] || fail "a new head gets its own trigger, total posted ${n}"
# A bot with no configured trigger is never pinged.
config 'review-bots = ["coderabbitai[bot]"]'
rm -rf "${repo}/tmp"; : > "${GH_LOG}"
rs "${fx}" 5 --trigger >/dev/null || fail "--trigger without a configured comment failed"
grep -q '^pr comment' "${GH_LOG}" && fail "no bot-triggers entry must mean no comment"
# A paused bot gets its resume command, not the review command.
config 'review-bots = ["coderabbitai[bot]"]' 'bot-triggers = ["coderabbitai[bot]=@coderabbitai review"]'
fx4="${tmp}/fx-paused"; fixture "${fx4}" "${HEAD}"
cat > "${fx4}/issue_comments.json" <<JSON
[{"id":77,"user":{"login":"coderabbitai[bot]"},"created_at":"$(at 1)","updated_at":"$(at 1)",
  "body":"<!-- This is an auto-generated comment: review paused by coderabbit.ai -->\n## Reviews paused"}]
JSON
rm -rf "${repo}/tmp"; : > "${GH_LOG}"
rs "${fx4}" 5 --trigger >/dev/null || fail "--trigger on a paused bot failed"
grep -q -- '--body @coderabbitai resume' "${GH_LOG}" || fail "a paused bot must get its resume command:
$(cat "${GH_LOG}")"
echo "PASS: test_trigger_posts_once_per_head"

# --- test_silent_bot_after_wait_is_not_waiting -------------------------------
# query_pr_state.py: a bot that never answers ends the wait instead of holding
# the loop at `waiting` forever.
qps() {  # qps <fixture-dir> <minutes-after-push> [args...]
    local d="$1" m="$2"; shift 2
    (cd "${repo}" && GH_FIXTURE="${d}" REVIEW_SOURCES_NOW="$(at "${m}")" \
        python3 "${QPS}" --pr 7 --repo acme/app "$@")
}
jget() { python3 -c "import json,sys;d=json.load(sys.stdin)
for k in sys.argv[1].split('.'): d=d[k]
print(d)" "$1"; }
config 'review-bots = ["coderabbitai[bot]"]' 'bot-wait-min = 20'
rm -rf "${repo}/tmp"
fx="${tmp}/fx-silent"
st=$(qps "${fx}" 10 | jget state)
[[ "${st}" == "waiting" ]] || fail "inside the wait the loop still waits, got ${st}"
out=$(qps "${fx}" 25); code=$?
st=$(jget state <<<"${out}")
[[ "${st}" == "bot_absent" ]] || fail "silent past bot-wait-min must be bot_absent, got ${st}:
${out}"
[[ ${code} -eq 0 ]] || fail "bot_absent is actionable (exit 0), got ${code}"
[[ "$(jget decision.local_review <<<"${out}")" == "diff" ]] \
    || fail "bot_absent with CI ok must ask for a diff review:
${out}"
st=$(qps "${fx}" 25 --local-review-done | jget state)
[[ "${st}" == "ready_to_merge" ]] || fail "a recorded local review clears bot_absent, got ${st}"
echo "PASS: test_silent_bot_after_wait_is_not_waiting"

# --- test_incident_replay_bounded (bot half) ---------------------------------
# Silent bot with a trigger configured: wait → one trigger → wait → absent, and
# the decision is one diff review — not another tick of `waiting`.
config 'review-bots = ["coderabbitai[bot]"]' 'bot-wait-min = 20' \
       'bot-triggers = ["coderabbitai[bot]=@coderabbitai review"]'
rm -rf "${repo}/tmp"; : > "${GH_LOG}"
st=$(qps "${fx}" 25 --trigger | jget state)
[[ "${st}" == "waiting" ]] || fail "right after the trigger the bot gets one more wait, got ${st}"
[[ $(grep -c '^pr comment 7' "${GH_LOG}") -eq 1 ]] || fail "the first absence sends the trigger once"
st=$(qps "${fx}" 35 --trigger | jget state)
[[ "${st}" == "waiting" ]] || fail "10 min after the trigger is still inside the wait, got ${st}"
out=$(qps "${fx}" 46 --trigger)
[[ "$(jget state <<<"${out}")" == "bot_absent" ]] \
    || fail "silence past wait + trigger + wait must be bot_absent:
${out}"
[[ "$(jget decision.local_review <<<"${out}")" == "diff" ]] || fail "decision must be diff"
[[ $(grep -c '^pr comment 7' "${GH_LOG}") -eq 1 ]] || fail "the trigger is sent once, not per tick"
echo "PASS: test_incident_replay_bounded (bot wait ends)"

echo "PASS: review_sources_test — all gates passed"
