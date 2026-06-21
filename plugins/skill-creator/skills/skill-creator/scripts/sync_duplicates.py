#!/usr/bin/env python3
"""sync_duplicates.py — detect and propagate cross-skill script drift.

Walks plugins/<plugin>/skills/<skill>/scripts/ (and ~/.claude/skills/<skill>/scripts/
if pointed at it) looking for the duplication header
(`DUPLICATED ACROSS SKILLS:` block in the file's docstring). Groups files
declared as siblings, computes per-file SHA-256, reports drift, and
optionally copies a chosen canonical onto its declared siblings.

Also scans *.sh files anywhere under the repo root (sibling of --library)
so that shell scripts with the same DUPLICATED ACROSS SKILLS header are
caught alongside Python scripts.

Usage:
    python3 sync_duplicates.py --library plugins/skill-creator/skills --check
    python3 sync_duplicates.py --library plugins/skill-creator/skills --apply <canonical-path>

`--check` exits 1 when any group has SHA drift, 0 otherwise.
`--apply <path>` copies <path> onto the other declared siblings.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
import _console as console  # noqa: E402

DUPLICATION_HEADER_RE = re.compile(
    r"DUPLICATED ACROSS SKILLS(?: \([^)]*\))?:\s*\n((?:(?:#\s+)?[-*]\s+\S.*\n)+)",
    re.IGNORECASE,
)
CANONICAL_MARK_RE = re.compile(r"\(canonical\)", re.IGNORECASE)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _parse_header(text: str) -> list[tuple[str, bool]]:
    m = DUPLICATION_HEADER_RE.search(text)
    if not m:
        return []
    out: list[tuple[str, bool]] = []
    for line in m.group(1).splitlines():
        # Strip shell comment prefix (e.g. "# - path") before the bullet marker.
        stripped = line.strip()
        if stripped.startswith("#"):
            stripped = stripped.lstrip("#").strip()
        stripped = stripped.lstrip("-*").strip()
        if not stripped:
            continue
        is_canon = bool(CANONICAL_MARK_RE.search(stripped))
        path = stripped.split(" ", 1)[0]
        if path.startswith("./"):
            path = path[2:]
        out.append((path, is_canon))
    return out


def _repo_root(start: Path) -> Path:
    """Walk up from start until we find a directory containing a Makefile or .git."""
    current = start.resolve()
    for _ in range(10):
        if (current / "Makefile").exists() or (current / ".git").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return start.resolve()


def _scan_files(
    paths: list[Path], groups: dict[frozenset[str], list[Path]]
) -> None:
    """Scan a list of files for the duplication header and populate groups."""
    seen: set[Path] = {f.resolve() for files in groups.values() for f in files}
    for script in paths:
        if script.resolve() in seen:
            continue
        text = script.read_text(encoding="utf-8", errors="replace")
        siblings = _parse_header(text)
        if not siblings:
            continue
        key = frozenset(p for p, _ in siblings)
        groups[key].append(script)
        seen.add(script.resolve())


def discover(library_dir: Path) -> dict[frozenset[str], list[Path]]:
    groups: dict[frozenset[str], list[Path]] = defaultdict(list)
    # Primary scan: *.py files in skill scripts/ directories.
    py_files: list[Path] = []
    for skill_dir in sorted(library_dir.iterdir()):
        scripts_dir = skill_dir / "scripts"
        if not scripts_dir.is_dir():
            continue
        py_files.extend(sorted(scripts_dir.rglob("*.py")))
    _scan_files(py_files, groups)

    # Secondary scan: *.sh files anywhere under the repo root so that shell
    # scripts carrying the DUPLICATED ACROSS SKILLS header are caught too.
    root = _repo_root(library_dir)
    sh_files = sorted(root.rglob("*.sh"))
    _scan_files(sh_files, groups)

    return groups


def report(groups: dict[frozenset[str], list[Path]], library_root: Path) -> bool:
    any_drift = False
    if not groups:
        console.ok("no duplicate-script groups declared")
        return False
    for key in sorted(groups, key=lambda k: ",".join(sorted(k))):
        files = groups[key]
        shas = {f: _sha256(f) for f in files}
        unique = set(shas.values())
        label = ", ".join(sorted(p for p in key))
        if len(unique) <= 1 and len(files) == len(key):
            console.ok(f"clean group: {label}")
        elif len(files) != len(key):
            any_drift = True
            console.warn(
                f"incomplete group: declared {len(key)} siblings, "
                f"found {len(files)} on disk — {label}"
            )
        else:
            any_drift = True
            console.warn(f"drift in group: {label}")
            for f, sha in shas.items():
                try:
                    rel = f.resolve().relative_to(library_root.parent.resolve()).as_posix()
                except ValueError:
                    rel = str(f)
                console.warn(f"  {sha[:12]}  {rel}")
    return any_drift


def apply_canonical(
    canonical: Path, groups: dict[frozenset[str], list[Path]], library_root: Path
) -> int:
    canonical = canonical.resolve()
    if not canonical.exists():
        console.fail(f"canonical not found: {canonical}")
        return 2
    matched = None
    try:
        canonical_rel = canonical.relative_to(library_root.parent.resolve()).as_posix()
    except ValueError:
        canonical_rel = str(canonical)
    for key, files in groups.items():
        for f in files:
            if f.resolve() == canonical:
                matched = (key, files)
                break
        if matched:
            break
    if matched is None:
        console.fail(f"canonical {canonical} is not in any declared duplicate group")
        return 2
    key, files = matched
    targets = [f for f in files if f.resolve() != canonical]
    declared_paths = {p for p in key} - {canonical_rel}
    repo_root = library_root.parent.resolve()
    for declared in declared_paths:
        target_path = (repo_root / declared).resolve()
        if not target_path.exists():
            console.warn(f"declared sibling missing on disk: {declared}")
            continue
        if target_path == canonical:
            continue
        if target_path not in [f.resolve() for f in targets]:
            targets.append(target_path)
    for target in targets:
        shutil.copyfile(canonical, target)
        console.ok(f"synced {target}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Detect and propagate duplicate-script drift.")
    parser.add_argument(
        "--library", default="plugins/skill-creator/skills", help="Skill library root"
    )
    parser.add_argument("--check", action="store_true", help="Report drift; exit 1 if any")
    parser.add_argument(
        "--apply", metavar="CANONICAL", help="Copy canonical file onto its siblings"
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    library_dir = Path(args.library).resolve()
    if not library_dir.is_dir():
        console.fail(f"not a directory: {library_dir}")
        return 2
    groups = discover(library_dir)
    if args.json:
        payload = {",".join(sorted(k)): {str(f): _sha256(f) for f in v} for k, v in groups.items()}
        print(json.dumps(payload))
    if args.apply:
        return apply_canonical(Path(args.apply), groups, library_dir)
    drift = report(groups, library_dir)
    if args.check and drift:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
