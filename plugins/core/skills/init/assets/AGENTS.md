# Claude Arsenal

<!-- claude-arsenal v0.29.0 — imported via @claude-arsenal/AGENTS.md -->

This file is imported by the host repo's `CLAUDE.md` via the session-protocol block
that `/init` injects. It provides the mechanics behind the proactive directives
in that block: queue seeding, worker dispatch, credit guards, and state layout.

---

## Session-start protocol

At the start of every session (fresh start, context compaction, or cold restart):

0. **Refresh the bundle**:
   a. If `claude-arsenal/bin/check_update.sh` exists, run it **with
      `--check-only`**. It reports being current, a missing `arsenal` remote, a
      bundle ahead of the newest tag, an `UPDATE AVAILABLE`, and — the one that has
      bitten consumers — an `UNTAGGED UPSTREAM RELEASE`, where upstream's default
      branch ships a version whose tag was never pushed. Surface any of those; the
      fix for an untagged release is upstream (`make tag`), not here.

      `--check-only` matters: without it the script merges the new subtree and
      commits. That is a history-writing side effect from a step described as a
      report, and it lands in the same main working tree the worker loop requires
      to be clean. Pull the update deliberately, not as a side effect of reading.
   b. Run `python3 .claude/skills/init/scripts/init.py --repo-path . --silent` to
      refresh any stale bundle script. Report anything it refreshes. Skip (a) and (b)
      when that script is not present.

1. **Establish the GitHub channel** — `bash claude-arsenal/bin/github_channel.sh --detect`.
   It prints `gh`, `rest`, or `none`. **`none` is not a failure**: it means no
   scriptable channel exists on this surface, so every GitHub step below is performed
   with your own built-in GitHub tools instead. What must not happen is skipping those
   steps. The previous protocol gated them on `command -v gh`, which turned required
   work into silent no-ops — on Claude Code on the web, where `gh` is absent, the
   merge-reconciliation and false-`done` checks therefore never ran at all.

2. **Fetch the task issues** — list issues labelled `arsenal:task`, **open and closed**,
   and save the JSON (e.g. to `/tmp/arsenal-issues.json`). Closed ones are not optional:
   a closed-as-completed issue is what marks a dependency satisfied.

3. **Read the board** —
   `python3 claude-arsenal/scripts/query_status.py --issues /tmp/arsenal-issues.json`.
   Report anything it flags: a task with no fenced gate block, a task file with no issue
   handle, or a dep that no task file declares.

4. **Create any missing handles** —
   `python3 claude-arsenal/scripts/handle_sync.py --issues /tmp/arsenal-issues.json`
   prints one JSON object per task file that has no issue yet; create those issues with
   the `arsenal:task` label and a visible `` `arsenal-task: <id>` `` line in the
   body. It must be visible text, not an HTML comment: some GitHub tools strip
   angle-bracketed content from bodies, and an id that is stripped leaves the
   issue anonymous and the board reading as stateless.
   This is the only sync in the system: one-directional and idempotent, so a failure
   delays work rather than corrupting it.

5. **Read handover** — if `arsenal/session/handover.md` has content beyond the template
   placeholder, read it for the previous session's context.
   > The handover is a snapshot from compaction time, not current state. Never resume a
   > task named there without re-reading the board first — the queue is the truth.

6. **Pick up work** — go to **Worker loop algorithm**. If the selector returns nothing
   and workspace plans exist, seed from them (see **Queue seeding**); if there is no plan
   either, report done or ask the user.

7. **Before ending a session with open work** — audit every task whose issue is claimed or
   whose PR is open (CI, reviews, mergeability), print the table for the user, then write
   `arsenal/session/handover.md`. `/session-end` does this in full; defer to it when loaded.

## Queue seeding from workspace plans

When there are no task files yet and workspace plans exist (per
`arsenal/project/overview.md`), seed the queue from each workspace's plan
without asking the user first.

For each workspace listed in the overview:
1. Read `arsenal/project/<workspace>/plan.md` for the implementation-tasks table.
2. Seed tasks for that workspace using `--workspace <NAME>` flag on `new_task.py`.

The table columns are: `T# | Description | Location | Size | Depends | Gate | Tests`

**Steps:**

1. Add tasks with no dependencies first, capturing each printed ID
   (priority: S=10, M=5, L=1):
   ```bash
   python3 .claude/skills/queue-add/scripts/new_task.py \
     --title "T1: <Description>" \
     --priority 10 \
     --workspace FRONTEND \
   # → prints e.g. t-3f8a91c2, and the issue handle to open on stderr
   ```

2. Add tasks whose deps are now in the queue:
   ```bash
   python3 .claude/skills/queue-add/scripts/new_task.py \
     --title "T3: <Description>" \
     --priority 5 \
     --workspace FRONTEND \
     --deps t-3f8a91c2 \
   ```

3. `new_task.py` writes `arsenal/tasks/<id>.md`; fill in its body and replace the
   placeholder gate:

   ```markdown
   # T1: <Description>

   ## Acceptance gate
   <Gate column content — prose describing what must be true.>

   If the check is mechanically runnable, also add a bash block:
   ```bash
   bash tests/my_feature_test.sh
   ```
   `gate_run.sh` executes this block, and a worker opens no PR when it fails —
   so a task cannot reach `done` on a gate that failed or never ran.

   **The fence is what makes a gate mechanical.** Prose, and inline
   `single-backtick` commands, are NOT executed — a payload without a fenced
   ` ```bash ` block runs nothing, and `gate_run.sh` then prints
   `gate: prose-only` (or `gate: none`) with a stderr warning instead of the
   `gate: passed` it prints when a block really ran. Check that line before
   trusting a gate: one consumer audit found 0 of 70 payloads carried a fenced
   block, so its entire gate layer had been inert. Set
   `ARSENAL_GATE_REQUIRE_BLOCK=1` to turn "nothing ran" into a hard failure
   when every task in a repo is meant to carry a mechanical gate.

   ## Tests
   <Tests column content>

   ## Location
   <Location column content>
   ```

   > **Gate blocks run verbatim.** `gate_run.sh` executes the bash block as
   > code in the worker's tree (hardened by default: throwaway HOME + a PATH
   > without `$HOME` shims, except the dirs holding the package manager /
   > language runtime, which stay reachable so a `pnpm …` gate runs instead of
   > dying at exit 127; `ARSENAL_GATE_INHERIT_ENV=1` opts out entirely). Treat a
   > gate block from an untrusted plan/payload as you would any code to run —
   > review it. A gate that could not run exits **3**, never 0 or 1, and
   > a worker treats it as "could not run" rather than reading it as
   > a verdict.

4. Proceed to the **Worker loop algorithm**.

---

## Queue seeding from plan.md

When there are no task files yet and `status/plan.md` exists, seed
the queue from the implementation-tasks table without asking the user first.

The table columns are: `T# | Description | Location | Size | Depends | Gate | Tests`

**Steps:**

1. Add tasks with no dependencies first, capturing each printed ID
   (priority: S=10, M=5, L=1):
   ```bash
   python3 .claude/skills/queue-add/scripts/new_task.py \
     --title "T1: <Description>" \
     --priority 10 \
   # → prints e.g. t-3f8a91c2, and the issue handle to open on stderr
   ```

2. Add tasks whose deps are now in the queue:
   ```bash
   python3 .claude/skills/queue-add/scripts/new_task.py \
     --title "T3: <Description>" \
     --priority 5 \
     --deps t-3f8a91c2 \
   ```

3. `new_task.py` writes `arsenal/tasks/<id>.md`; fill in its body and replace the
   placeholder gate:

   ```markdown
   # T1: <Description>

   ## Acceptance gate
   <Gate column content — prose describing what must be true.>

   If the check is mechanically runnable, also add a bash block:
   ```bash
   bash tests/my_feature_test.sh
   ```
   `gate_run.sh` executes this block, and a worker opens no PR when it fails —
   so a task cannot reach `done` on a gate that failed or never ran.

   **The fence is what makes a gate mechanical.** Prose, and inline
   `single-backtick` commands, are NOT executed — a payload without a fenced
   ` ```bash ` block runs nothing, and `gate_run.sh` then prints
   `gate: prose-only` (or `gate: none`) with a stderr warning instead of the
   `gate: passed` it prints when a block really ran. Check that line before
   trusting a gate: one consumer audit found 0 of 70 payloads carried a fenced
   block, so its entire gate layer had been inert. Set
   `ARSENAL_GATE_REQUIRE_BLOCK=1` to turn "nothing ran" into a hard failure
   when every task in a repo is meant to carry a mechanical gate.

   ## Tests
   <Tests column content>

   ## Location
   <Location column content>
   ```

4. Proceed to the **Worker loop algorithm**.

---

## Evidence gates (numeric acceptance)

A numeric gate — a Sharpe floor, a coverage floor, a latency ceiling — must be
backed by a **committed measurement**, not a worker's word. Declare it in the
payload's `## Acceptance gate` section as a fenced `gate` block:

````markdown
```gate
line_coverage >= 0.90
evidence: coverage.json
key: totals.percent_covered
```
````

Line 1 is the gate in `<metric> <op> <threshold>` grammar (the same grammar the
`gate-check` skill uses); `evidence` is a committed JSON file; `key` is a dotted
path to the measured number inside it. `gate_run.sh` asserts `measured <op>
threshold` over that file: a declared evidence gate with **no** evidence file, or
evidence that **violates** the threshold, is a hard failure — it can never pass
vacuously. This is the machine-checkable half of "`done` means the gate passed"
(closes the false-`done` hole for `[LAPTOP]`/science gates). The release-side
half is enforced at the choke point: a worker opens no PR unless
the PR is opened (not a bare `branch:` ref) and not closed-without-merge; the
payload's mechanical gate passes (it re-runs `gate_run.sh`, so the evidence/bash
gate is a hard precondition); and — for a task tagged **`laptop`** — the session
is not a cloud session. A cloud worker (`CLAUDE_CODE_REMOTE=true`) physically
cannot satisfy a `[LAPTOP]`-only gate (model training, CPCV Sharpe, soak,
paper-trade), so tag such tasks `laptop` (`new_task.py --tag laptop`) and the
laptop session records `done`; a cloud session is refused.

---

## Worker loop algorithm (parallel fan-out)

One orchestrator claims up to `ARSENAL_MAX_WORKERS` independent tasks and
dispatches that many workers at once. Run when the queue has open tasks:

> **Precondition — the main working tree must be clean.** Run
> `git status --porcelain` in the host's main tree before the first dispatch.
> If it reports anything, **stop and tell the user**: commit it, move it to a
> worktree, or explicitly accept the risk. The loop force-restores that tree
> after every worker (step 6), and uncommitted work sitting in it is exactly
> what gets caught. Keep it clean for the whole loop — do not cut branches or
> start edits there while workers are running.

0. **Establish worker isolation (once per session).** Parallel fan-out is only
   safe when each worker runs in its own `git worktree`; without it, concurrent
   workers share one tree and clobber each other, and any worker moves the
   orchestrator's HEAD off the coordination branch. The Task tool's
   `isolation: worktree` flag is **silently ignored on some surfaces** (observed
   on Claude Code on the web), so the orchestrator must establish isolation
   empirically, not assume it:
   - Run `claude-arsenal/bin/worktree_probe.sh`. If it prints `unavailable`
     (exit 1), git worktrees do not work here at all → set
     `ARSENAL_MAX_WORKERS=1` and run **serialized in-place mode** for the whole
     session (one worker at a time; `worker_postcheck.sh` keeps the branch clean
     between them).
   - If it prints `available`, dispatch the **first batch as a single worker**
     regardless of `ARSENAL_MAX_WORKERS`, then inspect the post-worker assertion
     (step 6): if it reports `restored` rather than `ok`, the Task tool did
     **not** honor `isolation: worktree` (it ran in-place and the orchestrator's
     HEAD had to be recovered) → clamp `ARSENAL_MAX_WORKERS=1` and stay in
     serialized in-place mode for the rest of the session. Only ramp to the
     configured `ARSENAL_MAX_WORKERS` once a worker has returned with `ok`,
     confirming real worktrees are in effect.
1. Apply credit guards (see below) if not already set this session.
2. **Budget check** — `claude-arsenal/bin/budget_check.sh`.
   - exit `0` → under quota (or quota unobservable; fail-open) AND under the
     per-session dispatch-round cap. Continue.
   - exit `3` → at/above `ARSENAL_QUOTA_STOP_PCT`, OR the session has dispatched
     `ARSENAL_MAX_ITERATIONS` rounds (the always-available cap). **Stop the
     loop**, write `handover.md`, and report the reason (remaining % + reset
     time, or the round cap). Do not dispatch.
3. Fetch the `arsenal:task` issues over the channel from step 1 of the
   session-start protocol, save them, and ask for the batch:

   ```bash
   python3 claude-arsenal/scripts/task_select.py \
       --issues "${ARSENAL_ISSUES_JSON:-/tmp/arsenal-issues.json}" \
       --max "${ARSENAL_MAX_WORKERS:-2}" \
       ${LOOP_WORKSPACE:+--workspace "$LOOP_WORKSPACE"}
   ```

   → up to N task JSON lines (JSONL), best first. Add `--tag` per `LOOP_TAGS`
   entry to narrow further.
   - Empty → loop done; report summary and write `handover.md`.
   - **No task in the batch can block another in it.** A task whose dep is not
     yet `done` is not eligible at all, so a blocked dependent cannot be
     selected alongside the dep it waits on. This needs no separate rule.
   - **Isolation clamp (mechanical).** `task_select.py` returns at most ONE task
     when worktree isolation is recorded `unavailable` (sentinel
     `arsenal/session/worktree_isolation`, written by `worktree_probe.sh` and
     `worker_postcheck.sh`; override with `ARSENAL_WORKTREE_ISOLATION`). This
     closes the double-dispatch window: once in-place mode is detected, the
     selector itself refuses to hand back a parallel batch, so two workers can
     never be dispatched in one round before the clamp takes effect. The clamp
     lives in the selector rather than in this protocol on purpose — a rule the
     caller has to remember is one it can skip exactly once, in the round that
     discovers isolation is missing.
4. For each task line, `bash claude-arsenal/bin/claim_task.sh <task_id>`
   (sequential — each push is atomic):
   - `won` → keep the task in the dispatch set. `claim_task.sh` reports `won`
     only when GitHub itself created the ref, which guards against a
     restricted-push surface that silently redirects the push off the shared
     ref — the web double-claim vector.
   - `lost` → another session claimed it; drop it from this batch.
   - `error: …` (exit 2) → **stop the loop and surface to the user.** A
     misconfiguration, not a race (wrong branch, protected coordination branch,
     no upstream). Do **not** retry — it spins forever on a deadlock. Re-run
     the GitHub channel (`github_channel.sh --detect`), or fix the
     protection, then resume.
   - **Never work around a `lost` or `error` by creating an upstream, pushing
     `-u`, or re-claiming on a different ref.** A `lost` means another session
     legitimately owns the task; an `error` means the lock is misconfigured.
     "Recovering" the claim by giving your branch its own pushable ref defeats
     the shared-ref lock entirely and lets two sessions both win the same task —
     the precise double-claim failure this protocol prevents. Obey the result.
5. **Spawn every won task as a Task-tool worker subagent in ONE message**
   (see `agents/worker.md`) so they run concurrently:
   - `isolation: worktree`
   - Inject the relative-path directive and the task payload path.
6. **Wait for all workers.** Then, for each returned outcome:
   - **Assert the tree invariant first** —
     `claude-arsenal/bin/worker_postcheck.sh`. It guarantees HEAD is back on the
     session's own branch and the tree is clean. In a real worktree this is a
     no-op (`ok`);
     if it prints `restored`, the worker ran in-place — clamp
     `ARSENAL_MAX_WORKERS=1` per step 0. Exit 2 (could not restore) → stop the
     loop and surface to the user.
   - ⚠️ **`worker_postcheck.sh` is destructive by design.** A `restored` result
     means it ran `git reset --hard` + `git clean -fd` in the tree it was
     invoked from — the host's MAIN working tree, when the orchestrator runs it.
     It restores whenever HEAD is off the recorded host branch, and it cannot
     tell a worker's residue from your own uncommitted work. So:
     - satisfy the loop precondition (step 0) — **the main working tree is
       clean before the loop starts**, and stays that way;
     - **never cut a branch in the main tree while the loop is running**
       (a small docs PR is the classic trigger: the branch moves, the next
       postcheck restores, and everything uncommitted goes with it). Do that
       work in a separate worktree, or commit first.
     - If a restore did catch uncommitted work, the tree was snapshotted first:
       the ref is on `worker_postcheck.sh`'s stderr and in
       `arsenal/session/rescue_refs`. Recover with
       `git checkout <ref> -- .`, and **surface it to the user** — do not
       silently continue the loop over rescued work.
   - Then record the outcome:
     - `done` + **PR URL** → nothing to record. The PR carries `Closes #<issue>`,
       so merging it closes the task by itself. Check the PR is open and the
       keyword is present; that is the whole of "recording done".
       If the worker returned `branch:<name>` instead of a URL (no PR backend was
       available in its worktree), **open the PR for that branch yourself** with
       the `Closes #<issue>` line — a pushed branch is not an opened PR, and a
       task whose PR never opened can never close.
     - `open` (gate failed) → append the worker's `## Attempt N failure` notes to
       the task file so the next attempt can read them, and leave the task for a
       retry. The next attempt claims `<id>.a<n+1>`; past `max-attempts` it stops
       being offered and needs a human.
     - Remove `arsenal:claimed` and your assignment from the issue when you are
       not continuing, so the task is visibly free again.

## Divergence handling

A **spec divergence** is code that contradicts what `spec.md` / `plan.md`
require — wrong labels, wrong scope, a missing step, a wrong constant. Noting one
in `handover.md` prose is **insufficient**: the handover is a snapshot the next
session overwrites, so a prose-only divergence never shows up in `queue-status`,
is never ordered or blocked against other tasks, and silently persists across
context compactions while workers keep building on the wrong inputs.

**Rule: any blocking spec divergence found during a session MUST be seeded as a
queue task before the session ends.** The queue is the source of truth, not the
handover.

Minimum task — title it `D-N` (the Nth divergence this session):

```bash
python3 .claude/skills/queue-add/scripts/new_task.py \
  --title "D-N: <short description>" \
```

In a workspace-structured project, add `--workspace <WORKSPACE>` to file the
divergence under the right workspace; solo / single-workspace repos omit it.
Give it a task file at `arsenal/tasks/<id>.md` that names three things:
what the spec requires, what the code does, and the fix location.

This applies to workers and solo sessions alike. A worker that spots a divergence
outside its own task's scope flags it in its returned outcome; the orchestrator —
the single queue writer — seeds the task (it never lets a worker push to the
coordination branch). A solo session seeds the task directly.

---

## Per-task PRs

Each worker implements its task in an isolated worktree, cuts a feature branch off
the **host default branch** via `claude-arsenal/bin/open_task_pr.sh`, runs the host
lint gate + `gate_run.sh`, and — only if the gate passes — commits (Conventional
Commits + the dynamic `Co-Authored-By` from the `github` skill, never a hardcoded
model), pushes, and opens a PR. The PR diff is just that task's code.

**The PR body must carry `Closes #<issue>`.** That is the entire completion
mechanism: GitHub closes the issue when the PR merges into the default branch, so
nothing has to remember to update the queue afterwards. For a stacked PR whose base
is another branch, put the keyword in the **commit message** instead — the PR-body
form only fires on a merge into the default branch.

Workers never claim or release: the orchestrator owns the claim, and completion is
a property of merging rather than a command anyone runs.

> **Web caveat:** Claude Code on the web differs from the CLI in two ways that
> matter here, so per-task PRs and parallel fan-out are **CLI-first** — verify
> both on the web before relying on them there:
>
> 1. **Restricted pushes.** Git may be routed through a proxy that restricts
>    pushes to the session's designated branch (feature-branch pushes can return
>    HTTP 403).
> 2. **Silent worktree fallback.** The Task tool's `isolation: worktree` flag
>    may be **silently ignored** — no worktree is created and the worker runs in
>    the orchestrator's own tree, moving its HEAD onto the worker's feature branch.
>    This breaks parallelism, because concurrent workers then clobber one tree.
>    The loop guards
>    against it: it probes with `worktree_probe.sh`, dispatches a lone first
>    worker, and runs `worker_postcheck.sh` after every worker to restore the
>    invariant; when isolation turns out to be unavailable it forces
>    `ARSENAL_MAX_WORKERS=1` and runs serialized in-place (loop step 0).
>
> On the CLI both behaviours are unrestricted: pushes are unproxied and
> `isolation: worktree` is honored.

---

## Quota governance — token-budget stop

`statusline_capture.sh` (registered by `/init` as the host `statusLine` command)
writes `arsenal/session/rate_limits.json` (gitignored) from the
`rate_limits` block Claude Code feeds a statusLine on stdin — the only channel
that data arrives on. Before every dispatch, the loop runs `budget_check.sh`:

- Either window (`five_hour` / `seven_day`) at/above `ARSENAL_QUOTA_STOP_PCT`
  (default 90) → exit `3`: stop, write `handover.md`, report the reset time.
- File missing / fields absent (non-Pro/Max plan, before the first response,
  older Claude Code) → exit `0`, **fail-open**: the loop runs where quota is not
  observable.

`rate_limits` is a snapshot at the last message and is **Pro/Max only**; on
API/metered usage the quota check always fails open. So `budget_check.sh` also
enforces an **always-available** per-session dispatch-round cap
(`ARSENAL_MAX_ITERATIONS`, default 50; `0` disables) that does not depend on
observable quota — the real ceiling for an auto-dispatching loop on metered
billing. The counter resets per `CLAUDE_SESSION_ID` and lives in the gitignored
`arsenal/session/budget_iterations.json`.

---

## Tuning knobs

| Env var | Default | Effect |
|---------|---------|--------|
| `ARSENAL_MAX_WORKERS` | `2` | Workers per batch. `2` is the validated git-push concurrency ceiling; higher N raises claim-race churn and PR/merge-conflict surface. **Forced to `1` when worktree isolation is unavailable** (loop step 0): parallel workers are unsafe sharing one tree. |
| `ARSENAL_QUOTA_STOP_PCT` | `90` | Stop the loop before dispatch at/above this used-percentage on either window. |
| `ARSENAL_MAX_ITERATIONS` | `50` | Always-available per-session dispatch-round cap (quota-independent). `0` disables it. |
| `ARSENAL_GATE_INHERIT_ENV` | _(unset)_ | Set `1` to run gate blocks with the caller's full environment instead of the hardened throwaway HOME + restricted PATH. |
| `LOOP_WORKSPACE` | _(unset)_ | Workspace scope; set by `/continue` token inference. |
| `LOOP_TAGS` | _(unset)_ | Comma/space-separated tag scope (ANDed); set by `/continue` token inference. |
| `ARSENAL_QUEUE_REMOTE` | `origin` | Remote for claim refs + per-task pushes. |
| `ARSENAL_CLAIM_PREFIX` | `arsenal/claims` | Ref namespace for atomic claim refs. |
| `ARSENAL_HOME` | `arsenal` | Host-owned tree (tasks, specs, plans, config, session). |

---

## Claiming — how two agents never collide

Two different problems, and conflating them is what made the old design complicated.

**Someone else already holds it.** A human assigned themselves the issue, or a worker is
on it. This is not a race — it happened long before — so it is a precondition check:
refuse to claim a task whose issue is closed, has an assignee, or carries
`arsenal:claimed`.

**Two agents want the same free task.** This *is* a race, and note that an assignee
cannot settle it: every session authenticates as the same GitHub identity, so
"is it assigned?" cannot tell two agents apart. Only the claim ref can.

```
POST /repos/{owner}/{repo}/git/refs   →  201 for exactly one caller
                                      →  422 "Reference already exists" for the rest
```

Creating a ref is a compare-and-swap decided by GitHub. There is no settle interval, no
tie-break, and no window in which two agents both believe they won. It needs no worktree,
no shared branch, and no push — which is why it works on a sandbox that only permits
pushing the session's own working branch.

```bash
bash claude-arsenal/bin/claim_task.sh <task-id>
#   won <ref>   → yours; proceed
#   lost        → someone else has it; take the next task (normal, not an error)
#   manual …    → no scriptable channel: make that exact call with your GitHub tools;
#                 201 = won, 422 = lost
#   error:      → misconfiguration; stop and surface it
```

Never route around a `lost` — claiming a different ref or bumping the attempt number to
"win" recreates exactly the double-claims this exists to prevent.

After winning, mark the issue so a human can see who holds it: self-assign, add
`arsenal:claimed`, and comment with the session id from `CLAUDE_CODE_REMOTE_SESSION_ID`
(a `cse_…` value that is also a session URL, so the claim is clickable). Fall back to
`CLAUDE_CODE_SESSION_ID`. **Do not invent an id** — the old code read `CLAUDE_SESSION_ID`,
which is not set on any current surface, so every claim was attributed to a process id.

**Retries and crashes.** A claim ref cannot be deleted from a sandboxed session, so it is
never released — it is superseded. Attempt *n* claims `<prefix>/<id>.a<n>`, bounded by the
task's `max-attempts`. A crashed session therefore blocks nothing.

**Two costs to know about.** Claim refs accumulate, roughly one per task ever claimed,
grouped under `arsenal/claims/` — prune them from a CLI session occasionally. And creating
a ref fires GitHub's `push`/`create` events, so a repository whose workflows trigger on an
unfiltered `on: push` will run CI on every claim; scope them with
`branches-ignore: ['arsenal/**']`.

---

## Completion — merging is the update

The failure the previous design could not fix: merging a PR and updating the queue were
two separate acts, and the second got forgotten. Worse, `reconcile_merged.sh` — the script
meant to catch that — was `gh`-gated and so never ran on the web at all.

Now the PR body carries `Closes #<issue>` and **GitHub closes the issue when the PR
merges**. There is no second act. A task cannot be recorded complete without a real merged
PR, because the recording *is* the merge.

Two caveats, or this quietly does not work:

1. **Only into the default branch.** GitHub closes linked issues when the PR merges into
   the repository's *default* branch; a merge into any other base closes nothing.
2. **Stacked PRs need the keyword in the commit message.** For multi-PR work where
   intermediate PRs target the previous branch, a `Closes #N` in the PR *body* never
   fires. Put it in the commit message, which closes the issue when that commit finally
   lands on the default branch.

## Credit guards — set before any Task-tool dispatch

```
CLAUDE_CODE_DISABLE_1M_CONTEXT=1
CLAUDE_CODE_DISABLE_FAST_MODE=1
CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6
```

**Version requirement**: Claude Code ≥ v2.1.172. Check with `claude --version`
before starting; older versions do not support `statusLine.rate_limits`.

---

## Agent definitions

| Agent | File | When used |
|-------|------|-----------|
| Worker | `agents/worker.md` | Spawned via Task tool per claimed task |

---

## Task format

A task is a file — `arsenal/tasks/<id>.md` — with YAML-ish front matter and a body:

````markdown
---
id: t-3f8a91c2
title: "Extract the surface probe into its own script"
priority: 5
deps: [t-aaaa1111, t-bbbb2222]
requires: [surface:cli]
tags: [CLI]
workspace: BACKEND
max-attempts: 3
---

## Acceptance gate
```bash
bash tests/surface_probe_test.sh
```
````

`deps` is the dependency graph, so the graph is versioned with the code and changes
through a pull request like anything else. **Task files are read from the default
branch**, never the session's working branch — that is what makes every agent compute the
same order regardless of what it is working on.

`priority` is a plain integer, larger runs sooner. Only `id` and `title` are required.

**Ids are random** (`t-` plus eight hex characters). They used to be a hash of the title
truncated to four characters, checked for uniqueness against the local file only — so two
agents adding a task with the same title minted the same id. Random ids need no
coordination, which is what lets several agents add tasks at once.

**The gate must be a fenced ` ```bash ` block.** Prose, and inline `single-backtick`
commands, are never executed: a gate that runs nothing passes everything. `query_status.py`
and `task_select.py` both report a task with no block, because an entire gate layer can go
inert without anyone noticing — one consumer audit found 0 of 70 payloads carried one.

### Task lifecycle

```
open ──claim ref created──→ claimed ──PR merged (Closes #N)──→ done
  ↑                            │
  └──── attempt failed ────────┘   (next attempt claims <id>.a2, up to max-attempts)
```

State is **derived, never stored**: `open` is an open issue with no claim, `claimed` is an
open issue carrying `arsenal:claimed` or an assignee, `done` is an issue closed **as
completed**. An issue closed as not-planned leaves dependents blocked on purpose — a stray
close must not release work that was never done. Because state is derived, a stored status
cannot drift from reality, which is the entire class of bug the old queue doctor existed
to detect.

## State directory layout

```
claude-arsenal/        ← upstream. /init owns it and may overwrite it freely
  AGENTS.md            ← this file; imported via @claude-arsenal/AGENTS.md
  agents/worker.md     ← worker subagent definition
  bin/
    github_channel.sh  ← the ONE place that knows how to reach GitHub (gh | rest | none)
    claim_task.sh      ← atomic claim via ref creation
    worktree_probe.sh  ← probes whether git worktrees work here (fan-out safety)
    worker_postcheck.sh ← restores a clean tree after each worker
    rescue_snapshot.sh ← snapshots a dirty tree before any forced restore
    open_task_pr.sh    ← worker-side; branch → commit → push → PR
    gate_run.sh        ← runs the task's fenced gate block
    budget_check.sh    ← quota stop + per-session round cap
    check_update.sh    ← bundle freshness against the upstream tag
    statusline_capture.sh, detect_surface.sh, workspace_list.sh
  scripts/
    task_select.py     ← pure selector: graph + issues → the next task
    query_status.py    ← the board
    handle_sync.py     ← task files with no issue handle yet
    arsenal_config.py  ← reads arsenal/config.toml
    arsenal_migrate.py ← one-time move from the old coordination-branch queue
    gate_evidence.py

arsenal/               ← yours. Scaffolded once, then never written by an upgrade
  config.toml          ← merge-policy, test-discipline, listing budget…
  tasks/<id>.md        ← the tasks; their front matter is the DAG
  specs/ plans/        ← specifications and plans
  project/             ← workspace overview + per-workspace context
  session/
    handover.md        ← live; updated each session
    surface_profile.json, rate_limits.json, budget_iterations.json  ← gitignored
```

The split is the point: upstream owns exactly one directory, so an upgrade can never touch
your tasks, plans, or settings — and the vendored prefix contains only upstream content,
which is what makes it consumable as a subtree.
