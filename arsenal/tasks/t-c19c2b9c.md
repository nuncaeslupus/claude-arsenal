---
id: t-c19c2b9c
title: "repo-audit/skill-workshop: fix doc drift"
label: "audit skills: doc drift"
priority: 10
tags: [skills]
---

- explain-repo: `references/document-types.md:74-76` uses the wrong pass names, and no runnable
  `create_artifact.py` invocation is given.
- repo-audit: `research-categories.md:3-4` contradicts the SKILL.md fan-out;
  `output-shape.md:10-12` uses the wrong trigger term; :69-71 says "this repo's test-first".
- skill-workshop: the Commands block omits `audit_rule_drift.py` and `audit_alignment.py`, and
  the trigger phrases in `frontmatter-and-naming.md:41-43` disagree with `validate.py:62`.

Found by the semantic skill-workshop walk over all skills (2026-11-09).

## Acceptance gate

```bash
set -e
grep -q audit_rule_drift.py plugins/skill-workshop/skills/skill-workshop/SKILL.md
if grep -q "this repo's test-first" plugins/repo-audit/skills/repo-audit/references/output-shape.md; then exit 1; fi
grep -q 'create_artifact.py' plugins/repo-audit/skills/explain-repo/SKILL.md
```
