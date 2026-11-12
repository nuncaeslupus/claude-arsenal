---
id: t-df0ae47a
title: "review: Onboarding command /init collides with Claude Code's built-in /init"
priority: 5
requires: [human:gate]
---

Imported from issue #589

**Severity:** high · **Confidence:** medium · **Category:** ux

**Where:** `README.md:32, docs/INSTALL.md:68, docs/INSTALL.md:215, plugins/core/skills/init/SKILL.md:2`

### Finding
README and INSTALL tell a new user to type `/init` right after `/plugin install core@claude-arsenal`. Plugin skills are namespaced (`core:init`, as INSTALL itself says for `core:specify`), and Claude Code ships a built-in `/init` that writes a CLAUDE.md; a first-time user typing `/init` gets the built-in, not the installer, and nothing says so. INSTALL.md:215 even warns that a bare name 'can quietly resolve to an unrelated built-in of the same name', but no doc ever gives the namespaced form.

### Evidence
grep for `core:init` in README/INSTALL/UPDATE/queue.md returns no invocation form; this session's own skill listing shows a built-in `init: Initialize a new CLAUDE.md file`. Not reproduced in a live CLI (resolution order unverified).

### Suggested direction
Document `/core:init` (or rename the skill, e.g. `arsenal-init`) and state how to tell the two apart; same check for `review` vs the built-in /review.

_From the full repo review of 2026-11-11 (finding #5). Not fixed yet; verify before acting._

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
