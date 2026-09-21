---
id: t-b7ac72fe
title: "sync_duplicates.py can't see cross-plugin .py duplicate pairs"
priority: 10
tags: [tooling, validator]
---

`sync_duplicates.py`'s primary `.py` scan (`discover()`, plugins/skill-workshop/skills/skill-workshop/scripts/sync_duplicates.py:98-107) only looks inside whatever single `--library` directory is passed (default: plugins/skill-workshop/skills), with no accumulation across invocations. Its `.sh` secondary scan already walks the whole repo (same file, lines 109-122) — the `.py` scan has no equivalent. The `sync-dupes` Makefile target never overrides `--library`, so `make sync-dupes` only ever checks skill-workshop's own scripts, and isn't wired into any CI workflow or the audit/smoke/test/lint targets. Nothing drifts silently in CI today — `make audit`'s `audit_library.py plugins/*/skills --by-plugin` has its own, separate, correctly repo-wide duplicate detection and is what CI actually runs — but a maintainer who runs sync-dupes directly (the tool built specifically for this) gets a false-clean result for every cross-plugin or cross-skill .py duplicate pair it isn't pointed at, including create_artifact.py (repo-audit skill vs. explain-repo skill) and create_task.py (core's queue-add vs. repo-audit).

Suggested direction: give the primary scan the same repo-wide fallback the .sh scan already has — walk plugins/*/skills/*/scripts/*.py from the repo root by default instead of only the single passed --library — or have the Makefile target loop over every plugin's skills dir and merge the groups before reporting.


## Acceptance gate

<!-- Replace this with a fenced bash block. A gate that is only prose runs
     nothing, and a gate that runs nothing passes everything — `task_select.py`
     reports gate: false for a task with no block, so an unenforced gate is
     visible rather than quietly inert. -->

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
# e.g. bash tests/surface_probe_test.sh
false
```
