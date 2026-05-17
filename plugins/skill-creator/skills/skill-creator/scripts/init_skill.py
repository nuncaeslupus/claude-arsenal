#!/usr/bin/env python3
"""init_skill.py — scaffold a new Claude Code skill.

Usage:
    python3 init_skill.py <skill-name> [--library plugins/<plugin>/skills] [--plugin <name>] [--force]

Creates `<library>/<skill-name>/` with SKILL.md, references/, scripts/,
assets/, evals/ directories, fills the SKILL.md frontmatter with the
name and a fresh canary phrase, and seeds evals/loading_verification.json
with that canary plus a placeholder negative-control.

When `--plugin <name>` is set, the default library is rewritten to
`plugins/<name>/skills`, so consumers can scaffold inside their own
plugin without typing the long path.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import secrets
import sys
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
import _console as console  # noqa: E402

ASSETS_DIR = _HERE.parent / "assets"
NAME_REGEX = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def _generate_canary(skill_name: str) -> str:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    # 64-bit random suffix + 32-bit cwd hash for cross-machine uniqueness.
    cwd_hash = hashlib.md5(str(Path.cwd()).encode("utf-8")).hexdigest()[:8]
    suffix = secrets.token_hex(8)
    return f"{skill_name}-loaded-{today}-{cwd_hash}-{suffix}"


def _read_template(name: str) -> str:
    path = ASSETS_DIR / name
    if not path.exists():
        console.fail(f"template missing: {path}")
        sys.exit(2)
    return path.read_text(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Scaffold a new Claude Code skill.")
    parser.add_argument("name", help="Skill name (kebab-case, ≤64 chars)")
    parser.add_argument(
        "--library",
        default=None,
        help="Skill library root (default: plugins/<--plugin>/skills, or plugins/skill-creator/skills if --plugin is unset)",
    )
    parser.add_argument(
        "--plugin",
        default=None,
        help="Plugin slug to scaffold inside; sets --library to plugins/<plugin>/skills when --library is not given.",
    )
    parser.add_argument("--force", action="store_true", help="Overwrite an existing folder")
    args = parser.parse_args()
    name = args.name
    if not NAME_REGEX.match(name) or len(name) > 64:
        console.fail(f"invalid name {name!r} — must be kebab-case, ≤64 chars")
        return 2
    if "anthropic" in name.lower() or "claude" in name.lower():
        console.fail(f"name {name!r} contains forbidden 'anthropic' or 'claude' substring")
        return 2
    if args.library:
        library_root = args.library
    elif args.plugin:
        library_root = f"plugins/{args.plugin}/skills"
    else:
        library_root = "plugins/skill-creator/skills"
    library = Path(library_root).resolve()
    target = library / name
    if target.exists() and not args.force:
        console.fail(f"folder already exists: {target}")
        return 2
    for sub in ("references", "scripts", "assets", "evals"):
        (target / sub).mkdir(parents=True, exist_ok=True)
    canary = _generate_canary(name)
    skill_md_template = _read_template("skill-md.template")
    skill_md = skill_md_template.replace("{{NAME}}", name).replace("{{CANARY}}", canary)
    (target / "SKILL.md").write_text(skill_md, encoding="utf-8")
    eval_template = _read_template("loading-verification.template.json")
    eval_filled = eval_template.replace("{{NAME}}", name).replace("{{CANARY}}", canary)
    (target / "evals" / "loading_verification.json").write_text(eval_filled, encoding="utf-8")
    json.loads(eval_filled)  # raise if template malformed
    console.ok(f"scaffolded {target}")
    console.info(f"canary: {canary}")
    console.info("next: fill in SKILL.md, then run validate.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
