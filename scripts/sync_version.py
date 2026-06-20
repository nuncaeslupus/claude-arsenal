#!/usr/bin/env python3
"""Sync every version string in the repo from the canonical ``.bundle-version``.

``.bundle-version`` (read by ``tag-release.yml`` and ``check_update.sh``) is the
single source of truth for the marketplace version. Both plugin manifests and the
vendored ``AGENTS.md`` header carry their own copy that used to drift (issue #80).

This script keeps them in lockstep:

    python3 scripts/sync_version.py            # rewrite drifted targets in place
    python3 scripts/sync_version.py --check    # exit 1 if any target has drifted

Replacement is a surgical regex on the version token only, so each file keeps its
hand-authored formatting. Stdlib-only.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_REL = "plugins/core/skills/init/assets/.bundle-version"

SEMVER = r"\d+\.\d+\.\d+"

_JSON_VERSION = re.compile(rf'(?P<pre>"version"\s*:\s*")(?P<ver>{SEMVER})(?P<post>")')
_AGENTS_HEADER = re.compile(rf"(?P<pre><!-- claude-arsenal v)(?P<ver>{SEMVER})(?P<post>)")


@dataclass(frozen=True)
class Target:
    """A file plus the regex locating its single version token (group ``ver``)."""

    path: Path
    pattern: re.Pattern[str]
    label: str


def build_targets(root: Path) -> tuple[Target, ...]:
    """Return the version-bearing targets, resolved against ``root``."""
    return (
        Target(root / "plugins/core/.claude-plugin/plugin.json", _JSON_VERSION, "core/plugin.json"),
        Target(
            root / "plugins/skill-creator/.claude-plugin/plugin.json",
            _JSON_VERSION,
            "skill-creator/plugin.json",
        ),
        Target(
            root / "plugins/core/skills/init/assets/AGENTS.md",
            _AGENTS_HEADER,
            "AGENTS.md header",
        ),
    )


def read_canonical(root: Path) -> str:
    """Return the canonical version from ``root``'s .bundle-version, validating semver."""
    bundle = root / BUNDLE_REL
    version = bundle.read_text(encoding="utf-8").strip()
    if not re.fullmatch(SEMVER, version):
        _fail(f"{bundle.name} is not a valid X.Y.Z version: {version!r}")
    return version


def current_version(target: Target, text: str) -> str:
    """Return the version token currently in ``text`` for ``target``."""
    match = target.pattern.search(text)
    if match is None:
        _fail(f"no version token found in {target.label} ({target.path})")
    return match.group("ver")


def _fail(message: str) -> NoReturn:
    print(f"sync_version: {message}", file=sys.stderr)
    raise SystemExit(2)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report drift and exit 1 without writing; for CI / make gates",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=REPO_ROOT,
        help="repo root to operate on (default: this script's repo); for tests",
    )
    args = parser.parse_args()

    root: Path = args.repo_root
    canonical = read_canonical(root)
    drifted: list[tuple[Target, str]] = []

    for target in build_targets(root):
        text = target.path.read_text(encoding="utf-8")
        have = current_version(target, text)
        if have == canonical:
            continue
        drifted.append((target, have))
        if not args.check:
            new_text = target.pattern.sub(rf"\g<pre>{canonical}\g<post>", text, count=1)
            target.path.write_text(new_text, encoding="utf-8")

    if args.check:
        if drifted:
            for target, have in drifted:
                print(f"DRIFT: {target.label} is {have}, expected {canonical}")
            print(f"\n{len(drifted)} version(s) drifted from .bundle-version ({canonical}).")
            print("Run `make sync-version` to fix.")
            return 1
        print(f"OK: all versions match .bundle-version ({canonical}).")
        return 0

    if drifted:
        for target, have in drifted:
            print(f"synced {target.label}: {have} -> {canonical}")
    else:
        print(f"OK: all versions already match .bundle-version ({canonical}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
