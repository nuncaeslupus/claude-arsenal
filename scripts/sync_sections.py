#!/usr/bin/env python3
"""Generate the shipped section manifest that ``init.py --list-sections`` reads.

A consumer's ``init.py`` lives in ``.claude/skills/init/scripts/``, and
``_source_skills_dir()`` resolves to ``.claude/skills/`` — which
``_vendor_skills`` has already pruned down to the sections that repo installed.
So a vendored ``init.py`` can enumerate the skills a repo *has* and cannot
enumerate the ones it does not, which is precisely the question a capability
map exists to answer.

The map therefore has to be shipped data, written here from the marketplace
where every skill is visible, and travelling with the bundle:

    python3 scripts/sync_sections.py            # rewrite the manifest
    python3 scripts/sync_sections.py --check    # exit 1 if it has drifted

The section defaults are imported from ``init.py`` rather than restated, so
there is one place a section is switched on by default. The *blurbs* are the
one hand-written part: a skill's ``description`` is written to trigger loading,
and a section has no frontmatter to carry a summary of its own. A shipped
section with no blurb is an error, not a blank line on every consumer's map.

Stdlib plus PyYAML, which the repo already depends on. This script is a repo
dev tool; it is not vendored.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, NoReturn

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / "plugins/core/skills/init/assets/sections.json"
INIT_PY = REPO_ROOT / "plugins/core/skills/init/scripts/init.py"

# The one hand-written field in the manifest. Written for someone who has never
# heard of the section, in the width of a terminal line: what its skills are
# for, not a list of them (the map prints the names separately).
SECTION_BLURBS: dict[str, str] = {
    "core": "the bundle itself — installer, queue engine, and the skills the protocol names",
    "workflow": "the spec → design → execute → review → ship discipline",
    "python": "the Python toolchain — coverage, mutation, dependency and release skills",
    "extract": "structured data out of artifacts you did not produce",
}


def die(msg: str) -> NoReturn:
    print(f"sync_sections: {msg}", file=sys.stderr)
    raise SystemExit(2)


def _init_module() -> Any:
    """Import the vendored installer so its section constants are read, not copied."""
    spec = importlib.util.spec_from_file_location("_arsenal_init", INIT_PY)
    if spec is None or spec.loader is None:  # pragma: no cover - packaging accident
        die(f"cannot import {INIT_PY}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _frontmatter(skill_md: Path) -> dict[str, Any]:
    """The YAML frontmatter block of a SKILL.md, or {} if it has none.

    Only the block between the opening ``---`` and the next ``---`` is parsed,
    matching ``init.py``'s ``_skill_section``: the word ``section:`` in body
    prose must not be able to re-file a skill.
    """
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    parsed = yaml.safe_load(text[3:end])
    return parsed if isinstance(parsed, dict) else {}


def build() -> dict[str, Any]:
    """The manifest, derived from every shipped SKILL.md plus the blurb table."""
    init = _init_module()
    core: str = init._CORE_SECTION
    defaults: dict[str, bool] = dict(init._SECTION_DEFAULTS)

    # Exactly the skills `/init` vendors — `init.py`'s own siblings. Scanning
    # every plugin instead would put `skill-workshop` on the map as though
    # `--sections` could install it, which it cannot: that is a marketplace
    # plugin, not a section of the bundle. The map must describe what the
    # command it is printed by can actually do.
    source: Path = init._source_skills_dir()
    by_section: dict[str, list[dict[str, str]]] = {}
    for skill_md in sorted(source.glob("*/SKILL.md")):
        fm = _frontmatter(skill_md)
        meta = fm.get("metadata") or {}
        section = str(meta.get("section") or fm.get("section") or core)
        name = str(fm.get("name") or skill_md.parent.name)
        description = " ".join(str(fm.get("description", "")).split())
        by_section.setdefault(section, []).append({"name": name, "description": description})

    missing = sorted(s for s in by_section if s not in SECTION_BLURBS)
    if missing:
        die(
            f"section(s) {', '.join(missing)} ship skills but have no SECTION_BLURBS entry. "
            "Add one line saying what the section is for — without it the capability map "
            "every consumer session reads has a blank row."
        )

    sections = []
    for name in sorted(by_section, key=lambda s: (s != core, s)):
        sections.append(
            {
                "name": name,
                "default": True if name == core else defaults.get(name, False),
                "core": name == core,
                "blurb": SECTION_BLURBS[name],
                "skills": sorted(by_section[name], key=lambda s: s["name"]),
            }
        )
    return {
        "generated_by": "scripts/sync_sections.py",
        "note": "Generated. Run `make sync-sections` after adding or re-filing a skill.",
        "sections": sections,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit 1 if the manifest has drifted")
    args = parser.parse_args(argv)

    want = json.dumps(build(), indent=2, ensure_ascii=False) + "\n"
    have = MANIFEST.read_text(encoding="utf-8") if MANIFEST.is_file() else ""

    if args.check:
        if want != have:
            print(
                f"DRIFT: {MANIFEST.relative_to(REPO_ROOT)} does not match the shipped skills. "
                "Run `make sync-sections` and commit the result.",
                file=sys.stderr,
            )
            return 1
        count = len(json.loads(have)["sections"])
        print(f"OK: sections.json matches the shipped skills ({count} sections).")
        return 0

    if want == have:
        print(f"OK: {MANIFEST.relative_to(REPO_ROOT)} already current.")
        return 0
    MANIFEST.write_text(want, encoding="utf-8")
    print(f"wrote {MANIFEST.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
