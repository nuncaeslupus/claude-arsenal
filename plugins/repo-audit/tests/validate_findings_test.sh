#!/usr/bin/env bash
# validate_findings_test.sh — a malformed ledger row is reported, never a crash.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/../skills/repo-audit/scripts/validate_findings.py"

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# A list where a level or status belongs is unhashable; it must be a problem
# line (exit 1), not a TypeError traceback.
cat > "${tmpdir}/ledger.json" <<'EOF'
[{"finding": "a", "where": "x", "status": "fixed", "severity": []},
 {"finding": "b", "where": "y", "status": ["fixed"]}]
EOF
set +e
out=$(python3 "${VALIDATE}" --input "${tmpdir}/ledger.json" 2>&1)
rc=$?
set -e
[[ ${rc} -eq 1 ]] || fail "expected exit 1, got ${rc}: ${out}"
grep -q 'findings\[0\] severity' <<<"${out}" || fail "severity [] not reported: ${out}"
grep -q 'findings\[1\] status' <<<"${out}" || fail "status [...] not reported: ${out}"
echo "PASS: non-string severity and status are reported, not raised"

cat > "${tmpdir}/clean.json" <<'EOF'
[{"finding": "a", "where": "x", "status": "fixed", "severity": "high", "confidence": "low"}]
EOF
python3 "${VALIDATE}" --input "${tmpdir}/clean.json" >/dev/null 2>&1 || fail "a clean ledger was rejected"
echo "PASS: validate_findings_test — all gates passed"
