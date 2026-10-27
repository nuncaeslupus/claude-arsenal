#!/usr/bin/env bash
# review_metrics_test.sh — reverts, fix-ups and tiers from git history (review-digest P4, T1).
#
# The metrics line is how a host tells whether loosening a tier raised reverts,
# so each counting rule is pinned on a fixture repository with known history.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS="${here}/../skills/init/assets/scripts/review_metrics.py"
[[ -f "${METRICS}" ]] || { echo "FAIL: ${METRICS} not found" >&2; exit 1; }

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
cd "${tmp}" && git init -q -b main . || exit 1
gc() {  # gc <file> <subject> [body] — one commit touching <file>
    echo "$RANDOM" >> "$1"; git add "$1"
    git -c user.name=t -c user.email=t@example.com commit -q -m "$2" ${3:+-m "$3"}
}

gc a.py "feat: add a (#1)" "Risk-tier: high (lines 500 > 400)"
gc b.py "feat: add b (#2)" "Risk-tier: low (docs/config only)"
gc c.py "feat: add c (#3)"
gc a.py "fix: a crashes on empty input"
gc b.py "Revert #2: add b (#4)"
gc z.py "fix: unrelated file"
gc c.py "Revert \"feat: add c\" (#5)" "Reverts owner/repo#3"

out="$(python3 "${METRICS}" --days 30)" || fail "metrics failed: ${out}"
grep -q "^30d: 3 merged (low 1 · high 1 · untiered 1)" <<<"${out}" || fail "test_untiered_merges_reported: ${out}"
grep -q "2 reverts (low, untiered)" <<<"${out}" || fail "test_revert_counted_against_its_tier (incl. GitHub's Revert button): ${out}"
grep -q "1 fix-ups ≤7d" <<<"${out}" || fail "test_fixup_within_7_days_counted: ${out}"
j="$(python3 "${METRICS}" --json)"
[[ "$(python3 -c 'import json,sys; print(json.load(sys.stdin)["fixups"]["high"])' <<<"${j}")" == "1" ]] \
    || fail "the fix-up should count against the high-tier merge it followed: ${j}"
echo "PASS: git — tiers from trailers, revert against its tier, fix-up against the merge it fixes"

# Digest records add rounds and who found the problems.
python3 - <<'PY' > prs.json
import json
def pr(n, rounds, srcs):
    rec = {"v": 1, "pr": n, "rounds": rounds, "findings": [{"found_by": s} for s in srcs]}
    return {"number": n, "body": "<!-- arsenal-digest\n" + json.dumps(rec) + "\n-->"}
bad = {"number": 9, "body": "<!-- arsenal-digest\n" + json.dumps({"v": 1, "pr": 9, "findings": None, "rounds": "x"}) + "\n-->"}
print(json.dumps([pr(1, 2, ["cold-reviewer", "ci"]), pr(2, 1, ["cold-reviewer", "bot:rb[bot]"]), bad, "junk"]))
PY
out="$(python3 "${METRICS}" --prs-json prs.json)"
grep -q "rounds 1.5" <<<"${out}" && grep -q "found by: cold-reviewer 50% · ci 25% · bot 25%" <<<"${out}" \
    || fail "records should add rounds and finding sources: ${out}"
echo "PASS: records — mean rounds and finding sources"

cd / && python3 "${METRICS}" >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "outside a git repo should exit 2"
echo "PASS: review_metrics_test — all gates passed"
