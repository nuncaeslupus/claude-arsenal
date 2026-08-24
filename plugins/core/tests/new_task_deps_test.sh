#!/usr/bin/env bash
# new_task_deps_test.sh — a dep on completed work is declarable.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PY="${SCRIPT_DIR}/../skills/queue-add/scripts/new_task.py"
[[ -f "${ADD_PY}" ]] || { echo "SKIP: ${ADD_PY} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT
cd "${tmpdir}"

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p arsenal/tasks/_history
printf -- '---\nid: t-live\nstatus: todo\n---\n' > arsenal/tasks/t-live.md
printf -- '---\nid: t-done\nstatus: done\n---\n' > arsenal/tasks/_history/t-done.md

# A merged task is the most satisfied dep there is — it must be declarable.
out="$(python3 "${ADD_PY}" --title "builds on merged work" --deps t-done 2>&1)" \
    || fail "a dep on a finished task was refused: ${out}"
grep -rq "deps: \[t-done\]" arsenal/tasks/*.md || fail "the dep was not written: ${out}"

# The live dir still works, and a genuine typo is still caught.
python3 "${ADD_PY}" --title "live dep" --deps t-live >/dev/null 2>&1 \
    || fail "a dep on a live task was refused"
if python3 "${ADD_PY}" --title "typo" --deps t-nope >/dev/null 2>&1; then
    fail "an unknown dep must still be rejected"
fi

# A `_`-prefixed history note lists ids it does not define. The selector skips
# such files, so a dep on one would never be satisfied.
printf -- 'archived: t-ghost\nid: t-ghost\n' > arsenal/tasks/_history/_migrated-history.md
if python3 "${ADD_PY}" --title "ghost" --deps t-ghost >/dev/null 2>&1; then
    fail "an id from a _-prefixed history note must not count as a dep"
fi

# A quoted id is an id: the selector's front-matter parser strips the quotes,
# so a task file spelling it that way defines a task this used to miss — and a
# dep on it was refused as unknown, leaving the graph unable to record it.
printf -- '---\nid: "t-quoted"\nstatus: todo\n---\n' > arsenal/tasks/t-quoted.md
out="$(python3 "${ADD_PY}" --title "depends on a quoted id" --deps t-quoted 2>&1)" \
    || fail "a dep on a task whose id is quoted was refused: ${out}"

# ...but only the quote pairs the selector strips. `_parse_scalar` reads an
# unmatched quote as part of the value, so accepting one here would let a dep
# validate against `t-halfquoted` and then resolve against `"t-halfquoted`.
printf -- '---\nid: "t-halfquoted\nstatus: todo\n---\n' > arsenal/tasks/t-half.md
if python3 "${ADD_PY}" --title "half-quoted dep" --deps t-halfquoted >/dev/null 2>&1; then
    fail "an id behind an unmatched quote is not the id the selector reads"
fi

echo "PASS: new_task_deps_test.sh"
