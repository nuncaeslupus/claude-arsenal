---
id: t-548eabc1
title: "handle_sync.py proposes a duplicate handle when a title changes"
priority: 5
status: merged
tags: [INFRA]
---

Issue #376 — found in a consumer (`nuncaeslupus/opos`) one `--apply` away from
duplicating a live task's handle.

`AGENTS.md` justifies fetching issues without `body` on the grounds that "every
script resolves an issue to its task from the `arsenal-task:` line *or* from the
title". The `arsenal-task:` line lives **in the body**, so without it there is one
path, not two, and any retitle breaks the pairing. `handle_sync.py` then reports
not "I cannot find the issue for `<id>`" but "`<id>` has no issue", which is the
line a caller acts on to open a second one.

Fix: carry the id where the pairing cannot break and the fetch already looks — an
`arsenal-id:<task-id>` label. `task_id_from_issue` reads it before the body and
before the title; `handle_sync.py` puts it on every handle it proposes and says so
when a resolution came from the title. `AGENTS.md` stops offering the body marker
as an available path on a body-less fetch. The token saving stands: labels are
already in the field list.

## Acceptance gate

```bash
bash plugins/core/tests/task_select_test.sh
bash plugins/core/tests/queue_hooks_test.sh
```
