---
id: t-dfb7e2a9
title: "T8: proofsheet.py milestone page; apply closes decided items"
label: "proofsheet: milestone page"
priority: 5
deps: [t-0858d047, t-4f52f364]
tags: [proofsheet]
workspace: proofsheet
---

Plan row T8 in `arsenal/project/proofsheet/plan.md` (spec: `arsenal/project/proofsheet/spec.md`). Tests named in that row are written failing first.

## Acceptance gate

```bash
set -e
python3 -m pytest -q plugins/core/tests/proofsheet_test.py -k milestone
```
