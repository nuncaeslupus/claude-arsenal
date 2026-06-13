#!/usr/bin/env bash
# claim_contention.sh — integration test for optimistic git-push concurrency.
# Verifies that when two sessions race to claim the same task, exactly one wins
# ("won") and the other loses ("lost").
#
# Usage: bash tests/claim_contention.sh
# Exit : 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAIM="${SCRIPT_DIR}/../bundle/bin/claim.sh"

if [[ ! -f "${CLAIM}" ]]; then
    echo "SKIP: claim.sh not found at ${CLAIM}" >&2
    exit 0
fi

# -- Create a bare "remote" repository --
tmpremote=$(mktemp -d)
git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD refs/heads/master

# -- Create two working clones --
tmpdir_a=$(mktemp -d)
tmpdir_b=$(mktemp -d)

cleanup() { rm -rf "${tmpdir_a}" "${tmpdir_b}" "${tmpremote}"; }
trap cleanup EXIT

# Initialise clone A and push the seed queue.
cd "${tmpdir_a}"
git init -q
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git remote add origin "${tmpremote}"
mkdir -p claude-arsenal/queue
cat > claude-arsenal/queue/tasks.jsonl <<'QUEUE'
{"id":"lo-c001","title":"Contention task","status":"open","priority":0,"requires":[],"deps":[],"assignee":null,"payload":"lo-c001.md"}
QUEUE
git add claude-arsenal/queue/tasks.jsonl
git commit -q -m "init: seed queue"
git push -q origin master

# Clone B from the remote.
git clone -q "${tmpremote}" "${tmpdir_b}"
cd "${tmpdir_b}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"

# -- Race two claim calls simultaneously --
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

wins=0
losses=0
if [[ "${status_a}" == "won" ]]; then wins=$((wins + 1)); else losses=$((losses + 1)); fi
if [[ "${status_b}" == "won" ]]; then wins=$((wins + 1)); else losses=$((losses + 1)); fi

if [[ ${wins} -eq 1 && ${losses} -eq 1 ]]; then
    echo "PASS: exactly one session won, one lost"
    exit 0
else
    echo "FAIL: expected 1 win + 1 loss, got ${wins} wins, ${losses} losses"
    exit 1
fi
