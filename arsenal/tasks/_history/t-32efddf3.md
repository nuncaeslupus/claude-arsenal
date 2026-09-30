---
id: t-32efddf3
title: "AGENTS.md: after compaction, resume from task notes + git, not the summary"
priority: 10
deps: [t-2cd1edc5]
tags: [agents]
status: merged
---

The session-start protocol treats compaction like a fresh start and reads only
`handover.md`, which is written at session end — not mid-task.

Done means: one line in `AGENTS.md` says that after compaction with a claimed task the
notes file and `git status` are the state, and the summary is a pointer to them.
`AGENTS.md` stays within its 250-line cap and the resident tier under budget.

## Acceptance gate

```bash
bash plugins/core/tests/compact_resume_test.sh agents
```
