# Pre-PR adversarial review

Load this when a change is finished and a PR is about to be opened — from
`execution` before its Create-PR step, from `github` before `gh pr create`, from
`ship` at its adversarial gate, or from a worker before `open_task_pr.sh`.

## What this is for

Every other check before a PR is run by the session that wrote the code. Lint
and tests catch what is broken; the self-review checklist catches what the
author already knows to look for. Neither can catch the change that works
perfectly and is not what was asked for, because the only reader so far shares
the assumption that produced it.

So the gate is one reviewer that has **never seen this work**, given the diff and
the stated intent and nothing else. Not a second opinion from the same session
under a different heading — a genuinely cold read.

## The protocol

### 1. Emit the case file

```bash
bash claude-arsenal/bin/adversarial_review.sh emit [--task <id>] [--intent <file>] [--base <ref>]
```

It resolves the base, captures the diff — committed work, uncommitted edits and
untracked files together — finds the intent (`--intent`, else the task payload,
else `status/specification.md`), embeds the rubric from
`claude-arsenal/agents/reviewer.md`, and writes `tmp/arsenal-review/packet.md`,
printing that path. Exit 3 means there is nothing to review.

The directory ignores itself, so nothing the review produces lands in the PR.

**On a stacked branch, pass `--base`.** The base is otherwise
`merge-base(default branch, HEAD)`, so a branch stacked on another PR presents
the whole stack as the change and the reviewer re-reads already-reviewed
commits as new. Pass the parent branch instead: `--base fix/iss-A`.

**If the intent is auto-discovered, check it.** With no `--intent` and no
`--task` the packet falls back to `status/specification.md`, then
`status/plan.md` — and `emit` says on stderr which file it picked. A repo that
keeps an archived spec around will hand the reviewer something that describes a
design nobody is implementing, and the findings that come back will be confident
and irrelevant. Naming the intent explicitly is the reliable path.

### 2. Spawn a reviewer that knows nothing else

Spawn a **subagent** whose entire prompt is:

> Read `tmp/arsenal-review/packet.md` and follow it. Write your full reply to
> `tmp/arsenal-review/verdict.md`.

That is the whole prompt. Do not summarize the change for it, do not tell it
what you were trying to do, do not mention which parts you are confident about,
and do not pass any conversation history. Every one of those transplants the
blind spot you are trying to escape — a reviewer told "this refactor is
behaviour-preserving" checks a different question than one that had to work it
out. The packet is complete on purpose; anything you add to it subtracts.

The reviewer may read the repository freely. What it must not have is your
account of the change.

### 3. Record the verdict

```bash
bash claude-arsenal/bin/adversarial_review.sh verdict
```

It reads `tmp/arsenal-review/verdict.md`, takes the last `VERDICT:` line, and
writes a receipt bound to the digest of the reviewed diff.

| Exit | Meaning | Do |
|---|---|---|
| 0 | CLEAR | Open the PR. |
| 1 | BLOCK | Show the findings **verbatim**, fix them, then start again at step 1. |
| 2 | No verdict line | Not a pass. Ask the reviewer again. |
| 3 | Stale — the tree moved during the review | Re-emit and review the tree you actually have. |

A second round starts from step 1, not step 2: `emit` retires the previous
receipt, because a CLEAR for the tree before the fix says nothing about the tree
after it.

## Handling BLOCK

Show the reviewer's findings as written. Do not paraphrase them into something
easier to dismiss, and do not fix them silently — the findings are the record of
what a cold reader saw.

A finding can be wrong. The reviewer is working without your context, which is
what makes it useful and also what makes it occasionally mistaken about
something the repository settles elsewhere. When you are confident it is a false
positive, say which finding, why the repository already answers it, and
what you checked — then proceed. Record that override where the PR's reader will
see it. What is not allowed is quietly re-running the review until it clears:
that is not a second opinion, it is shopping for one.

## Where it binds

`open_task_pr.sh` runs `adversarial_review.sh check` before it opens any task
PR — ahead of the host gate and the task's acceptance gate, because both of
those run arbitrary commands and any untracked artifact they leave would move
the tree out from under the receipt — and writes the outcome (CLEAR, BLOCK,
stale, or never run) into the PR body. The body states what the receipt proves:
that a verdict was recorded for this tree. Nothing can tell a subagent's verdict
from one a session wrote for itself, which is why the worker protocol says to
skip the step rather than stand in for the reviewer.

`arsenal/config.toml` sets how hard it binds **on that path only** — the
`execution`, `github` and `ship` skills run the gate as a step of their own
workflow and do not read this key:

| `pre-pr-review` | Effect |
|---|---|
| `warn` (default) | The task PR opens either way; the outcome is stated in its body. |
| `required` | No clearing verdict for this tree, no task PR. |
| `off` | Not checked, no line written in the body. |

`warn` is the default because a gate that breaks every worker loop on upgrade
gets switched off, and one that says nothing gets forgotten. Repos that want the
hard version set `required`.

## In a repo without the bundle

The core skills run in repos that never ran `/init`, where
`claude-arsenal/bin/` does not exist. The mechanism there is the same and only
the plumbing is manual: gather the diff (`git diff <base>` plus untracked files)
and the stated intent into one file yourself, spawn the subagent on that file
with the rubric from this bundle's `agents/reviewer.md` — the short form being
*find every reason this should not merge; anchor each finding to `path:line`
with the concrete trigger; report no style; end with `VERDICT: BLOCK — reason`
or `VERDICT: CLEAR — reason`* — and apply the same decision table above. The
digest-freshness guarantee is what you lose, so re-run the review after any
further edit.
