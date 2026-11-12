---
id: t-cbb2c98f
title: "review: open_task_pr issue lookup hardcodes the label and reads one page of 100"
priority: 5
requires: [human:gate]
---

Imported from issue #593

**Severity:** medium · **Confidence:** high · **Category:** correctness

**Where:** `plugins/core/skills/init/assets/bin/open_task_pr.sh:624-645, plugins/core/skills/init/assets/scripts/queue_hooks.py:73`

### Finding
_resolve_issue queries `issues?labels=arsenal:task&state=all&per_page=100` with no pagination, while queue_hooks.py uses the configurable `task-label` setting. A board with more than 100 task issues ever (state=all) or a repo that changed task-label gets 'cannot resolve the issue handle' and no PR; the fallback file is a fixed /tmp/arsenal-issues.json with no freshness or ownership check.

### Evidence
Read both: literal `arsenal:task` and single request in the shell script; `TASK_LABEL = setting("task-label")` and paginate() in queue_hooks.

### Suggested direction
Resolve through one Python helper that reads task-label and paginates; put the cache file under arsenal/session/ instead of /tmp.

_From the full repo review of 2026-11-11 (finding #9). Not fixed yet; verify before acting._

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
