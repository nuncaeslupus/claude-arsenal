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

# --- 7: a config file is seeded, and it is init.py's template (#264) ---
# `init.py` will not rewrite a config.toml that already exists, so a partial one
# written here is permanent. This script used to carry its own copy of the
# template; it drifted, and every repo migrated before `/init` lost `host-gate`
# and `[models]` with no ordering of the two that recovered them.
grep -q 'merge-policy = "after-ci"' "${REPO}/arsenal/config.toml" || fail "config.toml not seeded"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
python3 - "${INIT_PY}" "${REPO}/arsenal/config.toml" <<'PY' || fail "see above"
import importlib.util, re, sys

spec = importlib.util.spec_from_file_location("_init_for_keys", sys.argv[1])
module = importlib.util.module_from_spec(spec)
sys.modules["_init_for_keys"] = module
spec.loader.exec_module(module)

def keys(text):
    return {m.group(1) for m in re.finditer(r"^([a-z-]+|\[[a-z]+\]) *=?", text, re.M)
            if not m.group(1).startswith("#")}

want = keys(module._CONFIG_TEMPLATE)
got = keys(open(sys.argv[2]).read())
missing = sorted(want - got)
if missing:
    print(f"the migrated config.toml is missing {missing} that init.py's template has",
          file=sys.stderr)
    raise SystemExit(1)
PY
echo "PASS: the migrated config.toml carries every key init.py's template does"

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

# --- a legacy row cannot read or write outside the queue (#302) -------------
# `payload` and `id` come out of a file this script is pointed at, and both were
# joined straight onto a path. With --apply, one row could read a file outside
# the queue directory and write its contents outside arsenal/tasks/.
TRAV="${tmpdir}/traversal"
mkdir -p "${TRAV}/claude-arsenal/queue"
printf 'SECRET-CONTENTS\n' > "${TRAV}/outside.md"
cat > "${TRAV}/claude-arsenal/queue/tasks.jsonl" <<'JSON'
{"id": "lo-esc", "title": "reads outside", "status": "open", "payload": "../../outside.md"}
JSON
out=$(python3 "${MIGRATE_PY}" --repo-root "${TRAV}" --apply 2>&1)
if grep -rq "SECRET-CONTENTS" "${TRAV}/arsenal" 2>/dev/null; then
    fail "a ../ payload was read into a task file: ${out}"
fi
grep -q "resolves outside" <<<"${out}" || fail "the containment refusal was not reported: ${out}"
echo "PASS: a legacy payload path cannot escape the queue directory"

TRAV2="${tmpdir}/traversal-id"
mkdir -p "${TRAV2}/claude-arsenal/queue"
cat > "${TRAV2}/claude-arsenal/queue/tasks.jsonl" <<'JSON'
{"id": "../../../pwned", "title": "writes outside", "status": "open"}
JSON
code=0
python3 "${MIGRATE_PY}" --repo-root "${TRAV2}" --apply >/dev/null 2>&1 || code=$?
[[ ${code} -eq 2 ]] || fail "a traversing task id must exit 2, got ${code}"
if [[ -e "${TRAV2}/../pwned.md" || -e "${tmpdir}/pwned.md" ]]; then
    fail "a task file was written outside the tree"
fi
echo "PASS: a legacy task id that is not a filename is refused"

# --- a row that cannot be read stops the migration (#265) -------------------
# Skipping it and reporting success is how the only record of a task gets
# deleted along with the old queue the user was told they could remove.
BAD="${tmpdir}/badline"
mkdir -p "${BAD}/claude-arsenal/queue"
cat > "${BAD}/claude-arsenal/queue/tasks.jsonl" <<'JSON'
{"id": "lo-ok", "title": "fine", "status": "open"}
{"id": "lo-broken", "title": "truncated"
{"title": "no id at all", "status": "open"}
JSON
code=0
out=$(python3 "${MIGRATE_PY}" --repo-root "${BAD}" --apply 2>&1) || code=$?
[[ ${code} -eq 2 ]] || fail "a malformed queue line must exit 2, got ${code}: ${out}"
grep -q "tasks.jsonl:2" <<<"${out}" || fail "the refusal must name the line number: ${out}"
if [[ -d "${BAD}/arsenal/tasks" ]]; then
    fail "a refused migration must write nothing"
fi
echo "PASS: a malformed queue row stops the migration and names its line"

# --- list values survive being read back ------------------------------------
# `tags` and `requires` arrive as arbitrary JSON strings; joining them raw turned
# one tag into two, and a value with a colon into a mapping nested in the list.
YM="${tmpdir}/yamlsafe"
mkdir -p "${YM}/claude-arsenal/queue"
cat > "${YM}/claude-arsenal/queue/tasks.jsonl" <<'JSON'
{"id": "lo-yaml", "title": "list quoting", "status": "open", "tags": ["needs, review", "type: bug"], "workspace": "a: b"}
JSON
python3 "${MIGRATE_PY}" --repo-root "${YM}" --apply >/dev/null 2>&1 \
    || fail "the yaml fixture should migrate cleanly"
python3 - "${YM}/arsenal/tasks/lo-yaml.md" <<'PY' || fail "see above"
import re, sys
text = open(sys.argv[1]).read()
tags = re.search(r"^tags: (.+)$", text, re.M)
ws = re.search(r"^workspace: (.+)$", text, re.M)
if not tags or tags.group(1) != '["needs, review", "type: bug"]':
    print(f"tags were not serialised as two quoted items: {tags and tags.group(1)!r}",
          file=sys.stderr)
    raise SystemExit(1)
if not ws or ws.group(1) != '"a: b"':
    print(f"workspace with a colon was not quoted: {ws and ws.group(1)!r}", file=sys.stderr)
    raise SystemExit(1)
PY
echo "PASS: list and scalar values are serialised, not concatenated"

echo "PASS: arsenal_migrate_test — all gates passed"
