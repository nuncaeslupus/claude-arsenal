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
count=$(find "${REPO}/arsenal/tasks" -name '*.md' -not -name '_*' | wc -l | tr -d ' ')
[[ "${count}" == "2" ]] || fail "expected 2 task files after re-run, found ${count}"

# --- 9: the manual steps a sandbox cannot do are stated, not attempted ---
out=$(python3 "${MIGRATE_PY}" --repo-root "${REPO}")
grep -q "delete arsenal-queue" <<<"${out}" || fail "should tell the user to delete the coordination branch"

echo "PASS: arsenal_migrate_test — all gates passed"
