# GitHub automation — merging, and the upkeep GitHub does

Read this when a merge did not close its task, when a PR check about the closing
keyword fails, or when deciding whether to install / remove
`.github/workflows/arsenal-queue.yml`.

---

## Completion — merging is the update

The failure the previous design could not fix: merging a PR and updating the queue were
two separate acts, and the second got forgotten. Worse, `reconcile_merged.sh` — the script
meant to catch that — was `gh`-gated and so never ran on the web at all.

Merging is now the whole of it, and **no step in this protocol asks anyone to finish a
task**. `open_task_pr.sh` resolves the task's issue number, writes `Closes #<issue>` into
the PR body *and* the commit message, and moves the task file into `tasks/_history/` with
`status: merged` inside the same diff. So one merge closes the issue, archives the file,
and unblocks the dependents.

Writing the keyword in both places is not belt-and-braces for its own sake — each covers
a case the other does not. The body form fires on a merge into the **default** branch; the
commit form survives a squash and is what closes the issue for a **stacked** PR whose base
is another branch, when that commit eventually lands.

> The keyword used to be prose here and in `worker.md` — "make sure the body carries
> `Closes #<issue>`" — while nothing anywhere computed which issue that was and
> `open_task_pr.sh` wrote a body without it. An instruction with no data path behind it is
> a step that does not happen, so every task PR merged closing nothing. If you are reading
> a protocol that asks you to remember a completion step, that is the bug.

**When the helper refuses.** No resolvable issue handle means a PR that would merge
without closing anything, so it stops before touching git, leaving the worker's edits
intact. Pass `ARSENAL_TASK_ISSUE=<n>` (the orchestrator has the number from step 2 of the
session-start protocol in `AGENTS.md`) or create the handle with `handle_sync.py`. Do not reach for
`ARSENAL_ALLOW_UNLINKED_PR=1` to get past it — that is the old silent failure, opted into.
## Upkeep GitHub does — `.github/workflows/arsenal-queue.yml`

Merging covers a task that finished. Four things it cannot cover happen when **no session
is running**, and each used to be a line asking an agent to tidy up at the end — the least
reliable place to put anything, since the sessions that most need cleaning up are the ones
that ended badly:

| Event | What GitHub does |
|---|---|
| Task PR merged, keyword never fired | Closes the issue as completed, archives the task file |
| Task PR closed **without** merging | Removes `arsenal:claimed` + the assignee, so the task returns to the board |
| Task file lands on the default branch | Opens its `arsenal:task` issue handle immediately |
| Claim held >24h with no open PR | Releases it — the session holding it crashed |
| Task PR opened with no closing keyword | Fails its check **before** the merge |

`/init` installs the workflow and prints what it does and what it can touch. It never runs
code from a pull request, and only a merge into the **default** branch completes a task —
a stacked PR merging into another branch is not done yet, exactly as the keyword itself
behaves. Deleting the file opts out for good: `/init` records `queue-automation = false` in
`arsenal/config.toml` rather than reinstalling it on the next session start.

A repo without the workflow still works — the merge path is unchanged — but a session there
has to expect stale claims and unhandled task files, and fix them before starting.

So the session-start protocol's job is genuinely to read the board and pick up work. If
step 3 or 4 reports problems in a repo that has the workflow, that is a signal something
is wrong, not the normal cost of starting.
