#!/usr/bin/env bash
# run_gate_test.sh — the plan audit must not exit 0 for a gate nobody verified.
#
# `run_gate.py` reads the plan's Gate column and its Evidence log and reports
# whether each task's gate is met. The skill's own documented rule is that a
# non-numeric gate "reports manual, never PASS … and is never auto-passed" —
# and the `verdict` field honoured that. The EXIT CODE did not: a prose gate
# with no evidence row at all produced `? … verify manually` and exit 0, which
# to a caller — CI, release.sh, another script — is indistinguishable from a
# clean audit. #302 found it; this pins the distinction that fixes it:
#
#   prose gate + no evidence recorded  → incomplete, exit 1
#   prose gate + evidence recorded     → manual, exit 0 (a human looked)
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_GATE="${here}/../skills/gate-check/scripts/run_gate.py"
[[ -f "${RUN_GATE}" ]] || { echo "SKIP: run_gate.py not found" >&2; exit 0; }

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

audit() {  # audit <plan-file> -> prints report, returns exit code
    python3 "${RUN_GATE}" --input "$1" 2>&1
}

# --- a prose gate with no evidence is incomplete, not clean -----------------
cat > "${tmp}/unverified.md" <<'MD'
# Plan

## Implementation tasks

| T# | Description | Gate |
|----|-------------|------|
| T1 | numeric one | `coverage >= 90` |
| T2 | prose one   | all golden files identical |

## Evidence log

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | `coverage >= 90` | 93 | `make cov` | abc123 | ci | 2026-09-01 |
MD
out="$(audit "${tmp}/unverified.md")"; code=$?
[[ ${code} -eq 1 ]] \
    || fail "a prose gate with no evidence must not exit 0 (got ${code}):
${out}"
grep -q "T2" <<<"${out}" || fail "the report must name the unverified task: ${out}"
grep -qi "missing" <<<"${out}" || fail "the report must say what is missing: ${out}"
grep -q "1 passing" <<<"${out}" || fail "the numeric task must still pass: ${out}"
echo "PASS: a non-numeric gate with no evidence recorded fails the audit"

# --- ...and one a human DID record still passes ----------------------------
# The rule is "never auto-passed", not "never passes": a prose gate is exactly
# the kind that needs a person to write down what they checked. Making every
# manual gate a hard failure would delete a legitimate state and push authors
# towards a weaker, measurable gate instead.
cat > "${tmp}/verified.md" <<'MD'
# Plan

## Implementation tasks

| T# | Description | Gate |
|----|-------------|------|
| T2 | prose one   | all golden files identical |

## Evidence log

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T2 | all golden files identical | n/a — inspected | `make golden` | abc123 | ci | 2026-09-01 |
MD
out="$(audit "${tmp}/verified.md")"; code=$?
[[ ${code} -eq 0 ]] || fail "a manual gate with complete evidence must pass (got ${code}):
${out}"
grep -qi "manual\|by hand" <<<"${out}" \
    || fail "the report must still mark it as human-verified rather than PASS: ${out}"
grep -q "0 passing" <<<"${out}" \
    || fail "a manual gate must never be counted as PASS: ${out}"
echo "PASS: a non-numeric gate a human recorded still passes, and is never PASS"

# --- a numeric gate below its threshold still fails -------------------------
cat > "${tmp}/failing.md" <<'MD'
# Plan

## Implementation tasks

| T# | Description | Gate |
|----|-------------|------|
| T1 | numeric one | `coverage >= 90` |

## Evidence log

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | `coverage >= 90` | 42 | `make cov` | abc123 | ci | 2026-09-01 |
MD
out="$(audit "${tmp}/failing.md")"; code=$?
[[ ${code} -eq 1 ]] || fail "a violated numeric gate must exit 1 (got ${code}): ${out}"
grep -q "FAIL" <<<"${out}" || fail "a violated gate must say FAIL: ${out}"
echo "PASS: a numeric gate below its threshold still fails"

echo "PASS: run_gate_test — all gates passed"
