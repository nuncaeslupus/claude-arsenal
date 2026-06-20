#!/usr/bin/env bash
# gate_evidence_test.sh — unit test for gate_evidence.py and its gate_run.sh wiring.
# Verifies a numeric evidence gate passes only with a committed measurement that
# satisfies the threshold, that a missing evidence file is a hard failure (never
# a vacuous pass), and that gate_run.sh enforces it. Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GE="${SCRIPT_DIR}/../skills/init/assets/scripts/gate_evidence.py"
GR="${SCRIPT_DIR}/../skills/init/assets/bin/gate_run.sh"

if [[ ! -f "${GE}" ]]; then
    echo "SKIP: gate_evidence.py not found at ${GE}" >&2; exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}"
mkdir -p claude-arsenal/queue

cat > claude-arsenal/queue/lo-p.md <<'MD'
# P
## Acceptance gate
```gate
line_coverage >= 0.90
evidence: coverage.json
key: totals.percent_covered
```
MD

run() { python3 "${GE}" claude-arsenal/queue/lo-p.md >/dev/null 2>&1; echo $?; }

echo '{"totals":{"percent_covered":0.93}}' > coverage.json
[[ "$(run)" == "0" ]] || { echo "FAIL: satisfied gate should exit 0" >&2; exit 1; }
echo "PASS: satisfied evidence gate → 0"

echo '{"totals":{"percent_covered":0.80}}' > coverage.json
[[ "$(run)" == "1" ]] || { echo "FAIL: violated threshold should exit 1" >&2; exit 1; }
echo "PASS: violated threshold → 1"

rm -f coverage.json
[[ "$(run)" == "2" ]] || { echo "FAIL: missing evidence should exit 2" >&2; exit 1; }
echo "PASS: missing evidence file → 2 (hard fail, never vacuous)"

cat > claude-arsenal/queue/lo-n.md <<'MD'
# N
## Acceptance gate
prose only — nothing machine-checkable
MD
python3 "${GE}" claude-arsenal/queue/lo-n.md >/dev/null 2>&1
[[ "$?" == "0" ]] || { echo "FAIL: no gate block should exit 0" >&2; exit 1; }
echo "PASS: no evidence gate declared → 0"

# gate_run.sh integration: a failing evidence gate fails gate_run (CA-12).
if [[ -f "${GR}" ]]; then
    echo '{"totals":{"percent_covered":0.50}}' > coverage.json
    bash "${GR}" lo-p >/dev/null 2>&1
    [[ "$?" == "1" ]] || { echo "FAIL: gate_run with failing evidence should exit 1" >&2; exit 1; }
    echo "PASS: gate_run enforces a failing evidence gate (CA-12)"

    echo '{"totals":{"percent_covered":0.99}}' > coverage.json
    bash "${GR}" lo-p >/dev/null 2>&1
    [[ "$?" == "0" ]] || { echo "FAIL: gate_run with satisfied evidence should exit 0" >&2; exit 1; }
    echo "PASS: gate_run passes a satisfied evidence gate"
fi

echo "PASS: gate_evidence_test — all gates passed"
exit 0
