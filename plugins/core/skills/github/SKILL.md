---
name: github
description: Use whenever the user is creating commits, opening pull requests, or waiting on PR review/CI feedback — applies Conventional Commits + branch naming, then auto-polls the open PR for review-bot reactions (`:eyes:` watching → comments → `:+1:`/`:rocket:` approval) and CI status, addresses each unaddressed comment inline or pushes back with a reply, and tells the user when the PR is ready to merge. Triggers — "open a PR", "address review comments", "wait for Gemini / CodeRabbit", "/loop check pr state", "is CI done?". Owns scripts — query_pr_state.py, query_project_type.py. Do NOT use for engineering review semantics on a diff (see review), for generic git mechanics like branching or worktrees (see execution), or for stamping a hardcoded Co-Authored-By model name (this skill explicitly refuses hardcoded model strings — the active model identity is supplied by the harness).
metadata:
  type: workflow
---

# github

Apply Conventional Commits + PR conventions, then run a tight, automated review loop instead of asking the user to relay bot comments by hand. After a PR is opened, this skill polls for review-bot reactions, CI status, and review comments; it addresses or pushes back on each comment, then tells the user when the PR is ready to merge.

CANARY: github-loaded-2026-05-20-d436255c-54a7f770e04e4983

## When to load

After activation, confirm the task fits:

- The user asks to make a commit, open a PR, or amend a PR body.
- The user asks "is CI done?", "what did Gemini say?", or "address the review".
- A `/loop` cycle is checking PR state — see [pr-review-loop](references/pr-review-loop.md).

If the task is the *substance* of the review (judging whether a diff is correct, designing the fix), defer to the review or execution skill — this skill owns the *mechanics* of the review-bot dance, not the semantics of the change.

## Commit conventions

Conventional Commits: `<type>(scope): description`. Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`. Scope is the module or domain. Imperative voice, no trailing period, first line ≤72 chars. Body separated by a blank line; explain *why*, not *what*.

Always end the commit with `Co-Authored-By: <ACTIVE-MODEL-NAME> <noreply@anthropic.com>`. **Never hardcode a model name** in skill prose, scripts, templates, or examples. The active model identity is supplied by the harness's git commit instructions — use that value verbatim. If a port from an older skill shows `Claude Opus 4.5` / `4.6` etc., strip the literal and replace with the live identity at commit time.

## PR conventions

Body template:

```
## Summary
<1-3 bullets>

## Test plan
- [ ] <verifiable check>
```

Branches: `feat/<short-description>`, `fix/<short-description>`. Main branch is `main`. The same dynamic Co-Authored-By rule applies inside the PR body (do not hardcode a model name there either).

## Pre-PR gate — always run host lint before `gh pr create`

Before any `gh pr create` invocation, run the host repo's full lint/format/test gate (whatever the project's Makefile / package.json exposes — e.g. `make lint`, `make smoke`, `npm run lint`). Pre-commit hooks do not always cover the same checks CI runs; relying on them alone is how PRs land red. Treat a clean local lint as a non-negotiable precondition for opening the PR — the agile review loop assumes CI was green at push time.

If the host project has no lint target, document that gap (propose a Makefile addition to the user) and proceed; but the omission is the proposal, not a license to skip.

## The agile review loop

After `gh pr create` returns the PR number, immediately enter the polling loop:

```bash
/loop 90s python3 "${CLAUDE_SKILL_DIR}/scripts/query_pr_state.py" --pr <PR_NUMBER>
```

The script returns JSON to stdout and exits with:

| Exit | State |
|---|---|
| 0 | `bot_commented` (any bot line-comments — Claude judges per-comment) OR `ready_to_merge` |
| 1 | `waiting` / `bot_eyeing` / `ci_running` / `bot_approved` (loop continues) |
| 2 | `ci_failed` (Claude must act) |

Handle each state per the rubric in [pr-review-loop](references/pr-review-loop.md):

- `bot_eyeing` → loop continues. **Never** treat `:eyes:` as cleared on Claude's behalf — the bot owns clearing it.
- `bot_commented` → for each comment in `bot_line_comments`, judge: **already addressed** (reply "addressed in <sha>"), **agree** (fix + push), **disagree** (reply with rationale via `gh api .../pulls/<N>/comments/<id>/replies`), or **ambiguous** (ask user). Loop continues after action.
- `ci_failed` → fetch the failed log via `gh run view --log-failed <run-id>`, fix, push. Loop continues.
- `ready_to_merge` → exit the loop, tell the user "PR #N ready to merge".

## Project type — Classic vs v2

GitHub's Projects Classic silently breaks a few `gh` paths (notably `gh pr view --comments` and `gh pr edit --body`). On first use in a repo, run the detector:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/query_project_type.py" --write-claude-md
```

Output: `classic` / `v2` / `none`. With `--write-claude-md`, the detector appends `<!-- github-skill: projects=v2 -->` (or `classic`) to the repo's `CLAUDE.md` if no such marker exists. Future sessions read the marker and skip re-detection. When the marker says `classic`, follow the workarounds in [projects-detection](references/projects-detection.md).

## References

- [projects-detection](references/projects-detection.md) — Projects Classic detection signal + Classic-only `gh` gotchas (load when the detector returns `classic`).
- [pr-review-loop](references/pr-review-loop.md) — bot state-machine table, default watched-bot list, comment-handling rubric (load when entering the loop).
