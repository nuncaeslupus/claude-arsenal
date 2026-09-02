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

# Gate 1b: a run that imports TWO issues mints two tasks. Every other gate here
# feeds exactly one importable issue, which is how a crash on the second loop
# iteration shipped: `importable` deleted one of its own parameters inside the
# loop, so the first issue passed and the second raised UnboundLocalError.
two="${tmp}/two"
mkdir -p "${two}"
cat > "${tmp}/two.json" <<'JSON'
[
 {"number": 60, "state": "open", "title": "first of two",
  "labels": [{"name": "arsenal:queue"}], "body": "one"},
 {"number": 61, "state": "open", "title": "second of two",
  "labels": [{"name": "arsenal:queue"}], "body": "two"}
]
JSON
pair=$(python3 "${IMPORT}" --issues "${tmp}/two.json" --tasks-dir "${two}" --apply) \
    || fail "importing two issues in one run failed: ${pair}"
[[ "$(echo "${pair}" | wc -l)" -eq 2 ]] || fail "expected two imports, got: ${pair}"
[[ "$(ls "${two}"/*.md | wc -l)" -eq 2 ]] || fail "two issues must mint two distinct task files"
echo "PASS: two importable issues in one run mint two tasks"

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

# Gate 6 (#268): the body arrives through the same MCP tool as the title and is
# escaped the same way. It is the prose a human reads to write the task's real
# gate, so storing `&#39;` for every apostrophe degrades exactly the field the
# import exists to carry across.
fresh="${tmp}/tasks3"
mkdir -p "${fresh}"
cat > "${tmp}/issues-body.json" <<'JSON'
[{"number": 61, "state": "open", "labels": [{"name": "arsenal:queue"}],
  "html_url": "https://example/61", "title": "plain",
  "body": "The flag is &quot;after-review&quot; and it doesn&#39;t fire when a &lt;br&gt; is present."}]
JSON
python3 "${IMPORT}" --issues "${tmp}/issues-body.json" --tasks-dir "${fresh}" --apply >/dev/null
written=$(cat "${fresh}"/*.md)
grep -q 'The flag is "after-review" and it doesn'"'"'t fire when a <br> is present.' \
    <<<"${written}" || fail "the imported body kept the transport's escaping: ${written}"
echo "PASS: an imported body is stored as written, not as the transport spelled it"

# Gate 7 (#270): a bare URL in the template means an MD034 hit in every imported
# task file, in every consumer that lints its markdown, forever.
grep -q 'Imported from <https://example/61>' <<<"${written}" \
    || fail "the Imported-from line must be an autolink, not a bare URL: ${written}"

fresh="${tmp}/tasks4"
mkdir -p "${fresh}"
cat > "${tmp}/issues-nourl.json" <<'JSON'
[{"number": 62, "state": "open", "labels": [{"name": "arsenal:queue"}],
  "title": "no url", "body": "x"}]
JSON
python3 "${IMPORT}" --issues "${tmp}/issues-nourl.json" --tasks-dir "${fresh}" --apply >/dev/null
grep -q 'Imported from issue #62' "${fresh}"/*.md \
    || fail "the no-URL fallback must stay unwrapped — <issue #62> reads as an HTML tag"
echo "PASS: the Imported-from line is an autolink, and the fallback is left alone"

# Gate 8 (#269): the import must hand back the label swap, not only the marker.
# Step 2 fetches the board by `arsenal:task`; an issue left on the import label
# is invisible to it, and handle_sync.py then proposes a SECOND issue for a task
# whose first issue already carries the marker.
fresh="${tmp}/tasks5"
mkdir -p "${fresh}"
row=$(python3 "${IMPORT}" --issues "${tmp}/issues-body.json" --tasks-dir "${fresh}" --apply \
    | head -1)
python3 - "${row}" <<'PY' || fail "the import row does not carry the label swap: see above"
import json, sys
row = json.loads(sys.argv[1])
missing = [k for k in ("add_to_issue_body", "add_label", "remove_label") if k not in row]
if missing:
    print(f"row is missing {missing}: {row}", file=sys.stderr)
    raise SystemExit(1)
if row["add_label"] != "arsenal:task":
    print(f"add_label must be the board label, got {row['add_label']!r}", file=sys.stderr)
    raise SystemExit(1)
if row["remove_label"] != "arsenal:queue":
    print(f"remove_label must be the import label, got {row['remove_label']!r}", file=sys.stderr)
    raise SystemExit(1)
PY
echo "PASS: the import hands back the board label, not only the handle marker"

# Gate 9: an encoded blank body still gets the "nothing here" fallback.
# `html.unescape(body.strip())` decoded AFTER stripping, so `&nbsp;` survived
# the strip as text, became a non-breaking space, and landed as a body that is
# blank on screen and truthy in code — the one case the fallback exists for.
fresh="${tmp}/tasks6"
mkdir -p "${fresh}"
cat > "${tmp}/issues-blank.json" <<'JSON'
[{"number": 63, "state": "open", "labels": [{"name": "arsenal:queue"}],
  "html_url": "https://example/63", "title": "blank", "body": "&nbsp;&#32;"}]
JSON
python3 "${IMPORT}" --issues "${tmp}/issues-blank.json" --tasks-dir "${fresh}" --apply >/dev/null
grep -q '_(no issue body)_' "${fresh}"/*.md \
    || fail "an encoded whitespace-only body was stored instead of the fallback: $(cat "${fresh}"/*.md)"
echo "PASS: a body that decodes to whitespace gets the no-body fallback"

# Gate 10: the import label may not BE the board label. The row's add_label and
# remove_label would then be the same string, and a caller applying it
# faithfully strips the label session-start step 2 uses to find the board —
# undoing the very fix the labels were added for.
set +e
out=$(python3 "${IMPORT}" --issues "${tmp}/issues-body.json" --tasks-dir "${tmp}/tasks7" \
    --label arsenal:task --apply 2>&1)
code=$?
set -e
[[ ${code} -eq 2 ]] || fail "--label arsenal:task must be refused with exit 2, got ${code}"
grep -q "board label" <<<"${out}" || fail "the refusal does not say why: ${out}"
[[ ! -d "${tmp}/tasks7" ]] || fail "the refusal must happen before anything is written"
echo "PASS: the import label cannot be the board label"

# Gate 11: a malformed body in a LATER row must not take the batch down. A body
# that is not a string reached `pattern.search()` in task_id_from_issue and
# raised a TypeError, which for --apply meant a traceback mid-batch with the
# earlier task files already written and their issues not yet relabelled. The
# batch position matters: a single-row payload fails before anything is
# written, so the one-issue body gates above never covered this.
fresh="${tmp}/tasks8"
mkdir -p "${fresh}"
cat > "${tmp}/issues-malformed.json" <<'JSON'
[{"number": 70, "state": "open", "labels": [{"name": "arsenal:queue"}],
  "html_url": "https://example/70", "title": "first", "body": "a real body"},
 {"number": 71, "state": "open", "labels": [{"name": "arsenal:queue"}],
  "html_url": "https://example/71", "title": "second", "body": []}]
JSON
set +e
out=$(python3 "${IMPORT}" --issues "${tmp}/issues-malformed.json" --tasks-dir "${fresh}" --apply 2>&1)
code=$?
set -e
[[ ${code} -eq 0 ]] || fail "a non-string body must import as an empty body, got exit ${code}: ${out}"
rows=$(grep -c '"add_to_issue_body"' <<<"${out}")
[[ ${rows} -eq 2 ]] || fail "both issues must be emitted, got ${rows} row(s): ${out}"
files=$(find "${fresh}" -name '*.md' | wc -l)
[[ ${files} -eq 2 ]] || fail "both task files must land, found ${files}"
grep -lq '_(no issue body)_' "${fresh}"/*.md \
    || fail "the malformed body must render as the fallback: $(cat "${fresh}"/*.md)"
echo "PASS: a non-string body later in a batch imports as an empty body"

# Gate 12: a body that only fails on the UTF-8 encode still rolls the batch
# back. A lone surrogate survives JSON decoding and raises UnicodeEncodeError —
# a ValueError, so an `except OSError` handler let it past the rollback with the
# file already created. Nothing may be emitted either: a row is the caller's
# instruction to relabel an issue whose task file no longer exists.
fresh="${tmp}/tasks9"
mkdir -p "${fresh}"
python3 -c 'import json,sys; json.dump([{"number":72,"state":"open","labels":[{"name":"arsenal:queue"}],"html_url":"https://example/72","title":"fine","body":"ordinary"},{"number":73,"state":"open","labels":[{"name":"arsenal:queue"}],"html_url":"https://example/73","title":"surrogate","body":"bad \ud800 body"}], open(sys.argv[1],"w"))' "${tmp}/issues-surrogate.json"
set +e
out=$(python3 "${IMPORT}" --issues "${tmp}/issues-surrogate.json" --tasks-dir "${fresh}" --apply 2>&1)
code=$?
set -e
[[ ${code} -eq 1 ]] || fail "an unencodable body must fail cleanly, got exit ${code}: ${out}"
grep -q "Rolled back" <<<"${out}" || fail "the failure must report the rollback: ${out}"
! grep -q '"add_to_issue_body"' <<<"${out}" \
    || fail "no row may be emitted for a batch that rolled back: ${out}"
files=$(find "${fresh}" -name '*.md' | wc -l)
[[ ${files} -eq 0 ]] || fail "the rollback left ${files} task file(s) behind"
echo "PASS: an unencodable body rolls the batch back and emits nothing"

# Gate 13: a task file that appears between the pre-loop directory snapshot and
# the write is never overwritten. `mint()` picks ids against a snapshot taken
# before the loop, so a concurrent import — or a worker landing its own task —
# is invisible to it, and a non-exclusive write silently destroys that file.
# Pre-creating the file cannot stage this: it would be IN the snapshot and mint
# would simply pick another id. The race is reproduced where it actually opens,
# by creating the file after the snapshot and before the write.
fresh="${tmp}/tasks10"
mkdir -p "${fresh}"
cat >"${tmp}/issues-collide.json" <<'JSON'
[{"number":80,"state":"open","labels":[{"name":"arsenal:queue"}],"html_url":"https://example/80","title":"collides","body":"ordinary"}]
JSON
set +e
out=$(IMPORT="${IMPORT}" TASKS="${fresh}" ISSUES="${tmp}/issues-collide.json" python3 - <<'PY' 2>&1
import importlib.util, os, pathlib, sys

spec = importlib.util.spec_from_file_location("issue_import", os.environ["IMPORT"])
mod = importlib.util.module_from_spec(spec)
sys.modules["issue_import"] = mod
spec.loader.exec_module(mod)

tasks = pathlib.Path(os.environ["TASKS"])
real_render = mod.render


def racing_render(issue, task_id):
    """Another writer wins the path between the snapshot and this run's write."""
    (tasks / f"{task_id}.md").write_text("PRE-EXISTING TASK\n", encoding="utf-8")
    return real_render(issue, task_id)


mod.render = racing_render
sys.argv = ["issue_import", "--issues", os.environ["ISSUES"], "--tasks-dir", str(tasks), "--apply"]
sys.exit(mod.main())
PY
)
code=$?
set -e
[[ ${code} -ne 0 ]] || fail "an id won by another writer must not import silently: ${out}"
grep -q "could not create" <<<"${out}" \
    || fail "a collision must name the create that failed: ${out}"
survivor=$(grep -rl 'PRE-EXISTING TASK' "${fresh}" || true)
[[ -n ${survivor} ]] || fail "the other writer's task file was destroyed: $(ls -A "${fresh}")"
echo "PASS: an id won by another writer is never overwritten"

echo "PASS: issue_import_test — all gates passed"
