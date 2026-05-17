#!/usr/bin/env python3
"""audit_library.py — library-wide audit of a skill collection.

Walks the skill library, runs validate.py per skill, and adds the
checks that need every skill at once: pairwise description-overlap,
canary-phrase uniqueness, listing-budget total, and duplicate-script
SHA drift across declared sibling sets.

Usage:
    python3 audit_library.py [<library_dir> ...] [--by-plugin]
                              [--json] [--severity warn|fail]

Pass one library_dir (default `plugins/skill-creator/skills`) for the
per-plugin report. Pass two or more — or pass `--by-plugin` against
one or more `plugins/<plugin>/skills` paths — to also emit an
aggregate listing-budget across the union of plugins (the listing
budget is a global cap; every loaded skill's description shares the
same available-skills prompt).
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import re
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from pathlib import Path

import yaml

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
import _console as console  # noqa: E402

_validate_spec = importlib.util.spec_from_file_location(
    "skill_creator_validate", _HERE / "validate.py"
)
if _validate_spec is None or _validate_spec.loader is None:
    raise RuntimeError(f"failed to locate validate.py next to {__file__}")
_validate = importlib.util.module_from_spec(_validate_spec)
sys.modules["skill_creator_validate"] = _validate
_validate_spec.loader.exec_module(_validate)


LISTING_BUDGET_CHARS = 8000
DUPLICATION_HEADER_RE = re.compile(
    r"DUPLICATED ACROSS SKILLS(?: \([^)]*\))?:\s*\n((?:\s*[-*]\s+\S.*\n)+)",
    re.IGNORECASE,
)
TOKEN_RE = re.compile(r"[a-z0-9]+")


@dataclass
class Issue:
    severity: str
    check: str
    message: str
    path: str | None = None


@dataclass
class AuditResult:
    issues: list[Issue] = field(default_factory=list)
    per_skill: dict[str, list[dict]] = field(default_factory=dict)

    def fail(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("fail", check, message, str(path) if path else None))

    def warn(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("warn", check, message, str(path) if path else None))

    def info(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("info", check, message, str(path) if path else None))


def _load_frontmatter(skill_md: Path) -> dict:
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}
    try:
        data = yaml.safe_load(text[4:end])
    except yaml.YAMLError:
        return {}
    return data if isinstance(data, dict) else {}


def _tokens(text: str) -> Counter:
    return Counter(TOKEN_RE.findall(text.lower()))


def _cosine(a: Counter, b: Counter) -> float:
    if not a or not b:
        return 0.0
    common = set(a) & set(b)
    dot = sum(a[t] * b[t] for t in common)
    na = math.sqrt(sum(v * v for v in a.values()))
    nb = math.sqrt(sum(v * v for v in b.values()))
    return dot / (na * nb) if na and nb else 0.0


def _extract_canary(skill_dir: Path) -> str | None:
    canary_file = skill_dir / "evals" / "loading_verification.json"
    if not canary_file.exists():
        return None
    try:
        data = json.loads(canary_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    canary = data.get("canary")
    return canary if isinstance(canary, str) and canary.strip() else None


def _parse_duplication_header(text: str) -> list[str]:
    m = DUPLICATION_HEADER_RE.search(text)
    if not m:
        return []
    siblings = []
    for line in m.group(1).splitlines():
        line = line.strip().lstrip("-*").strip()
        if not line:
            continue
        path = line.split(" ", 1)[0]
        if path.startswith("./"):
            path = path[2:]
        siblings.append(path)
    return siblings


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def _plugin_slug_from(library_dir: Path) -> str | None:
    """Derive the plugin slug for a library path of the form plugins/<plugin>/skills."""
    parts = library_dir.resolve().parts
    if "plugins" in parts:
        plugin_idx = parts.index("plugins")
        if plugin_idx + 1 < len(parts):
            return parts[plugin_idx + 1]
    return None


def run_per_skill(library_dir: Path, profile: str) -> dict[str, list[dict]]:
    per_skill: dict[str, list[dict]] = {}
    for skill_dir in sorted(library_dir.iterdir()):
        if not skill_dir.is_dir() or not (skill_dir / "SKILL.md").exists():
            continue
        result = _validate.Result(skill=skill_dir.name)
        fm = _validate.check_frontmatter(skill_dir, profile, result) or {}
        _validate.check_file_layout(skill_dir, fm, result)
        _, body = _validate.check_body(skill_dir, result)
        _validate.check_references(skill_dir, body, result)
        _validate.check_scripts(skill_dir, result)
        _validate.check_symlinks(skill_dir, result)
        _validate.check_evals(skill_dir, result)
        _validate.check_taxonomy(skill_dir, fm, result)
        per_skill[skill_dir.name] = [asdict(i) for i in result.issues]
    return per_skill


def check_overlap(library_dir: Path, audit: AuditResult) -> None:
    descriptions: dict[str, str] = {}
    for skill_dir in sorted(library_dir.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            continue
        fm = _load_frontmatter(skill_md)
        desc = fm.get("description")
        if isinstance(desc, str) and desc.strip():
            descriptions[skill_dir.name] = desc
    names = sorted(descriptions)
    bows = {n: _tokens(descriptions[n]) for n in names}
    for i, a in enumerate(names):
        for b in names[i + 1 :]:
            score = _cosine(bows[a], bows[b])
            if score >= 0.95:
                audit.fail(
                    "overlap.cosine",
                    f"description cosine {score:.2f} between {a!r} and {b!r}",
                )
            elif score >= 0.85:
                audit.warn(
                    "overlap.cosine",
                    f"description cosine {score:.2f} between {a!r} and {b!r}",
                )


def check_canaries(library_dir: Path, audit: AuditResult) -> None:
    canaries: dict[str, str] = {}
    seen: dict[str, str] = {}
    for skill_dir in sorted(library_dir.iterdir()):
        if not skill_dir.is_dir():
            continue
        canary = _extract_canary(skill_dir)
        if not canary:
            continue
        canaries[skill_dir.name] = canary
        if canary in seen:
            audit.fail(
                "canary.uniqueness",
                f"canary phrase shared between {seen[canary]!r} and {skill_dir.name!r}: {canary!r}",
            )
        else:
            seen[canary] = skill_dir.name


def _budget_breakdown(library_dir: Path) -> tuple[int, int]:
    """Return (chars, skill_count) for the given library."""
    total = 0
    count = 0
    for skill_dir in sorted(library_dir.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            continue
        fm = _load_frontmatter(skill_md)
        desc = fm.get("description")
        if isinstance(desc, str):
            total += len(desc) + len(skill_dir.name) + 4  # rough listing-line cost
            count += 1
    return total, count


def check_listing_budget(library_dir: Path, audit: AuditResult) -> int:
    total, _ = _budget_breakdown(library_dir)
    if total > LISTING_BUDGET_CHARS:
        audit.fail(
            "listing.budget",
            f"library descriptions total {total} chars (>{LISTING_BUDGET_CHARS} listing budget)",
        )
    elif total > int(LISTING_BUDGET_CHARS * 0.9):
        audit.warn(
            "listing.budget",
            f"library descriptions total {total} chars (within 10% of {LISTING_BUDGET_CHARS})",
        )
    return total


def check_duplicate_groups(library_dir: Path, audit: AuditResult) -> dict[str, dict]:
    siblings_by_set: dict[frozenset[str], dict[str, str]] = defaultdict(dict)
    for skill_dir in sorted(library_dir.iterdir()):
        scripts_dir = skill_dir / "scripts"
        if not scripts_dir.is_dir():
            continue
        for script in scripts_dir.rglob("*.py"):
            text = script.read_text(encoding="utf-8", errors="replace")
            siblings = _parse_duplication_header(text)
            if not siblings:
                continue
            normalised = []
            for s in siblings:
                clean = s.split(" ", 1)[0]
                if clean.startswith("./"):
                    clean = clean[2:]
                normalised.append(clean)
            key = frozenset(normalised)
            try:
                rel = script.resolve().relative_to(library_dir.parent.resolve()).as_posix()
            except ValueError:
                rel = script.as_posix()
            siblings_by_set[key][rel] = _sha256(script)
    groups = {}
    for key, members in siblings_by_set.items():
        shas = set(members.values())
        groups[",".join(sorted(key))] = {
            "members": members,
            "drift": len(shas) > 1,
        }
        if len(shas) > 1:
            audit.warn(
                "duplicates.drift",
                f"sibling group has {len(shas)} distinct SHAs across {len(members)} files",
            )
    return groups


def emit_text(audit: AuditResult, total_chars: int, groups: dict[str, dict]) -> None:
    fails = [i for i in audit.issues if i.severity == "fail"]
    warns = [i for i in audit.issues if i.severity == "warn"]
    if not audit.issues:
        console.ok("library: clean")
    else:
        console.start(f"library: {len(fails)} fail, {len(warns)} warn")
        for issue in audit.issues:
            emit = console.fail if issue.severity == "fail" else console.warn
            loc = f" [{issue.path}]" if issue.path else ""
            emit(f"{issue.check}: {issue.message}{loc}")
    console.info(f"listing-budget total: {total_chars} chars")
    if groups:
        console.info(f"duplicate-groups: {len(groups)}")
        for label, info in groups.items():
            state = "drift" if info["drift"] else "clean"
            console.info(f"  [{state}] {label}")


def emit_by_plugin(
    per_library: list[tuple[Path, AuditResult, int, dict[str, dict]]],
) -> None:
    """Print a per-plugin listing-budget breakdown."""
    print("Listing-budget breakdown (8000 char cap)", file=sys.stderr)
    width = max(
        (len(_plugin_slug_from(d) or d.name) for d, *_ in per_library),
        default=4,
    )
    grand_chars = 0
    grand_skills = 0
    for library_dir, _audit, total_chars, _groups in per_library:
        slug = _plugin_slug_from(library_dir) or library_dir.name
        _, skill_count = _budget_breakdown(library_dir)
        grand_chars += total_chars
        grand_skills += skill_count
        skill_word = "skill" if skill_count == 1 else "skills"
        print(
            f"  {slug:<{width}}  {total_chars:>6} chars  ({skill_count} {skill_word})",
            file=sys.stderr,
        )
    sep_width = max(width + 36, 32)
    print("  " + "-" * sep_width, file=sys.stderr)
    skill_word_total = "skill" if grand_skills == 1 else "skills"
    print(
        f"  {'total':<{width}}  {grand_chars:>6} chars  ({grand_skills} {skill_word_total})",
        file=sys.stderr,
    )
    remaining = LISTING_BUDGET_CHARS - grand_chars
    if remaining >= 0:
        headroom_pct = int(remaining * 100 / LISTING_BUDGET_CHARS)
        print(
            f"  {'remaining':<{width}}  {remaining:>6} chars  ({headroom_pct}% headroom)",
            file=sys.stderr,
        )
        print("", file=sys.stderr)
        print("PASS — under cap.", file=sys.stderr)
    else:
        over = -remaining
        print("", file=sys.stderr)
        print(
            f"OVER cap by {over} chars. Consider `/plugin disable <plugin>` "
            f"for tasks not needing that plugin's skills.",
            file=sys.stderr,
        )


def _audit_one(library_dir: Path, profile: str) -> tuple[AuditResult, int, dict[str, dict]]:
    audit = AuditResult()
    per_skill = run_per_skill(library_dir, profile)
    audit.per_skill = per_skill
    check_overlap(library_dir, audit)
    check_canaries(library_dir, audit)
    total_chars = check_listing_budget(library_dir, audit)
    groups = check_duplicate_groups(library_dir, audit)
    return audit, total_chars, groups


def main() -> int:
    parser = argparse.ArgumentParser(description="Library-wide audit of skill collection.")
    parser.add_argument(
        "library_dirs",
        nargs="*",
        default=["plugins/skill-creator/skills"],
        help="One or more library paths (default: plugins/skill-creator/skills). "
        "Pass multiple to emit an aggregate listing-budget.",
    )
    parser.add_argument("--profile", choices=("claude-code", "skills-api"), default="claude-code")
    parser.add_argument("--severity", choices=("warn", "fail"), default="fail")
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--by-plugin",
        action="store_true",
        help="Emit a per-plugin listing-budget breakdown across the supplied libraries.",
    )
    args = parser.parse_args()
    resolved_dirs: list[Path] = []
    for raw in args.library_dirs:
        p = Path(raw).resolve()
        if not p.is_dir():
            console.fail(f"not a directory: {p}")
            return 2
        resolved_dirs.append(p)

    blocking_severities = {"fail"}
    if args.severity == "warn":
        blocking_severities.add("warn")

    per_library: list[tuple[Path, AuditResult, int, dict[str, dict]]] = []
    for library_dir in resolved_dirs:
        per_library.append((library_dir, *_audit_one(library_dir, args.profile)))

    aggregate_chars = sum(total for _, _, total, _ in per_library)
    aggregate_block_fail = aggregate_chars > LISTING_BUDGET_CHARS and (
        len(per_library) > 1 or args.by_plugin
    )
    aggregate_block_warn = (
        not aggregate_block_fail
        and aggregate_chars > int(LISTING_BUDGET_CHARS * 0.9)
        and (len(per_library) > 1 or args.by_plugin)
    )

    if args.json:
        print(
            json.dumps(
                {
                    "libraries": [
                        {
                            "path": str(d),
                            "plugin": _plugin_slug_from(d),
                            "issues": [asdict(i) for i in a.issues],
                            "per_skill": a.per_skill,
                            "listing_budget": total,
                            "duplicate_groups": g,
                        }
                        for d, a, total, g in per_library
                    ],
                    "aggregate_listing_budget": aggregate_chars,
                    "aggregate_over_budget": aggregate_block_fail,
                    "aggregate_near_budget": aggregate_block_warn,
                }
            )
        )
    elif args.by_plugin:
        emit_by_plugin(per_library)
    else:
        for library_dir, audit, total_chars, groups in per_library:
            if len(per_library) > 1:
                console.start(f"library: {library_dir}")
            for skill_name, issues in audit.per_skill.items():
                fails = [i for i in issues if i["severity"] == "fail"]
                warns = [i for i in issues if i["severity"] == "warn"]
                if fails or warns:
                    console.start(f"{skill_name}: {len(fails)} fail, {len(warns)} warn")
                    for i in issues:
                        emit = console.fail if i["severity"] == "fail" else console.warn
                        loc = f" [{i['path']}]" if i.get("path") else ""
                        emit(f"  {i['check']}: {i['message']}{loc}")
                else:
                    console.ok(f"{skill_name}: clean")
            emit_text(audit, total_chars, groups)
        if len(per_library) > 1:
            label = "aggregate listing-budget"
            line = f"{label} (sum across {len(per_library)} libraries): {aggregate_chars} chars"
            if aggregate_block_fail:
                console.fail(f"{line} — over the {LISTING_BUDGET_CHARS}-char global cap")
            elif aggregate_block_warn:
                console.warn(f"{line} — within 10% of the {LISTING_BUDGET_CHARS}-char global cap")
            else:
                console.info(line)

    per_library_block = any(
        any(i["severity"] in blocking_severities for issues in a.per_skill.values() for i in issues)
        or any(i.severity in blocking_severities for i in a.issues)
        for _, a, _, _ in per_library
    )
    has_block = per_library_block or aggregate_block_fail
    if "warn" in blocking_severities:
        has_block = has_block or aggregate_block_warn
    return 1 if has_block else 0


if __name__ == "__main__":
    sys.exit(main())
