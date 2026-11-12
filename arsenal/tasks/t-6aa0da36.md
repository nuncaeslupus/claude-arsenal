---
id: t-6aa0da36
title: "review: No uninstall path for what /init vendors"
priority: 5
requires: [human:gate]
---

Imported from issue #600

**Severity:** medium · **Confidence:** high · **Category:** docs

**Where:** `README.md:171, docs/INSTALL.md:174-184, docs/UPDATE.md`

### Finding
README links 'Update & uninstall' to docs/UPDATE.md, which has no uninstall section at all; INSTALL § 6 only removes the plugins. Nothing explains how to remove `.claude/skills/*` (marker folders), `claude-arsenal/`, the CLAUDE.md protocol block, the hooks and statusLine in `.claude/settings.json`, `.github/workflows/arsenal-queue.yml`, the README badge or the branch-protection rule. Removing the plugin leaves a repo whose every session still runs the protocol.

### Evidence
grep -n -i uninstall docs/UPDATE.md → no match.

### Suggested direction
Add an `init.py --uninstall` (or a documented checklist) covering every path and remote setting init writes.

_From the full repo review of 2026-11-11 (finding #16). Not fixed yet; verify before acting._

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
