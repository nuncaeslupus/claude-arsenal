#!/usr/bin/env python3
"""validate_memory.py — validator for CLAUDE.md / AGENTS.md memory layer.

Usage:
    python3 validate_memory.py [--root .] [--severity warn|fail] [--json]

Walks the repo from --root looking for CLAUDE.md and AGENTS.md files
(root and nested per-directory pairs). Checks each against the
project-memory-layer rules: 200-line target on CLAUDE.md, the
@AGENTS.md first-line ordering, recursive @-import depth, no
absolute home paths, no CLAUDE.md ↔ AGENTS.md symlink.

Exit 0 clean / 1 blocking findings / 2 internal error.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
import _console as console  # noqa: E402

HOME_PATH_REGEX = re.compile(r"(~/\.claude/|/home/\w+/\.claude/|/Users/\w+/\.claude/)")
AT_IMPORT_REGEX = re.compile(r"^\s*@([A-Za-z0-9_./-]+\.md)\b", re.MULTILINE)
FRONTMATTER_RE = re.compile(r"^---\n.*?\n---\n", re.DOTALL)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


@dataclass
class Issue:
    severity: str
    check: str
    message: str
    path: str | None = None


@dataclass
class Result:
    issues: list[Issue] = field(default_factory=list)

    def fail(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("fail", check, message, str(path) if path else None))

    def warn(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("warn", check, message, str(path) if path else None))


def _strip_fences(text: str) -> str:
    out, in_fence = [], False
    for line in text.splitlines():
        if line.strip().startswith(("```", "~~~")):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


def _strip_inline_code(text: str) -> str:
    text = re.sub(r"`[^`\n]*`", "", text)
    text = re.sub(r"`[^`]*`", "", text, flags=re.DOTALL)
    return text


def _strip_all_code(text: str) -> str:
    return _strip_inline_code(_strip_fences(text))


def _strip_preamble(text: str) -> str:
    text = FRONTMATTER_RE.sub("", text, count=1)
    text = HTML_COMMENT_RE.sub("", text)
    return text


def _import_chain_depth(start: Path, root: Path, seen: set[Path] | None = None) -> int:
    if seen is None:
        seen = set()
    start = start.resolve()
    if start in seen or not start.exists():
        return 0
    seen.add(start)
    try:
        text = start.read_text(encoding="utf-8")
    except Exception:
        return 0
    text = _strip_fences(text)
    max_child = 0
    for m in AT_IMPORT_REGEX.finditer(text):
        target = m.group(1)
        candidate = (start.parent / target).resolve()
        if not candidate.exists():
            candidate = (root / target).resolve()
        depth = _import_chain_depth(candidate, root, seen) if candidate.exists() else 0
        max_child = max(max_child, depth)
    return 1 + max_child


def check_memory_file(path: Path, root: Path, result: Result) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        result.fail("file.utf-8", "not valid UTF-8", path)
        return
    body_no_fence = _strip_all_code(_strip_preamble(text))
    if HOME_PATH_REGEX.search(body_no_fence):
        result.fail(
            "memory.home-path",
            "absolute ~/.claude or /home/X/.claude path outside fenced blocks",
            path,
        )
    if path.name == "CLAUDE.md":
        nonblank = [ln for ln in text.splitlines() if ln.strip()]
        if len(nonblank) > 200:
            result.warn(
                "memory.claude-length",
                f"CLAUDE.md is {len(nonblank)} non-blank lines (>200 target; not truncated)",
                path,
            )
        agents_path = path.parent / "AGENTS.md"
        if agents_path.exists():
            preamble_stripped = _strip_preamble(text)
            first_content = next(
                (ln for ln in preamble_stripped.splitlines() if ln.strip()),
                "",
            )
            if "@AGENTS.md" in text and first_content.strip() != "@AGENTS.md":
                result.fail(
                    "memory.agents-first-line",
                    "AGENTS.md is present and CLAUDE.md mentions @AGENTS.md, "
                    "but @AGENTS.md is not the first content line",
                    path,
                )
        if path.is_symlink() and (path.parent / "AGENTS.md").exists():
            target = (path.parent / path.readlink()).resolve()
            if target == (path.parent / "AGENTS.md").resolve():
                result.fail(
                    "memory.symlink",
                    "CLAUDE.md must not be a symlink to AGENTS.md (use @AGENTS.md import)",
                    path,
                )
    if path.name == "AGENTS.md" and path.is_symlink():
        target = (path.parent / path.readlink()).resolve()
        if target == (path.parent / "CLAUDE.md").resolve():
            result.fail(
                "memory.symlink",
                "AGENTS.md must not be a symlink to CLAUDE.md",
                path,
            )
    depth = _import_chain_depth(path, root)
    if depth > 5:
        result.warn(
            "memory.import-depth",
            f"@-import chain depth from this file is {depth} (>5; not loaded past depth 5)",
            path,
        )


def emit_text(result: Result) -> None:
    if not result.issues:
        console.ok("memory layer: clean")
        return
    fails = [i for i in result.issues if i.severity == "fail"]
    warns = [i for i in result.issues if i.severity == "warn"]
    console.start(f"memory layer: {len(fails)} fail, {len(warns)} warn")
    for issue in result.issues:
        emit = console.fail if issue.severity == "fail" else console.warn
        loc = f" [{issue.path}]" if issue.path else ""
        emit(f"{issue.check}: {issue.message}{loc}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validator for CLAUDE.md / AGENTS.md memory layer."
    )
    parser.add_argument("--root", default=".", help="Repo root (default: cwd)")
    parser.add_argument("--severity", choices=("warn", "fail"), default="fail")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    if not root.is_dir():
        console.fail(f"not a directory: {root}")
        return 2
    result = Result()
    skip_dirs = {".git", "node_modules", ".venv", "venv", "__pycache__"}
    for path in root.rglob("*"):
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.is_file() and path.name in ("CLAUDE.md", "AGENTS.md"):
            check_memory_file(path, root, result)
    if args.json:
        print(json.dumps({"issues": [asdict(i) for i in result.issues]}))
    else:
        emit_text(result)
    blocking = {"fail"}
    if args.severity == "warn":
        blocking.add("warn")
    return 1 if any(i.severity in blocking for i in result.issues) else 0


if __name__ == "__main__":
    sys.exit(main())
