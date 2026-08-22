#!/usr/bin/env python3
"""Validate every plugin manifest against the shapes Claude Code's loader requires.

v1.0.0 shipped ``plugins/core`` with ``"author": "nuncaeslupus"`` — a bare string
where the loader wants an object. Claude Code refused to load the plugin::

    Plugin core has an invalid manifest file at .../core/.claude-plugin/plugin.json.
    Validation errors: author: Invalid input: expected object, received string

``skill-workshop`` carried the correct object form, so the marketplace looked
healthy from the outside: one plugin installed, the other silently left at
whatever stale version the consumer already had. Nothing here checked the shape —
``sync_version.py`` rewrites the ``version`` token in these files and never reads
the rest — so a manifest the loader rejects could be tagged and released, and was.

This is that check. It validates only what the loader actually enforces; a full
schema mirrored here would be a second source of truth that drifts from the real
one. Stdlib-only, like every script in this directory::

    python3 scripts/validate_manifests.py          # exit 1 and name every problem
    python3 scripts/validate_manifests.py --quiet  # exit code only
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def _person(value: object, field: str) -> list[str]:
    """`author`/`owner` must be an object carrying a name — never a bare string.

    The bare string is the natural thing to write, reads fine, and is what
    v1.0.0 shipped. That is exactly why it needs a check rather than a
    convention: it looks right in the diff.
    """
    if not isinstance(value, dict):
        return [f"{field}: expected object, received {type(value).__name__}"]
    name = value.get("name")
    if not isinstance(name, str) or not name.strip():
        return [f"{field}.name: expected a non-empty string"]
    return []


def check_plugin(path: Path) -> list[str]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unreadable: {exc}"]
    if not isinstance(manifest, dict):
        return ["expected a JSON object at the top level"]

    problems: list[str] = []
    name = manifest.get("name")
    if not isinstance(name, str) or not name.strip():
        problems.append("name: expected a non-empty string")
    elif name != path.parent.parent.name:
        # A manifest naming a different directory installs under one name and is
        # referenced under another, which is invisible until an install fails.
        problems.append(f"name: {name!r} does not match its directory {path.parent.parent.name!r}")

    version = manifest.get("version")
    if version is not None and (not isinstance(version, str) or not SEMVER.match(version)):
        problems.append(f"version: expected a semver string, received {version!r}")

    if "author" in manifest:
        problems.extend(_person(manifest["author"], "author"))
    return problems


def check_marketplace(path: Path) -> list[str]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unreadable: {exc}"]
    problems = _person(manifest.get("owner"), "owner")
    for entry in manifest.get("plugins", []):
        source = entry.get("source", "")
        if not isinstance(source, str) or not source.startswith("./plugins/"):
            problems.append(f"plugins[{entry.get('name')!r}].source: expected ./plugins/<name>")
    return problems


def manifests(root: Path) -> list[Path]:
    return sorted(root.glob("plugins/*/.claude-plugin/plugin.json"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    found = manifests(args.repo_root)
    if not found:
        print(f"no plugin manifests under {args.repo_root}/plugins", file=sys.stderr)
        return 1

    failures = 0
    for path in found:
        for problem in check_plugin(path):
            failures += 1
            if not args.quiet:
                print(f"{path.relative_to(args.repo_root)}: {problem}", file=sys.stderr)

    marketplace = args.repo_root / ".claude-plugin" / "marketplace.json"
    if marketplace.is_file():
        for problem in check_marketplace(marketplace):
            failures += 1
            if not args.quiet:
                print(f".claude-plugin/marketplace.json: {problem}", file=sys.stderr)

    if failures:
        if not args.quiet:
            print(f"validate-manifests: {failures} problem(s)", file=sys.stderr)
        return 1
    if not args.quiet:
        print(f"validate-manifests: {len(found)} plugin manifest(s) OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
