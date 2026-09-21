#!/usr/bin/env bash
# sync_duplicates_test.sh — the duplicate-drift detector must see every declared
# group in the repository, and must not invent problems that aren't there.
#
# Two real failures motivate this file, both of which shipped because nothing
# exercised the script:
#
#   1. The .py scan was scoped to a single --library directory while .sh already
#      walked the whole repo, so a Python pair spanning two plugins — or living
#      outside a skill's scripts/ dir, like the hooks — was invisible. A
#      fail-open security hook stayed drifted from its canonical copy for
#      months, and this was the tool that should have said so.
#   2. --apply resolved declared sibling paths against the library's parent
#      rather than the repo root, so its cross-check could never find a file and
#      warned that every sibling was missing, on a tree where all were present.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SYNC="${REPO_ROOT}/plugins/skill-workshop/skills/skill-workshop/scripts/sync_duplicates.py"

[[ -f "${SYNC}" ]] || { echo "FAIL: sync_duplicates.py not found at ${SYNC}" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }
cd "${REPO_ROOT}" || fail "cannot enter ${REPO_ROOT}"

# --- 1: a clean tree reports clean -------------------------------------------
out="$(python3 "${SYNC}" --check 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "--check on a clean tree exited ${rc}: ${out}"
echo "PASS: a clean tree reports clean"

# --- 2: cross-plugin and outside-scripts/ pairs are discovered ----------------
# Each of these was invisible to the old library-scoped .py scan. gate_target.py
# lives in hooks/, not scripts/; create_task.py spans two plugins.
for pair in gate_target.py create_task.py create_artifact.py; do
    grep -q "${pair}" <<<"${out}" \
        || fail "--check never mentions ${pair} — the scan is not repo-wide"
done
echo "PASS: .py groups outside a skill's scripts/ and across plugins are found"

# --- 3: real drift is detected, and exits 1 ----------------------------------
victim="plugins/repo-audit/skills/explain-repo/scripts/create_artifact.py"
[[ -f "${victim}" ]] || fail "fixture missing: ${victim}"
backup="$(mktemp)"
cp "${victim}" "${backup}"
restore() { cp "${backup}" "${victim}"; rm -f "${backup}"; }
trap restore EXIT

printf '\n# drift introduced by sync_duplicates_test.sh\n' >> "${victim}"
out="$(python3 "${SYNC}" --check 2>&1)"; rc=$?
[[ "${rc}" -eq 1 ]] || fail "--check did not exit 1 on real drift (got ${rc}): ${out}"
grep -q "drift in group" <<<"${out}" || fail "drift was not named: ${out}"

# --- 4: --apply repairs it, without claiming siblings are missing -------------
out="$(python3 "${SYNC}" --apply "${REPO_ROOT}/plugins/repo-audit/skills/repo-audit/scripts/create_artifact.py" 2>&1)"
grep -q "missing on disk" <<<"${out}" \
    && fail "--apply warned a present sibling was missing: ${out}"
python3 "${SYNC}" --check >/dev/null 2>&1 \
    || fail "--apply did not restore the group to clean"
echo "PASS: real drift is detected, and --apply repairs it quietly"

restore
trap - EXIT

# --- 5: a placeholder header is an example, not a declaration ----------------
# assets/script.template.py carries a DUPLICATED ACROSS SKILLS header written
# with <plugin>/<verb_noun> placeholders. Reading it as real reported a
# permanently incomplete group naming two files that cannot exist.
out="$(python3 "${SYNC}" --check 2>&1)"
grep -q "<" <<<"${out}" && fail "a placeholder header was read as a real group: ${out}"
echo "PASS: a placeholder header is ignored"

echo "=== sync_duplicates_test: all passed ==="
exit 0
