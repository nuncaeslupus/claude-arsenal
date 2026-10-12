#!/usr/bin/env bash
# review_marker_test.sh — a second reader on the PR author's own login (#495).
#
# GitHub will not let a PR's author approve it, so in a fleet where every
# session posts with one credential the second reader can only leave a comment.
# `adversarial_review.sh marker` writes that comment from a fresh receipt;
# `pr_audit.py` (behind merge_ready.sh) reads it under `[review]
# reviewer-identity`:
#
#   * distinct-login (the default): a CLEAR from the author's login never
#     clears — and a repo that sets nothing sees exactly what it saw before,
#     because a PR with no marker reads as it always did;
#   * distinct-session: it clears when its session is none of the PR's
#     Claude-Session trailers, and is `unresolvable` — never clear — when the
#     session is missing, matches an implementer, or there is nothing to compare;
#   * a BLOCK on the head blocks under either value;
#   * an unknown value exits 2 rather than reading as the default.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
AUDIT="${ASSETS}/scripts/pr_audit.py"
REVIEW="${ASSETS}/bin/adversarial_review.sh"
CFG="${ASSETS}/scripts/arsenal_config.py"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

HEAD=1111111111111111111111111111111111111111
IMPL="https://claude.ai/code/session_01Implementer"

# --- pr_audit: the reader --------------------------------------------------
mkdir -p "${tmp}/root/arsenal"
identity() { printf '[review]\nreviewer-identity = "%s"\n' "$1" > "${tmp}/root/arsenal/config.toml"; }
COMMITS='[{"message":"feat: x\n\nClaude-Session: '"${IMPL}"'"}]'
# pr <comments-json> [commits-json] — green CI, no GitHub review, author `owner`.
pr() {
    cat > "${tmp}/prs.json" <<JSON
[{"number":7,"title":"T","head":{"sha":"${HEAD}","ref":"arsenal/task/T"},
  "user":{"login":"owner"},
  "checks":[{"name":"ci","status":"completed","conclusion":"success","head_sha":"${HEAD}"}],
  "reviews":[],"threads":[],
  "comments":$1,
  "commits":${2:-${COMMITS}}}]
JSON
}
marker() {  # marker <login> <association> <verdict> [session]
    local session=""
    [[ -n "${4:-}" ]] && session=" session=$4"
    printf '{"id":1,"author_association":"%s","user":{"login":"%s","type":"User"},"body":"<!-- arsenal-review: verdict=%s head=%s%s -->\\nAdversarial review"}' \
        "$2" "$1" "$3" "${HEAD}" "${session}"
}
audit() { python3 "${AUDIT}" --repo-root "${tmp}/root" --prs "${tmp}/prs.json" --policy after-ci-and-review "$@"; }
field() { python3 -c "import json,sys;print(json.load(sys.stdin)['prs'][0][sys.argv[1]])" "$1"; }

# Unset key: a PR with no marker reads exactly as before.
rm -f "${tmp}/root/arsenal/config.toml"
pr '[]'
[[ "$(audit --json | field review)" == "absent" ]] || fail "no marker, no review must stay absent"
audit --require-ready >/dev/null; [[ $? -eq 1 ]] || fail "no review must not be ready under after-ci-and-review"
echo "PASS: a PR without markers is judged as before"

# distinct-login (default): the author's own CLEAR never clears; another login's does.
pr "[$(marker owner OWNER CLEAR session_01Reviewer)]"
[[ "$(audit --json | field review)" == "unresolvable" ]] \
    || fail "under distinct-login a CLEAR from the author's login must not clear"
audit --json | field review_detail | grep -q "distinct-login" || fail "the refusal should name the rule"
pr "[$(marker second-reader COLLABORATOR CLEAR)]"
[[ "$(audit --json | field review)" == "clear" ]] || fail "a CLEAR from another trusted login must clear"
audit --require-ready >/dev/null || fail "green CI + a distinct reader's CLEAR must be ready"
# after-ci-and-review (#507): the adversarial CLEAR stands in for the review,
# never for CI — a red head stays blocked.
sed -i.bak 's/"conclusion":"success"/"conclusion":"failure"/' "${tmp}/prs.json"
audit --require-ready >/dev/null; [[ $? -eq 1 ]] || fail "a CLEAR marker must not stand in for green CI"
pr "[$(marker passer-by NONE CLEAR)]"
[[ "$(audit --json | field review)" == "absent" ]] || fail "a marker from an untrusted commenter must be ignored"
echo "PASS: distinct-login — the author cannot clear their own PR; another trusted login can"

# distinct-session.
identity distinct-session
pr "[$(marker owner OWNER CLEAR session_01Reviewer)]"
[[ "$(audit --json | field review)" == "clear" ]] \
    || fail "a CLEAR from the author's login with a distinct session must clear"
audit --json | field review_detail | grep -q "cleared via reviewer-identity distinct-session" \
    || fail "a head cleared via distinct-session must say so in its reason"
audit --require-ready >/dev/null || fail "...and the PR is then ready"

pr "[$(marker owner OWNER CLEAR)]"
[[ "$(audit --json | field review)" == "unresolvable" ]] || fail "a marker with no session must not clear"
pr "[$(marker owner OWNER CLEAR 01Implementer)]"
[[ "$(audit --json | field review)" == "unresolvable" ]] \
    || fail "a session equal to an implementer's (any spelling) must not clear"
pr "[$(marker owner OWNER CLEAR session_01Reviewer)]" '[{"message":"feat: no trailer"}]'
[[ "$(audit --json | field review)" == "unresolvable" ]] \
    || fail "with no implementer session to compare against, nothing can be shown to differ"
audit --require-ready >/dev/null; [[ $? -eq 1 ]] || fail "unresolvable must not be ready"

pr "[$(marker owner OWNER BLOCK session_01Reviewer)]"
[[ "$(audit --json | field review)" == "blocked" ]] || fail "a BLOCK from the same login must still block"
identity distinct-login
[[ "$(audit --json | field review)" == "blocked" ]] || fail "a BLOCK blocks under distinct-login too"
echo "PASS: distinct-session — clears only on a provably different session; BLOCK always blocks"

# A marker never outranks an open thread, and is about the head it names.
identity distinct-session
cat > "${tmp}/prs.json" <<JSON
[{"number":7,"title":"T","head":{"sha":"${HEAD}"},"user":{"login":"owner"},
  "checks":[],"reviews":[],"threads":[{"id":"t","resolved":false}],
  "comments":[$(marker owner OWNER CLEAR session_01Reviewer)],
  "commits":[{"message":"x\\n\\nClaude-Session: ${IMPL}"}]}]
JSON
[[ "$(audit --json | field review)" == "unresolved" ]] || fail "an open thread must beat a CLEAR marker"
sed -i.bak -e "s/head=${HEAD}/head=2222222/" -e 's/"threads":\[[^]]*\]/"threads":[]/' "${tmp}/prs.json"
[[ "$(audit --json | field review)" == "absent" ]] || fail "a marker for another head must not count"
echo "PASS: open threads and other heads are not cleared by a marker"

# Unknown value: exit 2 from both readers, never the default.
identity distinct-person
python3 "${AUDIT}" --repo-root "${tmp}/root" --prs "${tmp}/prs.json" >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "pr_audit must exit 2 on an unknown reviewer-identity"
(cd "${tmp}/root" && python3 "${CFG}" --get review.reviewer-identity >/dev/null 2>&1)
[[ $? -eq 2 ]] || fail "arsenal_config must exit 2 on an unknown reviewer-identity"
rm -f "${tmp}/root/arsenal/config.toml"
[[ "$(cd "${tmp}/root" && python3 "${CFG}" --get review.reviewer-identity)" == "distinct-login" ]] \
    || fail "the default must be distinct-login"
echo "PASS: an unknown reviewer-identity exits 2"

# --- adversarial_review.sh marker: the writer --------------------------------
REPO="${tmp}/repo"
mkdir -p "${REPO}"
cd "${REPO}" || exit 1
git init -q -b main .
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
echo "a" > app.txt; git add -A; git commit -qm init
git checkout -q -b feat
echo "b" >> app.txt
bash "${REVIEW}" emit --base main >/dev/null 2>&1 || fail "emit failed"
printf 'VERDICT: CLEAR — fine\n' > tmp/arsenal-review/verdict.md
bash "${REVIEW}" verdict >/dev/null 2>&1 || fail "verdict failed"

bash "${REVIEW}" marker >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "marker must refuse while the reviewed tree is uncommitted (it names HEAD)"
git commit -qam "the reviewed change"
out=$(CLAUDE_CODE_REMOTE_SESSION_ID=session_01Reviewer bash "${REVIEW}" marker 2>/dev/null) \
    || fail "marker on a committed, fresh CLEAR must exit 0"
grep -q "<!-- arsenal-review: verdict=CLEAR head=$(git rev-parse HEAD) session=session_01Reviewer -->" <<<"${out}" \
    || fail "the marker must carry verdict, the full HEAD sha and the session: ${out}"
out=$(env -u CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_SESSION_ID=local-7 bash "${REVIEW}" marker 2>/dev/null)
grep -q "session=local-7 -->" <<<"${out}" || fail "CLAUDE_CODE_SESSION_ID is the fallback: ${out}"
out=$(env -u CLAUDE_CODE_REMOTE_SESSION_ID -u CLAUDE_CODE_SESSION_ID bash "${REVIEW}" marker 2>/dev/null)
grep -q "session=" <<<"${out}" && fail "no session in the environment must mean no session field: ${out}"

# The marker the writer prints is one the reader accepts.
body=$(CLAUDE_CODE_REMOTE_SESSION_ID=session_01Reviewer bash "${REVIEW}" marker 2>/dev/null)
python3 - "${body}" "$(git rev-parse HEAD)" "${tmp}/prs.json" "${IMPL}" <<'PY'
import json, sys
body, head, path, impl = sys.argv[1:]
json.dump([{"number": 7, "title": "T", "head": {"sha": head}, "user": {"login": "owner"},
            "checks": [], "reviews": [], "threads": [],
            "comments": [{"id": 9, "author_association": "OWNER",
                          "user": {"login": "owner", "type": "User"}, "body": body}],
            "commits": [{"message": f"x\n\nClaude-Session: {impl}"}]}], open(path, "w"))
PY
identity distinct-session
[[ "$(audit --json | field review)" == "clear" ]] || fail "the reader must accept what the writer emits"

echo "c" >> app.txt; git commit -qam "edited after the review"
bash "${REVIEW}" marker >/dev/null 2>&1
[[ $? -eq 3 ]] || fail "a receipt for an earlier tree is stale (exit 3), not publishable"
echo "PASS: marker — fresh, committed, full sha, session from the environment"

echo "PASS: review_marker_test — a same-login reviewer clears only as a distinct session"
