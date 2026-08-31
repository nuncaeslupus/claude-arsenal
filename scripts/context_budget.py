#!/usr/bin/env python3
"""context_budget.py — what adopting this marketplace costs a consumer's context.

A skill set earns its place by making a session better at the work, and every
token it occupies is one the session cannot spend on the work itself. That
trade is only checkable if somebody states the number, so this states it.

Three tiers, because they are paid on completely different schedules:

* **Resident** — in context on every turn of every session, forever. Two things
  land here: the vendored `AGENTS.md`, which a consumer's `CLAUDE.md`
  `@`-imports, and the `name` + `description` of every **installed** skill,
  which sit in the skills index whether or not a skill is ever used. This is
  the number that matters, and the only one with a hard cap.
* **On invocation** — a `SKILL.md` body, paid once when its skill triggers.
  Cheap by comparison, and only paid by the session that wanted it.
* **On demand** — `references/` and agent definitions, paid only when something
  opens them. Effectively free until read, which is the whole point of putting
  content there.

**Installed, not shipped.** The resident tier used to be one number over every
`SKILL.md` in the repo, which is a figure no consumer has ever paid. It counted
`skill-workshop`, a marketplace plugin `/init` does not vendor at all, and it
counted every default-off section as though everyone had opted into it. Both
directions were wrong and they did not cancel: the number overstated what a
default install costs, while saying nothing at all about what enabling a
section costs the person who enables it. So the listing is now resolved per
install — the same `_PROFILES` and `section:` frontmatter `/init` itself reads
— and each row is a bill somebody actually receives.

The cap applies to `maximal`, every shipped section switched on, because that
is the largest bill a consumer can choose. A default-off skill is still free
for everyone who does not enable it, and the `minimal`/`general` rows are there
so a reviewer can see which of those two a change moved.

The estimate is characters ÷ 4. It is approximate on purpose: the exact count
depends on a tokenizer this script has no business depending on, and the
decisions it informs — "has the resident tier grown?", "should this move behind
a reference?" — do not turn on the third significant figure.

Usage:
    context_budget.py                    # report every tier
    context_budget.py --fail-over 5000   # non-zero exit when maximal exceeds it

Exit: 0 within budget, 1 over it (with --fail-over), 2 on a layout problem.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path
from typing import Any

FRONT_MATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
# `description` may fold across lines; the listing pays for all of it.
FIELD_RE = re.compile(r"^(name|description|when_to_use):[ \t]*(.*(?:\n[ \t]+.*)*)$", re.MULTILINE)

# Kept in step with bundle_refs_test.sh, which caps AGENTS.md on its own, and
# with `make audit`, which caps the listing on its own. This is the composite
# the two of them add up to, and the number a consumer actually pays.
DEFAULT_RESIDENT_BUDGET = 5000

# `make audit` caps the skills index at 8000 characters, but measures every
# skill in the marketplace — including the one plugin `/init` never vendors, and
# every default-off section at once. That is the right scope for a marketplace
# validator and the wrong one for "does a real install fit", so the per-install
# rows below carry the same cap against the sets a consumer actually gets.
LISTING_BUDGET_CHARS = 8000


def approx_tokens(text: str) -> int:
    return len(text) // 4


def read_or_fail(path: Path) -> str | None:
    """The file's text, or None after saying on stderr why it could not be read.

    Every input here is read for its size, so an unreadable one has no sensible
    size to stand in for it — the caller turns a None into the exit 2 this
    script already uses for a layout problem, rather than a traceback or a
    zero. `UnicodeDecodeError` is a `ValueError`, not an `OSError`, and it is
    the likelier half of the two.
    """
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"context_budget: cannot read {path}: {exc}", file=sys.stderr)
        return None


def listing_entry(text: str) -> str:
    """The frontmatter a skills index carries for one skill."""
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return ""
    return "".join(m.group(0) for m in FIELD_RE.finditer(match.group(1)))


def load_installer(root: Path) -> Any | None:
    """`init.py` as a module, or None if this tree has no installer to read.

    Imported rather than reimplemented, for the reason `sync_sections.py` gives:
    the profiles and the `section:` parser must be the ones `/init` runs, or the
    report and the install can disagree about who pays for what. A tree without
    an installer is not an error — the synthetic trees in the test suite have no
    `init.py` and still deserve a resident number — it just cannot be broken
    down by install, so the caller falls back to counting everything.
    """
    init_py = root / "plugins/core/skills/init/scripts/init.py"
    if not init_py.is_file():
        return None
    spec = importlib.util.spec_from_file_location("_arsenal_init_budget", init_py)
    if spec is None or spec.loader is None:  # pragma: no cover - packaging accident
        return None
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:  # pragma: no cover - a broken installer is init.py's own test
        print(f"context_budget: cannot import {init_py}: {exc}", file=sys.stderr)
        return None
    return module


def installs(init: Any, sections: set[str]) -> list[tuple[str, str, set[str]]]:
    """`(label, what it means, enabled sections)` for every install a consumer reaches.

    `maximal` is computed from what is actually shipped rather than taken from
    `_PROFILES["all"]`, which is built from `_SECTION_DEFAULTS` and so does not
    include a section that exists only as `section:` frontmatter. Printing both
    keeps that gap visible instead of letting the widest row quietly understate
    the widest install.
    """
    core = init._CORE_SECTION
    rows = [(name, f"--profile {name}", {core} | set(profile))
            for name, profile in init._PROFILES.items()]
    rows.append(("maximal", "every shipped section", {core} | sections))
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path())
    parser.add_argument(
        "--fail-over",
        type=int,
        default=None,
        metavar="TOKENS",
        help=f"exit 1 when the maximal install exceeds this (suggested {DEFAULT_RESIDENT_BUDGET})",
    )
    args = parser.parse_args(argv)

    skills = sorted(args.root.glob("plugins/*/skills/*/SKILL.md"))
    if not skills:
        print(f"context_budget: no skills under {args.root}/plugins/*/skills/", file=sys.stderr)
        return 2

    bodies_text: dict[Path, str] = {}
    for skill in skills:
        text = read_or_fail(skill)
        if text is None:
            return 2
        bodies_text[skill] = text

    # A missing AGENTS.md used to count as zero. It is the largest single
    # resident input — `@`-imported into the host's CLAUDE.md, so paid on every
    # turn — so scoring it as nothing made the one bundle that should certainly
    # fail the gate the one most likely to pass it: the report looked healthiest
    # at the moment it stopped measuring what it is named for. Same class of
    # fact as no skills at all, and the same exit code.
    agents_md = args.root / "plugins/core/skills/init/assets/AGENTS.md"
    agents_text = read_or_fail(agents_md)
    if agents_text is None:
        return 2
    agents_tokens = approx_tokens(agents_text)

    listings = {s: listing_entry(bodies_text[s]) for s in skills}
    entries = {s: approx_tokens(text) for s, text in listings.items()}

    init = load_installer(args.root)
    vendored: dict[Path, str] = {}
    external: list[Path] = []
    if init is not None:
        try:
            source = init._source_skills_dir().resolve()
        except OSError:  # pragma: no cover - a tree with an installer but no skills dir
            source = None
        for skill in skills:
            if source is not None and skill.parent.resolve().parent == source:
                vendored[skill] = init._skill_section(skill.parent)
            else:
                external.append(skill)

    print("RESIDENT — every turn, every session")
    print(f"  {'AGENTS.md (vendored, @-imported)':<44} {agents_tokens:>6}")

    if init is not None and vendored:
        shipped = {s for s in vendored.values() if s != init._CORE_SECTION}
        default_on = {name for name, on in init._SECTION_DEFAULTS.items() if on}
        default_install = {init._CORE_SECTION} | default_on
        rows = installs(init, shipped)
        capped = rows[-1][2]

        print("\n  skill listing, by what the consumer installed")
        print(
            f"    {'install':<10} {'sections':<26} {'skills':>6} {'listing':>8}"
            f" {'total':>7} {'chars':>7} {'index':>6}"
        )
        for label, meaning, enabled in rows:
            picked = [s for s, sec in vendored.items() if sec in enabled]
            listing = sum(entries[s] for s in picked)
            chars = sum(len(listings[s]) for s in picked)
            headroom = 100 - round(100 * chars / LISTING_BUDGET_CHARS)
            marks = []
            if enabled == default_install:
                marks.append("<- /init default")
            if label == "maximal":
                marks.append("<- capped")
            print(
                f"    {label:<10} {meaning:<26} {len(picked):>6} {listing:>8}"
                f" {agents_tokens + listing:>7} {chars:>7} {headroom:>5}%"
                f"  {' '.join(marks)}"
            )
        print(
            f"    {'':<10} {'':<26} {'':>6} {'':>8} {'':>7}"
            f" {'/' + str(LISTING_BUDGET_CHARS):>7} {'free':>6}"
        )

        listing_tokens = sum(entries[s] for s in vendored if vendored[s] in capped)
        if external:
            cost = sum(entries[s] for s in external)
            names = ", ".join(sorted(s.parent.name for s in external))
            print(
                f"\n  not vendored by /init, so resident for nobody: {names} ({cost} tokens)"
            )
    else:
        # No installer to read: every shipped skill counts, which is what this
        # reported before sections existed and what a bare tree deserves.
        listing_tokens = sum(entries.values())
        print(f"  {f'skill listing ({len(skills)} skills)':<44} {listing_tokens:>6}")

    resident = agents_tokens + listing_tokens
    print(f"\n  {'resident total (maximal install)':<44} {resident:>6}")

    print("\n  worst offenders in the listing")
    for skill, tokens in sorted(entries.items(), key=lambda e: -e[1])[:5]:
        section = vendored.get(skill)
        where = f"  [{section}]" if section else ""
        print(f"    {skill.parent.name:<42} {tokens:>6}{where}")

    bodies = sorted(((s, approx_tokens(t)) for s, t in bodies_text.items()),
                    key=lambda e: -e[1])
    print("\nON INVOCATION — one SKILL.md body, paid when that skill triggers")
    for skill, tokens in bodies[:5]:
        print(f"  {skill.parent.name:<44} {tokens:>6}")

    on_demand = []
    for path in args.root.glob("plugins/*/skills/*/**/*.md"):
        if path.name == "SKILL.md":
            continue
        text = read_or_fail(path)
        if text is None:
            return 2
        on_demand.append((path, approx_tokens(text)))
    on_demand.sort(key=lambda e: -e[1])
    total_demand = sum(t for _, t in on_demand)
    print(f"\nON DEMAND — {len(on_demand)} files, {total_demand} tokens, paid only when opened")
    for path, tokens in on_demand[:5]:
        print(f"  {path.relative_to(args.root)!s:<44} {tokens:>6}")

    if args.fail_over is not None and resident > args.fail_over:
        print(
            f"\ncontext_budget: resident tier is {resident} tokens, over the "
            f"{args.fail_over} budget.\n"
            "  Every consumer pays this on every turn before doing any work. Move what "
            "grew behind\n  a reference (paid on demand) or into a script (paid in "
            "output, not in context)\n  rather than raising the cap.",
            file=sys.stderr,
        )
        return 1
    if args.fail_over is not None:
        headroom = args.fail_over - resident
        print(f"\nWithin budget: {resident}/{args.fail_over} tokens ({headroom} headroom).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
