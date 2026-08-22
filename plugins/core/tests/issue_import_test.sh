#!/usr/bin/env bash
# issue_import_test.sh — issues filed between sessions become visible work (#142),
# and the listing budget is settable rather than hardcoded (#143).
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPT_DIR}/../skills/init/assets/scripts"
IMPORT="${SCRIPTS}/issue_import.py"
SELECT="${SCRIPTS}/task_select.py"
AUDIT="${SCRIPT_DIR}/../../skill-workshop/skills/skill-workshop/scripts/audit_library.py"

[[ -f "${IMPORT}" ]] || { echo "SKIP: issue_import.py not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

tasks="${tmp}/tasks"
mkdir -p "${tasks}"
cat > "${tmp}/issues.json" <<'JSON'
[
 {"number": 50, "state": "open", "title": "Rate limiter drops the last bucket",
  "html_url": "https://example/50", "labels": [{"name": "arsenal:queue"}],
  "body": "Repro: send 101 requests."},
 {"number": 51, "state": "open", "title": "How does the cache work?",
  "labels": [{"name": "question"}], "body": "just asking"},
 {"number": 52, "state": "closed", "title": "already finished",
  "labels": [{"name": "arsenal:queue"}], "body": "done"},
 {"number": 53, "state": "open", "title": "already a handle",
  "labels": [{"name": "arsenal:queue"}], "body": "`arsenal-task: t-existing1`"}
]
JSON

# Gate 1: only the open, labelled issue that is not already a handle is imported.
# The other three are each a different way of not being work: a question nobody
# opted in, an issue already finished, and an issue that IS a task's handle —
# importing that one would mint a second task for the same work.
out=$(python3 "${IMPORT}" --issues "${tmp}/issues.json" --tasks-dir "${tasks}" --apply)
[[ "$(echo "${out}" | wc -l)" -eq 1 ]] || fail "expected exactly one import, got: ${out}"
echo "${out}" | grep -q '"issue":50' || fail "the labelled open issue was not imported: ${out}"
echo "${out}" | grep -q '"add_to_issue_body":"`arsenal-task: t-' \
    || fail "no handle marker was printed for the caller to apply: ${out}"
echo "PASS: only an open, labelled, unhandled issue becomes a task"

# Gate 2: the seeded task is VISIBLE but never dispatched. Its gate is the
# issue's prose, and a gate that runs nothing passes everything — so a human
# writes a real one and deletes the requires line before it can be claimed.
task_file=$(ls "${tasks}"/*.md)
grep -q "requires: \[human:gate\]" "${task_file}" \
    || fail "a seeded task must carry requires: [human:gate], got: $(cat "${task_file}")"
grep -q "https://example/50" "${task_file}" || fail "the task should name the issue it came from"
echo '{}' > "${tmp}/state.json"
sel=$(python3 "${SELECT}" --tasks-dir "${tasks}" --state "${tmp}/state.json" \
      --capability surface:cli </dev/null 2>/dev/null)
[[ -z "${sel}" ]] || fail "an imported task must not be selectable until a human writes its gate: ${sel}"
echo "PASS: the seeded task is visible but not claimable"

# Gate 3: running it again imports nothing new once the caller has applied the
# marker — the import is idempotent, so a session that re-runs it does not
# duplicate the board.
marker=$(echo "${out}" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["add_to_issue_body"])')
python3 - "${tmp}/issues.json" "${marker}" <<'PY'
import json, sys
path, marker = sys.argv[1], sys.argv[2]
issues = json.loads(open(path).read())
for i in issues:
    if i["number"] == 50:
        i["body"] = marker + "\n\n" + i["body"]
open(path, "w").write(json.dumps(issues))
PY
again=$(python3 "${IMPORT}" --issues "${tmp}/issues.json" --tasks-dir "${tasks}" --apply 2>/dev/null)
[[ -z "${again}" ]] || fail "re-import after the marker was applied should be a no-op, got: ${again}"
echo "PASS: import is idempotent once the issue carries its handle marker"

# Gate 4 (#143): the listing budget is settable, and the effective value and its
# source are printed. A cap a library cannot pass is a check it stops running,
# and a configurable cap whose value never appears is one nobody can tell was
# quietly raised to whatever the library measured.
if [[ -f "${AUDIT}" ]] && command -v uv >/dev/null 2>&1; then
    lib="${SCRIPT_DIR}/../skills"
    report=$(cd "${SCRIPT_DIR}/../../.." && uv run python "${AUDIT}" "${lib}" --by-plugin 2>&1 || true)
    echo "${report}" | grep -q "8000 chars  (default)" \
        || fail "the default budget and its source should be printed: ${report}"
    report=$(cd "${SCRIPT_DIR}/../../.." && ARSENAL_LISTING_BUDGET_CHARS=12000 \
             uv run python "${AUDIT}" "${lib}" --by-plugin 2>&1 || true)
    echo "${report}" | grep -q "12000 chars  (ARSENAL_LISTING_BUDGET_CHARS)" \
        || fail "the env budget should be honoured and named: ${report}"
    report=$(cd "${SCRIPT_DIR}/../../.." && uv run python "${AUDIT}" "${lib}" --by-plugin --listing-budget 500 2>&1 || true)
    echo "${report}" | grep -q "500 chars  (--listing-budget)" \
        || fail "the flag should win and be named: ${report}"
    echo "PASS: the listing budget is settable and its source is reported"
else
    echo "SKIP: audit_library.py or uv unavailable — listing-budget gate not run" >&2
fi

# Gate 5 (#186): the title written into the task file is the real title, not
# how the transport spelled it. The GitHub MCP tools HTML-escape `<`, `>` and
# `&` in `title`, and `json.dumps` escapes every non-ASCII character — bake
# either into the file and the task's title no longer equals its issue's, which
# is exactly what stopped the bodyless board resolving.
fresh="${tmp}/tasks2"
mkdir -p "${fresh}"
cat > "${tmp}/issues-spelling.json" <<'JSON'
[{"number": 60, "state": "open", "labels": [{"name": "arsenal:queue"}],
  "html_url": "https://example/60", "body": "x",
  "title": "T42: annotations/&lt;offer_id&gt;.json &amp; \u20ac/month"}]
JSON
python3 "${IMPORT}" --issues "${tmp}/issues-spelling.json" --tasks-dir "${fresh}" --apply >/dev/null
written=$(cat "${fresh}"/*.md)
grep -q 'title: "T42: annotations/<offer_id>.json & €/month"' <<<"${written}" \
    || fail "the imported title must hold the real characters: ${written}"
echo "PASS: an imported title is stored as written, not as the transport spelled it"

echo "PASS: issue_import_test — all gates passed"
