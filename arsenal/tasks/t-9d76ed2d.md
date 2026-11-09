---
id: t-9d76ed2d
title: "queue-add: document every flag and the id label"
label: "queue-add: flags and label"
priority: 10
tags: [skills]
---

- The `argument-hint` omits `--size` and `--body`, and the example uses the raw `--priority`
  where `--size` is preferred.
- The issue instructions omit the `arsenal-id:<id>` label.
- "Replace before claimed" contradicts `evidence-gates.md`.
- `references/payload-template.md:18-19` uses project-specific anchors ("full-Σ NegBin", "R-1");
  shipped content must be generic.

Found by the semantic skill-workshop walk over all skills (2026-11-09).

## Acceptance gate

```bash
set -e
grep -q -- '--size' plugins/core/skills/queue-add/SKILL.md && grep -q -- '--body' <(sed -n 5p plugins/core/skills/queue-add/SKILL.md)
grep -q 'arsenal-id:' plugins/core/skills/queue-add/SKILL.md
if grep -q NegBin plugins/core/skills/queue-add/references/payload-template.md; then exit 1; fi
python3 plugins/skill-workshop/skills/skill-workshop/scripts/validate.py plugins/core/skills/queue-add
```
