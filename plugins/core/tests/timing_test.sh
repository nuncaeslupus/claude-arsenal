#!/usr/bin/env bash
# timing_test.sh — the metrics helper must record, must not forge, must not fail.
#
# `_timing.sh` is instrumentation wired into four scripts that do real work, so
# its failure modes are not "the number is wrong" — they are "the gate died
# because the metrics directory was read-only" and "the loop stopped writing the
# day someone dropped a source line in a refactor". Both are silent in the
# direction that matters: nothing fails loudly, the data is just not there when
# the question finally gets asked.
#
# So this checks the three things that cannot be seen by reading the diff: a
# begin/end pair really lands a parseable row, a label carrying a tab cannot
# forge one, and the reporter reads what the helper writes. It also asserts the
# four boundary scripts still source the helper — the wiring, not the helper,
# is what a refactor quietly removes.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
HELPER="${ASSETS}/bin/_timing.sh"
REPORTER="${ASSETS}/scripts/arsenal_timings.py"

[[ -f "${HELPER}" && -f "${REPORTER}" ]] \
    || { echo "SKIP: timing helper not found under ${ASSETS}" >&2; exit 0; }

fail=0
note() { echo "FAIL: $1" >&2; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# A real repo root, because _arsenal_metrics_file asks git for one. Without
# this the helper would fall back to $PWD, which under `make test` is the
# arsenal checkout itself — the test would then write into the tree it is
# testing, and pass for the wrong reason.
git -C "${tmp}" init -q 2>/dev/null || { echo "SKIP: git unavailable" >&2; exit 0; }
METRICS="${tmp}/tmp/arsenal-metrics/metrics.tsv"

# --- 1: a begin/end pair lands one parseable row ---
( cd "${tmp}" && source "${HELPER}" \
    && arsenal_timing_begin gate "suite-a" "T-1" \
    && arsenal_timing_end 0 ) || note "begin/end returned non-zero"

if [[ -f "${METRICS}" ]]; then
    n=$(wc -l < "${METRICS}")
    [[ "${n}" -eq 1 ]] || note "expected 1 row after one begin/end pair, got ${n}"
    IFS=$'\t' read -r stamp event label ms code task < "${METRICS}"
    [[ "${event}" == "gate" ]] || note "event column is '${event}', expected 'gate'"
    [[ "${label}" == "suite-a" ]] || note "label column is '${label}'"
    [[ "${task}" == "T-1" ]] || note "task column is '${task}'"
    [[ "${code}" == "0" ]] || note "exit-code column is '${code}'"
    [[ "${ms}" =~ ^[0-9]+$ ]] || note "duration '${ms}' is not a number"
    [[ "${stamp}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
        || note "timestamp '${stamp}' is not the ISO-8601 form the reporter parses"
else
    note "no metrics file written at ${METRICS}"
fi

# --- 2: the directory ignores itself ---
# open_task_pr.sh stages with `git add -A`. Without this the metrics file rides
# into the next task commit in any repo whose .gitignore does not cover tmp/.
[[ "$(cat "${tmp}/tmp/arsenal-metrics/.gitignore" 2>/dev/null)" == "*" ]] \
    || note "metrics directory has no self-ignoring .gitignore"
[[ -z "$(git -C "${tmp}" status --porcelain -- tmp 2>/dev/null)" ]] \
    || note "metrics files show up in git status — they would be committed"

# --- 3: a label cannot forge a row ---
# Labels are caller-chosen strings (a task id, a branch, a suite name). A tab or
# a newline in one would either shift every column or append a second row.
( cd "${tmp}" && source "${HELPER}" \
    && arsenal_timing_record gate "$(printf 'a\tb\nc')" 5 0 "T-2" ) \
    || note "record with a hostile label returned non-zero"
n=$(wc -l < "${METRICS}")
[[ "${n}" -eq 2 ]] || note "a tab/newline label produced ${n} rows in total, expected 2"
fields=$(awk 'NR==2 {print NF}' FS='\t' "${METRICS}")
[[ "${fields}" -eq 6 ]] || note "hostile label produced ${fields} columns, expected 6"

# --- 4: end without begin, and end twice, record nothing extra ---
# gate_run.sh calls arsenal_timing_end from a cleanup trap that also runs on
# paths where begin never ran, and a chained EXIT trap can reach it twice.
( cd "${tmp}" && source "${HELPER}" && arsenal_timing_end 0 ) \
    || note "arsenal_timing_end without a begin returned non-zero"
( cd "${tmp}" && source "${HELPER}" \
    && arsenal_timing_begin gate x T-3 && arsenal_timing_end 0 && arsenal_timing_end 0 )
n=$(wc -l < "${METRICS}")
[[ "${n}" -eq 3 ]] || note "end-without-begin / double-end wrote extra rows (${n}, expected 3)"

# --- 4b: a worktree writes to the MAIN repo's file ---
# Workers run in throwaway worktrees. A toplevel-anchored metrics file would be
# deleted with the worktree that wrote it, so the fleet — the case most worth
# measuring — would silently record nothing that survives.
git -C "${tmp}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
if git -C "${tmp}" worktree add -q "${tmp}/wt" -b wt 2>/dev/null; then
    before=$(wc -l < "${METRICS}")
    ( cd "${tmp}/wt" && source "${HELPER}" \
        && arsenal_timing_begin task-pr wt-test T-W && arsenal_timing_end 0 )
    [[ -f "${tmp}/wt/tmp/arsenal-metrics/metrics.tsv" ]] \
        && note "a worktree wrote its own metrics file — it dies with the worktree"
    [[ $(wc -l < "${METRICS}") -eq $((before + 1)) ]] \
        || note "a worktree's row did not land in the main repo's metrics file"
else
    echo "  (skipping worktree check: git worktree unavailable)"
fi

# --- 5: negative control — ARSENAL_METRICS=off records nothing ---
before=$(wc -l < "${METRICS}")
( cd "${tmp}" && ARSENAL_METRICS=off bash -c \
    "source '${HELPER}'; arsenal_timing_begin gate off-test T-4; arsenal_timing_end 0" ) \
    || note "the off path returned non-zero"
after=$(wc -l < "${METRICS}")
[[ "${before}" -eq "${after}" ]] \
    || note "ARSENAL_METRICS=off still recorded ($((after - before)) rows)"

# --- 6: an unwritable metrics directory must not fail the caller ---
# This is the one that matters most: the helper runs inside gate_run.sh, and a
# metrics write that can fail is a gate that can fail for a reason unrelated to
# the change under test.
ro="${tmp}/ro"
mkdir -p "${ro}/tmp/arsenal-metrics" && : > "${ro}/tmp/arsenal-metrics/metrics.tsv"
chmod -w "${ro}/tmp/arsenal-metrics/metrics.tsv"
if [[ -w "${ro}/tmp/arsenal-metrics/metrics.tsv" ]]; then
    echo "  (skipping unwritable-file check: running as a user that ignores the mode)"
else
    ( cd "${ro}" && source "${HELPER}" \
        && arsenal_timing_begin gate ro T-5 && arsenal_timing_end 0 ) \
        || note "a read-only metrics file made the helper return non-zero"
fi
chmod +w "${ro}/tmp/arsenal-metrics/metrics.tsv" 2>/dev/null

# --- 7: the reporter reads what the helper wrote ---
# The two halves are a file format apart, so they can drift without either one
# breaking on its own. Run the reporter over the rows above, not over a fixture.
out="$(cd "${tmp}" && python3 "${REPORTER}" --days 0 2>&1)"
rc=$?
[[ ${rc} -eq 0 ]] || note "reporter exited ${rc} over real helper output: ${out}"
grep -q 'gate' <<<"${out}" || note "reporter output never mentions the recorded event: ${out}"

# The empty case has to be a usable message, not a traceback: it is the first
# thing any new consumer sees.
empty="$(cd "${ro}" && ARSENAL_METRICS=off python3 "${REPORTER}" 2>&1)"
grep -qi 'nothing recorded\|no rows' <<<"${empty}" \
    || note "reporter's empty case does not say what to do: ${empty}"

# --- 8: the wiring — every boundary script still sources the helper ---
# The helper can be perfect and collect nothing. This is the check that fails
# when a refactor drops a source line.
for script in gate_run.sh open_task_pr.sh merge_ready.sh adversarial_review.sh; do
    path="${ASSETS}/bin/${script}"
    [[ -f "${path}" ]] || { note "${script} is missing from the bundle"; continue; }
    grep -q '_timing\.sh' "${path}" || note "${script} no longer sources _timing.sh"
    grep -qE 'arsenal_timing_(begin|record)' "${path}" \
        || note "${script} sources the helper but never records anything"
done
# A recorded begin with no end is a row that never lands.
for script in gate_run.sh open_task_pr.sh merge_ready.sh; do
    grep -q 'arsenal_timing_end' "${ASSETS}/bin/${script}" \
        || note "${script} calls begin but never end — nothing is ever written"
done

if [[ ${fail} -eq 0 ]]; then
    echo "PASS: timing_test — boundaries record, labels cannot forge, failures stay silent"
    exit 0
fi
exit 1
