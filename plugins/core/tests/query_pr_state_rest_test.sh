#!/usr/bin/env bash
# query_pr_state_rest_test.sh — the REST fallback when GitHub GraphQL is refused.
#
# Cloud sessions get a 403 on every GraphQL call, which made query_pr_state.py
# exit 2 before reading anything, so the review loop never ran there. These
# cases pin the fallback: a 403 builds the same state from REST, and any other
# gh failure still exits 2 instead of silently switching paths.
#
# A fake `gh` on PATH refuses GraphQL and serves canned REST JSON.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QPS="${SCRIPT_DIR}/../skills/github/scripts/query_pr_state.py"
[[ -f "${QPS}" ]] || { echo "FAIL: query_pr_state.py not found at ${QPS}" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
mkdir -p "${tmp}/bin"

cat > "${tmp}/bin/gh" <<'SH'
#!/usr/bin/env bash
mode="${GH_MODE:-graphql403}"
if [[ "$1" != "api" || "$2" == "graphql" ]]; then
    if [[ "${mode}" == "graphql403" ]]; then
        echo "HTTP 403: GitHub GraphQL is not available (https://api.github.com/graphql)" >&2
    else
        echo "HTTP 502: Bad Gateway" >&2
    fi
    exit 1
fi
[[ "$2" == "--paginate" ]] && shift
case "$2" in
  */pulls/7) echo '{"state":"open","merged_at":null,"closed_at":null,"mergeable":false,"head":{"sha":"abc"}}' ;;
  */pulls/7/commits) echo '[{"commit":{"committer":{"date":"2026-10-01T10:00:00Z"}}}]' ;;
  */commits/abc/check-runs) echo '{"check_runs":[{"status":"completed","conclusion":"success"}]}' ;;
  */commits/abc/status) echo '{"statuses":[]}' ;;
  */pulls/7/reviews) echo '[]' ;;
  */pulls/7/comments) echo '[{"id":1,"user":{"login":"bot[bot]","type":"Bot"},"created_at":"2026-10-01T10:01:00Z","body":"x"},{"id":2,"in_reply_to_id":1,"user":{"login":"me","type":"User"},"created_at":"2026-10-01T10:02:00Z","body":"addressed"}]' ;;
  */issues/7/reactions) echo '[]' ;;
  *) echo '[]' ;;
esac
SH
chmod +x "${tmp}/bin/gh"

run() { PATH="${tmp}/bin:${PATH}" python3 "${QPS}" --pr 7 --repo o/r --watch-bots "" "$@"; }

# 1. GraphQL refused → REST builds the state; the conflict is seen through REST.
out=$(run --unresolved-only); rc=$?
[[ ${rc} -eq 2 ]] || fail "conflicting PR via REST: want exit 2, got ${rc}"
echo "${out}" | grep -q '"state": "conflicts"' || fail "REST fallback did not report conflicts: ${out}"
echo "PASS: GraphQL 403 falls back to REST (state conflicts, CI read from check-runs)"

# 2. A human reply addresses the bot thread rebuilt from REST comments.
python3 - "${QPS}" <<'PY' || fail "REST thread rebuild"
import importlib.util, sys
spec = importlib.util.spec_from_file_location("q", sys.argv[1]); q = importlib.util.module_from_spec(spec); spec.loader.exec_module(q)
c = [{"id": 1, "user": {"type": "Bot"}, "created_at": "1"},
     {"id": 2, "in_reply_to_id": 1, "user": {"type": "User"}, "created_at": "2"},
     {"id": 3, "user": {"type": "Bot"}, "created_at": "3"}]
assert sorted(q._addressed_comment_ids(q._threads_from_rest(c))) == [1, 2]
PY
echo "PASS: human reply marks the REST-rebuilt thread addressed; an unanswered one stays"

# 3. Any other gh failure is permanent, not a reason to switch paths.
GH_MODE=other run >/dev/null 2>&1; rc=$?
[[ ${rc} -eq 2 ]] || fail "non-GraphQL failure: want exit 2, got ${rc}"
echo "PASS: a non-403 failure still exits 2"

echo "PASS: query_pr_state_rest_test — all gates passed"
