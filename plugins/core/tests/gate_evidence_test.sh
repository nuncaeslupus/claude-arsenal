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
mkdir -p arsenal/tasks

cat > arsenal/tasks/lo-p.md <<'MD'
# P
## Acceptance gate
```gate
line_coverage >= 0.90
evidence: coverage.json
key: totals.percent_covered
```
MD

run() { python3 "${GE}" arsenal/tasks/lo-p.md >/dev/null 2>&1; echo $?; }

echo '{"totals":{"percent_covered":0.93}}' > coverage.json
[[ "$(run)" == "0" ]] || { echo "FAIL: satisfied gate should exit 0" >&2; exit 1; }
echo "PASS: satisfied evidence gate → 0"

echo '{"totals":{"percent_covered":0.80}}' > coverage.json
[[ "$(run)" == "1" ]] || { echo "FAIL: violated threshold should exit 1" >&2; exit 1; }
echo "PASS: violated threshold → 1"

rm -f coverage.json
[[ "$(run)" == "2" ]] || { echo "FAIL: missing evidence should exit 2" >&2; exit 1; }
echo "PASS: missing evidence file → 2 (hard fail, never vacuous)"

cat > arsenal/tasks/lo-n.md <<'MD'
# N
## Acceptance gate
prose only — nothing machine-checkable
MD
python3 "${GE}" arsenal/tasks/lo-n.md >/dev/null 2>&1
[[ "$?" == "0" ]] || { echo "FAIL: no gate block should exit 0" >&2; exit 1; }
echo "PASS: no evidence gate declared → 0"

# Scientific-notation threshold + quoted evidence/key values.
cat > arsenal/tasks/lo-sci.md <<'MD'
# SCI
## Acceptance gate
```gate
p_value <= 1e-3
evidence: "metrics.json"
key: "stats.p"
```
MD
echo '{"stats":{"p":0.0005}}' > metrics.json
python3 "${GE}" arsenal/tasks/lo-sci.md >/dev/null 2>&1
[[ "$?" == "0" ]] || { echo "FAIL: 0.0005 <= 1e-3 should pass (sci notation + quotes)" >&2; exit 1; }
echo '{"stats":{"p":0.005}}' > metrics.json
python3 "${GE}" arsenal/tasks/lo-sci.md >/dev/null 2>&1
[[ "$?" == "1" ]] || { echo "FAIL: 0.005 <= 1e-3 should fail" >&2; exit 1; }
echo "PASS: scientific-notation threshold + quoted values handled"

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

# --- unmeasured: a metric that positively declares it cannot be scored yet ---
#     Without this the honest evidence (a null) lands in the non-numeric branch
#     and reads as a hard failure, so the only way forward is weakening the gate
#     to something measurable — the pressure these gates exist to remove.
cat > "${tmp}/arsenal/tasks/lo-u.md" <<'MD'
# Unmeasurable yet

## Acceptance gate
```gate
extraction_macro_f1 >= 0.75
evidence: extraction.json
key: extraction_macro_f1
status-key: extraction_status
```
MD
runu() { python3 "${GE}" arsenal/tasks/lo-u.md >/dev/null 2>&1; echo $?; }

echo '{"extraction_macro_f1": null, "extraction_status": "unmeasured"}' > extraction.json
[[ "$(runu)" == "3" ]] || { echo "FAIL: a declared-unmeasured metric should exit 3" >&2; exit 1; }
echo "PASS: declared unmeasured → 3 (not a verdict)"

# not reachable by omission: that would reopen the vacuous-pass hole elsewhere
echo '{"extraction_macro_f1": null}' > extraction.json
[[ "$(runu)" == "2" ]] || { echo "FAIL: a null with no positive status assertion must stay exit 2" >&2; exit 1; }
echo "PASS: a bare null is still a hard failure"

# a status that does not say unmeasured does not excuse a failing number
echo '{"extraction_macro_f1": 0.4, "extraction_status": "measured"}' > extraction.json
[[ "$(runu)" == "1" ]] || { echo "FAIL: a measured value below threshold must still exit 1" >&2; exit 1; }
echo "PASS: a measured value below threshold still fails"

# gate_run must propagate 3 rather than collapsing it into a verdict
echo '{"extraction_macro_f1": null, "extraction_status": "unmeasured"}' > extraction.json
bash "${GR}" lo-u >/dev/null 2>&1
[[ $? -eq 3 ]] || { echo "FAIL: gate_run should propagate exit 3 for an unmeasured gate" >&2; exit 1; }
echo "PASS: gate_run propagates unmeasured as 3"

# --- a gate that cannot be failed is not a gate (#302) ----------------------
# `json.loads` accepts the JavaScript spellings, and both are `float`, so they
# cleared the numeric type check and reached the comparison: NaN compares
# unequal to everything (itself included) so it passes every `!=` gate, and
# Infinity passes every directional one.
cat > arsenal/tasks/lo-ne.md <<'MD'
# NE
## Acceptance gate
```gate
drift != 0
evidence: metrics.json
key: value
```
MD
printf '{"value": NaN}\n' > metrics.json
python3 "${GE}" arsenal/tasks/lo-ne.md >/dev/null 2>&1
[[ $? -eq 2 ]] || { echo "FAIL: a NaN measurement must be refused, not pass a != gate" >&2; exit 1; }

printf '{"value": Infinity}\n' > metrics.json
python3 "${GE}" arsenal/tasks/lo-p.md >/dev/null 2>&1 || true
printf '{"totals":{"percent_covered": Infinity}}\n' > coverage.json
out=$(python3 "${GE}" arsenal/tasks/lo-p.md 2>&1); code=$?
[[ ${code} -eq 2 ]] \
    || { echo "FAIL: an Infinity measurement must be refused, got ${code}: ${out}" >&2; exit 1; }
grep -q "finite" <<<"${out}" || { echo "FAIL: the refusal must say why: ${out}" >&2; exit 1; }

# ...and a normal finite measurement still works, so this is a guard and not a
# blanket refusal.
echo '{"totals":{"percent_covered":0.93}}' > coverage.json
[[ "$(run)" == "0" ]] || { echo "FAIL: a finite measurement must still pass" >&2; exit 1; }
echo "PASS: NaN and Infinity are refused; a finite measurement still passes"

# --- an unfailable THRESHOLD is the same hole from the other side ------------
# The measurement side was closed above, but `GATE_RE` accepts an exponent, so
# `1e999` overflows to inf when the threshold is parsed. Every finite
# measurement then satisfies a `<=` gate no matter how bad it is.
cat > arsenal/tasks/lo-inf.md <<'MD'
# INF
## Acceptance gate
```gate
p95_latency_ms <= 1e999
evidence: metrics.json
key: value
```
MD
echo '{"value": 999999}' > metrics.json
out=$(python3 "${GE}" arsenal/tasks/lo-inf.md 2>&1); code=$?
if [[ ${code} -ne 2 ]]; then
    echo "FAIL: a non-finite threshold must be refused, got ${code}: ${out}" >&2; exit 1
fi
grep -q "finite" <<<"${out}" || { echo "FAIL: the refusal must say why: ${out}" >&2; exit 1; }

# A large-but-finite exponent threshold is still a legitimate gate.
cat > arsenal/tasks/lo-e.md <<'MD'
# E
## Acceptance gate
```gate
bytes <= 1e6
evidence: metrics.json
key: value
```
MD
echo '{"value": 1000}' > metrics.json
python3 "${GE}" arsenal/tasks/lo-e.md >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "FAIL: a finite exponent threshold must still pass" >&2; exit 1
fi
echo "PASS: a non-finite threshold is refused; a finite exponent still works"

echo "PASS: gate_evidence_test — all gates passed"
exit 0
