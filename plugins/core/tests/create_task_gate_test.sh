#!/usr/bin/env bash
# create_task_gate_test.sh — a --body that brings its own acceptance gate gets
# no placeholder gate appended after it (#501). Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/create_task.py"
[[ -f "${ADD_PY}" ]] || { echo "SKIP: ${ADD_PY} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"
mkdir -p arsenal/tasks

fail() { echo "FAIL: $*" >&2; exit 1; }
gates_in() { grep -c '^## Acceptance gate' "$1" || true; }

# No body, and a body without a gate: the placeholder is still the default.
id="$(python3 "${ADD_PY}" --title "no body" 2>/dev/null)"
[[ "$(gates_in "arsenal/tasks/${id}.md")" == 1 ]] || fail "no body: expected one gate section"
grep -q 'arsenal:gate-placeholder' "arsenal/tasks/${id}.md" || fail "no body: placeholder missing"

id="$(python3 "${ADD_PY}" --title "prose body" --body "Do the thing." 2>/dev/null)"
grep -q 'arsenal:gate-placeholder' "arsenal/tasks/${id}.md" || fail "prose body: placeholder missing"

# A body with its own gate keeps that one gate, and nothing else.
body=$'Do the thing.\n\n## Acceptance gate\n\n```bash\nbash tests/thing_test.sh\n```'
id="$(python3 "${ADD_PY}" --title "own gate" --body "${body}" 2>/dev/null)"
f="arsenal/tasks/${id}.md"
[[ "$(gates_in "$f")" == 1 ]] || fail "own gate: expected one gate section, got $(gates_in "$f")"
grep -q 'arsenal:gate-placeholder' "$f" && fail "own gate: the placeholder was appended anyway"
grep -q 'bash tests/thing_test.sh' "$f" || fail "own gate: the body's gate was lost"

# A gate heading with no fenced block is refused: the first gate section is the
# one gate_run.sh reads, and a placeholder after it would never run.
if python3 "${ADD_PY}" --title "prose gate" --body $'## Acceptance gate\n\nrun the tests' >/dev/null 2>&1; then
    fail "a prose-only gate section in --body must be refused"
fi

echo "PASS: create_task_gate_test.sh"
