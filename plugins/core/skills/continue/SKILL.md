---
name: continue
description: When the user wants to resume work or run the worker loop — picks the next unblocked task, optionally scoped by tag(s) and/or a workspace, or matched by title text. Use /continue [TAG … | WORKSPACE | search-text]. Do NOT use before running init.
user-invocable: true
argument-hint: "[TAG … | WORKSPACE | search-text]"
---

# continue

Resumes session work: reads the task graph from the repository, picks the next unblocked
task, claims it so no other agent can take it, and runs the worker loop. Optionally scoped
by tag(s) and/or a workspace, or matched against a fuzzy task title.

CANARY: continue-loaded-2026-06-13-fb78d23e-b2c3d4e5f6a7b8c9

## When to load

Load this skill when:

- The user types `/continue`, "continue", "resume", "run the workers", or "WORKSPACE: Continue".
- The session needs to pick up where a previous session left off.
- The user provides a workspace name or task search string after the command.

## The loop

**1. Fetch the task issues.** List issues labelled `arsenal:task`, open **and** closed, using whatever GitHub access
this surface offers — the built-in GitHub tools, `gh`, or REST — and save the JSON. Closed ones matter: a closed-as-completed issue is what marks a
dependency satisfied.

Run `github_channel.sh --detect` (in `claude-arsenal/bin/`); it prints `gh`, `rest`, or `none`.

`none` means no scriptable channel exists here; make the call with the built-in GitHub
tools instead. It is not a reason to skip the step — a skipped step here means the session
picks up work another agent is already doing.

**2. Ask for the next task.** One call, one line of output:

Run `task_select.py` (in `claude-arsenal/scripts/`) with the saved issues:

```
task_select.py --tasks-dir arsenal/tasks --issues /tmp/issues.json \
               --capability surface:cli --workspace FRONTEND --tag CLI
```

Ordering is a computation, not a judgement — deps, priority, capabilities and scope are
all applied by the script, so the decision costs one line of context rather than a
protocol re-read each session.

**3. Check nobody else holds it.** Before claiming, read the task's issue and skip it if
it is closed, has an assignee, or carries `arsenal:claimed`. This is not a race — a human
who assigned themselves did so long ago — so a plain check settles it.

**4. Claim it.**

Run `claim_task.sh <task-id>` (in `claude-arsenal/bin/`).

Obey the result verbatim:

- `won <ref>` → the task is claimed. Nobody else can hold it: creating the ref is a
  compare-and-swap that GitHub itself arbitrates.
- `lost` → another agent got there first. Drop it, take the next task. This is normal, not
  an error.
- `manual POST <path> <body>` → no scriptable channel; make that exact call with the
  built-in GitHub tools. **201 means won, 422 means lost.**
- `error:` → misconfiguration. Stop and surface it to the user.

Never work around a `lost` by claiming a different ref or re-running with another attempt
number. The whole point of the ref is that exactly one agent proceeds; routing around it
recreates the double-claims it exists to prevent.

Then mark the issue so a human can see which agent holds it: self-assign, add
`arsenal:claimed`, and comment with the session id from `CLAUDE_CODE_REMOTE_SESSION_ID`
— a `cse_…` value that doubles as a session URL, so the claim is clickable.

**5. Work the task, then open its PR with `Closes #<issue>` in the body.** When it merges,
GitHub closes the issue and the task is done — there is no separate "update the queue"
step for anyone to forget. For a stacked PR whose base is not the default branch, put
`Closes #<issue>` in the **commit message** instead: the PR-body keyword only fires on a
merge into the default branch.

**6. Loop back to step 2.**

## Scoping

```bash
# Bare-word tokens are order-independent and resolved by membership:
#   known workspace -> workspace filter (at most one)
#   known tag       -> tag filter (multiple tags are ANDed)
#   anything else   -> fuzzy title search
/continue CLI FRONTEND   # tag CLI AND workspace FRONTEND
/continue CLI WEB        # tag CLI AND tag WEB
/continue FRONTEND       # workspace only
```

`/continue CLI FRONTEND` and `/continue FRONTEND CLI` resolve to the same scope. A task
qualifies only if it carries **every** requested tag and matches the workspace when one is
given.

## Gotchas

- **`WORKSPACE: Continue`** as natural language (e.g. "FRONTEND: Continue") is equivalent
  to `/continue FRONTEND`.
- **Task files are read from the default branch.** That is what makes every agent compute
  the same graph regardless of the branch it is working on. A task file on an unmerged
  branch is not yet in the queue.
- **A task with no issue handle is invisible.** Run `handle_sync.py` (in `claude-arsenal/scripts/`) to list task files
  that need one, and create them. Missing handles delay work; they never corrupt it.
- **`gate: false` in the selector output means the task has no runnable gate.** A prose-only
  gate executes nothing and therefore passes everything. Fix the task file before working
  it, rather than completing something that nothing checked.
- **Blocked workspace**: if a scoped selection is empty but the global queue has tasks,
  report what is blocking and offer to fall back to the global queue.
- **Retries claim a new ref.** A crashed session blocks nothing: attempt 2 claims
  `<id>.a2`. Past `max-attempts` the task stops being offered and needs a human — read the
  `## Failure notes` in the task file before re-dispatching.
