#!/usr/bin/env bash
# context_budget_test.sh — the resident-tier cap must actually bite.
#
# A budget check that reports a number but never fails is decoration: it would
# have let every regression it exists to catch through. So this asserts the
# failing direction as carefully as the passing one.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUDGET_PY="${SCRIPT_DIR}/context_budget.py"
REPO_ROOT="${SCRIPT_DIR}/.."
[[ -f "${BUDGET_PY}" ]] || { echo "SKIP: ${BUDGET_PY} not found" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

# The real tree must be inside the budget the Makefile enforces.
budget=$(grep -E '^RESIDENT_TOKEN_BUDGET' "${REPO_ROOT}/Makefile" | tr -dc '0-9')
[[ -n "${budget}" ]] || fail "Makefile declares no RESIDENT_TOKEN_BUDGET"

out=$(python3 "${BUDGET_PY}" --root "${REPO_ROOT}" --fail-over "${budget}" 2>&1) \
    || fail "the repo is over its own resident budget:\n${out}"
grep -q "Within budget" <<<"${out}" || fail "expected a within-budget line: ${out}"

# Each tier is named, because the report's job is to say which schedule a cost
# is paid on — a number with no tier tells a reviewer nothing actionable.
for tier in "RESIDENT" "ON INVOCATION" "ON DEMAND"; do
    grep -q "${tier}" <<<"${out}" || fail "report omits the ${tier} tier: ${out}"
done

# The cap bites. An impossible budget must exit 1 and say what to do instead of
# raising it — the advice is the part that keeps the number meaningful.
out=$(python3 "${BUDGET_PY}" --root "${REPO_ROOT}" --fail-over 1 2>&1)
[[ $? -eq 1 ]] || fail "an exceeded budget must exit 1"
grep -q "over the 1 budget" <<<"${out}" || fail "an exceeded budget must say so: ${out}"
grep -q "rather than raising the cap" <<<"${out}" \
    || fail "the failure must point at moving content, not at raising the cap"

# Reporting without a cap is not a failure — that is the exploratory mode.
python3 "${BUDGET_PY}" --root "${REPO_ROOT}" >/dev/null 2>&1 \
    || fail "a plain report must exit 0"

# A tree with no skills is a layout problem, not a passing budget of zero.
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
python3 "${BUDGET_PY}" --root "${tmpdir}" >/dev/null 2>&1
[[ $? -eq 2 ]] || fail "an empty tree must exit 2, not report a budget of zero"

# A bundle missing its AGENTS.md is a layout problem too, and the one that used
# to score zero for the largest resident input and then report "Within budget" —
# the gate reading healthiest exactly when it had stopped measuring.
mkdir -p "${tmpdir}/tree/plugins/core/skills/demo"
cat > "${tmpdir}/tree/plugins/core/skills/demo/SKILL.md" <<'SKILL'
---
name: demo
description: A skill that exists so the tree is not empty.
---

Body.
SKILL
out=$(python3 "${BUDGET_PY}" --root "${tmpdir}/tree" --fail-over 5000 2>&1)
[[ $? -eq 2 ]] || fail "a missing AGENTS.md must exit 2, not score zero and pass: ${out}"
grep -q "AGENTS.md" <<<"${out}" || fail "the refusal must name the file it could not read: ${out}"
grep -q "Within budget" <<<"${out}" && fail "a bundle missing AGENTS.md must not report a budget: ${out}"

# An input that is not valid UTF-8 is the same answer, not a traceback.
# UnicodeDecodeError is a ValueError, so catching OSError alone would miss it.
agents="${tmpdir}/tree/plugins/core/skills/init/assets/AGENTS.md"
mkdir -p "$(dirname "${agents}")"
echo "resident text" > "${agents}"
printf 'name: demo\n\xff\xfe' > "${tmpdir}/tree/plugins/core/skills/demo/SKILL.md"
out=$(python3 "${BUDGET_PY}" --root "${tmpdir}/tree" --fail-over 5000 2>&1)
[[ $? -eq 2 ]] || fail "an undecodable input must exit 2: ${out}"
grep -q "Traceback" <<<"${out}" && fail "an undecodable input must be reported, not raised: ${out}"

echo "PASS: context_budget_test — resident tier reported and capped"
