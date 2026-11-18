#!/usr/bin/env bash
# validate_markdown_test.sh — validate_markdown.py catches what a hand-authored doc
# fix most often gets wrong: a broken relative link, an unbalanced fence, a
# leftover placeholder. A clean tree passes. (#612)
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail
SC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/repo-audit/scripts/validate_markdown.py"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir "${tmp}/d"
printf '# Ok\n\n[self](ok.md)\n' > "${tmp}/d/ok.md"
python3 "${SC}" --input-dir "${tmp}/d" >/dev/null 2>&1 || fail "a clean doc was flagged"

printf '# Bad\n\n[gone](missing.md)\n\nTODO later\n\n```\nunclosed\n' > "${tmp}/d/bad.md"
out=$(python3 "${SC}" --input-dir "${tmp}/d" --json); rc=$?
[[ ${rc} -eq 1 ]] || fail "problems must exit 1, got ${rc}"
for want in "broken relative link" "placeholder marker" "unbalanced code fence"; do
    grep -q "${want}" <<<"${out}" || fail "missing the '${want}' finding: ${out}"
done
python3 "${SC}" --input-dir "${tmp}/nope" >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "a bad directory must exit 2"
echo "PASS: validate_markdown flags broken links, fences and placeholders"
