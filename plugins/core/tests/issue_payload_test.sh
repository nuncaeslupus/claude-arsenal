#!/usr/bin/env bash
# issue_payload_test.sh — every script that reads a `gh issue list --json …`
# file rejects a wrong-shaped one the same way.
#
# A truncated or failed fetch produces valid JSON that is not an issue list:
# `null`, a bare scalar, `{"issues": null}`. Each of those raised a TypeError
# out of the comprehension that consumed it, so the operator got a traceback and
# exit 1 from scripts that all document exit 2 for unreadable input.
# query_status.py was hardened after a real incident — its comment even claimed
# its siblings already returned 2 — and handle_sync.py and issue_import.py,
# reading the identical payload, were not.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPT_DIR}/../skills/init/assets/scripts"
[[ -d "${SCRIPTS}" ]] || { echo "FAIL: ${SCRIPTS} not found" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

tasks="${tmp}/tasks"
mkdir -p "${tasks}"
cat > "${tasks}/t-payload1.md" <<'TASK'
---
id: t-payload1
title: "a task to read the board against"
priority: 1
---

## Acceptance gate

```bash
true
```
TASK

run() {  # run <script> <issues-file> — prints exit code, stderr to $tmp/err
    local script="$1" issues="$2" extra=()
    [[ "${script}" == "query_status" ]] && extra=(--no-remote-check)
    # issue_for_task resolves one task rather than reading the whole board.
    [[ "${script}" == "issue_for_task" ]] && extra=(--task t-payload1)
    python3 "${SCRIPTS}/${script}.py" --issues "${issues}" --tasks-dir "${tasks}" \
        "${extra[@]}" >/dev/null 2>"${tmp}/err"
    echo $?
}

# --- 1: a wrong-shaped payload is exit 2 with a sentence, from all three ------
i=0
for shape in '{"issues": null}' 'null' '"not an issue list"' '{"issues": 3}' '[1, 2, 3]x'; do
    i=$((i + 1))
    printf '%s' "${shape}" > "${tmp}/i${i}.json"
    for script in query_status handle_sync issue_import issue_for_task task_select; do
        code=$(run "${script}" "${tmp}/i${i}.json")
        # `[1, 2, 3]x` is malformed JSON, which is the read error rather than
        # the shape error; both are exit 2, and neither is a traceback.
        [[ "${code}" -eq 2 ]] \
            || fail "${script} on ${shape}: expected the documented exit 2, got ${code}
$(cat "${tmp}/err")"
        grep -q "Traceback" "${tmp}/err" \
            && fail "${script} on ${shape}: a traceback escaped the exit contract"
        grep -qE "is not an issue list|cannot read --issues|is not valid JSON" "${tmp}/err" \
            || fail "${script} on ${shape}: no explanation on stderr: $(cat "${tmp}/err")"
    done
done
echo "PASS: every reader rejects a wrong-shaped issue payload with exit 2"

# --- 2: a real payload still goes through ------------------------------------
#     The check has to reject the shape, not the input.
printf '[{"number": 1, "title": "a task to read the board against", "state": "OPEN", "labels": [], "assignees": []}]' \
    > "${tmp}/good.json"
for script in query_status handle_sync issue_import task_select; do
    code=$(run "${script}" "${tmp}/good.json")
    [[ "${code}" -eq 0 ]] \
        || fail "${script} rejected a well-formed payload (exit ${code}): $(cat "${tmp}/err")"
done
# ...and the `{"issues": [...]}` wrapper gh can emit is still unwrapped.
printf '{"issues": [{"number": 1, "title": "a task to read the board against", "state": "OPEN", "labels": [], "assignees": []}]}' \
    > "${tmp}/wrapped.json"
code=$(run query_status "${tmp}/wrapped.json")
[[ "${code}" -eq 0 ]] || fail "the {\"issues\": [...]} wrapper was rejected (exit ${code})"
echo "PASS: a well-formed payload, wrapped or bare, still reads"

# --- 3: nothing carries its own copy of the read ------------------------------
#     Three copies is how the hardening reached one of them and not the others.
owner=$(grep -rl 'def read_issue_payload' "${SCRIPTS}") \
    || fail "no module defines read_issue_payload()"
stragglers=$(grep -rln 'payload.get("issues"' "${SCRIPTS}" | grep -vxF "${owner}" || true)
[[ -z "${stragglers}" ]] \
    || fail "these still unwrap the payload themselves instead of using read_issue_payload():
${stragglers}"
echo "PASS: one reader, imported — not three copies to fix separately"

echo "PASS: issue_payload_test — all gates passed"
