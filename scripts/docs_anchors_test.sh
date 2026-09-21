#!/usr/bin/env bash
# docs_anchors_test.sh — every internal Markdown anchor in this repo resolves.
#
# An audit reported 67 dead `[text](#anchor)` links in the research archive.
# Measured mechanically, there are none: all 141 `<!-- @rule: R-XXX -->` markers
# already carry an `<a id="r-xxx"></a>` tag, and the only two unresolved targets
# are `[text](#anchor)` and `[R-X](#r-x)` — illustrative forms written inside
# code spans, not links. So this is the check that finding needed rather than
# the fix it asked for: cheap, mechanical, and it fails if a real one breaks.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - "${REPO_ROOT}" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
# `arsenal/` holds task records, whose prose quotes link forms as evidence.
SKIP = {".git", "node_modules", ".venv", "__pycache__", "arsenal"}


def heading_slug(heading: str) -> str:
    """GitHub's slug: lowercase, punctuation dropped, spaces to hyphens."""
    text = re.sub(r"`([^`]*)`", r"\1", heading).strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    # One hyphen per space, not per run: `## A — b` drops the dash and keeps
    # both surrounding spaces, so its slug is `a--b`, which is what the link
    # in the contents list says.
    return re.sub(r"\s", "-", text)


def strip_code(text: str) -> str:
    """Fenced blocks and inline spans, blanked out but line-count preserved.

    A link form written inside backticks is documentation ABOUT links, not a
    link — `[text](#anchor)` is the example the archive uses to describe the
    convention, and counting it is how a hand audit gets a number like 67.
    """
    text = re.sub(r"```.*?```", lambda m: "\n" * m.group().count("\n"), text, flags=re.DOTALL)
    return re.sub(r"`[^`\n]*`", "", text)


problems = []
checked = 0
for path in sorted(root.rglob("*.md")):
    if SKIP & set(path.parts):
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    ids = set(re.findall(r'<a id="([^"]+)"></a>', text))
    ids |= {heading_slug(h) for h in re.findall(r"^#{1,6}\s+(.*)$", text, re.M)}
    for target in re.findall(r"\]\(#([^)]+)\)", strip_code(text)):
        checked += 1
        if target not in ids:
            line = text.count("\n", 0, text.index(f"](#{target})")) + 1
            problems.append(f"{path.relative_to(root)}:{line}: no anchor '#{target}' in this file")

if problems:
    print("FAIL: internal links with no anchor to land on:", file=sys.stderr)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    sys.exit(1)
print(f"PASS: {checked} internal anchor link(s) across the repo's Markdown all resolve")
PY
