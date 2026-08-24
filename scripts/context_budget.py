#!/usr/bin/env python3
"""context_budget.py — what adopting this marketplace costs a consumer's context.

A skill set earns its place by making a session better at the work, and every
token it occupies is one the session cannot spend on the work itself. That
trade is only checkable if somebody states the number, so this states it.

Three tiers, because they are paid on completely different schedules:

* **Resident** — in context on every turn of every session, forever. Two things
  land here: the vendored `AGENTS.md`, which a consumer's `CLAUDE.md`
  `@`-imports, and the `name` + `description` of every shipped skill, which sit
  in the skills index whether or not a skill is ever used. This is the number
  that matters, and the only one with a hard cap.
* **On invocation** — a `SKILL.md` body, paid once when its skill triggers.
  Cheap by comparison, and only paid by the session that wanted it.
* **On demand** — `references/` and agent definitions, paid only when something
  opens them. Effectively free until read, which is the whole point of putting
  content there.

The estimate is characters ÷ 4. It is approximate on purpose: the exact count
depends on a tokenizer this script has no business depending on, and the
decisions it informs — "has the resident tier grown?", "should this move behind
a reference?" — do not turn on the third significant figure.

Usage:
    context_budget.py                    # report every tier
    context_budget.py --fail-over 5000   # non-zero exit when resident exceeds it

Exit: 0 within budget, 1 over it (with --fail-over), 2 on a layout problem.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FRONT_MATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
# `description` may fold across lines; the listing pays for all of it.
FIELD_RE = re.compile(r"^(name|description|when_to_use):[ \t]*(.*(?:\n[ \t]+.*)*)$", re.MULTILINE)

# Kept in step with bundle_refs_test.sh, which caps AGENTS.md on its own, and
# with `make audit`, which caps the listing on its own. This is the composite
# the two of them add up to, and the number a consumer actually pays.
DEFAULT_RESIDENT_BUDGET = 5000


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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path())
    parser.add_argument(
        "--fail-over",
        type=int,
        default=None,
        metavar="TOKENS",
        help=f"exit 1 when the resident tier exceeds this (suggested {DEFAULT_RESIDENT_BUDGET})",
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

    entries = [(s, approx_tokens(listing_entry(bodies_text[s]))) for s in skills]
    listing_tokens = sum(t for _, t in entries)
    resident = agents_tokens + listing_tokens

    print("RESIDENT — every turn, every session")
    print(f"  {'AGENTS.md (vendored, @-imported)':<44} {agents_tokens:>6}")
    print(f"  {f'skill listing ({len(skills)} skills)':<44} {listing_tokens:>6}")
    print(f"  {'total':<44} {resident:>6}")

    print("\n  worst offenders in the listing")
    for skill, tokens in sorted(entries, key=lambda e: -e[1])[:5]:
        print(f"    {skill.parent.name:<42} {tokens:>6}")

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
