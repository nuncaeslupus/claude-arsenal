#!/usr/bin/env bash
# audit_estimate_test.sh — pricing an audit before it starts (review-digest P4, T3).
#
# An overnight audit is only safe to start when its cost was shown first, so the
# estimate must count what an audit reads and nothing it skips.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EST="${here}/../skills/repo-audit/scripts/audit_estimate.py"
[[ -f "${EST}" ]] || { echo "FAIL: ${EST} not found" >&2; exit 1; }

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
cd "${tmp}" || exit 1

mkdir -p src/api src/core node_modules/x vendor
printf 'a\nb\nc\n' > src/api/a.py           # 3 lines
printf 'd\ne\n' > src/core/b.py             # 2 lines
printf 'x\n%.0s' {1..500} > node_modules/x/big.js
printf 'x\n%.0s' {1..500} > vendor/v.py
printf 'x\n%.0s' {1..500} > package-lock.json
printf '\0\1\2' > src/core/blob.bin

j="$(python3 "${EST}" . --json)"
get() { python3 -c "import json,sys; print(json.load(sys.stdin)[sys.argv[1]])" "$1" <<<"${j}"; }
[[ "$(get lines)" == "5" && "$(get files)" == "2" ]] \
    || fail "test_estimate_skips_lockfiles_and_vendor: $(get files) files, $(get lines) lines"
[[ "$(get tokens)" == "60" ]] || fail "5 lines at 12 tokens/line should be 60: $(get tokens)"
j="$(python3 "${EST}" . --json --tokens-per-line 20)"
[[ "$(get tokens)" == "100" ]] || fail "test_tokens_scale_with_flag: $(get tokens)"
[[ "$(get workers)" == "1" ]] || fail "a small scope is audited inline"
out="$(python3 "${EST}" src)"
grep -q "^scope: src · 2 files · 5 lines · ≈ 0k tokens · 1 worker (inline)" <<<"${out}" || fail "line format: ${out}"
python3 "${EST}" nope >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "a missing path should exit 2"
echo "PASS: audit_estimate_test — counts what an audit reads, skips vendor, lockfiles and binaries"
