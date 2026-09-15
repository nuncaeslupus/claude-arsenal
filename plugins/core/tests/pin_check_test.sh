#!/usr/bin/env bash
# pin_check_test.sh — the four ways a hand-run mutation cycle lies.
#
# Each of these produced a confident, wrong verdict in a real review, and none
# of them is visible to the person running the cycle:
#
#   * a `sed` that matched nothing, whose green test reads exactly like
#     "not pinned" when it is in fact "not mutated";
#   * a scoped test that was already red, which goes red under any mutation and
#     reads as a confirmation;
#   * a restore that did not happen, leaving the next session reading a mutated
#     tree as the code;
#   * a run that evaluated the tree in-process, scoring the code as it was when
#     the process started.
#
# pytest itself is stubbed: what is under test is the cycle around it, and a
# test that SKIPs wherever the dev toolchain is absent is exactly the silence
# this bundle keeps refusing elsewhere.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIN="${SCRIPT_DIR}/../skills/pin-check/scripts/pin_check.py"
[[ -f "${PIN}" ]] || { echo "SKIP: pin_check.py not found at ${PIN}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# A stub `pytest` module: it goes red when the source contains RED_IF, and
# records one line per run — its pid, whether bytecode writing was off, and
# what it read from disk. That log is how the cycle is inspected.
mkdir -p "${tmp}/stub/pytest" "${tmp}/proj/pkg"
cat > "${tmp}/stub/pytest/__init__.py" <<'PY'
PY
cat > "${tmp}/stub/pytest/__main__.py" <<'PY'
import os, pathlib, sys
src = pathlib.Path(os.environ["STUB_SOURCE"])
text = src.read_text(encoding="utf-8")
log = pathlib.Path(os.environ["STUB_LOG"])
with log.open("a", encoding="utf-8") as fh:
    fh.write(f"{os.getpid()}|{os.environ.get('PYTHONDONTWRITEBYTECODE', '')}|"
             f"{'MUT' if os.environ['STUB_RED_IF'] in text else 'ORIG'}|"
             f"{'CACHE' if any(src.parent.rglob('__pycache__')) else 'CLEAN'}\n")
if os.environ.get("STUB_ALWAYS_RED") == "1":
    sys.exit(1)
sys.exit(1 if os.environ["STUB_RED_IF"] in text else 0)
PY

SRC="${tmp}/proj/pkg/subject.py"
ORIGINAL='VALUE = "asynchronous"'
reset() {
    printf '%s\n' "${ORIGINAL}" > "${SRC}"
    rm -f "${tmp}/log" "${SRC}.pin_check_active"
    mkdir -p "${tmp}/proj/pkg/__pycache__"
    : > "${tmp}/proj/pkg/__pycache__/stale.pyc"
}

run() {
    PYTHONPATH="${tmp}/stub" STUB_SOURCE="${SRC}" STUB_LOG="${tmp}/log" \
    STUB_RED_IF="${RED_IF:-VALUE = \"async\"}" STUB_ALWAYS_RED="${ALWAYS_RED:-0}" \
    python3 "${PIN}" --source "${SRC}" --replace 'asynchronous' --with 'async' \
        --test tests/test_subject.py --cwd "${tmp}/proj" --root "${tmp}/proj" "$@" 2>&1
}
runs() { [[ -f "${tmp}/log" ]] && wc -l < "${tmp}/log" | tr -d ' ' || echo 0; }
intact() {
    [[ "$(cat "${SRC}")" == "${ORIGINAL}" ]] || fail "$1: the source was left mutated"
    [[ ! -e "${SRC}.pin_check_active" ]] || fail "$1: the sentinel outlived the run"
}

# --- PINNED: the mutation reaches the run, and the tree comes back ----------
reset
out=$(run); rc=$?
[[ ${rc} -eq 0 ]] || fail "a caught mutation should exit 0, got ${rc}: ${out}"
grep -q "^PINNED" <<<"${out}" || fail "expected PINNED, got: ${out}"
intact "PINNED"
grep -q "|MUT|" "${tmp}/log" || fail "the test run must see the MUTATED file on disk"
[[ "$(runs)" == "2" ]] || fail "expected a baseline run and a mutated run, got $(runs)"
echo "PASS: a caught mutation is PINNED, and the tree is restored"

# --- the run is a fresh subprocess, with no bytecode cache ------------------
# Clearing __pycache__ does not close the resident-module trap: a module already
# imported is not re-read whatever is on disk, which scores the pre-mutation
# code and manufactures a finding against correct code.
pids=$(cut -d'|' -f1 "${tmp}/log" | sort -u | wc -l | tr -d ' ')
[[ "${pids}" == "2" ]] || fail "each run must be its own process, saw ${pids} pid(s)"
grep -q "|1|" "${tmp}/log" || fail "bytecode writing must be off in the run"
grep -q "|CLEAN$" "${tmp}/log" || fail "__pycache__ must be purged before each run"
grep -q "|CACHE$" "${tmp}/log" && fail "a stale __pycache__ survived into a run"
echo "PASS: every run is a fresh subprocess over a purged, non-writing tree"

# --- NOT PINNED: the test stayed green over a real mutation -----------------
reset
out=$(RED_IF='nothing-matches-this' run); rc=$?
[[ ${rc} -eq 1 ]] || fail "an uncaught mutation should exit 1, got ${rc}: ${out}"
grep -q "^NOT PINNED" <<<"${out}" || fail "expected NOT PINNED, got: ${out}"
grep -q "1×" <<<"${out}" || fail "the verdict should say the target was really there: ${out}"
intact "NOT PINNED"
echo "PASS: a green test over a real mutation is NOT PINNED, with the count"

# --- NOT MUTATED is not a green, and runs nothing ---------------------------
reset
out=$(PYTHONPATH="${tmp}/stub" STUB_SOURCE="${SRC}" STUB_LOG="${tmp}/log" \
      STUB_RED_IF='x' STUB_ALWAYS_RED=0 \
      python3 "${PIN}" --source "${SRC}" --replace 'not-in-the-file' --with 'z' \
          --test t.py --cwd "${tmp}/proj" 2>&1); rc=$?
[[ ${rc} -eq 3 ]] || fail "an absent target should exit 3, not 0 or 1, got ${rc}: ${out}"
grep -q "^NOT MUTATED" <<<"${out}" || fail "expected NOT MUTATED, got: ${out}"
[[ -z "$(runs)" || "$(runs)" == "0" ]] || fail "nothing should have been run at all"
intact "NOT MUTATED"
echo "PASS: a target that is not there is NOT MUTATED, and runs no test"

# --- --expect-count refuses a different experiment --------------------------
reset
printf '%s\nALSO = "asynchronous"\n' "${ORIGINAL}" > "${SRC}"
out=$(run --expect-count 1); rc=$?
[[ ${rc} -eq 3 ]] || fail "two occurrences with --expect-count 1 should exit 3: ${out}"
grep -qi "different experiment" <<<"${out}" || fail "the refusal should say why: ${out}"
echo "PASS: --expect-count refuses to mutate more than the claim is about"

# --- INCONCLUSIVE: an already-red test proves nothing ------------------------
# Going red under a mutation is only evidence if it was green before it.
reset
out=$(ALWAYS_RED=1 run); rc=$?
[[ ${rc} -eq 4 ]] || fail "a baseline-red test should exit 4, not 0, got ${rc}: ${out}"
grep -q "^INCONCLUSIVE" <<<"${out}" || fail "expected INCONCLUSIVE, got: ${out}"
grep -q "|MUT|" "${tmp}/log" && fail "nothing should be mutated once the baseline is red"
intact "INCONCLUSIVE"
echo "PASS: a test that was already failing is INCONCLUSIVE, and nothing is mutated"

# --- a killed run leaves a recoverable tree, and the next run refuses -------
reset
printf 'the original\n' > "${SRC}.pin_check_active"
out=$(run); rc=$?
[[ ${rc} -eq 2 ]] || fail "a leftover sentinel should be an error, got ${rc}: ${out}"
grep -q "pin_check_active" <<<"${out}" || fail "the refusal must name the sentinel: ${out}"
grep -q "cp " <<<"${out}" || fail "the refusal must say how to restore: ${out}"
[[ "$(cat "${SRC}")" == "${ORIGINAL}" ]] || fail "a refused run must not touch the source"
[[ -f "${SRC}.pin_check_active" ]] || fail "a refused run must not delete the recovery copy"
echo "PASS: an abandoned mutation is recoverable and blocks the next run"

# --- --json carries the verdict and the count -------------------------------
reset
out=$(run --json)
python3 -c "
import json,sys
d=json.loads(sys.argv[1])
assert d['verdict']=='PINNED', d
assert d['exit']==0 and d['occurrences']==1, d
" "${out}" || fail "--json should carry verdict/exit/occurrences: ${out}"
echo "PASS: --json reports the verdict, the exit code and the occurrence count"

echo "PASS: pin_check_test — one claim, one mutation, and no confident wrong answer"
exit 0
