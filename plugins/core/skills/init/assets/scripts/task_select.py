#!/usr/bin/env python3
"""task_select.py — decide which task to work on next. Pure function, no network.

This is the piece that used to cost the most: choosing a task meant a session
walked a protocol, ran several scripts, and reasoned over their output in
context. Ordering is a computation, not a judgement call, so it belongs in a
script that answers in one line.

Two inputs, both cheap:

* **Task files** — `<home>/tasks/*.md`, each with YAML-ish front matter
  carrying `id`, `title`, `deps`, `priority`, `requires`. These are read from
  the repository, so the dependency graph is versioned with the code and
  identical for every agent.
* **State** — a JSON object mapping task id to `open` / `claimed` / `done`,
  supplied by the caller (`--state` or stdin). Keeping state *out* of this
  script is what makes it pure: it never touches git or GitHub, so it is
  trivially testable and cannot fail because a network call did.

A task is eligible when it is `open`, every dep is `done`, and every
`requires:` capability is offered by the current surface.

Output is one compact JSON object per line, best first — small on purpose,
since every byte lands in a model's context:

    {"id":"t-3f8a91c2","title":"...","path":"arsenal/tasks/t-3f8a91c2.md","priority":2,"gate":true}

Exit: 0 always (an empty selection is an answer, not an error).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

FRONT_MATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
GATE_BLOCK_RE = re.compile(r"^[ \t]*```bash\b", re.MULTILINE)
# The marker an issue carries to say which task file it is a handle for. Kept
# in the issue body rather than the task file so a task file never has to be
# rewritten to learn its issue number.
TASK_MARKER_RE = re.compile(r"<!--\s*arsenal-task:\s*([A-Za-z0-9._-]+)\s*-->")

TERMINAL = {"done", "merged"}


def state_from_issues(
    issues: list[dict[str, Any]], *, claimed_label: str = "arsenal:claimed"
) -> dict[str, str]:
    """Derive the task state map from GitHub issues.

    Deliberately pure: the caller fetches the issues with whatever GitHub
    channel its surface offers, and this turns them into the small map the
    selector needs. That split is what lets one script call answer "what
    next", instead of a protocol the model walks step by step.

    A task is `done` only when its issue was closed **as completed**. An issue
    closed by hand, or as not-planned, leaves the task blocked rather than
    unblocking everything downstream — a stray close should not release work
    that was never actually done.
    """
    state: dict[str, str] = {}
    for issue in issues:
        body = issue.get("body") or ""
        marker = TASK_MARKER_RE.search(body)
        if not marker:
            continue
        task_id = marker.group(1)
        labels = {
            label["name"] if isinstance(label, dict) else str(label)
            for label in (issue.get("labels") or [])
        }
        if str(issue.get("state", "")).lower() == "closed":
            reason = str(issue.get("state_reason") or "completed").lower()
            state[task_id] = "done" if reason == "completed" else "cancelled"
        elif claimed_label in labels or issue.get("assignee") or issue.get("assignees"):
            state[task_id] = "claimed"
        else:
            state[task_id] = "open"
    return state


def _parse_scalar(raw: str) -> Any:
    """Coerce a front-matter scalar. Deliberately small: the subset below is
    all a task file needs, and depending on PyYAML would break consumers who
    run these scripts with a bare `python3` and no site-packages."""
    text = raw.strip()
    if text.startswith(("'", '"')) and text.endswith(("'", '"')) and len(text) >= 2:
        return text[1:-1]
    if text.lower() in {"true", "false"}:
        return text.lower() == "true"
    if re.fullmatch(r"-?\d+", text):
        return int(text)
    return text


def parse_front_matter(text: str) -> dict[str, Any]:
    """Parse the `key: value` / `key: [a, b]` / `key:\\n  - a` subset."""
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return {}
    data: dict[str, Any] = {}
    pending_key: str | None = None
    for line in match.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        list_item = re.match(r"^[ \t]+-[ \t]*(.*)$", line)
        if list_item and pending_key is not None:
            data.setdefault(pending_key, [])
            if isinstance(data[pending_key], list):
                data[pending_key].append(_parse_scalar(list_item.group(1)))
            continue
        key_value = re.match(r"^([A-Za-z0-9_-]+):[ \t]*(.*)$", line)
        if not key_value:
            continue
        key, value = key_value.group(1), key_value.group(2).strip()
        if value == "":
            pending_key = key
            data[key] = []
            continue
        pending_key = None
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            data[key] = [_parse_scalar(p) for p in inner.split(",") if p.strip()] if inner else []
        else:
            data[key] = _parse_scalar(value)
    return data


def load_tasks(tasks_dir: Path) -> tuple[list[dict[str, Any]], list[str]]:
    """Return (tasks, warnings). A malformed task file is reported rather than
    skipped in silence — a task nobody can see is work that never happens."""
    tasks: list[dict[str, Any]] = []
    warnings: list[str] = []
    if not tasks_dir.is_dir():
        return tasks, [f"no task directory at {tasks_dir}"]
    seen: dict[str, Path] = {}
    for path in sorted(tasks_dir.glob("*.md")):
        # `_`- and `.`-prefixed files are notes that live alongside the tasks —
        # the migration's `_migrated-history.md`, a `_README.md` — not tasks.
        # Without this they would each warn about a missing `id:` on every run,
        # and a warning that fires every time is one people stop reading.
        if path.name.startswith(("_", ".")):
            continue
        text = path.read_text(encoding="utf-8")
        meta = parse_front_matter(text)
        task_id = meta.get("id")
        if not task_id or not isinstance(task_id, str):
            warnings.append(f"{path}: no `id:` in front matter — skipped")
            continue
        if task_id in seen:
            warnings.append(f"{path}: duplicate id {task_id} (also {seen[task_id]}) — skipped")
            continue
        seen[task_id] = path
        deps = meta.get("deps") or []
        tasks.append(
            {
                "id": task_id,
                "title": str(meta.get("title", task_id)),
                "path": str(path),
                "priority": meta.get("priority", 0)
                if isinstance(meta.get("priority", 0), int)
                else 0,
                "deps": [str(d) for d in deps] if isinstance(deps, list) else [],
                "requires": [str(r) for r in (meta.get("requires") or [])],
                "workspace": meta.get("workspace"),
                "tags": [str(t) for t in (meta.get("tags") or [])],
                "gate": bool(GATE_BLOCK_RE.search(text)),
            }
        )
    return tasks, warnings


def select(
    tasks: list[dict[str, Any]],
    state: dict[str, str],
    *,
    capabilities: set[str],
    workspace: str | None = None,
    tags: set[str] | None = None,
    limit: int = 1,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Choose eligible tasks, best first. Returns (selection, warnings)."""
    warnings: list[str] = []
    known = {t["id"] for t in tasks}

    for task in tasks:
        for dep in task["deps"]:
            if dep not in known:
                warnings.append(
                    f"{task['id']}: depends on unknown task {dep} — treated as blocking"
                )

    eligible: list[dict[str, Any]] = []
    for task in tasks:
        if state.get(task["id"], "open") != "open":
            continue
        # An unknown dep blocks rather than unblocks: guessing that a missing
        # dependency is satisfied is how work gets done out of order.
        if any(state.get(dep) not in TERMINAL for dep in task["deps"]):
            continue
        if not set(task["requires"]).issubset(capabilities):
            continue
        if workspace and task["workspace"] != workspace:
            continue
        if tags and not tags.issubset(set(task["tags"])):
            continue
        eligible.append(task)

    # Highest priority first, then by id so two agents reading the same graph
    # always rank it identically — ties resolved by luck would have them race
    # for the same task more often than necessary.
    eligible.sort(key=lambda t: (-int(t["priority"]), t["id"]))
    return eligible[:limit], warnings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--tasks-dir", type=Path, default=Path("arsenal/tasks"))
    parser.add_argument(
        "--state", type=Path, help="JSON file of {task_id: state}; omit to read stdin"
    )
    parser.add_argument(
        "--issues",
        type=Path,
        help="JSON array of GitHub issues (as your GitHub tools return them); "
        "state is derived from them, so no --state is needed",
    )
    parser.add_argument(
        "--capability", action="append", default=[], help="repeatable, e.g. surface:cli"
    )
    parser.add_argument("--workspace")
    parser.add_argument("--tag", action="append", default=[])
    parser.add_argument("--max", type=int, default=1, dest="limit")
    parser.add_argument(
        "--all", action="store_true", help="list every task with its computed status"
    )
    args = parser.parse_args(argv)

    state: dict[str, str] = {}
    if args.issues:
        try:
            payload = json.loads(args.issues.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"task_select: --issues is not valid JSON — {exc}", file=sys.stderr)
            return 2
        # Accept either a bare array or the {"issues": [...]} envelope some
        # GitHub tools wrap results in, so the caller can save what it got.
        if isinstance(payload, dict):
            payload = payload.get("issues", [])
        state = state_from_issues([i for i in payload if isinstance(i, dict)])
    else:
        raw_state = ""
        if args.state:
            raw_state = args.state.read_text(encoding="utf-8")
        elif not sys.stdin.isatty():
            raw_state = sys.stdin.read()
        try:
            state = json.loads(raw_state) if raw_state.strip() else {}
        except json.JSONDecodeError as exc:
            print(f"task_select: --state is not valid JSON — {exc}", file=sys.stderr)
            return 2

    tasks, warnings = load_tasks(args.tasks_dir)

    if args.all:
        for task in sorted(tasks, key=lambda t: (-int(t["priority"]), t["id"])):
            row = {"id": task["id"], "title": task["title"], "state": state.get(task["id"], "open")}
            print(json.dumps(row, separators=(",", ":")))
    else:
        selection, sel_warnings = select(
            tasks,
            state,
            capabilities=set(args.capability),
            workspace=args.workspace,
            tags=set(args.tag) or None,
            limit=max(1, args.limit),
        )
        warnings += sel_warnings
        for task in selection:
            print(
                json.dumps(
                    {
                        "id": task["id"],
                        "title": task["title"],
                        "path": task["path"],
                        "priority": task["priority"],
                        "gate": task["gate"],
                    },
                    separators=(",", ":"),
                )
            )

    for warning in warnings:
        print(f"task_select: {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
