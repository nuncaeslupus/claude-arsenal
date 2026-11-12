---
id: t-4a1ebaf9
title: "review: python-bootstrap hands off to a private `model-gen` / `model-val` toolkit"
priority: 5
requires: [human:gate]
---

Imported from issue #603

**Severity:** medium · **Confidence:** high · **Category:** correctness

**Where:** `plugins/core/skills/python-bootstrap/SKILL.md:54-59, plugins/core/skills/python-bootstrap/scripts/analyze_project.py:7,95`

### Finding
Step 3 tells any consumer whose repo has `models/*.json` that 'the project drives a JSON-spec backend generator' and that models/schemas/routes 'belong to the model-generator toolkit (`model-gen` / `model-val`)'. No such toolkit ships or is linked; a repo with ML model configs in `models/` gets pointed at tools it does not have. This is the convention-not-provenance case CLAUDE.md § Everything shipped is generic forbids.

### Evidence
grep -rn 'model-gen|model_gen' plugins → only this skill; analyze_project.py sets specs_present from any models/*.json.

### Suggested direction
Drop Step 3 and the `model_gen` field, or make the hand-off a host-configured hook.

_From the full repo review of 2026-11-11 (finding #19). Not fixed yet; verify before acting._

## Acceptance gate

<!-- This task came from an issue, so its "gate" is prose. Write a real check
     below, then DELETE the `requires: [human:gate]` line in the front matter.
     Until that line is gone the selector will not offer this task, which is
     deliberate: a prose gate runs nothing, and a gate that runs nothing passes
     everything. -->

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
false
```
