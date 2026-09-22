#!/usr/bin/env python3
"""Check a repo-audit findings ledger for shape before it becomes prose.

Catches the mistakes a findings list accumulates under its own weight: a
row missing the field that makes it actionable, a status outside the ones
the ledger format defines, or the same finding logged twice under
slightly different wording.

Input JSON shape (a bare list):
[
  {"finding": "...", "where": "path/or/component",
   "status": "fixed" | "queued" | "issue" | "flagged"}
]

Exit codes:
  0 — clean
  1 — one or more findings failed a check (printed to stderr, or as JSON
      to stdout with --json)
  2 — error (bad path, invalid JSON, not a list)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ALLOWED_STATUS = {"fixed", "queued", "issue", "flagged"}
REQUIRED_KEYS = {"finding", "where", "status"}


def check(findings: list[dict]) -> list[str]:
    problems = []
    seen: set[tuple[str, str]] = set()

    for i, row in enumerate(findings):
        if not isinstance(row, dict):
            problems.append(f"findings[{i}] is not an object")
            continue

        missing = REQUIRED_KEYS - row.keys()
        if missing:
            problems.append(f"findings[{i}] missing keys: {sorted(missing)}")
            continue

        if not str(row["finding"]).strip():
            problems.append(f"findings[{i}] has an empty finding")
        if not str(row["where"]).strip():
            problems.append(f"findings[{i}] has an empty where")
        if row["status"] not in ALLOWED_STATUS:
            problems.append(
                f"findings[{i}] status {row['status']!r} not in {sorted(ALLOWED_STATUS)}"
            )

        key = (str(row["finding"]).strip().lower(), str(row["where"]).strip().lower())
        if key in seen:
            problems.append(f"findings[{i}] duplicates an earlier row: {row['finding']!r}")
        seen.add(key)

    return problems


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--input", required=True, help="findings ledger JSON (a list; see module docstring)"
    )
    p.add_argument(
        "--json", action="store_true", help="emit problems as JSON to stdout instead of stderr text"
    )
    args = p.parse_args()

    try:
        data = json.loads(Path(args.input).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"✗ could not read {args.input}: {exc}\n")
        return 2

    if not isinstance(data, list):
        sys.stderr.write("✗ input must be a JSON list of findings\n")
        return 2

    problems = check(data)

    if args.json:
        print(json.dumps({"count": len(data), "problems": problems}))
    elif problems:
        for problem in problems:
            sys.stderr.write(f"✗ {problem}\n")
    else:
        sys.stderr.write(f"✓ {len(data)} finding(s), no problems\n")

    return 1 if problems else 0


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage (cp1252 and friends);
    # a non-ASCII line must degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
