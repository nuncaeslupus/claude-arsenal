#!/usr/bin/env bash
# claim_contention.sh — integration test for optimistic git-push concurrency.
# Two parts:
#   1. When two sessions race to claim the same task on the shared coordination
#      branch, exactly one wins ("won") and the other loses ("lost").
#   2. A session whose HEAD is NOT the coordination branch fails loud
#      ("error", exit 2) instead of silently looking like a lost race.
#
# Usage: bash tests/claim_contention.sh
# Exit : 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAIM="${SCRIPT_DIR}/../skills/init/assets/bin/claim.sh"
QUEUE_BRANCH="arsenal-queue"
export ARSENAL_QUEUE_BRANCH="${QUEUE_BRANCH}"

if [[ ! -f "${CLAIM}" ]]; then
    echo "SKIP: claim.sh not found at ${CLAIM}" >&2
    exit 0
fi

# -- Create a bare "remote" whose default branch is the coordination branch --
tmpremote=$(mktemp -d)
git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD "refs/heads/${QUEUE_BRANCH}"

tmpdir_a=$(mktemp -d)
tmpdir_b=$(mktemp -d)

cleanup() { rm -rf "${tmpdir_a}" "${tmpdir_b}" "${tmpremote}"; }
trap cleanup EXIT

# Initialise clone A on the coordination branch and push the seed queue.
cd "${tmpdir_a}"
git init -q -b "${QUEUE_BRANCH}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git remote add origin "${tmpremote}"
mkdir -p claude-arsenal/queue
cat > claude-arsenal/queue/tasks.jsonl <<'QUEUE'
{"id":"lo-c001","title":"Contention task","status":"open","priority":0,"requires":[],"deps":[],"assignee":null,"payload":"lo-c001.md"}
QUEUE
git add claude-arsenal/queue/tasks.jsonl
git commit -q -m "init: seed queue"
git push -q -u origin "${QUEUE_BRANCH}"

# Clone B from the remote (checks out the coordination branch by default).
git clone -q "${tmpremote}" "${tmpdir_b}"
cd "${tmpdir_b}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"

# -- Part 1: race two claim calls simultaneously --
out_a=$(mktemp)
out_b=$(mktemp)

(cd "${tmpdir_a}" && bash "${CLAIM}" lo-c001 session-a) > "${out_a}" 2>/dev/null &
pid_a=$!
(cd "${tmpdir_b}" && bash "${CLAIM}" lo-c001 session-b) > "${out_b}" 2>/dev/null &
pid_b=$!

wait "${pid_a}" || true
wait "${pid_b}" || true

status_a=$(head -1 "${out_a}" 2>/dev/null || echo "error")
status_b=$(head -1 "${out_b}" 2>/dev/null || echo "error")

echo "session-a: ${status_a}"
echo "session-b: ${status_b}"

# The loser must be exactly "lost" — a race misclassified as "error" would stop
# the worker loop, so it must not be accepted here.
wins=0
losts=0
for s in "${status_a}" "${status_b}"; do
    case "${s}" in
        won) wins=$((wins + 1)) ;;
        lost) losts=$((losts + 1)) ;;
    esac
done

if [[ ${wins} -ne 1 || ${losts} -ne 1 ]]; then
    echo "FAIL: expected exactly 1 'won' + 1 'lost', got a='${status_a}' b='${status_b}'"
    exit 1
fi
echo "PASS: exactly one session won, one lost"

# -- Part 2: a session on the wrong branch must fail loud, not look "lost" --
cd "${tmpdir_b}"
git checkout -q -b some-feature-branch
out_c=$(mktemp)
set +e
bash "${CLAIM}" lo-c001 session-c > "${out_c}" 2>/dev/null
rc=$?
set -e
status_c=$(head -1 "${out_c}" 2>/dev/null || echo "")

echo "off-branch claim: '${status_c}' (exit ${rc})"
if [[ "${status_c}" == error* && ${rc} -eq 2 ]]; then
    echo "PASS: off-branch claim failed loud (error, exit 2)"
    exit 0
else
    echo "FAIL: off-branch claim should be 'error' exit 2, got '${status_c}' exit ${rc}"
    exit 1
fi
