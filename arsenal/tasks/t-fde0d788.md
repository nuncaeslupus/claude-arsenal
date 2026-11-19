---
id: t-fde0d788
title: "T4: proofsheet.py build: manifest, item kinds, compare, verdicts, media"
label: "proofsheet: build"
priority: 1
deps: [t-eadef7eb]
tags: [proofsheet]
workspace: proofsheet
---

Plan row T4 in `arsenal/project/proofsheet/plan.md` (spec: `arsenal/project/proofsheet/spec.md`). Tests named in that row are written failing first.

## Acceptance gate

```bash
set -e
python3 -m pytest -q plugins/core/tests/proofsheet_test.py -k build
```
