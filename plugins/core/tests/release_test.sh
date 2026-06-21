#!/usr/bin/env bash
# release_test.sh — integration test for release.sh on the coordination branch.
# Covers:
#   CA-06: an already-at-target release is an idempotent no-op (exit 0, no new
#          commit), distinct from a real status change (which commits + pushes).
#   CA-03: release refuses to push when non-queue commits sit on the branch, so
#          task code can never leak onto the coordination ledger.
#   CA-11: `merged` is an accepted terminal status.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE="${SCRIPT_DIR}/../skills/init/assets/bin/release.sh"
QUEUE_BRANCH="arsenal-queue"
export ARSENAL_QUEUE_BRANCH="${QUEUE_BRANCH}"

if [[ ! -f "${RELEASE}" ]]; then
    echo "SKIP: release.sh not found at ${RELEASE}" >&2; exit 0
fi

tmpremote=$(mktemp -d)
tmpwork=$(mktemp -d)
cleanup() { rm -rf "${tmpremote}" "${tmpwork}"; }
trap cleanup EXIT

git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD "refs/heads/${QUEUE_BRANCH}"

cd "${tmpwork}"
git init -q -b "${QUEUE_BRANCH}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git remote add origin "${tmpremote}"
mkdir -p claude-arsenal/queue
cat > claude-arsenal/queue/tasks.jsonl <<'QUEUE'
{"id":"lo-r001","title":"Release task","status":"in_progress","priority":0,"requires":[],"deps":[],"assignee":"session-x","payload":"lo-r001.md"}
QUEUE
git add claude-arsenal/queue/tasks.jsonl
git commit -q -m "init: seed queue"
git push -q -u origin "${QUEUE_BRANCH}"

queue_status() {
    python3 -c "
import json,sys
for line in open(sys.argv[1]):
    r=json.loads(line)
    if r['id']==sys.argv[2]: print(r['status'])
" claude-arsenal/queue/tasks.jsonl "$1"
}

remote_tip() { git rev-parse "origin/${QUEUE_BRANCH}"; }

# --- Gate 1: a real status change commits and pushes (done) ---
before=$(remote_tip)
if ! bash "${RELEASE}" lo-r001 done --pr "https://example.com/pr/1" >/dev/null 2>&1; then
    echo "FAIL: release to done should succeed" >&2; exit 1
fi
if [[ "$(queue_status lo-r001)" != "done" ]]; then
    echo "FAIL: status not updated to done" >&2; exit 1
fi
git fetch -q origin "${QUEUE_BRANCH}"
if [[ "$(remote_tip)" == "${before}" ]]; then
    echo "FAIL: a real change should advance the remote ledger" >&2; exit 1
fi
echo "PASS: a status change commits + pushes to the ledger"

# --- Gate 1b (CA-11): refuse `done` from a branch ref or with no PR ---
before=$(remote_tip)
set +e
out=$(bash "${RELEASE}" lo-r001 done --pr "branch:arsenal/lo-r001-x" 2>&1); rc=$?
out2=$(bash "${RELEASE}" lo-r001 done 2>&1); rc2=$?
set -e
if [[ "${rc}" -ne 2 || "${rc2}" -ne 2 ]]; then
    echo "FAIL: done from a branch ref / no PR should exit 2 (got ${rc}/${rc2})" >&2; exit 1
fi
if ! printf '%s' "${out}" | grep -q "refusing to mark"; then
    echo "FAIL: expected 'refusing to mark ... done' refusal, got: ${out}" >&2; exit 1
fi
git fetch -q origin "${QUEUE_BRANCH}"
if [[ "$(remote_tip)" != "${before}" ]]; then
    echo "FAIL: a refused done must not advance the ledger" >&2; exit 1
fi
echo "PASS: refuses to mark done without an opened PR (CA-11)"

# --- Gate 2 (CA-06): re-releasing the same status is an idempotent no-op ---
before=$(remote_tip)
out=$(bash "${RELEASE}" lo-r001 done --pr "https://example.com/pr/1" 2>&1); rc=$?
if [[ "${rc}" -ne 0 ]]; then
    echo "FAIL: idempotent re-release should exit 0, got ${rc}" >&2; exit 1
fi
git fetch -q origin "${QUEUE_BRANCH}"
if [[ "$(remote_tip)" != "${before}" ]]; then
    echo "FAIL: a no-op release must not add a ledger commit" >&2; exit 1
fi
if ! printf '%s' "${out}" | grep -q "already at done"; then
    echo "FAIL: no-op release should report 'already at done', got: ${out}" >&2; exit 1
fi
echo "PASS: re-releasing an unchanged status is a no-op (CA-06)"

# --- Gate 3 (CA-11): merged is an accepted terminal status ---
if ! bash "${RELEASE}" lo-r001 merged --pr "https://example.com/pr/1" >/dev/null 2>&1; then
    echo "FAIL: release to merged should succeed" >&2; exit 1
fi
if [[ "$(queue_status lo-r001)" != "merged" ]]; then
    echo "FAIL: status not updated to merged" >&2; exit 1
fi
echo "PASS: 'merged' is an accepted terminal status (CA-11)"

# --- Gate 4 (CA-03): refuse to push when non-queue commits sit on the branch ---
git fetch -q origin "${QUEUE_BRANCH}"
git reset -q --hard "origin/${QUEUE_BRANCH}"
echo "leaked task code" > leaked.txt
git add leaked.txt
git commit -q -m "feat: task work that must NOT reach the ledger"
before=$(remote_tip)
set +e
out=$(bash "${RELEASE}" lo-r001 open 2>&1); rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
    echo "FAIL: release with extra commits should exit 2, got ${rc}: ${out}" >&2; exit 1
fi
if ! printf '%s' "${out}" | grep -q "refusing to push"; then
    echo "FAIL: expected 'refusing to push' refusal, got: ${out}" >&2; exit 1
fi
git fetch -q origin "${QUEUE_BRANCH}"
if [[ "$(remote_tip)" != "${before}" ]]; then
    echo "FAIL: refused release must not advance the ledger" >&2; exit 1
fi
echo "PASS: refuses to leak non-queue commits onto the ledger (CA-03)"

# --- Gate 5 (CA-15): refuse to stage a payload that contains a secret ---
git fetch -q origin "${QUEUE_BRANCH}"
git reset -q --hard "origin/${QUEUE_BRANCH}"
# AKIAIOSFODNN7EXAMPLE + 16 chars = valid AWS key pattern (well-known example value).
echo "## Failure notes" > "claude-arsenal/queue/lo-r001.md"
echo "token = AKIAIOSFODNN7EXAMPLE" >> "claude-arsenal/queue/lo-r001.md"
before=$(remote_tip)
set +e
out=$(bash "${RELEASE}" lo-r001 open 2>&1); rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
    echo "FAIL: release with secret in payload should exit 2, got ${rc}: ${out}" >&2; exit 1
fi
if ! printf '%s' "${out}" | grep -q "secret detected"; then
    echo "FAIL: expected 'secret detected' in stderr, got: ${out}" >&2; exit 1
fi
git fetch -q origin "${QUEUE_BRANCH}"
if [[ "$(remote_tip)" != "${before}" ]]; then
    echo "FAIL: refused secret-payload release must not advance the ledger" >&2; exit 1
fi
echo "PASS: refuses to stage payload with secret (CA-15)"

# --- Gate 6 (CA-13): refuse `done` for a closed (never-merged) PR ---
git fetch -q origin "${QUEUE_BRANCH}"
git reset -q --hard "origin/${QUEUE_BRANCH}"
# Put task back to in_progress so a `done` transition is valid status-wise.
python3 -c "
import json, sys
rows=[]
for line in open(sys.argv[1]):
    r=json.loads(line)
    if r['id']=='lo-r001': r['status']='in_progress'; r.pop('pr',None)
    rows.append(r)
open(sys.argv[1],'w').writelines(json.dumps(r)+'\n' for r in rows)
" claude-arsenal/queue/tasks.jsonl
git add claude-arsenal/queue/tasks.jsonl
git commit -q -m "test: reset lo-r001 to in_progress for CA-13 gate"
git push -q origin "${QUEUE_BRANCH}"
# Inject a mock gh that reports the PR as CLOSED.
_mock_gh_dir=$(mktemp -d)
cat > "${_mock_gh_dir}/gh" <<'GHEOF'
#!/usr/bin/env bash
# argv: pr view <url> --json state,mergedAt --jq .state
echo "CLOSED"
GHEOF
chmod +x "${_mock_gh_dir}/gh"
before=$(remote_tip)
set +e
out=$(PATH="${_mock_gh_dir}:${PATH}" bash "${RELEASE}" lo-r001 done --pr "https://example.com/pr/closed" 2>&1); rc=$?
set -e
rm -rf "${_mock_gh_dir}"
if [[ "${rc}" -ne 2 ]]; then
    echo "FAIL: done with closed PR should exit 2, got ${rc}: ${out}" >&2; exit 1
fi
if ! printf '%s' "${out}" | grep -q "is closed"; then
    echo "FAIL: expected 'is closed' refusal, got: ${out}" >&2; exit 1
fi
git fetch -q origin "${QUEUE_BRANCH}"
if [[ "$(remote_tip)" != "${before}" ]]; then
    echo "FAIL: refused closed-PR done must not advance the ledger" >&2; exit 1
fi
echo "PASS: refuses to mark done for a closed PR (CA-13)"

echo "PASS: release_test — all gates passed"
exit 0
