---
id: t-2cd1edc5
title: "SessionStart(compact) hook re-injects the active task's notes + git status"
priority: 5
deps: [t-a91a0550]
tags: [hooks]
---

After compaction the model resumes from the summary alone. A `SessionStart` hook with
matcher `compact` runs right after compaction and its stdout lands in context — a
PreCompact hook cannot reach the model, so it is not the lever.

Done means: `claude-arsenal/bin/compact_resume.sh` prints the resume block of the most
recently modified `tmp/*-notes.md` plus a short `git status`, stays silent when there is
none, never fails the session, and `/init` registers it in `.claude/settings.json`
(idempotently). The core plugin's `hooks.json` registers it too.

## Acceptance gate

```bash
bash plugins/core/tests/compact_resume_test.sh hook
```
