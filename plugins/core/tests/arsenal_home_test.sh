#!/usr/bin/env bash
# arsenal_home_test.sh — ARSENAL_HOME relocates the board for every reader.
#
# AGENTS.md tells a host that setting ARSENAL_HOME "relocates all of them at
# once", and init.py honours it. The board readers did not: each carried its own
# `--tasks-dir` default of the literal `arsenal/tasks`, and every canonical
# invocation omits the flag, so the default is what runs. A consumer who set
# ARSENAL_HOME got `tasks: 0 — open 0, problems 0` from a board that was there —
# output indistinguishable from a legitimately empty backlog.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPT_DIR}/../skills/init/assets/scripts"
[[ -d "${SCRIPTS}" ]] || { echo "FAIL: ${SCRIPTS} not found" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1: one resolver, and it reads the environment ---------------------------
resolved=$(ARSENAL_HOME=elsewhere python3 -c "
import sys; sys.path.insert(0, '${SCRIPTS}')
from task_select import default_tasks_dir
print(default_tasks_dir())
")
[[ "${resolved}" == "elsewhere/tasks" ]] \
    || fail "default_tasks_dir() ignored ARSENAL_HOME: got '${resolved}'"
resolved=$(python3 -c "
import sys; sys.path.insert(0, '${SCRIPTS}')
from task_select import default_tasks_dir
print(default_tasks_dir())
")
[[ "${resolved}" == "arsenal/tasks" ]] \
    || fail "unset ARSENAL_HOME must still mean arsenal/tasks, got '${resolved}'"
echo "PASS: default_tasks_dir() honours ARSENAL_HOME and defaults to arsenal/tasks"

# --- 2: nothing carries its own copy of the literal ---------------------------
#     The defect was five identical defaults, so a fix to one would not have
#     reached the others. This is the guard against a sixth being written.
stragglers=$(grep -rln 'default=Path("arsenal/tasks")' "${SCRIPTS}" || true)
[[ -z "${stragglers}" ]] \
    || fail "these still hardcode the board path instead of default_tasks_dir():
${stragglers}"
users=$(grep -rl 'default=default_tasks_dir()' "${SCRIPTS}" | wc -l | tr -d ' ')
[[ "${users}" -ge 5 ]] \
    || fail "expected at least 5 readers on the shared default, found ${users}"
echo "PASS: every --tasks-dir default resolves through the one function"

# --- 3: the readers the session protocol runs actually find a relocated board -
repo="${tmp}/repo"
mkdir -p "${repo}/host/tasks"
cat > "${repo}/host/tasks/t-relocated.md" <<'TASK'
---
id: t-relocated
title: "a task on a relocated board"
priority: 1
---

## Acceptance gate

```bash
true
```
TASK

out=$(cd "${repo}" && ARSENAL_HOME=host python3 "${SCRIPTS}/query_status.py" 2>&1)
grep -q "^tasks: 1" <<<"${out}" \
    || fail "query_status.py read a relocated board as empty: ${out}"

out=$(cd "${repo}" && ARSENAL_HOME=host python3 "${SCRIPTS}/task_select.py" 2>&1)
grep -q "t-relocated" <<<"${out}" \
    || fail "task_select.py found no task on a relocated board: ${out}"
echo "PASS: the board readers follow ARSENAL_HOME"

# ...and an explicit --tasks-dir still wins over it.
out=$(cd "${repo}" && ARSENAL_HOME=host python3 "${SCRIPTS}/query_status.py" --tasks-dir nowhere 2>&1)
grep -q "^tasks: 0" <<<"${out}" \
    || fail "an explicit --tasks-dir must override ARSENAL_HOME: ${out}"
echo "PASS: an explicit --tasks-dir still overrides ARSENAL_HOME"

echo "PASS: arsenal_home_test — all gates passed"
