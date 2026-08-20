#!/usr/bin/env python3
"""issue_import.py — turn labelled GitHub issues into queue tasks.

The board knows about issues in one direction: a task file gets an issue handle
(`handle_sync.py`). Nothing goes the other way, so an issue filed between
sessions — from a phone, while noticing something, with no session open to seed
a task — is not work as far as the selector is concerned. It never appears in a
batch, never blocks anything, and never shows up on the board. Because an empty
selection is the signal for "report done or ask the user", a repository can be
reported as having no work while carrying a dozen open issues.

That is the same failure the protocol already names for spec divergences — a
record that lives somewhere the queue does not read is a record that stops
existing — one layer further out.

    issue_import.py --issues /tmp/all-issues.json          # what would be imported
    issue_import.py --issues /tmp/all-issues.json --apply  # write the task files

Four things this deliberately does NOT do:

* **It does not import every issue.** Only issues carrying the import label
  (default `arsenal:queue`). Discussion threads and questions are not work, and
  turning them into claimable tasks means a worker opens a PR against a
  question. Opting in is the conservative direction.
* **It does not make the new task claimable.** A seeded task's gate is the issue
  body, which is prose — and a gate that runs nothing passes everything. So the
  task carries `requires: [human:gate]`, a capability no surface offers, which
  makes the selector skip it until a human writes a real gate and removes the
  line. Visible on the board, not dispatchable.
* **It does not open a second issue.** The imported issue *becomes* the handle:
  the caller adds the printed `arsenal-task: <id>` marker to that issue. Opening
  a fresh one would leave two issues for one task and a board that disagrees
  with itself.
* **It does not touch the network.** Task files are local and written here;
  every remote change is printed for the caller to apply over whatever channel
  the surface has. With no issues to read it does nothing, which is how it
  degrades when GitHub is unreachable.

Exit: 0 (an empty import is an answer), 2 on unreadable input.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from task_select import load_tasks, task_id_from_issue

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "queue-add" / "scripts"))

DEFAULT_IMPORT_LABEL = "arsenal:queue"

# The gate a seeded task cannot pass until a human writes one. `requires` is
# already the selector's "not eligible here" mechanism, and no surface ever
# offers this capability — so the task parks itself rather than needing a new
# state to track.
GATE_CAPABILITY = "human:gate"

TEMPLATE = """\
---
id: {task_id}
title: {title}
priority: 5
requires: [{capability}]
---

Imported from {url}

{body}

## Acceptance gate

<!-- This task came from an issue, so its "gate" is prose. Write a real check
     below, then DELETE the `requires: [{capability}]` line in the front matter.
     Until that line is gone the selector will not offer this task, which is
     deliberate: a prose gate runs nothing, and a gate that runs nothing passes
     everything. -->

```bash
false  # fail until a real check replaces this
```
"""


def labels_of(issue: dict[str, Any]) -> set[str]:
    return {
        label["name"] if isinstance(label, dict) else str(label)
        for label in (issue.get("labels") or [])
    }


def importable(
    issues: list[dict[str, Any]], *, label: str, known_ids: set[str]
) -> list[dict[str, Any]]:
    """Open, labelled issues that are not already a task handle."""
    out: list[dict[str, Any]] = []
    for issue in issues:
        if str(issue.get("state", "open")).lower() != "open":
            continue
        if label not in labels_of(issue):
            continue
        # Already a handle — for a task that exists, or for one whose file was
        # deleted. Either way importing it again would mint a second task.
        existing = task_id_from_issue(issue)
        if existing:
            continue
        del known_ids
        out.append(issue)
    return out


def render(issue: dict[str, Any], task_id: str) -> str:
    body = (issue.get("body") or "").strip() or "_(no issue body)_"
    return TEMPLATE.format(
        task_id=task_id,
        title=json.dumps(str(issue.get("title", task_id))),
        capability=GATE_CAPABILITY,
        url=issue.get("html_url") or f"issue #{issue.get('number')}",
        body=body,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tasks-dir", type=Path, default=Path("arsenal/tasks"))
    parser.add_argument("--issues", type=Path, required=True, help="JSON array of issues")
    parser.add_argument("--label", default=DEFAULT_IMPORT_LABEL)
    parser.add_argument("--apply", action="store_true", help="write the task files")
    args = parser.parse_args(argv)

    try:
        payload = json.loads(args.issues.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"issue_import: cannot read --issues — {exc}", file=sys.stderr)
        return 2
    if isinstance(payload, dict):
        payload = payload.get("issues", [])
    issues = [i for i in payload if isinstance(i, dict)]

    tasks, warnings = load_tasks(args.tasks_dir)
    for warning in warnings:
        print(f"issue_import: {warning}", file=sys.stderr)

    rows = importable(issues, label=args.label, known_ids={t["id"] for t in tasks})
    if not rows:
        print(
            f"issue_import: no open `{args.label}` issue is missing a task",
            file=sys.stderr,
        )
        return 0

    try:
        from new_task import new_task_id
    except ImportError:  # standalone bundle without the queue-add skill beside it
        import secrets

        def new_task_id() -> str:
            return f"t-{secrets.token_hex(4)}"

    for issue in rows:
        task_id = new_task_id()
        path = args.tasks_dir / f"{task_id}.md"
        if args.apply:
            args.tasks_dir.mkdir(parents=True, exist_ok=True)
            path.write_text(render(issue, task_id), encoding="utf-8")
        print(
            json.dumps(
                {
                    "issue": issue.get("number"),
                    "task": task_id,
                    "path": str(path),
                    "written": bool(args.apply),
                    # The caller appends this to the issue body, which turns that
                    # issue into the task's handle. Without it the import is only
                    # half done: the task file exists and nothing can claim it.
                    "add_to_issue_body": f"`arsenal-task: {task_id}`",
                },
                separators=(",", ":"),
            )
        )

    if not args.apply:
        print(
            f"issue_import: {len(rows)} issue(s) would be imported — re-run with --apply",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
