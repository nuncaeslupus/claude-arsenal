---
id: t-eadef7eb
title: "T2: Shared page core; the reader adopts it, speech-bubble icon, note font fix"
label: "proofsheet: page core"
priority: 5
deps: [t-bfaeecd0]
tags: [proofsheet]
workspace: proofsheet
---

Plan row T2 in `arsenal/project/proofsheet/plan.md` (spec: `arsenal/project/proofsheet/spec.md`). Tests named in that row are written failing first.

## Acceptance gate

```bash
set -e
python3 -m pytest -q plugins/core/tests/page_core_test.py
```
