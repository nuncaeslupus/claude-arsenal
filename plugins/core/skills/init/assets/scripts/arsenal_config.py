#!/usr/bin/env python3
"""arsenal_config.py — read the host-owned `arsenal/config.toml`.

The point of this file is that a consumer configures behaviour **without
editing a skill**. Skills are vendored build output: an upgrade overwrites
them, so a preference stored in one is a preference that silently disappears.
`arsenal/config.toml` is host-owned and upstream never rewrites it.

Every key has a default, so a repo with no config file behaves sensibly and a
repo with a partial file only overrides what it names.

Usage:
    arsenal_config.py                      # print the effective config as JSON
    arsenal_config.py --get merge-policy   # print one value, bare
    arsenal_config.py --explain            # show each value and where it came from

Exit: 0 on success, 2 on an invalid value (a typo in a policy name is a
configuration bug worth failing loudly for, not silently defaulting past).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tomllib
from pathlib import Path
from typing import Any

# Defaults live here rather than being scattered through the scripts that read
# them, so `--explain` can always say what the fallback is.
DEFAULTS: dict[str, Any] = {
    # How far a task PR must get before it may be merged. See the `github`
    # skill, which is the only thing that acts on this.
    "merge-policy": "after-ci",
    # test-first writes a failing test before the change; test-after writes
    # tests alongside it. Read by `execution`.
    "test-discipline": "test-first",
    # What /session-end writes when a session closes.
    "session-end": "handoff",
    # The skills-listing character budget the auditor enforces. It is a real
    # constraint, but its value differs by surface and has changed over time,
    # so a consumer whose budget differs can set it here instead of being
    # unable to pass the audit at all (#143).
    "listing-budget": 8000,
    # Whether `/init` keeps .github/workflows/arsenal-queue.yml installed. Set
    # to `true` on first install and to `false` when the file is found deleted,
    # so removing it is a real opt-out rather than something the next session's
    # `init --silent` quietly undoes.
    "queue-automation": True,
    # Where host-owned project content lives, relative to the repo root.
    "home": "arsenal",
    # The label that marks an issue as a machine-managed task handle. Anything
    # without it is never treated as claimable work, which is what keeps
    # ordinary issues people file out of the queue.
    "task-label": "arsenal:task",
    # Ref namespace for atomic claim refs.
    "claim-prefix": "arsenal/claims",
}

ENUMS: dict[str, set[str]] = {
    # `after-review` is not a weaker `after-ci-and-review` — it is the other
    # axis. `after-ci` is "the machines agree"; `after-review` is "a reader
    # agrees"; a repo should be able to require either, both, or neither.
    # Without it, a repo whose CI is structurally unavailable — out of runner
    # minutes, or no CI at all — can only choose between a policy that blocks
    # every merge indefinitely and one that everybody learns to wave through.
    "merge-policy": {"always", "after-review", "after-ci", "after-ci-and-review", "never"},
    "test-discipline": {"test-first", "test-after"},
    "session-end": {"handoff", "ticket", "none"},
}

CONFIG_RELPATH = "config.toml"


class ConfigError(Exception):
    """An invalid configuration value — loud on purpose."""


def _config_path(repo_root: Path, home: str) -> Path:
    return repo_root / home / CONFIG_RELPATH


def load(repo_root: Path | None = None) -> tuple[dict[str, Any], dict[str, str]]:
    """Return (effective config, source-of-each-value).

    Sources are reported so `--explain` can print "8000 (default)" versus
    "12000 (arsenal/config.toml)". A threshold whose value is invisible in the
    output is one nobody can tell has been quietly raised.
    """
    root = repo_root or Path.cwd()
    values: dict[str, Any] = dict(DEFAULTS)
    sources: dict[str, str] = dict.fromkeys(DEFAULTS, "default")

    # ARSENAL_HOME may relocate the whole host-owned tree; it also decides
    # where we look for the config itself, so it is resolved first.
    home = os.environ.get("ARSENAL_HOME", DEFAULTS["home"])
    if home != DEFAULTS["home"]:
        values["home"] = home
        sources["home"] = "ARSENAL_HOME"

    path = _config_path(root, home)
    if path.is_file():
        try:
            raw = tomllib.loads(path.read_text(encoding="utf-8"))
        except tomllib.TOMLDecodeError as exc:
            raise ConfigError(f"{path}: not valid TOML — {exc}") from exc
        for key, value in raw.items():
            if key not in DEFAULTS:
                # Unknown keys are tolerated rather than fatal: a consumer on
                # an older bundle should not break when a newer one adds a key,
                # and vice versa.
                continue
            values[key] = value
            sources[key] = str(path)

    for key, allowed in ENUMS.items():
        if values[key] not in allowed:
            raise ConfigError(
                f"{key}: {values[key]!r} is not one of {sorted(allowed)} (from {sources[key]})"
            )
    if not isinstance(values["listing-budget"], int) or values["listing-budget"] <= 0:
        raise ConfigError(
            f"listing-budget must be a positive integer, got {values['listing-budget']!r}"
        )

    return values, sources


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--get", metavar="KEY", help="print a single value, bare")
    parser.add_argument("--explain", action="store_true", help="show each value and its source")
    args = parser.parse_args(argv)

    try:
        values, sources = load(args.repo_root)
    except ConfigError as exc:
        print(f"arsenal_config: {exc}", file=sys.stderr)
        return 2

    if args.get:
        if args.get not in values:
            print(f"arsenal_config: unknown key {args.get!r}", file=sys.stderr)
            return 2
        print(values[args.get])
        return 0

    if args.explain:
        width = max(len(k) for k in values)
        for key in sorted(values):
            src = "default" if sources[key] == "default" else sources[key]
            print(f"{key:<{width}}  {values[key]}   ({src})")
        return 0

    print(json.dumps(values, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
