#!/usr/bin/env bash
# arsenal_migrate_test.sh — behaviour test for arsenal_migrate.py.
# Migration runs once per consumer and is hard to undo by hand, so the
# properties worth pinning are: it writes nothing without --apply, it never
# resurrects finished work, it preserves ids so deps keep resolving, and
# re-running it is safe.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE_PY="${SCRIPT_DIR}/../skills/init/assets/scripts/arsenal_migrate.py"
SELECT_PY="${SCRIPT_DIR}/../skills/init/assets/scripts/task_select.py"
[[ -f "${MIGRATE_PY}" ]] || { echo "SKIP: ${MIGRATE_PY} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="${tmpdir}/repo"
QUEUE_DIR="${REPO}/claude-arsenal/queue"
mkdir -p "${QUEUE_DIR}" "${REPO}/claude-arsenal/session" "${REPO}/claude-arsenal/project"

cat > "${QUEUE_DIR}/tasks.jsonl" <<'EOF'
{"id":"lo-a3f8","title":"T1: build the thing","status":"open","priority":10,"deps":[],"payload":"lo-a3f8.md","requires":["surface:cli"],"tags":["CLI"]}
{"id":"lo-b2c1","title":"T2: build on it","status":"open","priority":5,"deps":[{"id":"lo-a3f8","type":"blocks"}],"payload":"lo-b2c1.md"}
{"id":"lo-c9d2","title":"T0: already shipped","status":"merged","priority":1,"deps":[],"pr":"https://github.com/o/r/pull/9"}
EOF

cat > "${QUEUE_DIR}/lo-a3f8.md" <<'EOF'
# T1: build the thing

## Acceptance gate
```bash
bash tests/thing_test.sh
```
EOF

echo "handover contents" > "${REPO}/claude-arsenal/session/handover.md"
echo "overview contents" > "${REPO}/claude-arsenal/project/overview.md"

# --- 1: dry run writes nothing ---
out=$(python3 "${MIGRATE_PY}" --repo-root "${REPO}")
[[ -d "${REPO}/arsenal" ]] && fail "dry run must not create arsenal/"
grep -q "dry run" <<<"${out}" || fail "dry run should say so"
grep -q "3 row(s) — 2 live, 1 terminal" <<<"${out}" || fail "expected 2 live / 1 terminal, got: ${out}"

# --- 2: --apply creates one task file per live task, ids preserved ---
python3 "${MIGRATE_PY}" --repo-root "${REPO}" --apply >/dev/null
[[ -f "${REPO}/arsenal/tasks/lo-a3f8.md" ]] || fail "missing task file for lo-a3f8"
[[ -f "${REPO}/arsenal/tasks/lo-b2c1.md" ]] || fail "missing task file for lo-b2c1"

# --- 3: finished work is recorded, not recreated as a task ---
[[ -f "${REPO}/arsenal/tasks/lo-c9d2.md" ]] && fail "a merged task must not become a live task file"
grep -q "lo-c9d2" "${REPO}/arsenal/tasks/_migrated-history.md" || fail "merged task missing from history"

# --- 4: the payload body and its gate survive ---
grep -q "bash tests/thing_test.sh" "${REPO}/arsenal/tasks/lo-a3f8.md" || fail "gate block lost in migration"

# --- 5: deps survive in a form the selector understands ---
out=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${REPO}/arsenal/tasks" --capability surface:cli 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "lo-a3f8" ]] || fail "expected lo-a3f8 first after migration, got '${id}'"
out=$(echo '{"lo-a3f8":"done"}' | python3 "${SELECT_PY}" --tasks-dir "${REPO}/arsenal/tasks" 2>/dev/null)
id=$(python3 -c 'import sys,json;print(json.loads(sys.stdin.readline())["id"])' <<<"${out}")
[[ "${id}" == "lo-b2c1" ]] || fail "dep did not survive migration, got '${id}'"

# --- 6: host-owned state moved out of the vendored prefix ---
[[ -f "${REPO}/arsenal/session/handover.md" ]] || fail "session/ was not moved"
[[ -f "${REPO}/arsenal/project/overview.md" ]] || fail "project/ was not moved"
[[ -d "${REPO}/claude-arsenal/session" ]] && fail "session/ should no longer be inside the vendored prefix"

# --- 7: a config file is seeded ---
grep -q 'merge-policy = "after-ci"' "${REPO}/arsenal/config.toml" || fail "config.toml not seeded"

# --- 8: re-running is safe and does not duplicate or clobber ---
echo "EDITED BY HAND" >> "${REPO}/arsenal/tasks/lo-a3f8.md"
python3 "${MIGRATE_PY}" --repo-root "${REPO}" --apply >/dev/null
grep -q "EDITED BY HAND" "${REPO}/arsenal/tasks/lo-a3f8.md" || fail "re-run clobbered an existing task file"
count=$(find "${REPO}/arsenal/tasks" -maxdepth 1 -name '*.md' -not -name '_*' | wc -l | tr -d ' ')
[[ "${count}" == "2" ]] || fail "expected 2 live task files after re-run, found ${count}"

# --- 9: the manual steps a sandbox cannot do are stated, not attempted ---
out=$(python3 "${MIGRATE_PY}" --repo-root "${REPO}")
grep -q "delete arsenal-queue" <<<"${out}" || fail "should tell the user to delete the coordination branch"

# --- 10: a dep on completed work resolves, instead of blocking forever ---
#     The reported failure: terminal rows became prose, so every dep pointing at
#     finished work read as "unknown", and the selector blocks unknown deps by
#     design. On a real board 15 of 27 live tasks became permanently
#     unselectable — the reward for having your prerequisites done.
REPO2="${tmpdir}/repo2"
Q2="${REPO2}/claude-arsenal/queue"
mkdir -p "${Q2}"
cat > "${Q2}/tasks.jsonl" <<'EOF'
{"id":"lo-done1","title":"Finished earlier","status":"merged","priority":1,"deps":[],"payload":"lo-done1.md","pr":"https://github.com/o/r/pull/3"}
{"id":"lo-next1","title":"Ready once its dep is merged","status":"open","priority":9,"deps":[{"id":"lo-done1","type":"blocks"}],"payload":"lo-next1.md"}
EOF
cat > "${Q2}/lo-done1.md" <<'EOF'
# Finished earlier

## Acceptance gate
```bash
bash tests/done1_gate.sh
```
EOF
cat > "${Q2}/lo-next1.md" <<'EOF'
# Ready now

## Acceptance gate
```bash
true
```
EOF

python3 "${MIGRATE_PY}" --repo-root "${REPO2}" --apply >/dev/null
out=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${REPO2}/arsenal/tasks" 2>"${tmpdir}/warn.txt")
id=$(python3 -c 'import sys,json
line=sys.stdin.readline().strip()
print(json.loads(line)["id"] if line else "NONE")' <<<"${out}")
[[ "${id}" == "lo-next1" ]] || fail "a task whose dep is merged must be selectable, got '${id}'"
grep -q "unknown task" "${tmpdir}/warn.txt" && fail "a dep on migrated-terminal work must not warn as unknown"

# --- 11: the finished task keeps its gate, and is never handed back as work ---
[[ -f "${REPO2}/arsenal/tasks/_history/lo-done1.md" ]] || fail "terminal task file missing"
grep -q "bash tests/done1_gate.sh" "${REPO2}/arsenal/tasks/_history/lo-done1.md" \
    || fail "the finished task's gate was dropped — a re-assertion check would find nothing"
grep -q "^status: merged" "${REPO2}/arsenal/tasks/_history/lo-done1.md" || fail "no status recorded"
out=$(echo '{}' | python3 "${SELECT_PY}" --tasks-dir "${REPO2}/arsenal/tasks" --max 9 2>/dev/null)
grep -q '"id":"lo-done1"' <<<"${out}" && fail "finished work must never be selected again"

echo "PASS: arsenal_migrate_test — all gates passed"
