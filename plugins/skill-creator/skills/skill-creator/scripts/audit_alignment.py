#!/usr/bin/env python3
"""audit_alignment.py — emit per-skill semantic-review prompt blocks.

Walks one or more skill libraries and emits, for each skill, a
self-contained prompt block (ruleset + skill contents + findings
template). A Claude session reads each block, walks the rules against
the skill's current file state, and produces an alignment-state
findings report.

The script does NOT call any LLM API. It is a deterministic prompt
emitter; inference happens in the Claude session that consumes the
output.

Usage:
    python3 audit_alignment.py <library_dir> [<library_dir> ...] \\
        [--output-dir <dir>] \\
        [--input <rules.md>]

Without `--output-dir`, every skill's prompt block is concatenated to
stdout (separated by a sentinel line). With `--output-dir`, one
`<skill-name>.prompt.md` file is written per skill — easier to walk
one at a time.

Findings produced by walking these prompts append to each skill's
`findings.md` (gitignored, author-local) per the gate protocol in
`references/skill-rules.md`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from collections.abc import Iterable
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
import _console as console  # noqa: E402

DEFAULT_RULES_FILE = _HERE.parent / "references" / "skill-rules.md"
SENTINEL = "\n" + ("=" * 78) + "\n"

# File extensions to inline in the prompt block.
TEXT_SUFFIXES = {".md", ".json", ".yaml", ".yml", ".txt"}
SCRIPT_SUFFIXES = {".py", ".sh"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Emit per-skill semantic-review prompt blocks for a Claude session to walk."
    )
    parser.add_argument(
        "library",
        nargs="+",
        help="One or more skill library directories (e.g. plugins/<plugin>/skills).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="If set, write one <skill>.prompt.md per skill to this directory instead of stdout.",
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_RULES_FILE,
        help="Path to the canonical rules file (default: %(default)s).",
    )
    return parser.parse_args()


def find_skills(library_dirs: Iterable[Path]) -> list[Path]:
    """Return every <skill>/ directory containing a SKILL.md, sorted by path."""
    skills: list[Path] = []
    seen: set[Path] = set()
    for library in library_dirs:
        if not library.is_dir():
            console.warn(f"library directory not found: {library}")
            continue
        for skill_md in sorted(library.glob("*/SKILL.md")):
            skill_dir = skill_md.parent.resolve()
            if skill_dir in seen:
                continue
            seen.add(skill_dir)
            skills.append(skill_dir)
    return skills


def collect_files(skill_dir: Path) -> list[Path]:
    """Return every file in the skill folder worth inlining, sorted by path.

    Filters by extension. Skips __pycache__ and findings.md (the
    findings file is author-local; replaying it into the prompt would
    confuse the reviewer about which findings are current).
    """
    suffixes = TEXT_SUFFIXES | SCRIPT_SUFFIXES
    files: list[Path] = []
    for path in sorted(skill_dir.rglob("*")):
        if not path.is_file():
            continue
        if "__pycache__" in path.parts:
            continue
        if path.name == "findings.md":
            continue
        if path.suffix.lower() not in suffixes:
            continue
        files.append(path)
    return files


def fence_for(path: Path) -> str:
    """Pick a fenced-code language tag for `path`."""
    suffix = path.suffix.lower()
    if suffix in {".py"}:
        return "python"
    if suffix in {".sh"}:
        return "bash"
    if suffix in {".json"}:
        return "json"
    if suffix in {".yaml", ".yml"}:
        return "yaml"
    return ""


def render_prompt(skill_dir: Path, repo_root: Path, rules_text: str, files: list[Path]) -> str:
    try:
        rel_skill = skill_dir.relative_to(repo_root)
    except ValueError:
        rel_skill = skill_dir
    today = dt.date.today().isoformat()
    lines: list[str] = []
    lines.append(f"# Semantic review prompt — {skill_dir.name}")
    lines.append("")
    lines.append(f"- Skill: `{rel_skill}/`")
    lines.append(f"- Generated: {today}")
    lines.append("")
    lines.append("## Instructions")
    lines.append("")
    lines.append(
        "Walk every rule in the ruleset below against the **current state** of every "
        "file in this skill folder. For each file that violates one or more rules, "
        "emit a finding entry using the template at the bottom of this prompt. "
        "Files with no violations do not appear. A fully clean skill writes a single "
        "line: `## " + today + " — all files aligned with guidelines`."
    )
    lines.append("")
    lines.append(
        "Append the resulting block to the skill's `findings.md` (create it if it "
        "does not exist). `findings.md` is gitignored — local to the author."
    )
    lines.append("")
    lines.append("## Ruleset")
    lines.append("")
    lines.append(rules_text.rstrip())
    lines.append("")
    lines.append("## Skill contents")
    lines.append("")
    for path in files:
        rel_path = path.relative_to(skill_dir)
        lang = fence_for(path)
        lines.append(f"### `{rel_path}`")
        lines.append("")
        try:
            body = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            lines.append("_(binary or non-UTF-8 file — not inlined)_")
            lines.append("")
            continue
        lines.append(f"```{lang}")
        lines.append(body.rstrip("\n"))
        lines.append("```")
        lines.append("")
    lines.append("## Findings template")
    lines.append("")
    lines.append("```")
    lines.append(f"## {today}")
    lines.append("")
    lines.append("<relative_file_path> is not aligned with the guidelines:")
    lines.append("  must   line N   <one-line statement>  (<rule-id>)")
    lines.append("  should line M   <one-line statement>  (<rule-id>)")
    lines.append("")
    lines.append("(other files in this skill are aligned)")
    lines.append("```")
    lines.append("")
    lines.append(
        "If no file has any finding, write only the dated header followed by "
        "`— all files aligned with guidelines`."
    )
    lines.append("")
    return "\n".join(lines)


def _prompt_filename(skill_dir: Path, namespaced: bool) -> str:
    """Return the prompt-block filename for `skill_dir`.

    When `namespaced` (basename collides across libraries), prefix the
    filename with a library tag derived from the path — the plugin slug
    from `plugins/<plugin>/skills/<name>/`, or `local` for skills under
    `.claude/skills/` outside any plugin.
    """
    if not namespaced:
        return f"{skill_dir.name}.prompt.md"
    parts = skill_dir.parts
    if "plugins" in parts:
        plugin_idx = parts.index("plugins")
        if plugin_idx + 1 < len(parts):
            library_tag = parts[plugin_idx + 1]
            return f"{library_tag}--{skill_dir.name}.prompt.md"
    return f"local--{skill_dir.name}.prompt.md"


def repo_root_from(skill_dirs: list[Path]) -> Path:
    """Best-effort repo root: walk up until we see a `.git/` or hit filesystem root."""
    if not skill_dirs:
        return Path.cwd()
    p = skill_dirs[0]
    for parent in [p, *p.parents]:
        if (parent / ".git").exists():
            return parent
    return Path.cwd()


def main() -> int:
    args = parse_args()
    rules_path: Path = args.input
    if not rules_path.is_file():
        console.fail(f"rules file not found: {rules_path}")
        return 2
    rules_text = rules_path.read_text(encoding="utf-8")

    library_dirs = [Path(d).resolve() for d in args.library]
    skills = find_skills(library_dirs)
    if not skills:
        console.warn("no skills found under the given libraries")
        return 1

    repo_root = repo_root_from(skills)
    output_dir: Path | None = args.output_dir
    if output_dir is not None:
        output_dir.mkdir(parents=True, exist_ok=True)

    console.start(f"emitting {len(skills)} prompt block(s) from {rules_path.name}")

    # Detect basename collisions across libraries so we can namespace the
    # output filename per skill (two `example` skills land as
    # `<plugin-a>--example.prompt.md` and `<plugin-b>--example.prompt.md`
    # instead of silently overwriting one another).
    basenames: dict[str, int] = {}
    for skill_dir in skills:
        basenames[skill_dir.name] = basenames.get(skill_dir.name, 0) + 1
    collisions = {name for name, count in basenames.items() if count > 1}

    for skill_dir in skills:
        files = collect_files(skill_dir)
        prompt = render_prompt(skill_dir, repo_root, rules_text, files)
        if output_dir is None:
            sys.stdout.write(prompt)
            sys.stdout.write(SENTINEL)
        else:
            filename = _prompt_filename(skill_dir, skill_dir.name in collisions)
            dest = output_dir / filename
            dest.write_text(prompt, encoding="utf-8")
            try:
                display = dest.relative_to(Path.cwd())
            except ValueError:
                display = dest
            console.ok(f"wrote {display}")

    if output_dir is None:
        sys.stdout.flush()
    console.ok(f"done — {len(skills)} skill(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
