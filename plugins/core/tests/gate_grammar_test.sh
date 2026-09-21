#!/usr/bin/env bash
# gate_grammar_test.sh — the blocking gate and the advisory audit must read the
# same gate text the same way, and neither may guess at a number it cannot parse.
#
# Two parsers implement one grammar: gate_evidence.py hard-fails PR creation,
# run_gate.py reports a verdict that review and ship act on. They had already
# drifted — gate_evidence.py accepted an exponent and run_gate.py did not, so
# `throughput >= 1e6` was a threshold of 1000000 to one and 1 to the other. A
# measured 5 passed the audit and was then refused by the gate, for the same
# line of text. Nothing detected that, because a shared regex is not a shared
# file and carries no duplication header.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "${REPO_ROOT}" || { echo "FAIL: cannot enter ${REPO_ROOT}" >&2; exit 1; }

python3 - <<'PY'
import importlib.util
import sys

FAILED = []


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.path.insert(0, path.rsplit("/", 1)[0])
    spec.loader.exec_module(mod)
    return mod


rg = load("rg", "plugins/core/skills/gate-check/scripts/run_gate.py")
ge = load("ge", "plugins/core/skills/init/assets/scripts/gate_evidence.py")


def check(label, got, want):
    if got != want:
        FAILED.append(f"{label}: got {got!r}, want {want!r}")


# --- 1: the two grammars are literally the same -------------------------------
check("shared number grammar", rg._NUMBER, ge._NUMBER)

# --- 2: and agree on every threshold shape ------------------------------------
# Each of these is a real shape: an exponent, a thousands separator, a trailing
# unit the grammar documents as ignorable, and a malformed group that must be
# refused rather than silently truncated.
for text, want in (
    ("throughput >= 1e6", 1_000_000.0),
    ("rps >= 1,000", 1_000.0),
    ("n >= 1,000,000", 1_000_000.0),
    ("latency <= 200ms", 200.0),
    ("coverage >= 0.90", 0.90),
    ("errors == 0", 0.0),
    ("malformed >= 1,5", None),
):
    parsed = rg.parse_gate(text)
    a = parsed[2] if parsed else None
    m = ge.GATE_RE.search(text)
    b = float(m.group(2).replace(",", "")) if m else None
    check(f"run_gate {text!r}", a, want)
    check(f"gate_evidence {text!r}", b, want)
    check(f"parsers agree on {text!r}", a, b)

# --- 3: a Measured cell is a measurement, not any cell containing a digit ------
# `42ms` is 42 by design — the grammar allows a trailing unit. `2026-09-21: 0.85`
# also begins with a number, and used to score 2026.0 and PASS a >= 0.90 gate.
for cell, want in (
    ("0.93", 0.93),
    ("42ms", 42.0),
    ("**0.93**", 0.93),
    ("`0.95`", 0.95),
    ("1,200", 1200.0),
    ("2026-09-21: 0.85", None),
    ("n/a", None),
    ("", None),
):
    check(f"measured {cell!r}", rg._measured_from_row({"measured": cell}), want)

# A gate whose measurement cannot be read must not report PASS.
verdict = rg.evaluate("coverage >= 0.90", rg._measured_from_row({"measured": "2026-09-21: 0.85"}))
check("unreadable measurement is not a PASS", verdict["verdict"], "UNKNOWN")

# --- 4: the first assertion in a gate block wins ------------------------------
# A trailing note carrying an operator used to overwrite the real gate.
block = "cpcv_sharpe >= 1.0\nevidence: metrics.json\nkey: sharpe\nnote: previous target was >= 2.0\n"
_fields, gate_line = ge._parse_block(block)
check("first assertion wins", gate_line, "cpcv_sharpe >= 1.0")

if FAILED:
    for line in FAILED:
        print(f"FAIL: {line}", file=sys.stderr)
    sys.exit(1)
print("PASS: both parsers share one grammar and agree on every shape")
print("PASS: a Measured cell that is not a measurement does not become a verdict")
print("PASS: the first assertion in a gate block is the one enforced")
PY
rc=$?
[[ "${rc}" -eq 0 ]] || exit 1

echo "=== gate_grammar_test: all passed ==="
exit 0
