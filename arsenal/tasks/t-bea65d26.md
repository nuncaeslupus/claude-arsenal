---
id: t-bea65d26
title: "review: Documented `git add` after /init leaves the README badge uncommitted"
priority: 5
requires: [human:gate]
---

Imported from issue #596

**Severity:** medium · **Confidence:** high · **Category:** docs

**Where:** `README.md:36, docs/INSTALL.md:72, docs/INSTALL.md:124, docs/UPDATE.md (Upgrading), plugins/core/skills/init/scripts/init.py:1649-1683`

### Finding
Quick start says `git add .claude claude-arsenal arsenal .github CLAUDE.md .gitignore`, but init also edits README.md (attribution badge) by default. Following the docs leaves README.md modified in the main tree, which then trips the worker loop's 'main working tree is clean' precondition and can be swept into an unrelated PR.

### Evidence
init.py `_add_attribution` writes README.md when a title exists and attribution is unset; the three documented `git add` lines omit README.md; plugins/core/skills/init/assets/references/worker-loop.md:23-30 requires a clean tree.

### Suggested direction
Add README.md to the documented commit, or have init print the exact `git add` list for what it touched.

_From the full repo review of 2026-11-11 (finding #12). Not fixed yet; verify before acting._

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
