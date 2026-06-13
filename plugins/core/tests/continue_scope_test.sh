#!/usr/bin/env bash
# continue_scope_test.sh — token inference for /continue (query_task.py).
# Asserts: bare-word tokens resolve to workspace/tag/search by membership,
# order-independently; AND semantics; unknown tokens fall back to title search.
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
cd "${tmpdir}"

# Bootstrap claude-arsenal/ so query_task.py can call claude-arsenal/bin/queue_eval.sh.
echo "# Test repo" > CLAUDE.md
python3 "${INIT_PY}" --repo-path "${tmpdir}" --bundle-dir "${BUNDLE_DIR}" >/dev/null 2>&1
Q="claude-arsenal/queue/tasks.jsonl"

A=$(python3 "${ADD_PY}" --title "Login form" --priority 10 --tag CLI --workspace FRONTEND --queue "${Q}")
_=$(python3 "${ADD_PY}" --title "API route"  --priority 9  --tag CLI --workspace BACKEND  --queue "${Q}")
_=$(python3 "${ADD_PY}" --title "Web hook"   --priority 8  --tag WEB --workspace FRONTEND --queue "${Q}")

id_of() { python3 -c "import json,sys; print(json.load(sys.stdin)['id'])"; }

# Gate 1: tag CLI AND workspace FRONTEND → the Login task (A).
OUT=$(python3 "${QUERY_PY}" CLI FRONTEND --queue "${Q}" | id_of)
if [[ "${OUT}" != "${A}" ]]; then
    echo "FAIL: 'CLI FRONTEND' expected ${A}, got ${OUT}" >&2; exit 1
fi
echo "PASS: CLI FRONTEND resolves to tag ∧ workspace"

# Gate 2: order-independent — FRONTEND CLI yields the same task.
OUT2=$(python3 "${QUERY_PY}" FRONTEND CLI --queue "${Q}" | id_of)
if [[ "${OUT2}" != "${A}" ]]; then
    echo "FAIL: 'FRONTEND CLI' (reversed) expected ${A}, got ${OUT2}" >&2; exit 1
fi
echo "PASS: token order does not matter"

# Gate 3: two tags ANDed with no task carrying both → no eligible task (exit 1).
if python3 "${QUERY_PY}" CLI WEB --queue "${Q}" >/dev/null 2>&1; then
    echo "FAIL: 'CLI WEB' should match nothing (no task has both tags)" >&2; exit 1
fi
echo "PASS: multiple tags AND together"

# Gate 4: unknown token falls back to fuzzy title search.
OUT=$(python3 "${QUERY_PY}" login --queue "${Q}" | id_of)
if [[ "${OUT}" != "${A}" ]]; then
    echo "FAIL: unknown token 'login' should fuzzy-match the Login task ${A}, got ${OUT}" >&2; exit 1
fi
echo "PASS: unknown token falls back to title search"

# Gate 4b: token matching is case-insensitive (lowercase resolves to FRONTEND/CLI).
OUT=$(python3 "${QUERY_PY}" cli frontend --queue "${Q}" | id_of)
if [[ "${OUT}" != "${A}" ]]; then
    echo "FAIL: lowercase 'cli frontend' should resolve to ${A}, got ${OUT}" >&2; exit 1
fi
echo "PASS: token matching is case-insensitive"

# Gate 5: two distinct workspaces in one invocation is an error.
if python3 "${QUERY_PY}" FRONTEND BACKEND --queue "${Q}" >/dev/null 2>&1; then
    echo "FAIL: two workspaces should error" >&2; exit 1
fi
echo "PASS: two workspaces error out"

echo "PASS: continue_scope_test — all gates passed"
exit 0
