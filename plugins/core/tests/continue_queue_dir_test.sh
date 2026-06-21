#!/usr/bin/env bash
# continue_queue_dir_test.sh — query_task.py honors ARSENAL_QUEUE_DIR (CA-17).
# Asserts: when the main-tree tasks.jsonl is the empty "single source of truth"
# seed but the live ledger lives in the coordination worktree pointed at by
# ARSENAL_QUEUE_DIR, /continue reads the live ledger — not the empty seed.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERY_PY="${SCRIPT_DIR}/../skills/continue/scripts/query_task.py"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/create_task.py"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
BUNDLE_DIR="${SCRIPT_DIR}/../skills/init/assets"

for f in "${QUERY_PY}" "${ADD_PY}" "${INIT_PY}"; do
    if [[ ! -f "${f}" ]]; then
        echo "SKIP: ${f} not found" >&2; exit 0
    fi
done

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

# Main working tree: init, then empty the live queue seed (the "remove live
# queue state from main" pattern that triggered the bug).
main="${tmpdir}/main"
mkdir -p "${main}"
echo "# Test repo" > "${main}/CLAUDE.md"
python3 "${INIT_PY}" --repo-path "${main}" --bundle-dir "${BUNDLE_DIR}" >/dev/null 2>&1
Q="claude-arsenal/queue/tasks.jsonl"
: > "${main}/${Q}"   # 0-byte seed

# Coordination worktree: the intact, live ledger.
wt="${tmpdir}/wt"
mkdir -p "${wt}/claude-arsenal/queue"
A=$(python3 "${ADD_PY}" --title "Login form" --priority 10 --workspace LAPTOP \
        --queue "${wt}/${Q}")

cd "${main}"
id_of() { python3 -c "import json,sys; print(json.load(sys.stdin)['id'])"; }

# Gate 1: without ARSENAL_QUEUE_DIR, the empty main seed yields no match.
if python3 "${QUERY_PY}" login >/dev/null 2>&1; then
    echo "FAIL: empty main seed should not match 'login'" >&2; exit 1
fi
echo "PASS: empty main seed reads as no_match (baseline)"

# Gate 2: with ARSENAL_QUEUE_DIR set, the live worktree ledger is read.
OUT=$(ARSENAL_QUEUE_DIR="${wt}" python3 "${QUERY_PY}" login | id_of)
if [[ "${OUT}" != "${A}" ]]; then
    echo "FAIL: with ARSENAL_QUEUE_DIR set, 'login' expected ${A}, got ${OUT}" >&2
    exit 1
fi
echo "PASS: ARSENAL_QUEUE_DIR routes the reader to the live ledger"

echo "PASS: continue_queue_dir_test — all gates passed"
exit 0
