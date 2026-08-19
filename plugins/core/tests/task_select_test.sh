#!/usr/bin/env bash
# task_select_test.sh — behaviour test for task_select.py + arsenal_config.py.
# The selector is the piece every session runs first, so its ordering and its
# blocking rules are worth pinning down precisely.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELECT_PY="${SCRIPT_DIR}/../skills/init/assets/scripts/task_select.py"
CONFIG_PY="${SCRIPT_DIR}/../skills/init/assets/scripts/arsenal_config.py"

for f in "${SELECT_PY}" "${CONFIG_PY}"; do
    [[ -f "${f}" ]] || { echo "SKIP: ${f} not found" >&2; exit 0; }
done

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

TASKS="${tmpdir}/tasks"
mkdir -p "${TASKS}"

cat > "${TASKS}/t-aaaa1111.md" <<'EOF'
---
id: t-aaaa1111
title: "Base task"
priority: 5
---

## Acceptance gate
```bash
true
```
EOF

cat > "${TASKS}/t-bbbb2222.md" <<'EOF'
---
id: t-bbbb2222
title: "Depends on base"
priority: 10
deps: [t-aaaa1111]
---
No gate here.
EOF

cat > "${TASKS}/t-cccc3333.md" <<'EOF'
---
id: t-cccc3333
title: "Needs the CLI"
priority: 9
requires: [surface:cli]
---
EOF

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1: a blocked task is not selected even though its priority is highest ---
out=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "t-aaaa1111" ]] || fail "expected base task first, got '${id}'"

# --- 2: gate presence is reported, so a payload with no fenced block is visible ---
gate=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["gate"])' <<<"${out}")
[[ "${gate}" == "True" ]] || fail "expected gate=true for the base task, got '${gate}'"

# --- 3: once the dep is done, the dependent outranks by priority ---
out=$(echo '{"t-aaaa1111":"done"}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "t-bbbb2222" ]] || fail "expected dependent task after dep done, got '${id}'"

# --- 4: `merged` also satisfies a dep (both are terminal) ---
out=$(echo '{"t-aaaa1111":"merged"}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "t-bbbb2222" ]] || fail "merged dep should unblock, got '${id}'"

# --- 5: a claimed task is not offered again ---
out=$(echo '{"t-aaaa1111":"claimed"}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --max 5 2>/dev/null)
grep -q 't-aaaa1111' <<<"${out}" && fail "a claimed task must not be selected"

# --- 6: capability filtering — surface:cli only when the surface offers it ---
out=$(echo '{"t-aaaa1111":"done","t-bbbb2222":"done"}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" 2>/dev/null)
[[ -z "${out}" ]] || fail "task requiring surface:cli must not be selected without the capability"
out=$(echo '{"t-aaaa1111":"done","t-bbbb2222":"done"}' | python3 "${SELECT_PY}" \
        --tasks-dir "${TASKS}" --capability surface:cli 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "t-cccc3333" ]] || fail "capability task should be selected when offered, got '${id}'"

# --- 7: an unknown dep blocks rather than unblocks ---
cat > "${TASKS}/t-dddd4444.md" <<'EOF'
---
id: t-dddd4444
title: "Depends on something that does not exist"
priority: 99
deps: [t-nonexistent]
---
EOF
out=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --max 9 2>/dev/null)
grep -q 't-dddd4444' <<<"${out}" && fail "unknown dep must block, not unblock"
rm "${TASKS}/t-dddd4444.md"

# --- 8: two agents reading the same graph rank it identically ---
a=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --max 9 2>/dev/null)
b=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --max 9 2>/dev/null)
[[ "${a}" == "${b}" ]] || fail "selection must be deterministic across runs"

# --- 9: config defaults apply with no file, and a file overrides them ---
val=$(python3 "${CONFIG_PY}" --repo-root "${tmpdir}" --get merge-policy)
[[ "${val}" == "after-ci" ]] || fail "expected default merge-policy after-ci, got '${val}'"
mkdir -p "${tmpdir}/arsenal"
printf 'merge-policy = "never"\nlisting-budget = 12000\n' > "${tmpdir}/arsenal/config.toml"
val=$(python3 "${CONFIG_PY}" --repo-root "${tmpdir}" --get merge-policy)
[[ "${val}" == "never" ]] || fail "config file should override the default, got '${val}'"
val=$(python3 "${CONFIG_PY}" --repo-root "${tmpdir}" --get listing-budget)
[[ "${val}" == "12000" ]] || fail "expected listing-budget 12000, got '${val}'"

# --- 10: an invalid policy fails loudly instead of silently defaulting ---
printf 'merge-policy = "whenever-i-feel-like-it"\n' > "${tmpdir}/arsenal/config.toml"
if python3 "${CONFIG_PY}" --repo-root "${tmpdir}" --get merge-policy >/dev/null 2>&1; then
    fail "an invalid merge-policy must exit non-zero"
fi

# --- 11: --explain names the source of each value ---
printf 'merge-policy = "always"\n' > "${tmpdir}/arsenal/config.toml"
out=$(python3 "${CONFIG_PY}" --repo-root "${tmpdir}" --explain)
grep -q 'merge-policy.*always.*config.toml' <<<"${out}" \
    || fail "--explain should show where merge-policy came from"
grep -q 'test-discipline.*default' <<<"${out}" \
    || fail "--explain should mark unset keys as default"

# --- 12: state derived from GitHub issues, the way a session actually gets it ---
cat > "${tmpdir}/issues.json" <<'EOF'
[
  {"number": 1, "state": "closed", "state_reason": "completed",
   "body": "Task\n\n<!-- arsenal-task: t-aaaa1111 -->", "labels": [{"name": "arsenal:task"}]},
  {"number": 2, "state": "open",
   "body": "<!-- arsenal-task: t-bbbb2222 -->", "labels": [{"name": "arsenal:task"}]},
  {"number": 3, "state": "open",
   "body": "an ordinary issue somebody filed, no marker", "labels": []}
]
EOF
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues.json" 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "t-bbbb2222" ]] || fail "issue-derived state should unblock the dependent, got '${id}'"

# --- 13: an issue closed by hand (not completed) must NOT unblock dependents ---
cat > "${tmpdir}/issues-notplanned.json" <<'EOF'
[
  {"number": 1, "state": "closed", "state_reason": "not_planned",
   "body": "<!-- arsenal-task: t-aaaa1111 -->", "labels": [{"name": "arsenal:task"}]}
]
EOF
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues-notplanned.json" --max 9 2>/dev/null)
grep -q 't-bbbb2222' <<<"${out}" && fail "a not_planned close must not unblock dependents"

# --- 14: a claimed issue is not offered, so two agents do not both pick it ---
cat > "${tmpdir}/issues-claimed.json" <<'EOF'
[
  {"number": 1, "state": "open", "body": "<!-- arsenal-task: t-aaaa1111 -->",
   "labels": [{"name": "arsenal:task"}, {"name": "arsenal:claimed"}]}
]
EOF
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues-claimed.json" --max 9 2>/dev/null)
grep -q 't-aaaa1111' <<<"${out}" && fail "a claimed issue must not be selected"

# --- 15: issues without the marker are ignored entirely ---
#         (this is what keeps ordinary user-filed issues out of the queue)
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues.json" --max 9 2>/dev/null)
grep -q '"number"' <<<"${out}" && fail "selector must emit tasks, never raw issues"

# --- 16: the batch is clamped to one task without worktree isolation ---
#         Parallel workers without separate worktrees share one tree and clobber
#         each other. queue_batch.sh enforced this mechanically; when it was
#         deleted the rule survived only as prose in AGENTS.md, which is exactly
#         the kind of rule a caller skips once — in the round that discovers
#         isolation is missing, after two workers are already out.
sentinel="${tmpdir}/worktree_isolation"

echo "available" > "${sentinel}"
n=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --capability surface:cli --max 9 \
        --isolation-sentinel "${sentinel}" </dev/null 2>/dev/null | wc -l)
[[ "${n}" -gt 1 ]] || fail "with isolation available the batch must not be clamped (got ${n})"

echo "unavailable" > "${sentinel}"
n=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --capability surface:cli --max 9 \
        --isolation-sentinel "${sentinel}" </dev/null 2>/dev/null | wc -l)
[[ "${n}" -eq 1 ]] || fail "without worktree isolation the batch must be 1 task, got ${n}"

# the reason is reported, not silently applied
python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --capability surface:cli --max 9 --isolation-sentinel "${sentinel}" \
    </dev/null 2>&1 >/dev/null | grep -q "capped at 1" \
    || fail "the clamp must say why the batch shrank"

# a missing sentinel is not a clamp: an unprobed surface is not a known-bad one
rm -f "${sentinel}"
n=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --capability surface:cli --max 9 \
        --isolation-sentinel "${sentinel}" </dev/null 2>/dev/null | wc -l)
[[ "${n}" -gt 1 ]] || fail "an absent sentinel must not clamp the batch (got ${n})"

# the environment override wins over the file, for a surface probed by hand
echo "available" > "${sentinel}"
n=$(ARSENAL_WORKTREE_ISOLATION=unavailable python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --capability surface:cli \
        --max 9 --isolation-sentinel "${sentinel}" </dev/null 2>/dev/null | wc -l)
[[ "${n}" -eq 1 ]] || fail "ARSENAL_WORKTREE_ISOLATION must override the sentinel (got ${n})"

# --- 17: a ```sh gate counts as a gate, because gate_run.sh executes one ---
#         When the two disagree the board reports "no gate" for a task whose
#         gate runs fine — the direction that gets a working payload rewritten,
#         or teaches people to ignore the next real warning.
cat > "${TASKS}/t-dddd4444.md" <<'EOF'
---
id: t-dddd4444
title: "Gate written as sh"
priority: 20
---

## Acceptance gate
```sh
true
```
EOF
out=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${TASKS}" 2>/dev/null | head -1)
python3 -c 'import sys,json
t=json.loads(sys.stdin.readline())
assert t["id"]=="t-dddd4444", t["id"]
assert t["gate"] is True, "an sh-fenced gate must count as a gate"' <<<"${out}" \
    || fail "an sh-fenced gate must be recognised"
rm -f "${TASKS}/t-dddd4444.md"

# --- 18: a closed issue whose reason is unavailable still reads as done ---
#         The GitHub MCP tools a cloud session uses return no state_reason at
#         all. Reading absent as "not done" would stall the queue on that
#         surface; the cancelled LABEL carries the distinction instead, because
#         labels are the one signal every surface can see.
cat > "${tmpdir}/issues-noreason.json" <<'EOF'
[{"number": 1, "state": "CLOSED", "body": "handle <!-- arsenal-task: t-aaaa1111 -->"}]
EOF
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues-noreason.json" --max 9 2>/dev/null)
grep -q 't-bbbb2222' <<<"${out}" || fail "a closed issue with no state_reason must unblock its dependent"

cat > "${tmpdir}/issues-cancelled.json" <<'EOF'
[{"number": 1, "state": "CLOSED", "body": "handle <!-- arsenal-task: t-aaaa1111 -->",
  "labels": [{"name": "arsenal:cancelled"}]}]
EOF
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues-cancelled.json" --max 9 2>/dev/null)
grep -q 't-bbbb2222' <<<"${out}" && fail "arsenal:cancelled must NOT release the dependent"

# state_reason still wins where a surface can supply it
cat > "${tmpdir}/issues-notplanned2.json" <<'EOF'
[{"number": 1, "state": "CLOSED", "state_reason": "not_planned",
  "body": "handle <!-- arsenal-task: t-aaaa1111 -->"}]
EOF
out=$(python3 "${SELECT_PY}" --tasks-dir "${TASKS}" --issues "${tmpdir}/issues-notplanned2.json" --max 9 2>/dev/null)
grep -q 't-bbbb2222' <<<"${out}" && fail "state_reason=not_planned must still block the dependent"

echo "PASS: task_select_test — all gates passed"
