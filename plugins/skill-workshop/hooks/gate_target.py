#!/usr/bin/env python3
"""gate_target.py — decide what a tool call is about to write inside a skill folder.

Reads a PreToolUse payload on stdin, prints the skill-folder path the call would
modify, or nothing when it would not modify one.

Edit / Write / MultiEdit name their target outright. Bash does not: `sed -i`,
`tee`, a heredoc redirect and a Python one-liner all reach a SKILL.md without
ever appearing as a `file_path`, which is how the gate came to be bypassable by
the edit style the harness encourages. So for Bash the command is scanned, and
the distinction that matters is *mutation*, not mention — reading a skill file
and redirecting the output elsewhere has to stay allowed, or the gate becomes
something people route around instead of through.
"""
from __future__ import annotations

import json
import re
import sys

# .claude/skills/<name>/… or plugins/<plugin>/skills/<name>/… — one path segment
# past the skill folder, matching the shell hook's `*/skills/*/*` cases.
SKILL_PATH = re.compile(
    r"""(?:^|[\s'"=(])((?:[\w./-]*/)?(?:\.claude/skills|plugins/[^/\s'"]+/skills)/[^/\s'"]+/[^\s'"()]+)"""
)

# Utilities that write wherever they are pointed. `rm` counts: deleting a skill
# file is a skill change like any other.
MUTATORS = re.compile(
    r"(?:^|[\s;&|(])(?:sed\s+-[^\s]*i|tee|cp|mv|rm|truncate|patch|touch|install|dd|chmod|ln)\b"
)

# Python/Node write calls, for the heredoc-into-interpreter route.
WRITERS = re.compile(
    r"write_text\s*\(|\.write\s*\(|writeFileSync|shutil\.(?:copy|move)"
    r"|os\.replace|\.unlink\s*\(|\.rename\s*\("
)


def bash_target(command: str) -> str:
    paths = [m.group(1) for m in SKILL_PATH.finditer(command)]
    if not paths:
        return ""
    # A skill path that is itself a redirect target is a write, full stop.
    for p in paths:
        if re.search(r">>?\s*['\"]?" + re.escape(p), command):
            return p
    if MUTATORS.search(command) or WRITERS.search(command):
        return paths[0]
    return ""


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        return 0  # unparseable payload is not this hook's problem — allow
    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input", {}) or {}
    if tool == "Bash":
        print(bash_target(ti.get("command", "") or ""))
    else:
        print(ti.get("file_path", "") or "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
