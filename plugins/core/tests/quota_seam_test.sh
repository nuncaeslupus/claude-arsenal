#!/usr/bin/env bash
# quota_seam_test.sh — the quota guard's documented override actually works,
# and the shape the docs say does NOT satisfy it really does not (#329).
#
# `ARSENAL_RATE_LIMITS_FILE` shipped working and documented nowhere, which on a
# cloud session — the surface with no statusLine, and the one most likely to be
# running an unattended fleet — left the percentage guard permanently inert with
# no way to find the seam that fixes it. This pins the example printed in
# references/quota-governance.md so the doc cannot drift away from the code.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
BUDGET="${ASSETS}/bin/budget_check.sh"
DOC="${ASSETS}/references/quota-governance.md"
KNOBS="${ASSETS}/references/worker-loop.md"

[[ -f "${BUDGET}" ]] || { echo "SKIP: budget_check.sh not found" >&2; exit 0; }

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

# Iteration state must not leak between cases, or the round cap fires instead
# of the quota check and every exit code below means something else.
export ARSENAL_ITER_STATE_FILE="${tmp}/iters.json"
export ARSENAL_MAX_ITERATIONS=0

_check() {  # $1 = json body; echoes the exit code
    printf '%s' "$1" > "${tmp}/rl.json"
    ARSENAL_RATE_LIMITS_FILE="${tmp}/rl.json" bash "${BUDGET}" >/dev/null 2>&1
    echo $?
}

# The seam itself: the override must be read at all.
rc="$(_check '{"five_hour": {"used_percentage": 95, "resets_at": "2026-09-04T12:00:00Z"}}')"
[[ "${rc}" -eq 3 ]] || fail "the documented override did not engage the guard (exit ${rc}, expected 3)"
echo "PASS: ARSENAL_RATE_LIMITS_FILE is read, and the guard stops at 95%"

rc="$(_check '{"five_hour": {"used_percentage": 10}}')"
[[ "${rc}" -eq 0 ]] || fail "a below-threshold snapshot stopped the loop (exit ${rc}, expected 0)"
echo "PASS: a below-threshold snapshot does not stop the loop"

rc="$(_check '{"seven_day": {"used_percentage": 99}}')"
[[ "${rc}" -eq 3 ]] || fail "the seven_day window is not checked (exit ${rc}, expected 3)"
echo "PASS: the seven_day window engages the guard too"

# The trap the doc warns about: a document that plainly describes exhaustion in
# another vocabulary still buys nothing, and says nothing about it.
for shape in '{"status": "allowed", "rateLimitType": "five_hour"}' \
             '{"status": "rejected"}' \
             '{"five_hour": {"used_percentage": "95"}}'; do
    rc="$(_check "${shape}")"
    [[ "${rc}" -eq 0 ]] \
        || fail "a shape the docs call unsatisfying returned ${rc}, expected 0 (fail open): ${shape}"
done
echo "PASS: a non-conforming shape fails open, as documented"

# The doc must keep carrying a working example. If someone edits the JSON in
# quota-governance.md into something budget_check.sh does not accept, this
# fails — which is the whole point of pinning it.
if [[ -f "${DOC}" ]]; then
    grep -q 'ARSENAL_RATE_LIMITS_FILE' "${DOC}" \
        || fail "quota-governance.md no longer documents ARSENAL_RATE_LIMITS_FILE"
    example="$(grep -o '{"five_hour": *{"used_percentage": *[0-9]*[^}]*}}' "${DOC}" | head -1)"
    [[ -n "${example}" ]] || fail "quota-governance.md carries no machine-checkable example"
    rc="$(_check "${example}")"
    [[ "${rc}" -eq 3 ]] \
        || fail "the example printed in quota-governance.md does not engage the guard (exit ${rc})"
    echo "PASS: the example printed in the docs is one budget_check.sh accepts"
fi

if [[ -f "${KNOBS}" ]]; then
    grep -q 'ARSENAL_RATE_LIMITS_FILE' "${KNOBS}" \
        || fail "the tuning-knobs table does not list ARSENAL_RATE_LIMITS_FILE"
    echo "PASS: the knob is listed in the tuning table"
fi

echo "PASS: quota_seam_test — all gates passed"
exit 0
