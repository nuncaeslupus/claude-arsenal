#!/usr/bin/env bash
# instruction_economy_test.sh — each file says its thing once.
#
# Instruction length is paid by every session that loads the file, so length
# that does not earn its keep makes the agent do the job worse, not better.
# skill-workshop/SKILL.md stated its gate procedure three times — "The two
# passes", then an operational checklist restating the first three of them,
# then a "before committing" bullet pointing back — in the highest-traffic
# skill in the repo, the one the pre-edit hook requires loaded before any
# skill file is touched.
#
# These are ceilings, not targets: a file may shrink freely, and a rewrite
# that grows one past the line has to say why.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }

WORKSHOP="${ROOT}/skill-workshop/skills/skill-workshop/SKILL.md"
AUDIT="${ROOT}/repo-audit/skills/repo-audit/SKILL.md"
TAXONOMY="${ROOT}/repo-audit/skills/repo-audit/references/issue-taxonomy.md"
for f in "${WORKSHOP}" "${AUDIT}" "${TAXONOMY}"; do
    [[ -f "${f}" ]] || fail "${f} not found"
done

# --- 1: the gate procedure is stated once -----------------------------------
#     Asserted on the two restatements that were removed, not on a count of the
#     script names: the scripts inventory and the worked examples name them
#     again for good reasons, and a count cannot tell those apart.
grep -q "Operational checklist applied at the gate" "${WORKSHOP}" \
    && fail "the checklist that restated the two passes is back"
grep -q "gate's operational checklist passed" "${WORKSHOP}" \
    && fail "the commit-time bullet pointing back at the gate is back"
grep -q "### The two passes" "${WORKSHOP}" \
    || fail "the one place the gate procedure IS stated has gone"
echo "PASS: the gate procedure is stated in one place"

# --- 2: the taxonomy prompts rather than enumerates -------------------------
#     Naming patterns hands a worker something to match instead of code to
#     read. The rewrite is one open question per group.
lines=$(wc -l < "${TAXONOMY}")
[[ "${lines}" -le 75 ]] \
    || fail "issue-taxonomy.md is ${lines} lines — it is enumerating patterns again (ceiling 75)"
grep -q "Simplicity and instruction economy" "${TAXONOMY}" \
    || fail "the simplicity group is missing — it is the one that found this file"
groups=$(grep -cE '^[0-9]+\. \*\*' "${TAXONOMY}")
[[ "${groups}" -eq 9 ]] || fail "expected 9 dispatch groups in issue-taxonomy.md, found ${groups}"
echo "PASS: nine groups, each a question, at the density of research-categories.md"

# --- 3: a condensed Gotcha does not stand in for the full reference ----------
#     Two Gotchas restated sections output-shape.md states in full, with
#     nothing signalling the fuller decision tree existed — so the short
#     version read as complete and a reader could miss the distinctions.
grep -q "What never goes into the target repo" "${AUDIT}" \
    && fail "repo-audit/SKILL.md restates output-shape.md's 'what never goes' section"
grep -q "output-shape.md" "${AUDIT}" \
    || fail "repo-audit/SKILL.md no longer points at the reference that holds the decision"
echo "PASS: the Gotchas name the reference instead of condensing it"

# --- 4: the on-invocation tier did not grow ---------------------------------
#     Measured the way context_budget.py measures: characters of the body.
check_size() {  # check_size <file> <ceiling-chars> <what>
    local size
    size=$(wc -c < "$1")
    [[ "${size}" -le "$2" ]] \
        || fail "$3 is ${size} chars, over its ${2} ceiling — on-invocation cost grew"
}
check_size "${WORKSHOP}" 12800 "skill-workshop/SKILL.md"
check_size "${AUDIT}" 7000 "repo-audit/SKILL.md"
check_size "${TAXONOMY}" 3800 "issue-taxonomy.md"
echo "PASS: every thinned file is still under its ceiling"

echo "PASS: instruction_economy_test — all gates passed"
