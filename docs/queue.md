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

**The gate must be a fenced ` ```bash ` block.** Prose is not executable, and a
gate that runs nothing passes everything. `task_select.py` reports `gate: false`
for a task that has no block, so a queue full of unenforced gates is visible
rather than quietly inert.

---

## The loop

Reading the queue is one command. The session fetches its `arsenal:task` issues
with whatever GitHub access it has, saves them, and asks for the next task:

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

Work the task, and open the pull request with **`Closes #42`** in the body. When
it merges, GitHub closes the issue, and the task is done. There is no separate
"update the queue" step to forget — which is the failure the old design could
not fix, because the script that reconciled merged PRs was gated on `gh` and
therefore never ran on the web at all.

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
retry claims `…​.a2` instead. A crashed session therefore blocks nothing.

---

## Configuration

`arsenal/config.toml` is yours, and upstream never rewrites it. That is what
makes it the right place for preferences: a setting stored in a vendored skill
disappears the next time that skill is refreshed.

```toml
merge-policy    = "after-ci"   # always | after-ci | after-ci-and-review | never
test-discipline = "test-first" # or test-after
session-end     = "handoff"    # handoff | ticket | none
listing-budget  = 8000         # the skills-listing budget the auditor enforces
```

`merge-policy` answers "what do you need before a task PR may merge?" — asked
once at `/init`, then never again.

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
