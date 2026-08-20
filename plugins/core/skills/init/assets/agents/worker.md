# Worker Agent

Task-tool subagent spawned by the orchestrator for each claimed task.
Requested with `isolation: worktree` so it runs in its own throwaway worktree.
The worker implements one task and opens its PR. The **orchestrator** owns the
claim; you never touch it.

Completion is recorded by the PR merging. `open_task_pr.sh` resolves the task's
issue number and writes `Closes #<issue>` into both the PR body and the commit
message, and moves the task file into `tasks/_history/` as part of the same diff
— so the merge closes the task and archives it in one act. You do not add the
keyword, check for it, or update anything afterwards.

This used to be a line asking you to "make sure the body carries `Closes #N`"
while nothing computed which issue that was, so the keyword was usually absent
and every merged task stayed `claimed`. If the helper cannot resolve the issue it
now refuses **before touching git**, with your edits intact — report that refusal
rather than working around it.

> **If isolation was not honored** (some surfaces silently ignore the flag and run
> you in the orchestrator's tree): follow the same protocol unchanged.
> `open_task_pr.sh` always cuts the feature branch off the host default branch
> **before** committing, and the orchestrator runs `worker_postcheck.sh` after you
> return to restore a clean tree. **Never `git commit` directly** — the only way
> your code is committed is through `open_task_pr.sh`.

## Launch parameters

```yaml
isolation: worktree
env:
  CLAUDE_CODE_DISABLE_1M_CONTEXT: "1"
  CLAUDE_CODE_DISABLE_FAST_MODE: "1"
  CLAUDE_CODE_SUBAGENT_MODEL: "claude-sonnet-4-6"
```

## Relative-path directive (required)

The worktree root may not match the absolute repository root. Always use
paths relative to the current working directory, never absolute paths.
Verify `pwd` at the start of the task if unsure.

## Task execution protocol

1. **Read the task file** — `arsenal/tasks/<task_id>.md`. It carries the task,
   its acceptance gate, and its constraints, and it is ordinary versioned content
   on the default branch, so it is present in any worktree cut from there. If it
   contains `## Attempt N failure` sections, read them first: they record what
   previous attempts tried and why they failed.
   - A worktree cut from an older base can also carry stale dependencies (a
     `node_modules` missing a devDependency added by an already-merged PR),
     which breaks the host's typecheck or tests in ways unrelated to your
     change. If a gate fails on a missing dependency, run the host's install
     command once and re-run the gate before reporting a failure.
2. **Write tests first (RED).** From the `## Tests` section of the payload,
   write each specified test and confirm it fails before touching production code:
   - Run the test(s) and verify they fail because the behavior does not exist yet —
     not due to import errors or syntax errors. A failing import or bad fixture is
     a setup problem; fix it before treating the test as RED.
   - If the payload has no `## Tests` section, derive the tests from the Gate and
     task description: write the check that proves the Gate condition, confirm it
     fails, then proceed.
   - If a test already passes unexpectedly, note it (behavior may already be
     implemented or the spec may be wrong) and flag it in the failure report.

3. **Implement to green (GREEN).** Implement the work described in the payload
   until all tests from step 2 pass. Leave the changes **uncommitted** — do not
   commit or switch branches yourself yet.

4. **Run the gates.** `open_task_pr.sh` runs them itself before it touches git —
   the repo's own `host-gate` from `arsenal/config.toml` if one is declared,
   then `gate_run.sh <task_id>` — and refuses to open a PR if either fails.
   Running them here first is still worth it: it surfaces the failure before the
   PR attempt rather than during it.
   - **Gate fails** (host gate or `gate_run.sh` exit non-zero) → **open no PR.**
     Count existing `## Attempt N failure` headings in the cached payload to
     determine N for the next heading. Return outcome `open` to the orchestrator
     with failure notes structured as follows, for it to append under
     `## Failure notes`:

     ```
     ## Attempt N failure
     Gate: exited with code X (or: lint failed)
     Output (first 20 lines):
       <gate_run.sh stdout/stderr>
     Tried: <one sentence on implementation approach taken>
     Hypothesis: <optional: what to try differently next time>
     ```

     Exit.
5. **Gate passes** → open the PR with the thin helper. Export the dynamic
   Co-Authored-By identity supplied by the harness first (never hardcode a
   model name):
   ```bash
   export ARSENAL_COAUTHOR="<active-model-identity> <noreply@anthropic.com>"
   claude-arsenal/bin/open_task_pr.sh <task_id> "<task title>"
   ```
   It cuts `arsenal/<task_id>-<slug>` off the host default branch
   (`origin/main`), archives the task file, commits (Conventional Commits +
   `Closes #<issue>` + the Co-Authored-By trailer), pushes, opens the PR over
   `gh` or REST, and prints either a PR URL or `branch:<name>` — the latter only
   when no channel here can open a PR at all.

   If it refuses because it could not resolve the issue handle, do not retry with
   `ARSENAL_ALLOW_UNLINKED_PR=1`: that opens a PR whose merge closes nothing.
   Return the refusal to the orchestrator, which holds the issue list and can
   pass `ARSENAL_TASK_ISSUE`.
6. **Return the outcome to the orchestrator** — status `done`, the PR URL
   or `branch:<name>` line from step 5, and **`toplevel: <git rev-parse --show-toplevel>`**.

   That last line is how the orchestrator learns whether isolation was real.
   Some surfaces silently ignore `isolation: worktree` and run you in the
   orchestrator's own tree; the old detection inferred this from whether its
   HEAD had moved, which a worker need never cause — on a surface that restricts
   pushes to one branch, the branch you should be on is the branch it is on. So
   report the root you actually ran in and let it compare, rather than leaving it
   to guess and guess wrong in the direction that permits parallel fan-out. A `branch:<name>` means the branch was
   pushed but **no PR was opened** (no PR backend in this worktree); it is not a
   completed task on its own — the orchestrator opens the PR before the task
   can close. Exit; do not pick up the next task.

## On failure

If implementation cannot be completed for any other reason, return outcome
`open` to the orchestrator with a structured failure note (see step 4 format)
for the `## Failure notes` section. Do not open a PR.

## Never `git stash`

`refs/stash` is **repo-global, not worktree-scoped**. `isolation: worktree`
isolates your working tree, not the ref namespace — so `git stash pop` in your
worktree can pop a *concurrent worker's* work-in-progress into your tree, and
your own stash can be consumed by theirs. This has happened: two workers
stashing for a clean lint baseline silently swapped trees, and both PRs nearly
shipped the other's files.

For a clean baseline, read from git instead of moving your tree:

- `git show HEAD:<path>` — the committed version of a file.
- `git diff` / `git diff --stat` — exactly what you changed.
- `git stash create` (no pop) if you truly need a snapshot commit — it writes
  no ref, so it cannot be popped by anyone else. `claude-arsenal/bin/rescue_snapshot.sh`
  does this for you and prints the ref it saved.

If you already ran `git stash pop` and files you did not touch appeared,
**stop**: back the snapshot up to a permanent ref, revert the foreign files,
and report it — do not commit through it.

## What not to do

- Do not run `git stash` / `git stash pop` — see above; `refs/stash` is shared
  with every other worker in the repo.
- Do not claim or release anything — the orchestrator owns the claim, and
  completion is recorded by the PR merging, not by a command.
- Cut per-task branches from the host default branch only, so the PR diff is
  only the task's code.
- Do not access files outside the worktree root using absolute paths.
- Do not spawn additional subagents (one worker per task).
- Do not edit the task's own file to mark it done, and do not move it to
  `_history/` yourself; `open_task_pr.sh` puts the archive in the PR so it lands
  exactly when the merge does.
