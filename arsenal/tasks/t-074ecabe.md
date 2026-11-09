---
id: t-074ecabe
title: "github skill: fix stale and garbled references"
label: "github: stale references"
priority: 10
tags: [skills]
---

`github/SKILL.md:76-77` points at a "rubric in the loop command" that no longer exists, and
:83-84 is a garbled sentence. In `references/pr-review-loop.md`: there is no load trigger at :3;
:42 says "(since 5.19.0)", which is history; the history at :26 is repeated at :84; and :99
says "below" where it means "above".

Found by the semantic skill-workshop walk over all skills (2026-11-09).

## Acceptance gate

```bash
set -e
if grep -q 'rubric in the loop command' plugins/core/skills/github/SKILL.md; then exit 1; fi
if grep -q 'since 5.19.0' plugins/core/skills/github/references/pr-review-loop.md; then exit 1; fi
python3 plugins/skill-workshop/skills/skill-workshop/scripts/validate.py plugins/core/skills/github
```
