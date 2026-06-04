#!/usr/bin/env python3
"""Rule-drift auditor.

Cross-checks the rule IDs (R-*) in the rubric references against the
research source-of-truth and the deferred-rule list. Two directions are
checked:

  - **rubric → research (always blocks):** rule absent from the research
    doc — i.e. the rubric introduced an ID the research never
    documented.
  - **research → rubric (informational by default, blocks under
    ``--strict``):** rule absent from BOTH the rubric AND the deferred
    list — i.e. the research grew a rule the rubric did not catch up
    with. Triaging is manual (add to ``skill-rules.md`` or to
    ``research-coverage.md``), so the default is warn-not-fail.

Q-* IDs (content-quality scanner IDs) are author-defined and not
expected to appear in the research doc — they are excluded entirely.

Inputs default to the layout under
``plugins/skill-creator/skills/skill-creator/`` plus
``docs/research/claude-skill-system_v1.17.md``, all resolved from the
repo root (located via ``.claude-plugin/marketplace.json``).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ID_RE = re.compile(r"\bR-[A-Z]+-?[0-9]+[A-Z]?\b")


def _extract_ids(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return set(ID_RE.findall(path.read_text(encoding="utf-8")))


def _resolve_repo_root(start: Path) -> Path:
    # Prefer the marketplace manifest (arsenal layout), but also accept a
    # `.git` or `.claude` marker so the auditor still resolves a root once
    # the skill is vendored into a host repo that has no marketplace.json.
    cur = start.resolve()
    for parent in (cur, *cur.parents):
        if (
            (parent / ".claude-plugin" / "marketplace.json").is_file()
            or (parent / ".git").exists()
            or (parent / ".claude").is_dir()
        ):
            return parent
    raise RuntimeError(
        f"could not locate repo root above {start} "
        "(expected .claude-plugin/marketplace.json, .git, or .claude in an ancestor)"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Diff rule IDs between rubric and research doc.")
    parser.add_argument(
        "--root",
        default=None,
        help="Repo root (default: auto-detect via marketplace.json).",
    )
    parser.add_argument(
        "--rubric",
        action="append",
        default=None,
        help="Rubric file(s). Defaults to skill-rules.md + content-quality-rules.md.",
    )
    parser.add_argument(
        "--research",
        default=None,
        help="Research doc (default: docs/research/claude-skill-system_v1.17.md).",
    )
    parser.add_argument(
        "--deferred",
        default=None,
        help="Deferred-IDs list (default: references/research-coverage.md).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Promote 'research IDs missing from rubric' from warn to fail.",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve() if args.root else _resolve_repo_root(Path(__file__))
    skill_refs = root / "plugins" / "skill-creator" / "skills" / "skill-creator" / "references"

    rubric_paths = (
        [Path(p) for p in args.rubric]
        if args.rubric
        else [skill_refs / "skill-rules.md", skill_refs / "content-quality-rules.md"]
    )
    research_path = (
        Path(args.research)
        if args.research
        else root / "docs" / "research" / "claude-skill-system_v1.17.md"
    )
    deferred_path = Path(args.deferred) if args.deferred else skill_refs / "research-coverage.md"

    rubric_ids: set[str] = set()
    for p in rubric_paths:
        rubric_ids |= _extract_ids(p)
    research_ids = _extract_ids(research_path)
    deferred_ids = _extract_ids(deferred_path)

    missing_in_research = sorted(rubric_ids - research_ids)
    missing_in_rubric = sorted(research_ids - rubric_ids - deferred_ids)

    if not research_ids:
        print(f"audit-rule-drift: research doc empty or missing: {research_path}", file=sys.stderr)
        return 2

    exit_code = 0
    if missing_in_research:
        print(
            "audit-rule-drift: rubric IDs absent from research doc:",
            file=sys.stderr,
        )
        for rid in missing_in_research:
            print(f"  - {rid}", file=sys.stderr)
        exit_code = 1

    if missing_in_rubric:
        severity = "FAIL" if args.strict else "warn"
        print(
            f"audit-rule-drift [{severity}]: research IDs absent from rubric AND deferred list:",
            file=sys.stderr,
        )
        for rid in missing_in_rubric:
            print(f"  - {rid}", file=sys.stderr)
        if args.strict:
            exit_code = 1

    if exit_code == 0 and not missing_in_rubric:
        print(
            f"audit-rule-drift: clean ({len(rubric_ids)} rubric, "
            f"{len(deferred_ids)} deferred, {len(research_ids)} research IDs)"
        )
    elif exit_code == 0:
        print(
            f"audit-rule-drift: rubric→research clean; "
            f"{len(missing_in_rubric)} research IDs awaiting triage."
        )
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
