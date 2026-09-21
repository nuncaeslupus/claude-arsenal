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
grep -q "default-off section" <<<"${out}" \
    || fail "the failure must name the other way out: an opt-in section costs nobody who declined it"
grep -q "always-installed tier" <<<"${out}" \
    || fail "the failure must say WHICH tier is over, now that only one of them is capped"

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
grep -q "^RESIDENT" <<<"${out}" && fail "a refused measurement must print no tier report either: ${out}"

# An input that is not valid UTF-8 is the same answer, not a traceback.
# UnicodeDecodeError is a ValueError, so catching OSError alone would miss it.
agents="${tmpdir}/tree/plugins/core/skills/init/assets/AGENTS.md"
mkdir -p "$(dirname "${agents}")"
echo "resident text" > "${agents}"
printf 'name: demo\n\xff\xfe' > "${tmpdir}/tree/plugins/core/skills/demo/SKILL.md"
out=$(python3 "${BUDGET_PY}" --root "${tmpdir}/tree" --fail-over 5000 2>&1)
[[ $? -eq 2 ]] || fail "an undecodable input must exit 2: ${out}"
grep -q "Traceback" <<<"${out}" && fail "an undecodable input must be reported, not raised: ${out}"
grep -q "cannot read" <<<"${out}" || fail "an undecodable input must say it could not be read: ${out}"
grep -q "SKILL.md" <<<"${out}" || fail "the read error must name the file: ${out}"

# --- the listing is billed per install, not per repo -------------------------
# The number that used to be reported was a sum over every SKILL.md in the tree,
# which is a bill no consumer receives: it counted a marketplace plugin `/init`
# never vendors, and charged every repo for default-off sections nobody enabled.
# These assert the report says whose bill each row is.
out=$(python3 "${BUDGET_PY}" --root "${REPO_ROOT}" --fail-over "${budget}" 2>&1) \
    || fail "the repo is over its own resident budget:\n${out}"

grep -q "by what the consumer installed" <<<"${out}" \
    || fail "the listing must be broken down by install: ${out}"
grep -q -- "<- /init default" <<<"${out}" \
    || fail "the report must mark which row a default install actually pays: ${out}"
grep -q -- "<- capped" <<<"${out}" \
    || fail "the report must mark which row the cap applies to: ${out}"

# A plugin `/init` does not vendor is resident for nobody, so it must not be
# billed to anyone. skill-workshop is the whole class: a marketplace plugin,
# never installed into a consumer's skills dir.
grep -q "not vendored by /init, so resident for nobody" <<<"${out}" \
    || fail "skills outside the vendored set must be reported as costing nobody: ${out}"

# The gate the har plan calls `resident_token_delta_without_extract == 0`: a
# default-off section is free for every consumer who did not ask for it. If the
# default install ever costs the same as the capped one, either a section was
# switched on by default or the breakdown stopped distinguishing them — both are
# the regression this row exists to catch.
vendored_skills=$(ls -d "${REPO_ROOT}"/plugins/core/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
python3 - "${out}" "${vendored_skills}" <<'PY' || fail "install rows are wrong:\n${out}"
import re, sys

rows = dict(
    (m[0], (int(m[1]), int(m[2])))
    for m in re.findall(r"^\s{4}(\w+)\s+.*?\s+(\d+)\s+(\d+)\s+\d+", sys.argv[1], re.M)
)
for needed in ("minimal", "general", "all"):
    if needed not in rows:
        print(f"report has no {needed} row", file=sys.stderr)
        raise SystemExit(1)

# The cap must sit on the NARROWEST install — core alone, the one section /init
# never switches off. It used to sit on the widest, which made an opt-in skill
# compete for a budget no single consumer necessarily pays, turning the guard on
# the involuntary bill into a ceiling on the whole marketplace.
#
# Read the row the report itself marks `<- capped`, not the one this test would
# pick: an assertion about a row chosen by a different measure passes while the
# cap sits somewhere else.
capped = re.search(r"^\s{4}(\w+)\s+.*<- capped", sys.argv[1], re.M)
if not capped:
    print("report marks no row as capped", file=sys.stderr)
    raise SystemExit(1)
if capped[1] not in rows:
    print(f"capped row {capped[1]!r} is not one of {sorted(rows)}", file=sys.stderr)
    raise SystemExit(1)
narrowest = min(rows, key=lambda name: rows[name][0])
if capped[1] != narrowest:
    print(
        f"the cap sits on {capped[1]!r} ({rows[capped[1]][0]} skills), not on the "
        f"always-installed row {narrowest!r} ({rows[narrowest][0]}): an opt-in "
        f"section is failing a build for consumers who never install it",
        file=sys.stderr,
    )
    raise SystemExit(1)

# The WIDEST row still has to reach every skill /init can vendor. It is reported
# rather than capped now, but understating it hides a real cost from whoever
# opted in — and `--profile all` is resolved by `_resolve_sections` as every
# *known* section, which includes one that exists only as `section:`
# frontmatter. Reading `_PROFILES["all"]` instead silently drops those; this is
# what makes that drift visible.
if rows["all"][0] != int(sys.argv[2]):
    print(
        f"the all row lists {rows['all'][0]} skills but /init can vendor "
        f"{sys.argv[2]} — a section is missing from the report: {rows}",
        file=sys.stderr,
    )
    raise SystemExit(1)

if not rows["minimal"][0] < rows["general"][0] < rows["all"][0]:
    print(f"installs are not strictly nested: {rows}", file=sys.stderr)
    raise SystemExit(1)
if rows["general"][1] >= rows["all"][1]:
    print(f"default install costs as much as the widest one: {rows}", file=sys.stderr)
    raise SystemExit(1)
PY

# A tree with no installer cannot resolve sections, so it falls back to one flat
# number over every skill — the pre-sections behaviour. That fallback must work,
# not merely not-crash: a report that silently dropped to zero rows would still
# print a RESIDENT header and still say "Within budget".
#
# On its own tree rather than the shared one, because the shared tree is
# deliberately corrupted further down to test the read-error path, and an
# assertion that only passes because its input was already broken is not an
# assertion. (An earlier revision of this file asserted the *opposite* of the
# correct behaviour and passed for exactly that reason.)
flat=$(mktemp -d)
trap 'rm -rf "${tmpdir}" "${flat}"' EXIT
mkdir -p "${flat}/plugins/core/skills/demo" "${flat}/plugins/core/skills/init/assets"
cat > "${flat}/plugins/core/skills/demo/SKILL.md" <<'SKILL'
---
name: demo
description: A skill in a tree that ships no installer to resolve sections with.
---

Body.
SKILL
echo "resident text" > "${flat}/plugins/core/skills/init/assets/AGENTS.md"

out=$(python3 "${BUDGET_PY}" --root "${flat}" --fail-over 5000 2>&1) \
    || fail "a tree with no installer must still report a budget: ${out}"
grep -q "skill listing (1 skills)" <<<"${out}" \
    || fail "no installer means the flat listing, counting every skill: ${out}"
grep -q "by what the consumer installed" <<<"${out}" \
    && fail "sections cannot be resolved without an installer, so no breakdown: ${out}"
grep -q "Within budget" <<<"${out}" || fail "the fallback must still be capped: ${out}"

echo "PASS: context_budget_test — resident tier reported and capped"
