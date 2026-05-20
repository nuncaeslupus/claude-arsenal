# PR review loop — bot state machine + handling rubric

The agile review loop, triggered after `gh pr create`, runs `query_pr_state.py` on a 90-second cadence (via `/loop`). The script emits a JSON snapshot of the PR's review state and exits with a code that drives the next step.

## State machine

| Snapshot state | Trigger conditions (any of) | Exit | Next action |
|---|---|---|---|
| `waiting` | No watched-bot signal yet, OR bot opened `CHANGES_REQUESTED` and Claude has not pushed since | 1 | Loop continues. |
| `bot_eyeing` | A watched bot reacted `:eyes:` on the PR header; no review submitted yet | 1 | Loop continues. The bot is preparing a comment. |
| `ci_running` | At least one CI check is `in_progress` / `queued` | 1 | Loop continues. |
| `ci_failed` | At least one CI check is `failure` | 2 | Fetch `gh run view --log-failed <run-id>`, fix, commit, push. Loop resumes on next tick. |
| `bot_commented` | At least one watched-bot line-level comment is newer than the most recent commit | 0 | Address each unaddressed comment (rubric below). |
| `bot_approved` | CI green + at least one watched-bot event (review, reaction, or comment) + quiet anchor not yet elapsed | 1 | Loop continues. Quiet anchor = later of (last bot event, head commit). |
| `ready_to_merge` | Same as `bot_approved` + quiet window of `--min-quiet-seconds` (default 60) has elapsed past the quiet anchor | 0 | Exit loop. Tell the user `PR #N ready to merge`. |

**CI-only mode**: when invoked with `--watch-bots ""` (no bots configured), the script skips bot tracking. Green CI alone is enough to reach `ready_to_merge` once the quiet window past the head commit has elapsed.

**Silent approval**: a bot may post a `COMMENTED` review then go silent after Claude pushes a fix. The script treats silence past the quiet anchor as approval — provided no new comments arrived and CI is green. The bot doesn't need to leave an explicit `:+1:` or `APPROVED` for `ready_to_merge`.

## Default watched bots

```
gemini-code-assist[bot]
coderabbitai[bot]
claude[bot]
```

Override with `--watch-bots gemini-code-assist[bot],custom-bot[bot]`. Empty list → no bots watched (CI-only mode).

## Comment-handling rubric

When `query_pr_state.py` returns `bot_commented`, its JSON payload includes an `unaddressed_comments` array. Each entry carries `id`, `user`, `path`, `line`, `body`, `created_at` — one entry per watched-bot line-level comment newer than the head commit.

For each comment, Claude picks one of three actions:

| Claude's stance | Action |
|---|---|
| **Agrees** | Edit the file, stage, commit (`fix(<scope>): address review on <path>:<line>`), push. One commit per logical fix; bundling acceptable when ≥2 comments hit the same diff. |
| **Disagrees** | Reply to the line-level comment with a one-paragraph rationale. Use `gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment-id>/replies -f body=@/tmp/reply.md`. Cite the line in the reply if helpful. |
| **Ambiguous** (need user input) | Pause the loop, surface the comment to the user with the proposed fix or push-back, wait for direction. Resume the loop after. |

Never silently skip a comment. If a comment cannot be addressed (e.g. the file no longer exists), reply explaining that.

## "Addressed" detection

The script's heuristic for "unaddressed":

- A bot line-comment is **unaddressed** if its `created_at` is newer than the latest commit's `committer.date` on the PR head ref.
- Once a fix is pushed, the next loop tick filters out comments older than the new head commit — so they no longer appear in `unaddressed_comments`.
- A bot may re-raise the same issue on the new diff; the new comment will appear as unaddressed on the next tick.

This is intentionally simple: the script tracks ordering, not semantic resolution. False positives (bot comments that need no action, e.g. praise) are filtered by Claude during the "agrees / disagrees / ambiguous" classification — reply once with "noted, no change" and the next push moves the comment behind the head ref.

## Loop control

- Cadence: `/loop 90s …`. Lower than 60s risks hitting `gh` rate limits on long-running PRs; higher than 120s slows the user.
- Termination: the loop exits as soon as `query_pr_state.py` returns `ready_to_merge` (exit 0 with `state: "ready_to_merge"`).
- Abort: Claude stops the loop if `query_pr_state.py` returns exit 2 with a state other than `ci_failed` (e.g. authentication error, repo not found). Surface the error to the user.

## Caveats

- Reactions vs reviews are tracked separately. A bot that *only* reacts `:+1:` (no formal `APPROVED` review) is treated as approval if its most recent review is `COMMENTED` with no unaddressed comments newer than the latest push.
- Some bots use the priority-badge image pattern (`![medium](...)`, `![high](...)`) at the start of each comment body. The script preserves the body verbatim; Claude reads the badge to triage priority.
- For repos with no review bots, `--watch-bots ""` skips bot tracking and waits only on CI. Useful for solo branches.
