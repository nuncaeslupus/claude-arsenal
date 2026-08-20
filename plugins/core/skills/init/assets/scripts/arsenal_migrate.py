#!/usr/bin/env python3
"""arsenal_migrate.py — move a repo from the coordination-branch queue to task files.

What changes, and why it is safe to run:

* `claude-arsenal/queue/tasks.jsonl` + `<id>.md` payloads  →  `arsenal/tasks/<id>.md`,
  one file per task, front matter carrying the fields the selector needs and
  the payload kept as the body. Task ids are preserved so `deps` keep resolving.
* `claude-arsenal/session/` and `claude-arsenal/project/`  →  `arsenal/`,
  because host-owned state living inside the vendored prefix is what stopped
  the bundle being consumable as a subtree.
* `arsenal/config.toml` is created if absent.

Tasks in a terminal state are **not** recreated as work — they are recorded in
`arsenal/tasks/_migrated-history.md` so the record survives without
resurrecting finished tasks into the queue.

Nothing is deleted. The coordination branch and its worktree are reported for
you to remove by hand, because a sandboxed session cannot delete refs and a
half-done automatic cleanup is worse than an explicit instruction.

Runs read-only by default — pass `--apply` to write. Re-running is safe: a task
file that already exists is left alone, so an interrupted migration can simply
be run again.

Exit: 0 on success, 1 if nothing to migrate, 2 on error.
"""

from __future__ import annotations

import argparse
import json
import re
import secrets
import shutil
import sys
from pathlib import Path
from typing import Any

TERMINAL = {"done", "merged"}
HISTORY_DIRNAME = "_history"
DEFAULT_QUEUE = Path("claude-arsenal/queue/tasks.jsonl")

CONFIG_TEMPLATE = """\
# claude-arsenal host configuration.
#
# This file is yours. Upstream never rewrites it, so anything set here survives
# a bundle upgrade — which is the point: a preference stored in a vendored
# skill disappears the next time that skill is refreshed.

# How far must a task PR get before it may be merged?
#   always              merge as soon as it is open
#   after-review        merge once a review approves — for a repo with no CI, or
#                       whose CI is unavailable rather than merely red
#   after-ci            merge once CI is green
#   after-ci-and-review require both
#   never               never merge automatically; you review every PR
merge-policy = "{merge_policy}"

# test-first writes a failing test before the change; test-after writes tests
# alongside it.
test-discipline = "test-first"

# What /session-end leaves behind: handoff | ticket | none
session-end = "handoff"

# The skills-listing character budget the auditor enforces. The default is
# 8000; raise it if your surface's real budget differs, rather than deleting
# skills to fit a number that is not yours.
listing-budget = 8000
"""


def new_task_id() -> str:
    """Random, not derived from the title.

    The old scheme was `"lo-" + sha256(title)[:4]`: deterministic on the title
    and only four hex characters wide, with uniqueness checked against the
    local file only. Two agents adding a task with the same title produced the
    *same* id, and neither could see the other's row. Random ids need no
    coordination to mint, which is what lets several agents create tasks at
    once.
    """
    return f"t-{secrets.token_hex(4)}"


def read_rows(queue_path: Path) -> list[dict[str, Any]]:
    if not queue_path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    for line in queue_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(data, dict) and data.get("id"):
            rows.append(data)
    return rows


def _yaml_list(values: list[str]) -> str:
    return "[" + ", ".join(values) + "]"


def task_markdown(row: dict[str, Any], payload_body: str, *, terminal: bool = False) -> str:
    deps = [str(d.get("id")) for d in row.get("deps", []) if isinstance(d, dict) and d.get("id")]
    # `ensure_ascii=False`: the default escapes every non-ASCII character to
    # `\uXXXX`, which a reader has to decode and a human cannot skim.
    title = json.dumps(str(row.get("title", row["id"])), ensure_ascii=False)
    lines = ["---", f"id: {row['id']}", f"title: {title}"]
    priority = row.get("priority", 0)
    lines.append(f"priority: {priority if isinstance(priority, int) else 0}")
    if deps:
        lines.append(f"deps: {_yaml_list(deps)}")
    if row.get("requires"):
        lines.append(f"requires: {_yaml_list([str(r) for r in row['requires']])}")
    if row.get("workspace"):
        lines.append(f"workspace: {row['workspace']}")
    if row.get("tags"):
        lines.append(f"tags: {_yaml_list([str(t) for t in row['tags']])}")
    if row.get("issue"):
        lines.append(f"issue: {row['issue']}")
    if terminal:
        # The status is what makes a dep on this task resolve as satisfied
        # rather than unknown, and it is recorded in the file because the issue
        # that once carried it may be closed, pruned, or never have existed.
        lines.append(f"status: {row.get('status')}")
        if row.get("pr"):
            lines.append(f"pr: {row['pr']}")
    max_attempts = row.get("max_attempts")
    if isinstance(max_attempts, int) and max_attempts != 3:
        lines.append(f"max-attempts: {max_attempts}")
    lines.append("---")
    lines.append("")
    body = payload_body.strip()
    if body:
        # Strip a leading H1 that just repeats the title — it is noise in a
        # file whose front matter already carries it.
        body = re.sub(r"\A#\s+.*\r?\n+", "", body)
        lines.append(body)
    else:
        lines.append(f"# {row.get('title', row['id'])}")
        lines.append("")
        lines.append("## Acceptance gate")
        lines.append("")
        lines.append("<!-- No gate was recorded for this task. Add a fenced bash block")
        lines.append("     below so completion can be checked mechanically. -->")
    lines.append("")
    return "\n".join(lines)


def migrate(
    repo_root: Path,
    queue_path: Path,
    home: Path,
    *,
    apply: bool,
    merge_policy: str,
) -> tuple[int, list[str]]:
    """Return (exit code, report lines)."""
    report: list[str] = []
    rows = read_rows(queue_path)
    queue_dir = queue_path.parent

    tasks_dir = home / "tasks"
    live = [r for r in rows if r.get("status") not in TERMINAL]
    finished = [r for r in rows if r.get("status") in TERMINAL]

    if not rows and not (repo_root / "claude-arsenal").exists():
        report.append("nothing to migrate: no queue file and no claude-arsenal/ tree")
        return 1, report

    report.append(f"queue: {len(rows)} row(s) — {len(live)} live, {len(finished)} terminal")

    def payload_for(row: dict[str, Any]) -> str:
        payload_path = queue_dir / str(row.get("payload") or f"{row['id']}.md")
        return payload_path.read_text(encoding="utf-8") if payload_path.is_file() else ""

    created = skipped = 0
    for row in live:
        target = tasks_dir / f"{row['id']}.md"
        if target.exists():
            skipped += 1
            continue
        if apply:
            tasks_dir.mkdir(parents=True, exist_ok=True)
            target.write_text(task_markdown(row, payload_for(row)), encoding="utf-8")
        created += 1
    report.append(f"task files: {created} to create, {skipped} already present → {tasks_dir}/")

    # Finished tasks keep their files too. Recording them only as prose meant a
    # dep on completed work resolved as *unknown*, and the selector blocks on
    # unknown deps by design — so on a real board every task whose prerequisites
    # had just been finished became permanently unselectable. It also dropped
    # the payloads, and with them each finished task's gate, so a host check
    # that re-asserts them found nothing to check and passed in silence.
    history_dir = tasks_dir / HISTORY_DIRNAME
    kept = 0
    for row in finished:
        target = history_dir / f"{row['id']}.md"
        if target.exists():
            continue
        if apply:
            history_dir.mkdir(parents=True, exist_ok=True)
            target.write_text(
                task_markdown(row, payload_for(row), terminal=True), encoding="utf-8"
            )
        kept += 1
    if finished:
        report.append(
            f"history files: {kept} terminal task(s) → {history_dir}/ "
            "(ids resolve, gates preserved)"
        )

    if finished:
        history = tasks_dir / "_migrated-history.md"
        if apply and not history.exists():
            tasks_dir.mkdir(parents=True, exist_ok=True)
            lines = [
                "# Completed before the migration",
                "",
                "Recorded so the history survives; these are not queue entries.",
                "",
            ]
            lines += [
                f"- `{r['id']}` — {r.get('title', '')} ({r.get('status')})"
                + (f" — {r['pr']}" if r.get("pr") else "")
                for r in finished
            ]
            history.write_text("\n".join(lines) + "\n", encoding="utf-8")
        report.append(f"history: {len(finished)} terminal task(s) → {history}")

    # Host-owned state out of the vendored prefix.
    for name in ("session", "project"):
        src = repo_root / "claude-arsenal" / name
        dst = home / name
        if not src.is_dir():
            continue
        if dst.exists():
            report.append(f"state: {dst} already exists — left alone")
            continue
        if apply:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(dst))
        report.append(f"state: {src} → {dst}")

    config = home / "config.toml"
    if not config.exists():
        if apply:
            home.mkdir(parents=True, exist_ok=True)
            config.write_text(CONFIG_TEMPLATE.format(merge_policy=merge_policy), encoding="utf-8")
        report.append(f"config: create {config} (merge-policy = {merge_policy})")
    else:
        report.append(f"config: {config} already exists — left alone")

    report.append("")
    report.append("Then, by hand — a sandboxed session cannot delete refs:")
    report.append("  git push origin --delete arsenal-queue")
    report.append("  git worktree remove ../<repo>-arsenal-queue-wt   # if one exists")
    report.append("  rm -rf claude-arsenal/queue")
    report.append("")
    report.append(
        "Each live task also needs its issue handle; run handle_sync.py "
        "(in claude-arsenal/scripts/) to list the ones still missing."
    )

    if not apply:
        report.append("")
        report.append("(dry run — nothing written. Re-run with --apply.)")
    return 0, report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--queue", type=Path, help=f"default: {DEFAULT_QUEUE}")
    parser.add_argument("--home", type=Path, help="default: <repo-root>/arsenal")
    parser.add_argument("--apply", action="store_true", help="write changes (default is a dry run)")
    parser.add_argument(
        "--merge-policy",
        default="after-ci",
        choices=["always", "after-review", "after-ci", "after-ci-and-review", "never"],
        help="seed value for the new config file",
    )
    args = parser.parse_args(argv)

    repo_root = args.repo_root
    queue_path = args.queue or (repo_root / DEFAULT_QUEUE)
    home = args.home or (repo_root / "arsenal")

    try:
        code, report = migrate(
            repo_root, queue_path, home, apply=args.apply, merge_policy=args.merge_policy
        )
    except OSError as exc:
        print(f"arsenal_migrate: {exc}", file=sys.stderr)
        return 2

    for line in report:
        print(line)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
