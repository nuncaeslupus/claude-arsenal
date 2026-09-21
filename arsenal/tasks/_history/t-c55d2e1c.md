---
id: t-c55d2e1c
title: "worker_postcheck.sh runs reset --hard against whatever tree the caller is in"
priority: 10
tags: [fleet, safety]
status: merged
---

worker_postcheck.sh runs `git reset -q --hard` and `git clean -fdq` (:230-231)
with no `cd` to the repo root and no `git -C`, so it operates on whatever tree
the caller's CWD happens to be. The only rev-parse --show-toplevel in the file
(:188) is inside _isolation_from_worker_root, comparing roots for the isolation
verdict — it does not anchor the destructive path.

Its sibling open_task_pr.sh added exactly that anchor (:161-169) after two
numbered incidents of this class (#239, #244). The script's own comment concedes
the assumption: "this runs in the host's shared tree, where the assumption can
be wrong."

Severity is bounded by a real mitigation: _rescue_before_restore snapshots to a
refs/arsenal-rescue/ ref first and REFUSES with exit 3 if it cannot, so work is
recoverable. The sharper consequence is the isolation verdict — computed from
that same wrong CWD and written into the sentinel task_select.py reads to decide
how wide to fan out the next batch.

Done means: the script anchors to the repo root before any destructive call, the
way open_task_pr.sh does.


## Acceptance gate

```bash
# The destructive path anchors to the repo root, and refuses when there
# is no repository to anchor to.
bash plugins/core/tests/worker_postcheck_test.sh
```
