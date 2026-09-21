---
id: t-b720cfe7
title: "Gate evaluation produces false PASSes on three different inputs"
priority: 5
tags: [gates, correctness]
---

Three ways a gate that should fail reports PASS. All three matter because this
repo's central claim is that "done" means a mechanical check passed.

1. run_gate.py:164-168 takes the FIRST number anywhere in the Measured cell via
   a bare re.search, with no scale or provenance check. A cell reading
   `2026-09-21: 0.85` parses as 2026.0 and PASSes `line_coverage >= 0.90`.
   A cell reading `42ms (target 90)` scores 42 against the wrong target.

2. GATE_RE's threshold pattern (run_gate.py:40, same in gate_evidence.py:63)
   is \d+(?:\.\d+)? and stops at a comma: `throughput_rps >= 1,000` parses
   as threshold 1.0, so a measured 50 reports PASS.

3. gate_evidence.py:93-107 lets any later operator-matching line overwrite the
   real assertion, so a trailing note like "previous target was >= 2.0" silently
   becomes the enforced gate.

Done means: each of the three shapes is either evaluated correctly or rejected
loudly. A gate whose assertion cannot be parsed unambiguously must not evaluate.


## Acceptance gate

```bash
python3 - <<'PY'
import sys
sys.path.insert(0, "plugins/core/skills/gate-check/scripts")
import run_gate
p = run_gate.parse_gate("throughput_rps >= 1,000")
assert p and p[2] == 1000.0, f"thousands separator mis-parsed: {p}"
v = run_gate.evaluate("line_coverage >= 0.90", run_gate._measured_from_row({"measured": "2026-09-21: 0.85"}))
assert v["verdict"] != "PASS", f"date in Measured cell produced {v['verdict']}"
PY
```
