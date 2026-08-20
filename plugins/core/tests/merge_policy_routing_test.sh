#!/usr/bin/env bash
# merge_policy_routing_test.sh — the merge policy has to be read, not just stored.
#
# `merge-policy` shipped written (arsenal_migrate.py), validated (arsenal_config.py)
# and documented (docs/queue.md) — and unread. Over six versions no protocol step
# consulted it, so a repo that had set `after-review` for a named reason still had
# every merge stop to ask the owner whether it could merge (#192). That is the
# inert-gate shape one level up: a policy nothing reads decides nothing, and it
# fails quietly in the expensive direction — nothing merges wrongly, it just never
# stops asking.
#
# Prose is what went inert, so prose is what this checks: the merge step must name
# the command that reads the key, and the reference it points at must say what each
# of the five values requires. A value added to the enum with no rule written for it
# fails here rather than in a consumer's session.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
CFG="${ASSETS}/scripts/arsenal_config.py"
AGENTS="${ASSETS}/AGENTS.md"
REF="${ASSETS}/references/github-automation.md"

[[ -f "${CFG}" && -f "${AGENTS}" && -f "${REF}" ]] \
    || { echo "SKIP: bundle not found under ${ASSETS}" >&2; exit 0; }

fail=0
note() { echo "FAIL: $1" >&2; fail=1; }

# --- 1: the merge step names the command, so the read has a data path ---
# `AGENTS.md` is the file resident at the moment the question is asked. A pointer
# to a reference is not enough on its own: the reference is only opened by someone
# who already knows the key exists, which is exactly what nobody did.
grep -q 'arsenal_config.py --get merge-policy' "${AGENTS}" \
    || note "AGENTS.md never names the command that reads merge-policy"
grep -q 'github-automation.md' "${AGENTS}" \
    || note "AGENTS.md § Completion does not route to github-automation.md"
grep -q 'arsenal_config.py --get merge-policy' "${REF}" \
    || note "github-automation.md documents the policy without the command to read it"

# --- 2: every value in the enum has a rule written for it ---
mapfile -t values < <(python3 - "${CFG}" <<'PY'
import ast, sys

# ENUMS is annotated (`ENUMS: dict[str, set[str]] = {...}`), so it parses as an
# AnnAssign, not an Assign. Read it rather than importing the module: the point
# is to compare the prose against the source of truth, without inheriting
# whatever that module does at import time.
tree = ast.parse(open(sys.argv[1]).read())
for node in ast.walk(tree):
    target = getattr(node, "target", None) if isinstance(node, ast.AnnAssign) else None
    if getattr(target, "id", "") != "ENUMS":
        continue
    for key, val in zip(node.value.keys, node.value.values):
        if key.value == "merge-policy":
            print("\n".join(sorted(e.value for e in val.elts)))
PY
)

[[ ${#values[@]} -eq 5 ]] \
    || note "expected 5 merge-policy values from arsenal_config.py, parsed ${#values[@]}"

for value in "${values[@]}"; do
    grep -q "\`${value}\`" "${REF}" \
        || note "merge-policy value '${value}' has no rule in github-automation.md"
done

# --- 3: the two questions the values do not answer by themselves ---
# `after-review` does not say whose review, and a host that answers that by naming
# a bot in its own config has a policy that goes stale the day it swaps vendors.
# `after-ci` does not say what an absent CI run means, which is the state the
# `after-review` value was added for in the first place.
grep -qi 'counts as a review' "${REF}" \
    || note "github-automation.md never says what satisfies 'after-review'"
grep -qi 'cannot report' "${REF}" \
    || note "github-automation.md never says what to do when CI cannot report at all"

# --- 4: end to end — the command in the prose actually returns a value ---
tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/arsenal"
for value in "${values[@]}"; do
    printf 'merge-policy = "%s"\n' "${value}" > "${tmp}/arsenal/config.toml"
    got=$(python3 "${CFG}" --repo-root "${tmp}" --get merge-policy 2>/dev/null) \
        || { note "the documented read failed for '${value}'"; continue; }
    [[ "${got}" == "${value}" ]] \
        || note "documented read returned '${got}' for '${value}'"
done

if [[ ${fail} -eq 0 ]]; then
    echo "PASS: merge_policy_routing_test — the policy is named, ruled and readable"
    exit 0
fi
exit 1
