# The task queue

> **Status:** live as of v0.25.0. The session protocol, the `/queue-*` skills and
> the worker all run on the model described here; the coordination branch and its
> machinery are gone. Existing repos migrate with `arsenal_migrate.py` (below).
> It replaces `docs/orchestrator-guide.md`, which described the old design
> and has been removed.

Two ideas, and everything else follows from them.

**The repository defines the work.** Tasks are files. They are versioned,
reviewed in the pull request that adds them, readable with no network, and
identical for every agent.

**GitHub coordinates who is doing it.** An issue is a *handle* for a task —
not a copy of it — and a claim is an atomic ref creation that GitHub itself
arbitrates.

The handle names its task with a visible line in the issue body:

```
`arsenal-task: t-3f8a91c2`
Task defined in `arsenal/tasks/t-3f8a91c2.md`
```

**Visible, not an HTML comment.** The id used to live in `<!-- … -->`, and the
GitHub tools a cloud session uses strip angle-bracketed content out of issue
bodies — so on that surface every issue was anonymous, the state map came back
empty, and an empty map looks exactly like a healthy new board right up until
the first finished task is handed out a second time. The task-file path is read
as a fallback, which rescues issues opened before the visible token existed, and
a legacy comment still works wherever it survives. If issues are fetched and
none yields a task id, that is reported as the parse failure it is.

There is no coordination branch, no side worktree, and no ledger file that two
sessions have to keep in step.

---

## Layout

```
arsenal/                  # yours. Upstream scaffolds it once, then never writes here
  config.toml             # your configuration; survives every bundle upgrade
  tasks/t-3f8a91c2.md     # one file per task: deps, priority, acceptance gate
  specs/  plans/          # specifications and plans
  session/handover.md     # session state
.claude/skills/           # vendored upstream. Regenerated wholesale; never hand-edit
```

The split is the point. Upstream owns exactly one directory and may overwrite it
freely, so an upgrade can never touch your queue, your plans, or your settings.

---

## A task file

````markdown
---
id: t-3f8a91c2
title: "Extract the surface probe into its own script"
priority: 5
deps: [t-aaaa1111, t-bbbb2222]
requires: [surface:cli]
tags: [CLI]
---

## Acceptance gate
```bash
bash tests/surface_probe_test.sh
```
````

`deps` is the dependency graph. Because it lives in the file, the graph is part
of the project: it changes through a pull request like anything else, and every
agent computes the same order from it.

**Ids are random** (`t-` plus eight hex characters). They used to be derived
from the title, which meant two agents adding a task with the same title minted
the same id. Random ids need no coordination, so several agents can create tasks
at once.

**A numeric gate may declare itself unmeasurable.** An evidence gate can carry
`status-key:`, pointing at a field that reads `unmeasured`; the gate then exits
3 — "the check ran, and what it found is that this cannot be scored yet" — which
is neither a pass nor a fail. It has to be asserted positively in the evidence
file: inferring it from a missing or null value would let a gate stop checking
by omission, which is the hole evidence gates exist to close.

**The gate must be a fenced ` ```bash ` block.** Prose is not executable, and a
gate that runs nothing passes everything. `task_select.py` reports `gate: false`
for a task that has no block, so a queue full of unenforced gates is visible
rather than quietly inert.

---

## The loop

Reading the queue is one command. The session fetches its `arsenal:task` issues
with whatever GitHub access it has — asking for `number`, `title`, `state`,
`labels`, `assignees` and not `body`, since a task id resolves from the title
when no body is present and the bodies are the bulk of the fetch — saves them,
and asks for the next task:

```bash
python3 claude-arsenal/scripts/task_select.py \
    --tasks-dir arsenal/tasks --issues /tmp/issues.json --capability surface:cli
```

```json
{"id":"t-3f8a91c2","title":"Extract the surface probe…","path":"arsenal/tasks/t-3f8a91c2.md","priority":5,"gate":true}
```

One line in, one line out. Choosing a task is a computation, not a judgement,
so it belongs in a script rather than in a protocol the model re-reads every
session — that is where most of the old queue's token cost went.

Then claim it:

```bash
bash claude-arsenal/bin/claim_task.sh t-3f8a91c2
# won refs/heads/arsenal/claims/t-3f8a91c2
```

Work the task, then open the pull request with `open_task_pr.sh`. It resolves the
task's issue number, writes **`Closes #42`** into the PR body *and* the commit
message, and moves `arsenal/tasks/t-3f8a91c2.md` into `arsenal/tasks/_history/`
with `status: merged` — all inside the PR's own diff.

So one merge closes the issue, archives the task, and unblocks its dependents.
There is no separate "update the queue" step to forget, and none to remember at
the end of a session either.

> For a long time the keyword was only ever *documented*: the protocol told the
> agent to make sure the body carried it, `open_task_pr.sh` wrote a body without
> it, and nothing anywhere computed which issue a task belonged to. Every task PR
> merged closing nothing, and each new session opened by reconciling a board that
> claimed work already done. An instruction with no data path behind it is not a
> weak guarantee — it is no guarantee.

### What GitHub keeps current

Merging covers a task that finished. `/init` installs
`.github/workflows/arsenal-queue.yml` for everything that happens when no
session is running:

| Event | What happens |
|---|---|
| Task PR merged, keyword never fired | The issue closes as completed; the task file is archived |
| Task PR closed **without** merging | `arsenal:claimed` and the assignee are removed — the task is back on the board |
| A task file lands on the default branch | Its issue handle is opened immediately |
| A claim held >24h with no open PR | Released; that session is not coming back |
| A task PR carries no closing keyword | Its check fails **before** the merge |

Each of those was previously a line in a protocol asking an agent to tidy up
before ending a session, which is the worst possible place for it: the sessions
that most need the cleanup are the ones that ended badly. The workflow needs
`issues: write` and `contents: write`, and never runs code from a pull request.
Deleting the file opts out: `/init` records `queue-automation = false` in
`arsenal/config.toml` and stops reinstalling it. The merge path is unchanged
without the workflow.

---

## How claiming can't go wrong

Two different problems, deliberately solved by two different mechanisms.

**Someone else already holds it.** A human assigned themselves the issue, or a
worker is on it. This is not a race — it happened long before — so it is a
precondition check: skip any task whose issue is closed, assigned, or carries
`arsenal:claimed`.

**Two agents want the same free task.** This *is* a race, and an assignee cannot
settle it, because every session authenticates as the same GitHub identity. The
claim ref settles it:

```
POST /repos/{owner}/{repo}/git/refs   →  201 for one caller
                                      →  422 "Reference already exists" for all others
```

Creating a ref is a compare-and-swap decided by GitHub. There is no settle
interval, no tie-break, and no window in which two agents both believe they won.
`claim_task.sh` prints `won` or `lost` accordingly.

Claim refs are never deleted — a sandboxed session cannot delete a ref — so a
crashed claim needs an escape hatch: `claim_task.sh <id> 2` takes `….a2`. That
suffix is a different ref, which nobody else is contending for, so the collision
cannot arbitrate it — it steps *past* the lock rather than competing for it.
Stepping past a claim therefore has to be deliberate: the retry is refused
unless `ARSENAL_CLAIM_STALE_OK=1` says the base claim has been established as
stale. A crashed session still blocks nothing; a live one is no longer
overrun by a second argument.

---

## Configuration

`arsenal/config.toml` is yours, and upstream never rewrites it. That is what
makes it the right place for preferences: a setting stored in a vendored skill
disappears the next time that skill is refreshed.

```toml
merge-policy    = "after-ci"   # always | after-review | after-ci | after-ci-and-review | never
host-gate       = ""           # shell command; non-zero means no task PR is opened
test-discipline = "test-first" # or test-after
session-end     = "handoff"    # handoff | ticket | none
listing-budget  = 8000         # the skills-listing budget the auditor enforces
```

`merge-policy` answers "what do you need before a task PR may merge?" You are
prompted for it once, at `/init`, and never asked again — but the value is read
**on every merge** (`AGENTS.md` § Completion), and
`references/github-automation.md` maps each value to a check, including what
counts as a review and what to do when CI cannot report at all. Set once, read
every time; it shipped for six versions with only the first half of that.

The two middle values are different axes, not degrees: `after-ci` is "the
machines agree", `after-review` is "a reader agrees". A repo can require either,
both, or neither.

`after-review` exists because "CI is unavailable" is a different state from "CI
is red" — a repo out of runner minutes, or with no CI at all, has no run to wait
for. Under `after-ci` that leaves two readings, both bad: nothing merges for as
long as the outage lasts, or everyone learns to wave the gate through, which is
the habit they keep on the day it starts meaning something again.

### The host gate

`open_task_pr.sh` runs `host-gate` before it touches git, and refuses to open the
PR if it exits non-zero — the same refusal a failing payload gate gets. Empty by
default, so a repo without one is unaffected.

Point it at everything the repo actually checks. The instruction it replaces
named `make lint` as its example, so a repo whose real gate was five commands
had four of them enforced by nobody — and the four it skipped were the ones that
catch board drift, evidence drift and a stale bundle, which are exactly the
failures invisible in a diff.

There is no way to skip it. An escape hatch would be reached for precisely the
situation the refusal exists for — a red repo with a PR to open.

### Saying "closed, but not done"

A closed issue reads as `done`. To close one *without* releasing the work that
depends on it, add the **`arsenal:cancelled`** label.

GitHub's own `state_reason` says the same thing and is honoured when present,
but it cannot be the mechanism: the GitHub tools a cloud session uses do not
return that field at all, so on that surface every closed issue would look
identical. A label is the one signal every surface can read.

### Finished tasks

`arsenal/tasks/_history/<id>.md` holds tasks that are already done — same front
matter plus `status:` and `pr:`. They are never selected as work. They exist so
a dep pointing at completed work resolves instead of reading as unknown (an
unknown dep blocks by design), and so a finished task's acceptance gate stays on
disk for any check that re-asserts it.

Inspect the effective values and where each came from:

```bash
python3 claude-arsenal/scripts/arsenal_config.py --explain
```

A threshold whose value is invisible is one nobody can tell has been quietly
raised, so the source is always printed. An invalid value fails loudly rather
than defaulting past a typo.

---

## Reaching GitHub

Surfaces differ, and the old code assumed `gh`:

| | CC CLI | Cloud sessions (web, desktop and mobile apps, Claude Tag, routines) |
|---|---|---|
| `gh` CLI | if installed | **absent** |
| REST via `$GITHUB_TOKEN` | yes | **403** — credentials live outside the sandbox |
| Built-in GitHub tools | if configured | **always**, even at network access level `None` |
| `git push` to another branch | yes | **documented as blocked** |

`github_channel.sh --detect` prints `gh`, `rest`, or `none`. **`none` is not a
failure** — it means no scriptable channel exists here, so the caller prints the
exact API call for the model to make with its built-in tools. That matters
because the old pattern, `command -v gh || skip`, turned required steps into
silent no-ops: the queue looked healthy while nothing happened.

---

## Migrating an existing repo

```bash
python3 claude-arsenal/scripts/arsenal_migrate.py            # dry run
python3 claude-arsenal/scripts/arsenal_migrate.py --apply
```

It converts task rows into task files (ids preserved, so `deps` keep resolving),
moves `session/` and `project/` out of the vendored prefix, and seeds
`config.toml`. Finished tasks are recorded in `tasks/_migrated-history.md`
rather than resurrected as work.

Nothing is deleted, and re-running is safe — an existing task file is left
alone, so an interrupted migration can simply be run again. Afterwards, by hand:

```bash
git push origin --delete arsenal-queue
git worktree remove ../<repo>-arsenal-queue-wt    # if one exists
rm -rf claude-arsenal/queue
```

Those are yours to run because a sandboxed session cannot delete refs, and a
half-finished automatic cleanup is worse than an explicit instruction.

---

## One thing to check in your own repo

Creating a claim ref fires GitHub's `push` and `create` events. If any workflow
triggers on an unfiltered `on: push`, it will run on every claim. Scope it:

```yaml
on:
  push:
    branches-ignore: ['arsenal/**']
```
