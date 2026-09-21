#!/usr/bin/env bash
# query_status_report_test.sh — the board reports the same findings to a machine
# as to a human, and resolving it is one pass over the issues.
#
# `--json` printed `problems` and returned. `warnings` and `notes` — a duplicate
# task id, malformed front matter, a title collision, the mixed-priority
# warning — were rendered only after that return. JSON is the documented
# cheap-fetch path, so the automated caller was the blind one: `--json
# --fail-on-problems` never learned the board had two tasks sharing an id.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPT_DIR}/../skills/init/assets/scripts"
QS="${SCRIPTS}/query_status.py"
[[ -f "${QS}" ]] || { echo "FAIL: ${QS} not found" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

tasks="${tmp}/tasks"
mkdir -p "${tasks}"
task() {  # task <file> <id> <title> <priority> [gate]
    {
        printf -- '---\nid: %s\ntitle: "%s"\npriority: %s\n---\n\n## Acceptance gate\n\n' "$2" "$3" "$4"
        [[ "${5:-yes}" == "yes" ]] && printf '```bash\ntrue\n```\n'
    } > "${tasks}/$1.md"
}
# A duplicate id (warning), a gateless task (problem), and two priority scales
# in one board (warning) — one of each channel.
task a t-rep00001 "first"          10
task b t-rep00001 "duplicate id"   10
task c t-rep00002 "no gate here"   5  no
task d t-rep00003 "ranked, not sized" 95

# --- 1: stderr is identical whichever format was asked for -------------------
python3 "${QS}" --tasks-dir "${tasks}" --no-remote-check >/dev/null 2>"${tmp}/text.err"
python3 "${QS}" --tasks-dir "${tasks}" --no-remote-check --json >/dev/null 2>"${tmp}/json.err"
if ! diff -q "${tmp}/text.err" "${tmp}/json.err" >/dev/null; then
    echo "FAIL: a --json caller is told less than a text caller:" >&2
    diff "${tmp}/text.err" "${tmp}/json.err" >&2
    exit 1
fi
for needle in "duplicate id" "no fenced gate block" "mixed-priority-convention"; do
    grep -q "${needle}" "${tmp}/json.err" \
        || fail "--json mode never reported '${needle}': $(cat "${tmp}/json.err")"
done
echo "PASS: --json reports every finding a text caller gets"

# --- 2: and --fail-on-problems still fails in JSON mode ----------------------
python3 "${QS}" --tasks-dir "${tasks}" --no-remote-check --json --fail-on-problems \
    >/dev/null 2>/dev/null
[[ $? -eq 1 ]] || fail "--json --fail-on-problems did not fail on a board with problems"
echo "PASS: --json --fail-on-problems still exits 1"

# --- 3: the board is resolved in one pass over the issues --------------------
#     Both resolution sites rescanned every issue per task: O(tasks x issues) on
#     the path the session-start protocol runs, ~40,000 matches at the 200-task
#     scale the queue is designed for.
for i in $(seq 1 30); do task "s${i}" "t-scale0${i}" "scale task ${i}" 5; done
python3 - "${SCRIPTS}" "${tasks}" "${tmp}" <<'PY' || exit 1
import json
import sys
from pathlib import Path

scripts, tasks_dir, tmp = sys.argv[1], sys.argv[2], Path(sys.argv[3])
sys.path.insert(0, scripts)

issues = [
    {"number": 100 + i, "title": f"scale task {i}", "state": "OPEN", "labels": [], "assignees": []}
    for i in range(1, 31)
]
(tmp / "issues.json").write_text(json.dumps(issues), encoding="utf-8")

import task_select

calls = 0
real = task_select.task_id_from_issue


def counted(*a, **kw):
    global calls
    calls += 1
    return real(*a, **kw)


task_select.task_id_from_issue = counted
import issue_for_task

issue_for_task.task_id_from_issue = counted
import query_status

query_status.main(
    ["--tasks-dir", tasks_dir, "--issues", str(tmp / "issues.json"), "--no-remote-check"]
)
# One pass for the state map and one for the handle map, plus slack. The old
# shape was two scans per task: 34 tasks x 30 issues x 2 = over 2000.
budget = 6 * len(issues)
if calls > budget:
    print(
        f"FAIL: resolving the board took {calls} issue matches for {len(issues)} issues "
        f"— budget {budget}; it is still scanning the list per task",
        file=sys.stderr,
    )
    sys.exit(1)
print(f"PASS: the board resolves in {calls} issue matches for {len(issues)} issues")
PY

echo "PASS: query_status_report_test — all gates passed"
