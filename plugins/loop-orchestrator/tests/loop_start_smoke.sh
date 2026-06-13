#!/usr/bin/env bash
# loop_start_smoke.sh — smoke test for loop-start mechanics (T7 gate, no Claude required).
# Seeds one task, runs queue_eval → claim → release pipeline, verifies done status.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_EVAL="${SCRIPT_DIR}/../core/scripts/queue_eval.sh"
CLAIM="${SCRIPT_DIR}/../core/scripts/claim.sh"
RELEASE="${SCRIPT_DIR}/../core/scripts/release.sh"
ADD_PY="${SCRIPT_DIR}/../skills/loop-add/scripts/create_task.py"
STATUS_PY="${SCRIPT_DIR}/../skills/loop-status/scripts/query_status.py"

for f in "${QUEUE_EVAL}" "${CLAIM}" "${RELEASE}" "${ADD_PY}" "${STATUS_PY}"; do
    if [[ ! -f "${f}" ]]; then
        echo "SKIP: ${f} not found" >&2; exit 0
    fi
done

tmpremote=$(mktemp -d)
tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpremote}" "${tmpdir}"; }
trap cleanup EXIT

# --- Setup: init a bare remote + working clone ---
git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD refs/heads/master

cd "${tmpdir}"
git init -q
git config user.email "test@loop.example"
git config user.name "Loop Test"
git remote add origin "${tmpremote}"
mkdir -p .loop/state/tasks

# Seed one task via add_task.py
TASK_ID=$(python3 "${ADD_PY}" --title "Smoke test task" --priority 5 --queue ".loop/state/queue.jsonl")
if [[ -z "${TASK_ID}" ]]; then
    echo "FAIL: add_task.py did not emit a task ID" >&2; exit 1
fi

git add .loop/state/queue.jsonl
git commit -q -m "init: seed queue"
git push -q -u origin master

# --- Step 1: queue_eval finds the task ---
EVAL_OUT=$(bash "${QUEUE_EVAL}")
if [[ -z "${EVAL_OUT}" ]]; then
    echo "FAIL: queue_eval.sh returned empty — task not found" >&2; exit 1
fi
EVAL_ID=$(echo "${EVAL_OUT}" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
if [[ "${EVAL_ID}" != "${TASK_ID}" ]]; then
    echo "FAIL: queue_eval returned task ${EVAL_ID}, expected ${TASK_ID}" >&2; exit 1
fi

# --- Step 2: claim the task ---
CLAIM_OUT=$(bash "${CLAIM}" "${TASK_ID}" "smoke-session")
CLAIM_RESULT="${CLAIM_OUT%%$'\n'*}"
if [[ "${CLAIM_RESULT}" != "won" ]]; then
    echo "FAIL: claim.sh returned '${CLAIM_RESULT}', expected 'won'" >&2; exit 1
fi

# Verify status is in_progress
STATUS=$(python3 "${STATUS_PY}" --queue ".loop/state/queue.jsonl")
if ! echo "${STATUS}" | grep -q "in_progress=1"; then
    echo "FAIL: expected in_progress=1 after claim, got: ${STATUS}" >&2; exit 1
fi

# --- Step 3: release as done ---
bash "${RELEASE}" "${TASK_ID}" "done"

# --- Step 4: verify done status ---
STATUS_FINAL=$(python3 "${STATUS_PY}" --queue ".loop/state/queue.jsonl")
if ! echo "${STATUS_FINAL}" | grep -q "done=1"; then
    echo "FAIL: expected done=1 after release, got: ${STATUS_FINAL}" >&2; exit 1
fi

# --- Step 5: queue_eval now returns empty (queue exhausted) ---
EVAL_AFTER=$(bash "${QUEUE_EVAL}")
if [[ -n "${EVAL_AFTER}" ]]; then
    echo "FAIL: queue_eval should return empty after task done, got: ${EVAL_AFTER}" >&2; exit 1
fi

echo "PASS: loop_start_smoke — queue_eval → claim → release pipeline verified"
exit 0
