#!/usr/bin/env python3
"""Snapshot the review state of a GitHub PR.

Returns one of:
  - waiting       — no review-bot signal, CI not green yet
  - bot_eyeing    — watched bot reacted :eyes:, no review submitted
  - bot_commented — watched bot left unaddressed line-level comments
  - ci_running    — at least one CI check is in progress / queued
  - ci_failed     — at least one CI check failed
  - bot_approved  — watched bot approved, quiet window not elapsed yet
  - ready_to_merge — bot approved + CI green + quiet window elapsed

Exit codes:
  0 — bot_commented (unaddressed) OR ready_to_merge (actionable)
  1 — waiting / bot_eyeing / ci_running / bot_approved (loop continues)
  2 — ci_failed (Claude action) or error (surface to user)
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from typing import Any

DEFAULT_BOTS = ["gemini-code-assist[bot]", "coderabbitai[bot]", "claude[bot]"]


def _norm_user(name: str | None) -> str:
    """`gh pr view --json reviews` strips the `[bot]` suffix; REST keeps it.
    Normalize both sides to the bare login for comparison."""
    if not name:
        return ""
    return name[:-5] if name.endswith("[bot]") else name


def _gh(*args: str) -> Any:
    """Run a gh subcommand and parse JSON output. Exits 2 on failure."""
    if shutil.which("gh") is None:
        sys.stderr.write("gh CLI not found in PATH\n")
        sys.exit(2)
    try:
        out = subprocess.check_output(["gh", *args], text=True)
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(f"gh failed: gh {' '.join(args)}\nstderr: {exc.stderr or ''}\n")
        sys.exit(2)
    out = out.strip()
    return json.loads(out) if out else None


def _default_repo() -> str:
    data = _gh("repo", "view", "--json", "nameWithOwner")
    return str(data["nameWithOwner"])


def _parse_ts(s: str | None) -> datetime | None:
    if not s:
        return None
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def _aggregate_ci(checks: list[dict]) -> str:
    """Returns: success | failure | running | none."""
    if not checks:
        return "none"
    any_failed = any_running = False
    for c in checks:
        status = c.get("status", "")
        conclusion = c.get("conclusion", "")
        state = c.get("state", "")
        if status in ("IN_PROGRESS", "QUEUED", "PENDING"):
            any_running = True
        elif (
            conclusion in ("FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED")
            or state == "FAILURE"
        ):
            any_failed = True
    if any_failed:
        return "failure"
    if any_running:
        return "running"
    return "success"


def _classify(
    args: argparse.Namespace,
    head_ts: datetime,
    ci: str,
    reactions: list[dict],
    reviews: list[dict],
    line_comments: list[dict],
) -> dict:
    watched = {_norm_user(b) for b in args.watch_bots}
    bot_eye = bot_thumb = bot_changes_requested = bot_approved_review = bot_commented_review = False
    last_bot_event_ts: datetime | None = None

    def _bump(ts: datetime | None) -> None:
        nonlocal last_bot_event_ts
        if ts is None:
            return
        if last_bot_event_ts is None or ts > last_bot_event_ts:
            last_bot_event_ts = ts

    for r in reactions:
        user = _norm_user((r.get("user") or {}).get("login"))
        if user not in watched:
            continue
        _bump(_parse_ts(r.get("created_at")))
        content = r.get("content")
        if content == "eyes":
            bot_eye = True
        elif content in ("+1", "heart", "hooray", "rocket"):
            bot_thumb = True

    for rev in reviews:
        author = rev.get("author") or rev.get("user") or {}
        user = _norm_user(author.get("login"))
        if user not in watched:
            continue
        _bump(_parse_ts(rev.get("submittedAt") or rev.get("submitted_at")))
        state = rev.get("state", "")
        if state == "APPROVED":
            bot_approved_review = True
        elif state == "CHANGES_REQUESTED":
            bot_changes_requested = True
        elif state == "COMMENTED":
            bot_commented_review = True

    # GitHub's review-thread resolution status is only exposed via GraphQL; rather than
    # guess that a comment is "addressed" by virtue of a later commit (it usually isn't —
    # a later commit may have fixed something else entirely), return ALL bot line-comments
    # and let the caller (Claude) judge per-comment. The previous timestamp-only heuristic
    # caused false ready_to_merge readings on PRs where bots commented before an unrelated
    # fix push.
    bot_comments = []
    for c in line_comments:
        user = _norm_user((c.get("user") or {}).get("login"))
        if user not in watched:
            continue
        ts = _parse_ts(c.get("created_at"))
        _bump(ts)
        bot_comments.append(
            {
                "id": c["id"],
                "user": user,
                "path": c.get("path"),
                "line": c.get("line"),
                "body": c.get("body"),
                "created_at": c.get("created_at"),
            }
        )

    if ci == "failure":
        state, exit_code = "ci_failed", 2
    elif bot_comments:
        state, exit_code = "bot_commented", 0
    elif bot_changes_requested:
        # Explicit CHANGES_REQUESTED with no line-comments: bot wants more work.
        state, exit_code = "waiting", 1
    elif ci == "running":
        state, exit_code = "ci_running", 1
    elif bot_eye and not (bot_thumb or bot_approved_review):
        # :eyes: is a "look here later" signal. Until the bot either thumbs/approves
        # OR explicitly retracts via a new review event, treat as eyeing — never
        # ready_to_merge. (A stale :eyes: from an earlier push still blocks; the bot
        # owns clearing it by acting again.)
        state, exit_code = "bot_eyeing", 1
    elif ci == "success" and (bot_thumb or bot_approved_review or not watched):
        # Explicit positive signal (thumb / approved review) OR CI-only mode.
        # Silent approval requires the bot to have left a positive signal — not
        # just to have once commented and then gone silent.
        anchors = [t for t in (last_bot_event_ts, head_ts) if t is not None]
        quiet_anchor = max(anchors)
        now = datetime.now(UTC)
        if (now - quiet_anchor).total_seconds() >= args.min_quiet_seconds:
            state, exit_code = "ready_to_merge", 0
        else:
            state, exit_code = "bot_approved", 1
    else:
        state, exit_code = "waiting", 1

    return {
        "state": state,
        "exit_code": exit_code,
        "ci": ci,
        "head_commit_at": head_ts.isoformat(),
        "bot_reactions": {"eyes": bot_eye, "thumb_or_approved": bot_thumb or bot_approved_review},
        "bot_reviews": {
            "approved": bot_approved_review,
            "commented": bot_commented_review,
            "changes_requested": bot_changes_requested,
        },
        "bot_line_comments": bot_comments,
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--pr", required=True, type=int, help="PR number")
    p.add_argument("--repo", help="owner/name (defaults to current repo)")
    p.add_argument(
        "--watch-bots",
        default=",".join(DEFAULT_BOTS),
        help="comma-separated bot usernames; empty disables bot tracking",
    )
    p.add_argument(
        "--min-quiet-seconds",
        type=int,
        default=60,
        help="seconds the bot must be quiet after approval before declaring ready_to_merge",
    )
    args = p.parse_args()
    args.watch_bots = [b.strip() for b in args.watch_bots.split(",") if b.strip()]

    repo = args.repo or _default_repo()
    owner, name = repo.split("/", 1)

    pr = _gh(
        "pr",
        "view",
        str(args.pr),
        "--repo",
        repo,
        "--json",
        "statusCheckRollup,headRefOid,reviews,commits",
    )
    if not pr:
        sys.stderr.write(f"PR #{args.pr} not found in {repo}\n")
        return 2

    commits = pr.get("commits") or []
    if not commits:
        sys.stderr.write("PR has no commits\n")
        return 2
    head_ts = _parse_ts(commits[-1].get("committedDate") or commits[-1].get("authoredDate"))
    if head_ts is None:
        sys.stderr.write("could not parse head commit timestamp\n")
        return 2

    checks = pr.get("statusCheckRollup") or []
    ci = _aggregate_ci(checks)

    reactions = _gh("api", f"repos/{owner}/{name}/issues/{args.pr}/reactions") or []
    line_comments = _gh("api", f"repos/{owner}/{name}/pulls/{args.pr}/comments") or []
    reviews = pr.get("reviews") or []

    result = _classify(args, head_ts, ci, reactions, reviews, line_comments)
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return int(result["exit_code"])


if __name__ == "__main__":
    sys.exit(main())
