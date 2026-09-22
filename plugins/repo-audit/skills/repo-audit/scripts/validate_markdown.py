#!/usr/bin/env python3
"""Sanity-check Markdown files before proposing them to a target repo.

Generic checks only — this is not the skill-workshop rubric (that governs
Claude Code skill files specifically; this runs against any repo's docs).
Catches what a hand-authored doc fix or new reference page most often gets
wrong: a relative link to a file that doesn't exist, an unbalanced code
fence, a path that climbs out of the repo, or a placeholder left in by
mistake.

Exit codes:
  0 — clean
  1 — one or more files failed a check (printed to stderr, or as JSON to
      stdout with --json)
  2 — error (bad path)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
PLACEHOLDER_RE = re.compile(r"\b(TODO|FIXME|TBD|XXX)\b")
# There was a second check here for `<word>`, reported as an unfilled template
# token. `<word>` is how every CLI usage line, type parameter and HTML snippet
# in a doc names a variable, so it fired on documented, intentional text — six
# times on the skill that ships it. A one-line signal whose findings have to be
# hand-dismissed on a routine run makes the agent distrust the check, which
# costs more than the check was worth. TODO/FIXME/TBD/XXX are unambiguous and
# stay. The cost of dropping it: a genuinely unfilled `<PLACEHOLDER>` in prose
# is no longer caught here.


def find_markdown_files(input_dir: Path) -> list[Path]:
    return sorted(input_dir.rglob("*.md"))


def check_file(path: Path, repo_root: Path) -> list[str]:
    problems = []
    text = path.read_text(errors="replace")

    fence_count = len(re.findall(r"^```", text, flags=re.MULTILINE))
    if fence_count % 2 != 0:
        problems.append(f"{path}: unbalanced code fence ({fence_count} ``` markers)")

    for match in PLACEHOLDER_RE.finditer(text):
        line_no = text.count("\n", 0, match.start()) + 1
        problems.append(f"{path}:{line_no}: placeholder marker left in ({match.group(1)})")

    for match in LINK_RE.finditer(text):
        target = match.group(1).strip()
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        target_path = target.split("#", 1)[0]
        if not target_path:
            continue
        if ".." in Path(target_path).parts:
            resolved = (path.parent / target_path).resolve()
            if repo_root.resolve() not in resolved.parents and resolved != repo_root.resolve():
                problems.append(f"{path}: link escapes repo root via '..': {target}")
                continue
        resolved = (path.parent / target_path).resolve()
        if not resolved.exists():
            problems.append(f"{path}: broken relative link: {target}")

    return problems


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--input-dir", required=True, help="directory of changed/new Markdown files to check"
    )
    p.add_argument(
        "--repo-root", help="target repo root, for link resolution (default: --input-dir)"
    )
    p.add_argument(
        "--json", action="store_true", help="emit problems as JSON to stdout instead of stderr text"
    )
    args = p.parse_args()

    input_dir = Path(args.input_dir)
    if not input_dir.is_dir():
        sys.stderr.write(f"✗ not a directory: {input_dir}\n")
        return 2
    repo_root = Path(args.repo_root) if args.repo_root else input_dir

    files = find_markdown_files(input_dir)
    if not files:
        sys.stderr.write(f"✗ no .md files found under {input_dir}\n")
        return 2

    problems: list[str] = []
    for f in files:
        problems.extend(check_file(f, repo_root))

    if args.json:
        print(json.dumps({"files_checked": len(files), "problems": problems}))
    elif problems:
        for problem in problems:
            sys.stderr.write(f"✗ {problem}\n")
    else:
        sys.stderr.write(f"✓ {len(files)} file(s), no problems\n")

    return 1 if problems else 0


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage (cp1252 and friends);
    # a non-ASCII line must degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
