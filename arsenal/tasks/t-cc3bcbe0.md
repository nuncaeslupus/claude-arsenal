---
id: t-cc3bcbe0
title: "review: Session-start protocol runs ~9 steps and 3 GitHub fetches before any request"
priority: 5
requires: [human:gate]
---

Imported from issue #598

**Severity:** medium · **Confidence:** high · **Category:** design

**Where:** `plugins/core/skills/init/assets/AGENTS.md:34-96, docs/UPDATE.md:57-66`

### Finding
Resident AGENTS.md requires, on every fresh start, compaction and restart: check_update.sh, init.py --silent, init.py --list-sections, channel detection, two issue-list fetches, query_status, handle_sync, an import fetch including issue bodies, issue_import --apply, handover read, then auto pick-up of queue work. A user who opens a session to ask one question pays all of it, and step 0a is INERT for the two most common installs (UPDATE.md says so). This is the context-budget rule the repo sets for itself ('narrow the fetch', 'on demand, not resident') not applied to its own hottest path.

### Evidence
Counted steps in AGENTS.md:36-96; UPDATE.md table marks `check_update.sh --check-only` INERT for plugin and clone installs; `init.py --list-sections` alone prints 673 bytes each session.

### Suggested direction
Collapse steps 0-4b into one script that prints a short board summary, skip 0a when the install is not a subtree, and gate queue pick-up on the user's request or an unattended-run flag.

_From the full repo review of 2026-11-11 (finding #14). Not fixed yet; verify before acting._

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
