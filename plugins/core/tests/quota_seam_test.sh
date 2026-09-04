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

# A refusal is its own stop condition, not a percentage. These two shapes carry
# no `used_percentage` at all — they are what `get_session` gives a cloud
# session — and used to land in the "no used_percentage" fail-open, which is the
# half of #329 that left the guard inert on the one surface that runs unattended.
for shape in '{"status": "rejected", "rateLimitType": "five_hour", "resetsAt": 1787709000}' \
             '{"five_hour": {"status": "rejected"}}' \
             '{"five_hour": {"status": "throttled"}}'; do
    rc="$(_check "${shape}")"
    [[ "${rc}" -eq 3 ]] \
        || fail "a refusal did not stop the loop (exit ${rc}, expected 3): ${shape}"
done
echo "PASS: a refusal stops the loop with no percentage anywhere in the document"

# A MALFORMED status is an unrecognised status. Keying the check on the value
# being a string let `null`, `false` and `0` fall through to the no-percentage
# fail-open — a present status permitting another dispatch, which is the one
# outcome the polarity forbids. Presence of the KEY is what decides.
for shape in '{"status": null}' \
             '{"status": false}' \
             '{"five_hour": {"status": 0}}' \
             '{"five_hour": {"status": null}}'; do
    rc="$(_check "${shape}")"
    [[ "${rc}" -eq 3 ]] \
        || fail "a present-but-malformed status did not stop the loop (exit ${rc}): ${shape}"
done
echo "PASS: a present status that is not \"allowed\" stops, malformed values included"

# ...and an ABSENT status is not a malformed one. These must still fail open, or
# every document written before this shape existed becomes a hard stop.
for shape in '{"five_hour": {"used_percentage": 10}}' \
             '{}'; do
    rc="$(_check "${shape}")"
    [[ "${rc}" -eq 0 ]] \
        || fail "an absent status was treated as a refusal (exit ${rc}): ${shape}"
done
echo "PASS: an absent status is not a refusal"

# A window that is not an object at all used to raise AttributeError and escape
# as exit 1 — the loud "stop" code — from a document the contract says fails
# open. Unreadable is unreadable, whatever its shape.
rc="$(_check '{"five_hour": "nonsense"}')"
[[ "${rc}" -eq 0 ]] \
    || fail "a non-object window did not fail open (exit ${rc})"
echo "PASS: a non-object window fails open instead of crashing"

# The property that makes it a SEPARATE signal rather than a synthesised 100%:
# no threshold setting can talk the loop past a refusal. If the refusal were
# mapped onto the percentage path, ARSENAL_QUOTA_STOP_PCT=101 would disable it.
printf '%s' '{"status": "rejected"}' > "${tmp}/rl.json"
ARSENAL_QUOTA_STOP_PCT=101 ARSENAL_RATE_LIMITS_FILE="${tmp}/rl.json" \
    bash "${BUDGET}" >/dev/null 2>&1
[[ $? -eq 3 ]] || fail "ARSENAL_QUOTA_STOP_PCT=101 talked the loop past a refusal"
echo "PASS: ARSENAL_QUOTA_STOP_PCT cannot disable the refusal stop"

# `allowed` is an answer, not missing data — it must not stop the loop, and it
# must not be reported as a fail-open either.
printf '%s' '{"status": "allowed", "rateLimitType": "five_hour"}' > "${tmp}/rl.json"
out="$(ARSENAL_RATE_LIMITS_FILE="${tmp}/rl.json" bash "${BUDGET}" 2>&1)"
rc=$?
[[ "${rc}" -eq 0 ]] || fail "status=allowed stopped the loop (exit ${rc})"
grep -q 'failing open' <<<"${out}" \
    && fail "status=allowed was reported as a fail-open: ${out}"
echo "PASS: status=allowed passes, and is not reported as missing data"

# Genuinely unusable data still fails open — the quota half of the guard is not
# allowed to stop a loop over a document it cannot read.
for shape in '{"five_hour": {"used_percentage": "95"}}' \
             '{"five_hour": {}}'; do
    rc="$(_check "${shape}")"
    [[ "${rc}" -eq 0 ]] \
        || fail "an unreadable shape returned ${rc}, expected 0 (fail open): ${shape}"
done
echo "PASS: a shape carrying neither signal still fails open, as documented"

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
