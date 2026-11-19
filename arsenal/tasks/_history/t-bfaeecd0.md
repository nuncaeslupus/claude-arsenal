---
id: t-bfaeecd0
title: "T1: review-notes v1: shared notes and verdict format"
label: "proofsheet: notes format"
priority: 10
tags: [proofsheet]
workspace: proofsheet
status: merged
---

Plan row T1 in `arsenal/project/proofsheet/plan.md` (spec: `arsenal/project/proofsheet/spec.md`). Tests named in that row are written failing first.

## Acceptance gate

```bash
set -e
python3 -m pytest -q plugins/core/tests/review_notes_test.py
```
