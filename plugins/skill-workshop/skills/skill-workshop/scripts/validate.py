#!/usr/bin/env python3
"""validate.py — mechanical validator for a single Claude Code skill.

Usage:
    python3 validate.py <skill_dir> [--profile claude-code|skills-api]
                                    [--severity warn|fail] [--json]

Exits 0 when all blocking checks pass, 1 on failures, 2 on internal
error. Pass `--severity warn` to treat warnings as blocking too.
Library-wide checks (description-overlap, canary uniqueness,
listing-budget, duplicate-group drift) live in audit_library.py.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

import yaml

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
import _console as console  # noqa: E402

FRONTMATTER_KEYS = {
    "skills-api": {"name", "description", "license", "allowed-tools", "metadata"},
    "claude-code": {
        "name",
        "description",
        "when_to_use",
        "argument-hint",
        "arguments",
        "disable-model-invocation",
        "user-invocable",
        "allowed-tools",
        "model",
        "effort",
        "context",
        "agent",
        "hooks",
        "paths",
        "shell",
        "license",
        "metadata",
        "version",
    },
}

NAME_REGEX = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
TRIGGER_REGEX = re.compile(
    r"\b(When the user|Triggered by|whenever)\b",
    re.IGNORECASE,
)
NEGATIVE_TRIGGERS = ("Do NOT", "do not", "Avoid", "avoid ", "not for", "except for")
SECOND_PERSON_REGEX = re.compile(
    r"(?<![\w'])(you|your|yours|you're|you've|you'll)\b", re.IGNORECASE
)
WINDOWS_BACKSLASH_REGEX = re.compile(r"[\\][^\s\\]{1,80}\.(md|py|sh|json|yaml|yml)\b")
HOME_PATH_REGEX = re.compile(
    r"(~/\.claude/|/home/\w+/\.claude/|/Users/\w+/\.claude/|/root/\.claude/)"
)
SCRIPT_PATH_REGEX = re.compile(r"(?<![\w/.\-])([\w][\w./-]+\.(?:py|sh))(?!\w)")
CONTAINER_PATH_PREFIXES = (
    "/app/",
    "/tmp/",
    "/usr/",
    "/bin/",
    "/var/",
    "/etc/",
    "/root/",
    "/srv/",
    "/opt/",
    "/proc/",
)
SCRIPT_PATH_PLACEHOLDER_CHARS = set("<>${}*?…")
SECRET_REGEXES = [
    re.compile(r"sk-ant-api03-[A-Za-z0-9_-]{40,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"ghp_[A-Za-z0-9]{30,}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(r"-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----"),
]
PROGRAMMATIC_SKILL_CALL_REGEX = re.compile(r"\bSkill\s*\([\"'`]")
AT_IMPORT_REGEX = re.compile(r"(^|\s)@[A-Za-z0-9_./-]+\.md\b", re.MULTILINE)
RULE_ID_REGEX = re.compile(r"\b[QR]-[A-Z]+-\d+\b")
# Q-EVER-2: catch GitHub-style PR refs (#1234) and project-ticket prefixes
# (ABC-123, JIRA-4567, PROJ-12, etc.) — anywhere from 2 to 6 uppercase chars
# followed by 2+ digits, matching the conventional shape across trackers.
PR_BRANCH_REGEX = re.compile(r"(?:(?<!\]\()(?<!\w)#\d+|(?<![A-Z])[A-Z]{2,6}-\d{2,})")
HARDCODED_DATE_REGEX = re.compile(r"\b20\d{2}-\d{2}-\d{2}\b")
CANARY_LINE_REGEX = re.compile(r"^CANARY:.*$", re.MULTILINE)
# Built via chr() instead of a literal "../" so the AST self-scan on
# line 776 does not see this file's own check string as a finding.
_DOTDOT_SLASH = chr(46) + chr(46) + chr(47)


def _string_has_double_parent_traversal(value: str) -> bool:
    """True when a string literal contains two consecutive ../ traversals."""
    return (_DOTDOT_SLASH + _DOTDOT_SLASH) in value


KEBAB_CASE_REGEX = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
FORBIDDEN_BASENAMES = {"README.md", "Readme.md", "readme.md", "AGENTS.md"}
REFERENCE_FM_WHITELIST = {"title", "summary", "load_when"}
INLINE_CODE_REGEX = re.compile(r"`([^`\n]+)`")
PARENT_TRAVERSAL_IN_CODE_REGEX = re.compile(r"(?<!\.)\.\./[\w]")

CANONICAL_ARGS = {
    # Core I/O
    "--output",
    "--output-dir",
    "--input",
    "--input-dir",
    # Generic identifiers
    "--name",
    "--id",
    "--tag",
    "--label",
    # Iteration / limits
    "--all",
    "--all-pages",
    "--limit",
    "--page",
    # Time windows (relative + absolute)
    "--since",
    "--days",
    "--date",
    "--date-from",
    "--date-to",
    "--start",
    "--end",
    # Action gating
    "--list-only",
    "--dry-run",
    "--force",
    # Output / verbosity
    "--json",
    "--format",
    "--summary",
    "--verbose",
    "--quiet",
    "--debug",
    "--help",
    # Selectors
    "--include-pending",
    "--filter",
    "--query",
    "--search",
    "--field",
    "--contains",
    # Meta-skill self-flags
    "--profile",
    "--severity",
    "--check",
    "--apply",
    "--canonical",
    "--library",
    "--root",
    "--by-plugin",
    # audit_rule_drift flags
    "--rubric",
    "--research",
    "--deferred",
    "--strict",
    # init_skill consumer flag
    "--plugin",
    # github skill flags
    "--pr",
    "--repo",
    "--watch-bots",
    "--min-quiet-seconds",
    "--unresolved-only",
    "--write-claude-md",
    "--claude-md",
    # session-end skill flags
    "--project",
    # init skill flags — what a bundle install is pointed at
    "--spec",
    "--plan",
    "--bundle-dir",
    # queue flags — the fields a task carries
    "--workspace",
    "--tasks-dir",
    "--title",
    "--size",
    "--priority",
    "--deps",
    "--requires",
    "--max-attempts",
    # mutmut-report flags — where the mutation run lives
    "--venv",
    "--module",
    # github skill: a PR body is not a --name
    "--body",
    # meta-skill self-flag
    "--listing-budget",
    # init skill: which sections of the bundle a repo installs
    "--section",
    "--sections",
    "--list-sections",
    "--allow-downgrade",
    # har skill — what a capture is read *for*. These are the nouns of a HAR
    # (entries, headers, cookies, redirects, websockets) and the ways one is
    # reduced to an answer; none has a canonical equivalent to defer to, and
    # forcing them into `--filter`/`--query` would say less, not more.
    "--index",
    "--no-index",
    "--verify-offsets",
    "--stats",
    "--errors",
    "--endpoints",
    "--headers",
    "--cookies",
    "--redirects",
    "--slowest",
    "--largest",
    "--websockets",
    "--show",
    "--fields",
    "--schema",
    "--json-path",
    "--css",
    "--xpath",
    "--extract-body",
    "--max-body",
    "--secrets",
    "--keep-bodies",
    "--drop-types",
    "--against",
    "--size-tolerance",
}
FORBIDDEN_ARG_SYNONYMS = {
    "--out": "--output",
    "--out-path": "--output",
    "--output-folder": "--output-dir",
    "--output-file": "--output",
    "--in": "--input",
    "--in-path": "--input",
    "--input-folder": "--input-dir",
}
ALLOWED_SCRIPT_VERBS = {
    "fetch",
    "query",
    "analyze",
    "create",
    "validate",
    "compare",
    "sync",
    "init",
    "audit",
    "run",
}


@dataclass
class Issue:
    severity: str  # "fail" | "warn"
    check: str
    message: str
    path: str | None = None


@dataclass
class Result:
    skill: str
    issues: list[Issue] = field(default_factory=list)

    def fail(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("fail", check, message, str(path) if path else None))

    def warn(self, check: str, message: str, path: Path | None = None) -> None:
        self.issues.append(Issue("warn", check, message, str(path) if path else None))


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


# Up to three leading spaces still opens a fence; four or more makes it an
# indented code block, where the backticks are literal content (CommonMark 4.5).
FENCE_OPEN_REGEX = re.compile(r"^( {0,3})(`{3,}|~{3,})(.*)$")


def untagged_fences(text: str) -> list[int]:
    """1-indexed lines of fenced blocks opened without a language tag.

    A closing fence is a marker of the same character, at least as long as the
    one that opened the block, carrying no info string — so a ```` ```` ````
    wrapper around a ```` ``` ```` example closes correctly instead of reading
    as a second untagged block. Counting bare `startswith("```")` gets that
    case backwards and reports the wrapper's closing line as a violation.

    Untagged is a `should`, not a `must`: markdown renders either way. It costs
    syntax highlighting where the block is code, and it is what `markdownlint`
    MD040 reports, so a reviewer sees it whether or not this does.

    Takes the whole file rather than the post-frontmatter body on purpose. Line
    numbers are the entire value of this warning — a reader opens the file at
    the number it prints — and counting from the body reports every line short
    by the height of the frontmatter, which is a wrong answer delivered
    confidently.
    """
    stack: list[str] = []
    untagged: list[int] = []
    for i, line in enumerate(text.splitlines(), 1):
        m = FENCE_OPEN_REGEX.match(line)
        if not m:
            continue
        marker, info = m.group(2), m.group(3).strip()
        if stack and marker[0] == stack[-1][0] and len(marker) >= len(stack[-1]) and not info:
            stack.pop()
            continue
        stack.append(marker)
        if not info:
            untagged.append(i)
    return untagged


def _strip_fences(text: str) -> str:
    """The text with fenced blocks removed, for checks that must ignore code.

    Deliberately cruder than `untagged_fences`: it toggles on any line starting
    with a fence marker, which is right for "is this prose or code" and wrong
    for "where does this block open". A ```` wrapper around a ``` example
    toggles this four times and still ends balanced, so the stripping is
    correct even though the individual toggles are not.
    """
    out, in_fence = [], False
    fence_re = re.compile(r"^(```|~~~)")
    for line in text.splitlines():
        if fence_re.match(line.strip()):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


def _strip_inline_code(text: str) -> str:
    """Drop inline backtick spans so doc-example paths don't trigger checks."""
    text = re.sub(r"`[^`\n]*`", "", text)  # single-line spans
    text = re.sub(r"`[^`]*`", "", text, flags=re.DOTALL)  # multi-line spans
    return text


def _strip_all_code(text: str) -> str:
    """The text with both fenced blocks and inline-code spans removed."""
    return _strip_inline_code(_strip_fences(text))


def _split_frontmatter(text: str) -> tuple[dict | None, str]:
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    fm_block = text[4:end]
    body = text[end + 5 :]
    try:
        data = yaml.safe_load(fm_block)
    except yaml.YAMLError:
        return None, body
    return data if isinstance(data, dict) else None, body


def _find_repo_root(start: Path) -> Path | None:
    for d in (start, *start.parents):
        if (d / ".git").exists():
            return d
    return None


def _check_script_paths(
    text: str,
    source: Path,
    repo_root: Path | None,
    result: Result,
    check_prefix: str,
) -> None:
    """Flag script paths (.py / .sh) mentioned in `text` that do not resolve.

    Resolution is repo-root-relative. Skips placeholder strings (`<name>`,
    `${VAR}`, …) and container paths (`/app/...`, `/tmp/...`, etc).
    """
    if repo_root is None:
        return
    seen: set[str] = set()
    for match in SCRIPT_PATH_REGEX.finditer(text):
        candidate = match.group(1)
        if candidate in seen:
            continue
        seen.add(candidate)
        if "/" not in candidate:
            continue
        if any(ch in candidate for ch in SCRIPT_PATH_PLACEHOLDER_CHARS):
            continue
        if candidate.startswith(CONTAINER_PATH_PREFIXES):
            continue
        candidates_to_try: list[Path]
        if candidate.startswith("/"):
            candidates_to_try = [Path(candidate)]
        else:
            candidates_to_try = [repo_root / candidate]
        if any(p.exists() for p in candidates_to_try):
            continue
        result.fail(
            f"{check_prefix}.missing-script",
            f"references script path that does not exist on disk: {candidate}",
            source,
        )


SECTION_REF_REGEX = re.compile(r"`([^`\s]+)`\s*§\s*([^.\n`,;)]+?)\s*(?=[.\n`,;)]|$)", re.MULTILINE)
HEADER_REGEX = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.MULTILINE)


def _normalise_header(text: str) -> str:
    r"""Lowercase + drop backticks, underscores, and runs of whitespace.

    Lets a citation `§ between alpha and beta` match a header
    `## Between \`alpha\` and \`beta\``.
    """
    s = text.casefold().replace("`", "").replace("_", "")
    return re.sub(r"\s+", " ", s).strip()


def _resolve_section_target(
    cited: str, source: Path, skill_dir: Path, repo_root: Path | None
) -> list[Path]:
    """Return candidate .md files where `cited` should resolve, in priority order."""
    candidates: list[Path] = []
    # Plugin-namespaced skill: `<plugin>:<skill>` → plugins/<plugin>/skills/<skill>/
    if ":" in cited and "/" not in cited and repo_root is not None:
        plugin_name, _, skill_name = cited.partition(":")
        plugin_dir = repo_root / "plugins" / plugin_name / "skills" / skill_name
        if plugin_dir.is_dir():
            candidates.append(plugin_dir / "SKILL.md")
            refs = plugin_dir / "references"
            if refs.is_dir():
                candidates.extend(sorted(refs.rglob("*.md")))
        return candidates
    # `references/<file>.md` relative to the current skill
    if cited.startswith("references/") and cited.endswith(".md"):
        candidates.append(skill_dir / cited)
        return candidates
    # Bare `<file>.md` — try the source's own dir, then the skill's references/
    if cited.endswith(".md") and "/" not in cited:
        candidates.append(source.parent / cited)
        candidates.append(skill_dir / "references" / cited)
        return candidates
    return candidates


def _check_section_anchors(
    text: str,
    source: Path,
    skill_dir: Path,
    repo_root: Path | None,
    result: Result,
    check_prefix: str,
) -> None:
    """Verify each `<thing> § <section text>` resolves to a matching header.

    The `<thing>` token (inside the backticks immediately before §) names
    the cited target — a plugin-namespaced skill, a references/ file, or
    a bare .md filename. The `<section text>` is matched as a
    case-insensitive substring against headers in the resolved files.
    Unresolved targets are skipped silently; only resolved-but-no-match
    cases fail (those are the rot-prone citations).
    """
    seen: set[tuple[str, str]] = set()
    for match in SECTION_REF_REGEX.finditer(text):
        cited = match.group(1).strip()
        section_text = match.group(2).strip()
        if not section_text or (cited, section_text) in seen:
            continue
        seen.add((cited, section_text))
        targets = _resolve_section_target(cited, source, skill_dir, repo_root)
        if not targets:
            continue
        needle = _normalise_header(section_text)
        # Strip a leading "step " so "§ Step 1a.1" still matches a header
        # like "1a.1 Workspace …" while we migrate numeric citations away.
        needle_alt = re.sub(r"^step\s+", "", needle).strip()
        matched = False
        for target in targets:
            if not target.exists():
                continue
            try:
                body = target.read_text(encoding="utf-8")
            except OSError:
                continue
            for header_match in HEADER_REGEX.finditer(body):
                header_norm = _normalise_header(header_match.group(1))
                if needle in header_norm or (needle_alt and needle_alt in header_norm):
                    matched = True
                    break
            if matched:
                break
        if not matched:
            result.fail(
                f"{check_prefix}.section-anchor",
                (
                    f"cites `{cited}` § '{section_text}' but no matching "
                    "header found in the cited file(s)"
                ),
                source,
            )


def check_frontmatter(skill_dir: Path, profile: str, result: Result) -> dict | None:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        result.fail("file.skill-md", "SKILL.md not found in skill folder", skill_md)
        return None
    try:
        text = _read_text(skill_md)
    except UnicodeDecodeError:
        result.fail("file.utf-8", "SKILL.md is not valid UTF-8", skill_md)
        return None
    fm, _ = _split_frontmatter(text)
    if fm is None:
        result.fail("frontmatter.shape", "SKILL.md missing or invalid YAML frontmatter", skill_md)
        return None
    name = fm.get("name", "")
    description = fm.get("description", "")
    if not isinstance(name, str) or not name.strip():
        result.fail("frontmatter.name", "frontmatter.name missing or empty", skill_md)
    elif (
        not NAME_REGEX.match(name)
        or len(name) > 64
        or "anthropic" in name.lower()
        or "claude" in name.lower()
    ):
        result.fail(
            "frontmatter.name",
            f"frontmatter.name must match {NAME_REGEX.pattern}, ≤64 chars, "
            f"and not contain 'anthropic' or 'claude' (got {name!r})",
            skill_md,
        )
    if not isinstance(description, str) or not description.strip():
        result.fail("frontmatter.description", "frontmatter.description missing or empty", skill_md)
    elif len(description) > 1024:
        result.fail(
            "frontmatter.description",
            f"frontmatter.description is {len(description)} chars (>1024)",
            skill_md,
        )
    when_to_use = fm.get("when_to_use")
    if isinstance(when_to_use, str) and isinstance(description, str):
        combined = len(description) + len(when_to_use)
        if combined > 1536:
            result.fail(
                "frontmatter.description",
                f"description + when_to_use is {combined} chars (>1536)",
                skill_md,
            )
    if isinstance(name, str) and "/" in name:
        result.fail("frontmatter.name", "frontmatter.name must not contain '/'", skill_md)
    for k, v in fm.items():
        if isinstance(v, str) and ("<" in v or ">" in v):
            result.fail(
                "frontmatter.html-safe",
                f"frontmatter.{k} contains '<' or '>'",
                skill_md,
            )
    allowed = FRONTMATTER_KEYS.get(profile, FRONTMATTER_KEYS["claude-code"])
    extra = set(fm.keys()) - allowed
    if extra:
        result.fail(
            "frontmatter.allow-list",
            f"frontmatter contains keys outside the {profile} allow-list: {sorted(extra)}",
            skill_md,
        )
    if isinstance(description, str) and not TRIGGER_REGEX.search(description):
        result.fail(
            "description.trigger",
            "description has no trigger phrase ('When the user', 'Triggered by', 'whenever')",
            skill_md,
        )
    if isinstance(description, str) and not any(
        p.lower() in description.lower() for p in NEGATIVE_TRIGGERS
    ):
        result.warn(
            "description.negative-trigger",
            "description has no negative trigger ('Do NOT', 'Avoid', 'not for', 'except for')",
            skill_md,
        )
    return fm


def check_file_layout(skill_dir: Path, fm: dict, result: Result) -> None:
    folder_name = skill_dir.name
    if not KEBAB_CASE_REGEX.match(folder_name):
        result.fail(
            "folder.kebab-case", f"folder name {folder_name!r} is not kebab-case", skill_dir
        )
    fm_name = fm.get("name", "") if fm else ""
    if fm_name and fm_name != folder_name:
        result.fail(
            "folder.matches-name",
            f"folder name {folder_name!r} != frontmatter.name {fm_name!r}",
            skill_dir,
        )
    skill_md = skill_dir / "SKILL.md"
    if skill_md.exists() and not (skill_dir / "SKILL.md").is_file():
        result.fail("file.skill-md", "SKILL.md is not a regular file", skill_md)
    for entry in skill_dir.iterdir():
        if entry.name in FORBIDDEN_BASENAMES:
            result.fail(
                "file.forbidden",
                f"forbidden file inside skill folder: {entry.name}",
                entry,
            )
    case_variants = [p.name for p in skill_dir.iterdir() if p.name.lower() == "skill.md"]
    if case_variants and case_variants != ["SKILL.md"]:
        result.fail(
            "file.skill-md",
            f"SKILL.md must be exactly 'SKILL.md' (case-sensitive); found {case_variants}",
            skill_dir,
        )


def check_body(skill_dir: Path, result: Result) -> tuple[str, str]:
    """Check the SKILL.md body — length, fences, voice, forbidden content.

    Returns `(text, body)`: the whole file and the part after the frontmatter.
    Callers want both, and which one a check needs is not incidental — line
    numbers reported to a reader must count from the file, while content checks
    that would trip over frontmatter keys read the body.
    """
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return "", ""
    text = _read_text(skill_md)
    _, body = _split_frontmatter(text)
    line_count = body.count("\n") + (0 if body.endswith("\n") else 1)
    if line_count > 500:
        result.fail("body.length", f"SKILL.md body is {line_count} lines (>500)", skill_md)
    elif line_count > 400:
        result.warn("body.length", f"SKILL.md body is {line_count} lines (>400)", skill_md)
    fence_count = sum(1 for line in body.splitlines() if line.strip().startswith(("```", "~~~")))
    if fence_count % 2 != 0:
        result.fail("body.fences", "unbalanced fenced code blocks in SKILL.md body", skill_md)
    for line_no in untagged_fences(text):
        result.warn(
            "body.fence-language",
            f"line {line_no}: fenced block opened without a language tag (MD040)",
            skill_md,
        )
    body_no_code = _strip_all_code(body)
    if WINDOWS_BACKSLASH_REGEX.search(body_no_code):
        result.fail("body.windows-paths", "body contains Windows-style backslash path", skill_md)
    if HOME_PATH_REGEX.search(body_no_code):
        result.fail(
            "body.home-path",
            (
                "body contains machine-specific home `.claude` path "
                "(/home/X/.claude/, /Users/X/.claude/, ~/.claude/) — use a "
                "repo-relative path or a $(git rev-parse --show-toplevel) snippet"
            ),
            skill_md,
        )
    for rx in SECRET_REGEXES:
        if rx.search(body):
            result.fail("body.secrets", f"body matches secret regex {rx.pattern!r}", skill_md)
    if PROGRAMMATIC_SKILL_CALL_REGEX.search(body):
        result.fail(
            "body.skill-call",
            "body contains a programmatic skill-call construct (e.g. literal Skill(...))",
            skill_md,
        )
    if AT_IMPORT_REGEX.search(_strip_all_code(body)):
        result.warn(
            "body.at-import",
            "body contains @-import directive (skill layer should not use @-import; "
            "use markdown links into references/ instead)",
            skill_md,
        )
    if SECOND_PERSON_REGEX.search(_strip_all_code(body)):
        result.fail(
            "body.voice",
            "body uses second-person voice (you/your); prefer imperative ('Run …', 'Open …')",
            skill_md,
        )
    _check_inline_parent_traversal(body, skill_md, result, "body")
    _check_skill_dir_var(skill_dir, body, result)
    repo_root = _find_repo_root(skill_dir)
    _check_script_paths(body, skill_md, repo_root, result, "body")
    _check_section_anchors(body, skill_md, skill_dir, repo_root, result, "body")
    return text, body


def _scan_content_quality(prose: str, source: Path, result: Result) -> None:
    """Run the three evergreen-doc-style detectors lifted from content-quality-rules.md.

    Operates on code-stripped, canary-stripped prose. Flags only the first
    occurrence of each token so a single drift does not produce a wall of
    duplicate warnings.
    """
    prose = CANARY_LINE_REGEX.sub("", prose)
    seen_rule_ids: set[str] = set()
    for m in RULE_ID_REGEX.finditer(prose):
        token = m.group(0)
        if token in seen_rule_ids:
            continue
        seen_rule_ids.add(token)
        result.warn(
            "content.rule-id-in-prose",
            f"rule-ID {token!r} in body prose; IDs are rubric vocabulary (Q-EVER-1)",
            source,
        )
    seen_pr: set[str] = set()
    for m in PR_BRANCH_REGEX.finditer(prose):
        token = m.group(0)
        if token in seen_pr:
            continue
        seen_pr.add(token)
        result.warn(
            "content.pr-number-in-prose",
            f"PR / branch reference {token!r} in body prose; rots quickly (Q-EVER-2)",
            source,
        )
    seen_dates: set[str] = set()
    for m in HARDCODED_DATE_REGEX.finditer(prose):
        token = m.group(0)
        if token in seen_dates:
            continue
        seen_dates.add(token)
        result.warn(
            "content.hard-coded-date",
            f"hard-coded date {token!r} in body prose; dated callouts rot (Q-EVER-4)",
            source,
        )


def check_content_quality(skill_dir: Path, body: str, result: Result) -> None:
    """Lift the mechanical detectors of content-quality-rules.md onto SKILL.md + references.

    Skips the skill-workshop skill itself — that skill owns the rubrics, so
    rule IDs / PR examples / dated findings-format examples there are
    content, not rot.
    """
    if skill_dir.name == "skill-workshop":
        return
    skill_md = skill_dir / "SKILL.md"
    if skill_md.exists():
        _scan_content_quality(_strip_all_code(body), skill_md, result)
    refs_dir = skill_dir / "references"
    if not refs_dir.is_dir():
        return
    for ref in sorted(refs_dir.rglob("*.md")):
        text = _read_text(ref)
        _, ref_body = _split_frontmatter(text) if text.startswith("---\n") else (None, text)
        _scan_content_quality(_strip_all_code(ref_body), ref, result)


def _check_inline_parent_traversal(
    text: str, source: Path, result: Result, check_prefix: str
) -> None:
    """R-REFLOC-1 (mechanical surrogate): warn on `..` paths inside inline-code spans.

    Demoted to warn: the mechanical check cannot distinguish a skill-internal
    navigation attempt (the actual rule violation) from documentation of an
    external `..` pattern (docker volume, git worktree, .gitignore glob). The
    semantic walk owns the must-tier disposition.
    """
    seen: set[str] = set()
    for match in INLINE_CODE_REGEX.finditer(text):
        snippet = match.group(1)
        if snippet in seen:
            continue
        if PARENT_TRAVERSAL_IN_CODE_REGEX.search(snippet):
            seen.add(snippet)
            result.warn(
                f"{check_prefix}.parent-traversal-code",
                f"inline code contains parent-traversal path: {snippet!r}",
                source,
            )


def _check_skill_dir_var(skill_dir: Path, body: str, result: Result) -> None:
    """R-SHARE-4: project-scope skills cite bundled scripts via ${CLAUDE_SKILL_DIR}/."""
    skill_path = str(skill_dir)
    if "plugins/" in skill_path or "/plugins/" in skill_path:
        return  # plugin-scope: ${CLAUDE_PLUGIN_ROOT} territory, not this rule
    if "/.claude/skills/" not in skill_path:
        return  # cannot infer scope
    self_prefix = f".claude/skills/{skill_dir.name}/"
    if self_prefix in body:
        result.fail(
            "body.skill-dir-var",
            f"hardcoded self-path '{self_prefix}' in SKILL.md body; "
            f"use '${{CLAUDE_SKILL_DIR}}/' instead",
            skill_dir / "SKILL.md",
        )


REFERENCE_MENTION_REGEX = re.compile(r"references/([\w./-]+\.md)")
CROSS_SKILL_REF_CITE_REGEX = re.compile(r"`[^`\n]*§\s*(references/[\w./-]+\.md)[^`\n]*`")


def check_references(skill_dir: Path, body: str, result: Result) -> None:
    """Check every `references/*.md`: linkage, one-hop reach, TOC, and fences.

    `body` is the SKILL.md body, needed to tell a cited reference from an
    orphaned one.
    """
    skill_md = skill_dir / "SKILL.md"
    refs_dir = skill_dir / "references"
    cross_skill_ranges = [(m.start(1), m.end(1)) for m in CROSS_SKILL_REF_CITE_REGEX.finditer(body)]
    reported: set[str] = set()
    for match in REFERENCE_MENTION_REGEX.finditer(body):
        if any(
            cs_start <= match.start() and match.end() <= cs_end
            for cs_start, cs_end in cross_skill_ranges
        ):
            continue
        rel = match.group(1)
        if rel in reported:
            continue
        target = refs_dir / rel
        if not target.exists():
            result.fail(
                "references.dangling",
                f"SKILL.md mentions 'references/{rel}' but the file does not exist",
                skill_md,
            )
            reported.add(rel)
    if not refs_dir.is_dir():
        return
    ref_files = sorted(refs_dir.rglob("*.md"))
    for ref in ref_files:
        text = _read_text(ref)
        ref_fm, body_text = _split_frontmatter(text) if text.startswith("---\n") else (None, text)
        if isinstance(ref_fm, dict):
            extra_keys = set(ref_fm.keys()) - REFERENCE_FM_WHITELIST
            if extra_keys:
                result.warn(
                    "references.frontmatter",
                    (
                        "reference frontmatter keys outside whitelist "
                        f"{sorted(REFERENCE_FM_WHITELIST)}: {sorted(extra_keys)}"
                    ),
                    ref,
                )
        nonblank = [ln for ln in body_text.splitlines() if ln.strip()]
        if len(nonblank) > 100:
            head = "\n".join(body_text.splitlines()[:50])
            if not re.search(
                r"^##\s+(Contents|Table of Contents)\s*$", head, re.MULTILINE | re.IGNORECASE
            ):
                result.fail(
                    "references.toc",
                    "reference >100 lines without '## Contents' in first 50 lines",
                    ref,
                )
        fence_count = sum(
            1 for ln in body_text.splitlines() if ln.strip().startswith(("```", "~~~"))
        )
        if fence_count % 2 != 0:
            result.fail("references.fences", "unbalanced fenced code blocks", ref)
        for line_no in untagged_fences(text):
            result.warn(
                "references.fence-language",
                f"line {line_no}: fenced block opened without a language tag (MD040)",
                ref,
            )
        text_no_code = _strip_all_code(body_text)
        if WINDOWS_BACKSLASH_REGEX.search(text_no_code):
            result.fail(
                "references.windows-paths", "reference contains Windows-style backslash path", ref
            )
        if HOME_PATH_REGEX.search(text_no_code):
            result.fail(
                "references.home-path",
                (
                    "reference contains machine-specific home `.claude` path "
                    "(/home/X/.claude/, /Users/X/.claude/, ~/.claude/)"
                ),
                ref,
            )
        for rx in SECRET_REGEXES:
            if rx.search(text):
                result.fail(
                    "references.secrets", f"reference matches secret regex {rx.pattern!r}", ref
                )
        if AT_IMPORT_REGEX.search(text_no_code):
            result.warn(
                "references.at-import",
                "reference contains @-import directive (skill layer should not use @-import)",
                ref,
            )
        _check_inline_parent_traversal(body_text, ref, result, "references")
        repo_root = _find_repo_root(skill_dir)
        _check_script_paths(body_text, ref, repo_root, result, "references")
        _check_section_anchors(body_text, ref, skill_dir, repo_root, result, "references")
        rel = ref.relative_to(skill_dir).as_posix()
        if rel not in body and ref.name not in body:
            result.fail(
                "references.linked",
                f"reference {rel!r} is not mentioned by name in SKILL.md",
                ref,
            )
    _check_link_safety(skill_dir, body, result)


def _resolve_doc_link(target: str, base: Path, repo_root: Path | None) -> Path:
    """Resolve a markdown link target. A '/'-prefixed target is repo-relative
    (resolved against repo_root), not host-FS-root-relative; Path('/a') / '/b'
    would otherwise collapse to '/b'."""
    if target.startswith("/"):
        root = repo_root if repo_root is not None else base
        return (root / target.lstrip("/")).resolve()
    return (base / target).resolve()


def _check_link_safety(skill_dir: Path, body: str, result: Result) -> None:
    skill_md = skill_dir / "SKILL.md"
    repo_root = _find_repo_root(skill_dir)
    link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
    body_no_fence = _strip_all_code(body)
    for m in link_re.finditer(body_no_fence):
        target = m.group(1).split("#", 1)[0].split(" ", 1)[0]
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        if target.startswith(".claude/skills/"):
            parts = target.split("/")
            if len(parts) >= 3 and parts[2] != skill_dir.name:
                result.fail(
                    "links.cross-skill",
                    f"SKILL.md links into another skill: {target!r}",
                    skill_md,
                )
        if ".." in target.split("/"):
            result.fail("links.parent-traversal", f"SKILL.md link uses '..': {target!r}", skill_md)
        if target and not target.startswith("#"):
            resolved = _resolve_doc_link(target, skill_dir, repo_root)
            if not resolved.exists():
                result.fail(
                    "links.resolve",
                    f"SKILL.md link does not resolve on disk: {target!r}",
                    skill_md,
                )
    refs_dir = skill_dir / "references"
    if refs_dir.is_dir():
        for ref in refs_dir.rglob("*.md"):
            ref_text = _read_text(ref)
            ref_no_fence = _strip_all_code(ref_text)
            for m in link_re.finditer(ref_no_fence):
                target = m.group(1).split("#", 1)[0].split(" ", 1)[0]
                if target.startswith(("http://", "https://", "mailto:")):
                    continue
                if ".." in target.split("/"):
                    result.fail(
                        "links.parent-traversal", f"reference link uses '..': {target!r}", ref
                    )
                if target.startswith(".claude/skills/"):
                    parts = target.split("/")
                    if len(parts) >= 3 and parts[2] != skill_dir.name:
                        result.fail(
                            "links.cross-skill",
                            f"reference links into another skill: {target!r}",
                            ref,
                        )
                if target and not target.startswith("#"):
                    resolved = _resolve_doc_link(target, ref.parent, repo_root)
                    if not resolved.exists():
                        result.warn(
                            "links.resolve",
                            f"reference link does not resolve on disk: {target!r}",
                            ref,
                        )
                rel_to_skill = ref.parent.relative_to(skill_dir).as_posix()
                if (
                    target.endswith(".md")
                    and not target.startswith("/")
                    and "references" in rel_to_skill
                ):
                    candidate = (ref.parent / target).resolve()
                    refs_root = (skill_dir / "references").resolve()
                    try:
                        candidate.relative_to(refs_root)
                        if candidate.exists() and candidate != ref.resolve():
                            result.warn(
                                "references.one-hop",
                                f"reference links to another reference: {target!r}",
                                ref,
                            )
                    except ValueError:
                        pass


def check_scripts(skill_dir: Path, result: Result) -> None:
    scripts_dir = skill_dir / "scripts"
    if not scripts_dir.is_dir():
        return
    for script in scripts_dir.rglob("*.py"):
        if script.name.startswith("_"):
            continue
        text = _read_text(script)
        if "def main(" not in text:
            result.warn("scripts.main", "script missing def main()", script)
        if '__name__ == "__main__"' not in text and "__name__ == '__main__'" not in text:
            result.warn("scripts.guard", "script missing if __name__ == '__main__': guard", script)
        try:
            tree = ast.parse(text)
        except SyntaxError:
            tree = None
        if tree is not None:
            for node in ast.walk(tree):
                if (
                    isinstance(node, ast.Constant)
                    and isinstance(node.value, str)
                    and _string_has_double_parent_traversal(node.value)
                ):
                    result.warn(
                        "scripts.parent-traversal",
                        "string literal contains 2+ consecutive parent traversals",
                        script,
                    )
                    break
        for rx in SECRET_REGEXES:
            if rx.search(text):
                result.fail(
                    "scripts.secrets", f"script matches secret regex {rx.pattern!r}", script
                )
        for syn, canon in FORBIDDEN_ARG_SYNONYMS.items():
            if re.search(
                rf"add_argument\(\s*"
                rf"(?:[\"\']-[a-zA-Z][\"\']\s*,\s*)?"
                rf"[\"\']({re.escape(syn)})[\"\']",
                text,
            ):
                result.warn(
                    "scripts.arg-synonym",
                    f"argparse uses {syn!r}; canonical is {canon!r}",
                    script,
                )
        for m in re.finditer(
            r"add_argument\(\s*"
            r"(?:[\"\']-[a-zA-Z][\"\']\s*,\s*)?"
            r"[\"\'](--[a-z][a-z0-9-]*)[\"\']",
            text,
        ):
            arg = m.group(1)
            if arg not in CANONICAL_ARGS and arg not in FORBIDDEN_ARG_SYNONYMS:
                result.warn(
                    "scripts.arg-canon",
                    f"argparse uses non-canonical argument {arg!r}; "
                    "if intentional, extend the canon list",
                    script,
                )
        verb = script.stem.split("_", 1)[0]
        if verb not in ALLOWED_SCRIPT_VERBS and not script.stem.startswith("_"):
            result.warn(
                "scripts.naming",
                f"script verb {verb!r} not in canonical set {sorted(ALLOWED_SCRIPT_VERBS)}",
                script,
            )


def check_symlinks(skill_dir: Path, result: Result) -> None:
    skill_root = skill_dir.resolve()
    for entry in skill_dir.rglob("*"):
        if entry.is_symlink():
            target = (entry.parent / entry.readlink()).resolve()
            try:
                target.relative_to(skill_root)
            except ValueError:
                result.warn(
                    "symlinks.scope",
                    f"symlink {entry} points outside skill folder ({target})",
                    entry,
                )


def check_evals(skill_dir: Path, result: Result) -> None:
    evals_dir = skill_dir / "evals"
    canary_file = evals_dir / "loading_verification.json"
    if not canary_file.exists():
        result.fail(
            "evals.loading-verification",
            "evals/loading_verification.json missing",
            canary_file,
        )
        return
    try:
        data = json.loads(_read_text(canary_file))
    except json.JSONDecodeError as exc:
        result.fail(
            "evals.loading-verification",
            f"loading_verification.json invalid JSON: {exc}",
            canary_file,
        )
        return
    canary = data.get("canary", "")
    negative = data.get("negative_control", "")
    if not isinstance(canary, str) or not canary.strip():
        result.fail("evals.canary", "evals.canary missing or empty", canary_file)
    if not isinstance(negative, str) or not negative.strip():
        result.fail(
            "evals.negative-control", "evals.negative_control missing or empty", canary_file
        )
    skill_md = skill_dir / "SKILL.md"
    if isinstance(canary, str) and canary.strip() and skill_md.exists():
        body = _read_text(skill_md)
        if canary not in body:
            result.fail(
                "evals.canary",
                "canary phrase from loading_verification.json does not appear in SKILL.md",
                canary_file,
            )


def check_taxonomy(skill_dir: Path, fm: dict, result: Result) -> None:
    if not fm:
        return
    metadata = fm.get("metadata") or {}
    declared_type = metadata.get("type") if isinstance(metadata, dict) else None
    if declared_type in ("workflow", "capability"):
        return
    description = (fm.get("description") or "").lower()
    has_scripts = (
        any((skill_dir / "scripts").rglob("*.py")) if (skill_dir / "scripts").is_dir() else False
    )
    capability_verbs = (
        "fetch",
        "query",
        "extract",
        "run",
        "validate",
        "analyze",
        "compare",
        "create",
        "audit",
    )
    workflow_verbs = (
        "triage",
        "investigate",
        "solve",
        "fix",
        "onboard",
        "review",
        "implement",
        "scaffold",
    )
    is_capability = any(v in description for v in capability_verbs)
    is_workflow = any(v in description for v in workflow_verbs)
    if is_capability and not has_scripts and not is_workflow:
        result.warn(
            "taxonomy.capability",
            "description suggests a capability skill but folder owns no scripts "
            "(set `metadata.type: workflow` in frontmatter to silence)",
            skill_dir,
        )
    if is_workflow and has_scripts and not is_capability:
        result.warn(
            "taxonomy.workflow",
            "description suggests a workflow skill but folder owns scripts "
            "(set `metadata.type: capability` in frontmatter to silence)",
            skill_dir,
        )


def emit_text(result: Result) -> None:
    if not result.issues:
        console.ok(f"{result.skill}: clean")
        return
    fails = [i for i in result.issues if i.severity == "fail"]
    warns = [i for i in result.issues if i.severity == "warn"]
    console.start(f"{result.skill}: {len(fails)} fail, {len(warns)} warn")
    for issue in result.issues:
        emit = console.fail if issue.severity == "fail" else console.warn
        loc = f" [{issue.path}]" if issue.path else ""
        emit(f"{issue.check}: {issue.message}{loc}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Mechanical validator for a single skill folder.")
    parser.add_argument("skill_dir", help="Path to the skill folder")
    parser.add_argument("--profile", choices=("claude-code", "skills-api"), default="claude-code")
    parser.add_argument(
        "--severity",
        choices=("warn", "fail"),
        default="fail",
        help="Promote warnings to blocking when 'warn'",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON to stdout")
    args = parser.parse_args()

    skill_dir = Path(args.skill_dir).resolve()
    if not skill_dir.is_dir():
        console.fail(f"not a directory: {skill_dir}")
        return 2

    result = Result(skill=skill_dir.name)
    fm = check_frontmatter(skill_dir, args.profile, result) or {}
    check_file_layout(skill_dir, fm, result)
    _, body = check_body(skill_dir, result)
    check_references(skill_dir, body, result)
    check_content_quality(skill_dir, body, result)
    check_scripts(skill_dir, result)
    check_symlinks(skill_dir, result)
    check_evals(skill_dir, result)
    check_taxonomy(skill_dir, fm, result)

    if args.json:
        print(json.dumps({"skill": result.skill, "issues": [asdict(i) for i in result.issues]}))
    else:
        emit_text(result)

    blocking = {"fail"}
    if args.severity == "warn":
        blocking.add("warn")
    has_block = any(i.severity in blocking for i in result.issues)
    return 1 if has_block else 0


if __name__ == "__main__":
    sys.exit(main())
