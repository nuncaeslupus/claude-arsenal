#!/usr/bin/env bash
# review_policy_test.sh — risk tier and per-tier approval (review-digest P1, T2).
#
# The tier decides who must approve a PR, so a misread here merges a change
# nobody looked at. Each case is one rule from the script's docstring.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY="${here}/../skills/init/assets/scripts/review_policy.py"
[[ -f "${POLICY}" ]] || { echo "FAIL: ${POLICY} not found" >&2; exit 1; }

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}" || exit 1
mkdir -p arsenal

fail() { echo "FAIL: $1" >&2; exit 1; }
field() { python3 -c "import json,sys; print(json.load(sys.stdin)[sys.argv[1]])" "$1"; }
tier_of() { printf '%s' "$1" | python3 "${POLICY}" tier --files - | field tier; }

docs='[{"filename":"docs/guide.md","additions":3,"deletions":1},{"filename":"README.md","additions":1,"deletions":0}]'
mixed='[{"filename":"docs/guide.md","additions":3,"deletions":1},{"filename":"src/app.py","additions":2,"deletions":0}]'
auth='[{"filename":"src/auth/login.py","additions":1,"deletions":0}]'
big='[{"filename":"src/app.py","additions":300,"deletions":200}]'

# --- tiers ----------------------------------------------------------------------
[[ "$(tier_of "${docs}")" == "low" ]] || fail "a docs-only diff should be low"
[[ "$(tier_of "${mixed}")" == "medium" ]] || fail "test_tier_mixed_docs_and_code_is_not_low"
[[ "$(tier_of "${big}")" == "high" ]] || fail "500 changed lines should be high (risk-lines 400)"
printf 'risk-paths = ["src/auth/*"]\n' > arsenal/config.toml
[[ "$(tier_of "${auth}")" == "high" ]] || fail "a risk-paths match should be high"
a="$(printf '%s' "${mixed}" | python3 "${POLICY}" tier --files -)"
b="$(printf '%s' "${mixed}" | python3 "${POLICY}" tier --files -)"
[[ "${a}" == "${b}" ]] || fail "test_tier_same_input_same_output"
echo "PASS: tiers — docs low, mixed medium, risk path or size high, deterministic"

# --- approval -------------------------------------------------------------------
printf '[review]\npreset = "solo-trust"\nalways-human-paths = ["src/auth/*"]\n' > arsenal/config.toml
out="$(printf '%s' "${auth}" | python3 "${POLICY}" tier --files -)"
[[ "$(field tier <<<"${out}")" == "high" ]] || fail "an always-human path should force high"
req="$(python3 "${POLICY}" require --tier high --human-paths)"
[[ "$(field approval <<<"${req}")" == "human:1" ]] \
    || fail "test_tier_always_human_path_forces_high_and_one_human: ${req}"
req="$(python3 "${POLICY}" require --tier high)"
[[ "$(field approval <<<"${req}")" == "human-after" && "$(field ratify <<<"${req}")" == "True" ]] \
    || fail "solo-trust high should be human-after with ratify: ${req}"
printf '[review]\npreset = "team"\napproval-medium = "agent"\n' > arsenal/config.toml
[[ "$(python3 "${POLICY}" require --tier medium | field approval)" == "agent" ]] \
    || fail "review.approval-medium should override the preset row"
[[ "$(python3 "${POLICY}" require --tier high | field humans)" == "2" ]] || fail "team high needs 2 humans"
: > arsenal/config.toml
[[ -z "$(python3 "${POLICY}" require --tier high | field approval)" ]] \
    || fail "no preset should leave approval empty (merge-policy alone)"
echo "PASS: approval — preset rows, overrides, always-human paths, legacy fallback"

# --- explain --------------------------------------------------------------------
printf '[review]\npreset = "solo-trust"\n' > arsenal/config.toml
n="$(python3 "${POLICY}" explain | wc -l)"
(( n <= 12 )) || fail "test_explain_fits_twelve_lines: ${n} lines"
python3 "${POLICY}" explain | grep -q "merge-policy after-ci-and-review" || fail "explain should name the implied merge-policy"
printf '[review]\npreset = "nope"\n' > arsenal/config.toml
python3 "${POLICY}" explain >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "a bad config should exit 2"
echo "PASS: explain fits 12 lines; a bad config exits 2"

echo "PASS: review_policy_test — all gates passed"
