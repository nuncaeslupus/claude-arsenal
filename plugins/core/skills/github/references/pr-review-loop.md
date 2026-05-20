# PR review loop — bot state machine + handling rubric

The agile review loop, triggered after `gh pr create`, runs `query_pr_state.py` on a 90-second cadence (via `/loop`). The script emits a JSON snapshot of the PR's review state and exits with a code that drives the next step.

## State machine

| Snapshot state | Trigger conditions | Exit | Next action |
|---|---|---|---|
| `waiting` | No watched-bot positive signal yet, OR bot opened `CHANGES_REQUESTED` with no line-comments | 1 | Loop continues. |
| `bot_eyeing` | A watched bot has reacted `:eyes:` on the PR header AND has not since thumbed/approved | 1 | Loop continues. The bot owns clearing the eyes — never assume the eyes are stale on Claude's behalf. |
| `ci_running` | At least one CI check is `in_progress` / `queued` | 1 | Loop continues. |
| `ci_failed` | At least one CI check is `failure` | 2 | Fetch `gh run view --log-failed <run-id>`, fix, commit, push. Loop resumes on next tick. |
| `bot_commented` | At least one watched-bot line-level comment exists on the PR (regardless of when) | 0 | Address each comment per the rubric below. Claude judges per-comment whether it was already addressed; the script does not pre-filter. |
| `bot_approved` | CI green + explicit positive signal (thumb / APPROVED review) + quiet anchor not yet elapsed | 1 | Loop continues. Quiet anchor = later of (last bot event, head commit). |
| `ready_to_merge` | Same as `bot_approved` + quiet window of `--min-quiet-seconds` (default 60) has elapsed | 0 | Exit loop. Tell the user `PR #N ready to merge`. |

**Eyes is a hard block.** If a watched bot has reacted `:eyes:` and not since thumbed or approved, the loop will NEVER declare `ready_to_merge` — regardless of timestamps. Bots set `:eyes:` to mark "I will get back to this" and own clearing it by acting again (thumb, approval, or a follow-up review). Letting Claude assume a stale eyes is safely ignorable is how PRs get merged with unread feedback.

**No timestamp filter on comments.** The script returns ALL bot line-level comments and leaves the judgment of "addressed vs not" to Claude per-comment. The previous heuristic ("addressed if older than head commit") was wrong — a later commit may fix something unrelated, leaving the original comment still outstanding.

**CI-only mode**: when invoked with `--watch-bots ""` (no bots configured), the script skips bot tracking. Green CI plus the quiet window past the head commit is enough to reach `ready_to_merge`.

**Silent approval requires a positive signal.** A bot that commented and then went silent is NOT silent approval — silent approval requires the bot to have left a `:+1:` / `:rocket:` reaction or an `APPROVED` review. If the bot only ever commented (no positive signal), the state stays `waiting` indefinitely, awaiting the bot's resolution OR Claude pushing back. This is intentional: ambiguous silence should not auto-merge.

## Default watched bots

```
gemini-code-assist[bot]
coderabbitai[bot]
claude[bot]
```

Override with `--watch-bots gemini-code-assist[bot],custom-bot[bot]`. Empty list → no bots watched (CI-only mode).

## Comment-handling rubric

When `query_pr_state.py` returns `bot_commented`, its JSON payload includes a `bot_line_comments` array — ALL watched-bot line-level comments on the PR, with no timestamp filter. Each entry carries `id`, `user`, `path`, `line`, `body`, `created_at`.

Claude's job is to judge, for each comment, one of four outcomes:

| Claude's stance | Action |
|---|---|
| **Already addressed** | The current code already does what the comment asks (or the comment refers to a deleted file/line). Reply once via `gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment-id>/replies -f body="addressed in <commit-sha>"`. This is the move that "clears" the comment from future loop ticks once GitHub marks the thread resolved (or via your own reply heuristic). |
| **Agrees, not yet addressed** | Edit the file, stage, commit (`fix(<scope>): address review on <path>:<line>`), push. One commit per logical fix; bundling acceptable when ≥2 comments hit the same diff. |
| **Disagrees** | Reply to the line-level comment with a one-paragraph rationale via `gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment-id>/replies`. Cite the specific line in the reply. |
| **Ambiguous** (need user input) | Pause the loop, surface the comment to the user with the proposed fix or push-back, wait for direction. Resume after. |

Never silently skip a comment. Every comment gets *some* response — code change, reply, or escalation to user.

## How the script tracks "addressed"

It doesn't. Deliberately.

The previous heuristic ("addressed if older than the head commit") was wrong: a later commit may fix something unrelated, leaving the original comment still outstanding. False `ready_to_merge` readings on PRs with un-addressed feedback were the result.

The current design returns ALL bot line-comments and pushes the judgment of "is this addressed?" to Claude per-comment. GitHub exposes a `resolved` flag on review threads via GraphQL — a future iteration may consume it to filter out resolved threads automatically, but until then Claude reads each comment and decides.

## Loop control

- Cadence: `/loop 90s …`. Lower than 60s risks hitting `gh` rate limits on long-running PRs; higher than 120s slows the user.
- **Cron's floor is 1 minute.** `/loop` converts `Ns` to `ceil(N/60)m`, so `90s` schedules as `*/2 * * * *` (every 2 min) — it does NOT poll sub-minute. Treat the `90s` figure as user-facing intent; the underlying cron cadence is 2 min. If you genuinely need every-minute polling, write `/loop 1m …` and accept the higher API load.
- **Always include the agree/disagree/ambiguous rubric inline in the `/loop` prompt.** A bare `/loop 90s python3 .../query_pr_state.py --pr <N>` produces a JSON snapshot each tick and forces the LLM to re-derive what to do from the skill body every time. The rubric-inlined form keeps each tick self-contained:

  ```
  /loop 90s python3 "${CLAUDE_SKILL_DIR}/scripts/query_pr_state.py" --pr <N> — if state is bot_commented, address per the rubric (agree → fix; disagree → reply via gh api repos/<owner>/<repo>/pulls/<N>/comments/<id>/replies; ambiguous → ask user). If ci_failed, fetch the failing job log and fix. Only stop the loop on ready_to_merge — bot_approved still waits for the quiet window. When stopping, CronDelete <job-id> and hand back to user to merge.
  ```

- Termination: the loop exits as soon as `query_pr_state.py` returns `ready_to_merge` (exit 0 with `state: "ready_to_merge"`). Call `CronDelete <job-id>` to stop early — the `/loop` skill prints the job ID at scheduling time, and `CronList` recovers it later.
- Abort: Claude stops the loop if `query_pr_state.py` returns exit 2 with a state other than `ci_failed` (e.g. authentication error, repo not found). Surface the error to the user.

## Caveats

- **`:eyes:` reactions are sticky.** GitHub does not remove a bot's `:eyes:` automatically when the bot finishes its review; the bot owns the lifecycle. The script treats any present `:eyes:` from a watched bot as `bot_eyeing` (a hard block on `ready_to_merge`) unless the bot has also thumbed or approved.
- **Silent approval requires a positive signal.** A bot that posted a COMMENTED review and then went silent is NOT silent approval. Approval requires `:+1:` / `:rocket:` reaction or `APPROVED` review submission.
- **Priority-badge convention.** Some bots prefix comments with `![critical](...)`, `![high](...)`, `![medium](...)`, `![low](...)`. The script preserves the body verbatim; Claude reads the badge to triage which comment to address first.
- **CI-only mode.** `--watch-bots ""` skips bot tracking; only CI status drives the state machine. Useful for solo branches where no bots are configured.
