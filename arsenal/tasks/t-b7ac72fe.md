---
id: t-b7ac72fe
title: "sync_duplicates.py can't see cross-plugin .py duplicate pairs"
priority: 10
tags: [tooling, validator]
---

`sync_duplicates.py`'s primary `.py` scan (`discover()`, plugins/skill-workshop/skills/skill-workshop/scripts/sync_duplicates.py:98-107) only looks inside whatever single `--library` directory is passed (default: plugins/skill-workshop/skills), with no accumulation across invocations. Its `.sh` secondary scan already walks the whole repo (same file, lines 109-122) — the `.py` scan has no equivalent. The `sync-dupes` Makefile target never overrides `--library`, so `make sync-dupes` only ever checks skill-workshop's own scripts, and isn't wired into any CI workflow or the audit/smoke/test/lint targets. Nothing drifts silently in CI today — `make audit`'s `audit_library.py plugins/*/skills --by-plugin` has its own, separate, correctly repo-wide duplicate detection and is what CI actually runs — but a maintainer who runs sync-dupes directly (the tool built specifically for this) gets a false-clean result for every cross-plugin or cross-skill .py duplicate pair it isn't pointed at, including create_artifact.py (repo-audit skill vs. explain-repo skill) and create_task.py (core's queue-add vs. repo-audit).

Suggested direction: give the primary scan the same repo-wide fallback the .sh scan already has — walk plugins/*/skills/*/scripts/*.py from the repo root by default instead of only the single passed --library — or have the Makefile target loop over every plugin's skills dir and merge the groups before reporting.


## Acceptance gate

```bash
# The scan must see duplicate .py pairs that span plugins, and ones living
# outside a skill's scripts/ dir. All three were invisible to the old
# library-scoped scan.
out=$(python3 plugins/skill-workshop/skills/skill-workshop/scripts/sync_duplicates.py --check 2>&1)
echo "$out"
for pair in gate_target.py create_task.py create_artifact.py; do
  echo "$out" | grep -q "$pair" || { echo "scan is blind to $pair" >&2; exit 1; }
done
```
