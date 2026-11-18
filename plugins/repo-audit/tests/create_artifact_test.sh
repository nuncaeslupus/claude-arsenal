#!/usr/bin/env bash
# create_artifact_test.sh — the ledger shows severity and confidence, sorted by them.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER="${SCRIPT_DIR}/../skills/repo-audit/scripts/create_artifact.py"

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

cat > "${tmpdir}/in.json" <<'JSON'
{"title": "t", "sections": [{"id": "a", "tag": "a", "heading": "A"}],
 "ledger": [
  {"finding": "unrated-row", "where": "x", "status": "fixed"},
  {"finding": "low-row", "where": "y", "status": "flagged", "severity": "low", "confidence": "high"},
  {"finding": "high-row", "where": "z", "status": "queued", "severity": "high", "confidence": "medium"}]}
JSON
python3 "${RENDER}" --input "${tmpdir}/in.json" --output "${tmpdir}/out.html" 2>/dev/null

grep -q '<th>Severity</th><th>Confidence</th>' "${tmpdir}/out.html" || fail "no severity/confidence columns"
grep -q '<td>high-row</td><td><code>z</code></td><td>high</td><td>medium</td>' "${tmpdir}/out.html" \
  || fail "high-row does not carry its severity and confidence"
order=$(grep -o 'high-row\|low-row\|unrated-row' "${tmpdir}/out.html" | tr '\n' ' ')
[[ "${order}" == "high-row low-row unrated-row " ]] || fail "wrong order: ${order}"
echo "PASS: ledger renders severity and confidence and sorts by them"
