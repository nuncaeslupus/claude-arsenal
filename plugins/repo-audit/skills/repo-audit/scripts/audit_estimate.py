#!/usr/bin/env python3
"""audit_estimate.py — what auditing a scope will cost, before anything starts.

    audit_estimate.py src lib
    → scope: src, lib · 412 files · 61,300 lines · ≈ 740k tokens · 3 workers (src/api, ...)

Counts the text files in scope (`git ls-files` when inside a repository, so what
.gitignore hides is skipped), leaving out vendored trees, lockfiles, minified and
generated files, and binaries. Tokens are lines x --tokens-per-line: 12 is a
STARTING VALUE covering reading plus reasoning, not a measurement — compare a real
run against `usage_report.py` and tune it. Workers follow the audit's own sizing
rule: inline under about 150 files and 20k lines, else one per subsystem (capped).

Usage:
    audit_estimate.py [PATH ...] [--tokens-per-line 12] [--max-workers 8] [--json]
Exit: 0 ok, 2 a path does not exist.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import subprocess
import sys
from pathlib import Path

SKIP_DIRS = {
    ".git", "node_modules", "vendor", "third_party", ".venv", "venv",
    "dist", "build", "__pycache__", ".tox", "target", ".mypy_cache",
}  # fmt: skip
SKIP_FILES = (
    "*.lock", "package-lock.json", "pnpm-lock.yaml", "go.sum", "*.min.js",
    "*.min.css", "*.map", "*.svg", "*.pdf", "*.png", "*.jpg", "*.gif", "*.ico",
)  # fmt: skip
INLINE_FILES, INLINE_LINES = 150, 20_000


def _skipped(path: Path) -> bool:
    return any(p in SKIP_DIRS for p in path.parts) or any(
        fnmatch.fnmatch(path.name, g) for g in SKIP_FILES
    )


def files_in(scope: list[Path]) -> list[Path]:
    res = subprocess.run(
        ["git", "ls-files", "-z", "--", *map(str, scope)], capture_output=True, check=False
    )
    if res.returncode == 0 and res.stdout:
        listed = [Path(p) for p in res.stdout.decode(errors="surrogateescape").split("\0") if p]
    else:
        listed = [p for s in scope for p in ([s] if s.is_file() else s.rglob("*")) if p.is_file()]
    return sorted(p for p in listed if not _skipped(p) and p.is_file())


def count_lines(path: Path) -> int | None:
    """Lines in a text file; None for a binary (a NUL byte in the first 8 KiB)."""
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return None
    return data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)


def subsystems(files: list[Path], scope: list[Path]) -> list[str]:
    """Top-level directories under each scope root, largest first."""
    sizes: dict[str, int] = {}
    for f in files:
        root = next((s for s in scope if s == Path() or f.is_relative_to(s)), Path())
        rel = f.relative_to(root) if root != Path() else f
        key = str(root / rel.parts[0]) if len(rel.parts) > 1 else str(root)
        sizes[key] = sizes.get(key, 0) + 1
    return [k for k, _ in sorted(sizes.items(), key=lambda kv: -kv[1])]


def estimate(scope: list[Path], tokens_per_line: int, max_workers: int) -> dict:
    counted = [(f, n) for f in files_in(scope) if (n := count_lines(f)) is not None]
    lines = sum(n for _, n in counted)
    subs = subsystems([f for f, _ in counted], scope)
    inline = len(counted) < INLINE_FILES and lines < INLINE_LINES
    workers = 1 if inline else min(max(len(subs), 1), max_workers)
    return {
        "scope": [str(s) for s in scope],
        "files": len(counted),
        "lines": lines,
        "tokens": lines * tokens_per_line,
        "tokens_per_line": tokens_per_line,
        "workers": workers,
        "subsystems": subs[:workers] if not inline else [],
    }


def line(e: dict) -> str:
    tok = e["tokens"]
    tok_s = f"{tok / 1e6:.1f}M" if tok >= 1e6 else f"{round(tok / 1e3)}k"
    split = f" ({', '.join(e['subsystems'])})" if e["subsystems"] else " (inline)"
    return (
        f"scope: {', '.join(e['scope'])} · {e['files']} files · {e['lines']:,} lines"
        f" · ≈ {tok_s} tokens · {e['workers']} worker{'s' if e['workers'] != 1 else ''}{split}"
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n", 1)[0])
    ap.add_argument("paths", nargs="*", default=["."])
    ap.add_argument("--tokens-per-line", type=int, default=12, help="starting value; tune it")
    ap.add_argument("--max-workers", type=int, default=8)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    scope = [Path(p) for p in args.paths]
    missing = [str(p) for p in scope if not p.exists()]
    if missing or args.tokens_per_line < 1 or args.max_workers < 1:
        print(
            f"audit_estimate: bad scope or flag: {', '.join(missing) or 'a value < 1'}",
            file=sys.stderr,
        )
        return 2
    e = estimate(scope, args.tokens_per_line, args.max_workers)
    print(json.dumps(e, indent=2) if args.json else line(e))
    return 0


if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
