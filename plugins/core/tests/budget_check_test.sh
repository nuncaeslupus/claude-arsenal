#!/usr/bin/env bash
# budget_check_test.sh — unit test for budget_check.sh (token-budget stop).
# Asserts: exit 3 over threshold (either window), exit 0 under, and exit 0
# fail-open when the file is missing or the data is absent/unparseable.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUDGET="${SCRIPT_DIR}/../skills/init/assets/bin/budget_check.sh"

if [[ ! -f "${BUDGET}" ]]; then
    echo "SKIP: budget_check.sh not found at ${BUDGET}" >&2; exit 0
fi

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

FILE="${tmpdir}/rate_limits.json"
ITER="${tmpdir}/budget_iterations.json"

# rc <expected> <description>; runs budget_check.sh with ARSENAL_RATE_LIMITS_FILE.
# The dispatch-round cap is disabled here (ARSENAL_MAX_ITERATIONS=0) so these
# gates isolate the quota check; the cap has its own gates below. The iter-state
# file is kept inside tmpdir so the test never writes into the repo.
expect_rc() {
    local want="$1" desc="$2"; shift 2
    set +e
    ARSENAL_RATE_LIMITS_FILE="${FILE}" ARSENAL_QUOTA_STOP_PCT=90 \
        ARSENAL_MAX_ITERATIONS=0 ARSENAL_ITER_STATE_FILE="${ITER}" \
        bash "${BUDGET}" >/dev/null 2>&1
    local got=$?
    set -e
    if [[ "${got}" -ne "${want}" ]]; then
        echo "FAIL: ${desc} — expected exit ${want}, got ${got}" >&2; exit 1
    fi
    echo "PASS: ${desc} (exit ${got})"
}

# Gate 1: missing file → fail-open (exit 0).
rm -f "${FILE}"
expect_rc 0 "missing file fails open"

# Gate 2: both windows well under threshold → exit 0.
cat > "${FILE}" <<'JSON'
{"five_hour":{"used_percentage":10},"seven_day":{"used_percentage":20}}
JSON
expect_rc 0 "under threshold proceeds"

# Gate 3: five_hour over threshold → exit 3.
cat > "${FILE}" <<'JSON'
{"five_hour":{"used_percentage":95,"resets_at":1234567890},"seven_day":{"used_percentage":20}}
JSON
expect_rc 3 "five_hour over threshold stops"

# Gate 4: only seven_day over threshold → exit 3.
cat > "${FILE}" <<'JSON'
{"five_hour":{"used_percentage":12},"seven_day":{"used_percentage":91}}
JSON
expect_rc 3 "seven_day over threshold stops"

# Gate 5: exactly at threshold (90) → exit 3 (>= is inclusive).
cat > "${FILE}" <<'JSON'
{"five_hour":{"used_percentage":90},"seven_day":{"used_percentage":1}}
JSON
expect_rc 3 "at-threshold stops (inclusive)"

# Gate 6: present file but no used_percentage fields → fail-open.
cat > "${FILE}" <<'JSON'
{"five_hour":{},"seven_day":{}}
JSON
expect_rc 0 "absent percentages fail open"

# Gate 7: unparseable file → fail-open.
printf 'not json' > "${FILE}"
expect_rc 0 "unparseable file fails open"

# --- Dispatch-round cap (CA-08): always-available, quota-independent ---
# No rate_limits.json at all, so the quota check fails open — only the cap can
# stop the loop here. Cap of 3 with a fresh state file: rounds 1-3 pass, 4 stops.
rm -f "${FILE}" "${ITER}"
cap_rc() {
    set +e
    ARSENAL_RATE_LIMITS_FILE="${FILE}" ARSENAL_MAX_ITERATIONS=3 \
        ARSENAL_ITER_STATE_FILE="${ITER}" CLAUDE_SESSION_ID="sess-cap" \
        bash "${BUDGET}" >/dev/null 2>&1
    local got=$?
    set -e
    echo "${got}"
}
for round in 1 2 3; do
    got=$(cap_rc)
    if [[ "${got}" -ne 0 ]]; then
        echo "FAIL: round ${round} under cap should exit 0, got ${got}" >&2; exit 1
    fi
done
got=$(cap_rc)
if [[ "${got}" -ne 3 ]]; then
    echo "FAIL: round 4 over cap should exit 3, got ${got}" >&2; exit 1
fi
echo "PASS: dispatch-round cap stops the loop past ARSENAL_MAX_ITERATIONS"

# A different session resets the counter (fresh round 1 passes despite the file).
got=$(set +e; ARSENAL_RATE_LIMITS_FILE="${FILE}" ARSENAL_MAX_ITERATIONS=3 \
    ARSENAL_ITER_STATE_FILE="${ITER}" CLAUDE_SESSION_ID="sess-other" \
    bash "${BUDGET}" >/dev/null 2>&1; echo $?)
if [[ "${got}" -ne 0 ]]; then
    echo "FAIL: new session should reset the cap counter, got exit ${got}" >&2; exit 1
fi
echo "PASS: cap counter resets per CLAUDE_SESSION_ID"

echo "PASS: budget_check_test — all gates passed"
exit 0
