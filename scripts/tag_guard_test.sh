#!/usr/bin/env bash
# tag_guard_test.sh — the release gate, exercised without a release.
#
# tag-release.yml fired on any push to main and tagged v<.bundle-version> with
# no check of ci.yml's conclusion, so a merge whose main-branch CI went red was
# still tagged — and consumers gate updates on exactly the newest remote tag.
# The decision lives in a script so it can be run here; a release gate nobody
# can run locally is a release gate nobody tests.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="${SCRIPT_DIR}/tag_guard.sh"
[[ -f "${GUARD}" ]] || { echo "FAIL: ${GUARD} not found" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

verdict() {  # verdict <json> -> the guard's word
    printf '%s' "$1" > "${tmp}/runs.json"
    bash "${GUARD}" "${tmp}/runs.json"
}
expect() {  # expect <want> <json> <why>
    local got
    got=$(verdict "$2")
    [[ "${got}" == "$1" ]] || fail "$3 — expected '$1', got '${got}'"
}

run() {  # run <status> <conclusion> <created_at>
    printf '{"status":"%s","conclusion":%s,"created_at":"%s"}' \
        "$1" "$([[ "$2" == "null" ]] && echo null || printf '"%s"' "$2")" "$3"
}

expect tag "{\"workflow_runs\":[$(run completed success 2026-01-02)]}" \
    "a green run is the only thing that permits a tag"
expect refuse "{\"workflow_runs\":[$(run completed failure 2026-01-02)]}" \
    "a red CI run must never be tagged — this is the whole defect"
expect refuse "{\"workflow_runs\":[$(run completed cancelled 2026-01-02)]}" \
    "a cancelled run is not a pass"
expect refuse "{\"workflow_runs\":[$(run completed null 2026-01-02)]}" \
    "a completed run with no conclusion is not a pass"
expect pending "{\"workflow_runs\":[$(run in_progress null 2026-01-02)]}" \
    "a run still going is not yet an answer"
expect pending "{\"workflow_runs\":[$(run queued null 2026-01-02)]}" \
    "a queued run is not yet an answer"
echo "PASS: a tag needs a concluded, successful run"

# `absent` is deliberately NOT `refuse`: it is what an Actions outage at merge
# time looks like afterwards, and refusing it forever would reintroduce the
# untagged-release failure (v0.20.4, v0.21.0) the daily schedule exists to heal.
expect absent '{"workflow_runs":[]}' "no runs at all is 'absent', not 'refuse'"
expect absent '[]' "a bare empty array reads the same as the envelope"
echo "PASS: 'no CI run at all' stays distinct from 'CI failed'"

# A re-run supersedes what it replaced, whichever order the API returns them in.
newest_green="{\"workflow_runs\":[$(run completed failure 2026-01-01),$(run completed success 2026-01-03)]}"
expect tag "${newest_green}" "a green re-run must supersede the red run it replaced"
newest_red="{\"workflow_runs\":[$(run completed success 2026-01-01),$(run completed failure 2026-01-03)]}"
expect refuse "${newest_red}" "a red re-run must supersede the green run it replaced"
# ...and an unconcluded newer run does not hide an older verdict.
expect tag "{\"workflow_runs\":[$(run in_progress null 2026-01-04),$(run completed success 2026-01-03)]}" \
    "a newer in-flight run must not erase a concluded green one"
echo "PASS: the newest CONCLUDED run decides, in either order"

# Unreadable input is exit 2, never a verdict — the vacuous-pass shape.
printf 'not json' > "${tmp}/bad.json"
out=$(bash "${GUARD}" "${tmp}/bad.json" 2>&1); code=$?
[[ ${code} -eq 2 ]] || fail "malformed input must exit 2, got ${code} (${out})"
grep -qi "cannot read" <<<"${out}" || fail "the refusal must say why: ${out}"
out=$(bash "${GUARD}" 2>&1); code=$?
[[ ${code} -eq 2 ]] || fail "a missing argument must exit 2, got ${code}"
echo "PASS: unreadable input is an error, not a verdict"

# The workflow must actually consult the guard, and tag only on its verdict.
WF="${SCRIPT_DIR}/../.github/workflows/tag-release.yml"
grep -q 'scripts/tag_guard.sh' "${WF}" || fail "tag-release.yml does not run the guard"
grep -q "steps.guard.outputs.verdict == 'tag'" "${WF}" \
    || fail "the tag step is not conditioned on the guard's verdict"
grep -q 'workflows: \[ci\]' "${WF}" || fail "tag-release.yml no longer waits for ci to finish"
grep -q 'schedule:' "${WF}" || fail "the outage-recovery schedule was dropped"
grep -q 'workflow_dispatch:' "${SCRIPT_DIR}/../.github/workflows/ci.yml" \
    || fail "ci.yml has no manual trigger, so the recovery path cannot start it"
echo "PASS: the workflow gates the tag step on the guard, and keeps the recovery path"

echo "PASS: tag_guard_test — all gates passed"
