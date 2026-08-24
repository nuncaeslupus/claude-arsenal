#!/usr/bin/env python3
"""init.py - Bootstrap or update claude-arsenal/ in a host repository."""
import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

CLAUDE_MD_MARKER = "<!-- claude-arsenal: auto-managed -->"
CLAUDE_MD_END_MARKER = "<!-- /claude-arsenal: auto-managed -->"
# How the block ended before it had a closing marker.
LEGACY_BLOCK_TAIL = "@claude-arsenal/AGENTS.md"

CLAUDE_MD_BLOCK = """\
<!-- claude-arsenal: auto-managed -->
## Automatic session protocol

Every session, without waiting to be asked:

1. Read `arsenal/session/handover.md` for the previous session's context.
2. List the repository's issues labelled `arsenal:task` — **open and closed** — and
   save the JSON. Use whatever GitHub access this surface has; run
   `claude-arsenal/bin/github_channel.sh --detect` to find out which. Request
   `number`, `title`, `state`, `labels`, `assignees` and **not `body`** — the bodies
   are the bulk of that fetch and nothing downstream reads them.
3. Run `python3 claude-arsenal/scripts/query_status.py --issues <that file>` for the
   board, and report anything it flags.
4. Pick up work: `python3 claude-arsenal/scripts/task_select.py --issues <that file>`
   returns the next unblocked task, then
   `bash claude-arsenal/bin/claim_task.sh <id>` takes it (see `@claude-arsenal/AGENTS.md`).
   - **Nothing returned + workspace plans exist** → seed tasks from each plan.
   - **Nothing at all** → ask what to work on.
5. Open each task's PR with `Closes #<issue>` so merging it closes the task by itself.
6. After any session with tasks: update `arsenal/session/handover.md`.

@claude-arsenal/AGENTS.md
<!-- /claude-arsenal: auto-managed -->"""

_CONFIG_TEMPLATE = """\
# claude-arsenal host configuration — yours; upstream never rewrites this file.

# How far must a task PR get before an agent may merge it?
#
#   always               The gates open_task_pr.sh already ran are the whole bar.
#   after-ci             Every required check has REPORTED, and is green.
#                        Absent is not green: no runners, no workflows, or a
#                        job that died unassigned means "wait", not "pass".
#   after-review         A review has landed (human or bot — whatever GitHub
#                        reports on the PR) and every comment it raised is
#                        fixed or answered. CI is NOT consulted. This is the
#                        value for a repo with no CI, or whose CI is
#                        unavailable rather than failing.
#   after-ci-and-review  Both of the two above: green checks AND a review whose
#                        comments are all addressed. The usual choice for a repo
#                        that has CI and a review bot — pick this one if you
#                        expect "wait for green, answer the bot, then merge".
#   never                An agent never merges. It reports the PR ready and
#                        stops; a human merges.
#
# Whichever is set, both directions are failures: merging past what it allows,
# and stopping to ask a question this file already answers. Do not set a policy
# nothing in the repo can ever satisfy — it gets waved through, and then it
# stays waved through on the day it starts meaning something again.
merge-policy = "after-ci"

# Shell command run before any task PR is opened; a non-zero exit means no PR.
# Empty = no host gate. Point it at everything your repo actually checks, not
# just lint — whatever is not named here is enforced by nobody.
#   host-gate = "make lint test evidence"
host-gate = ""

# test-first writes a failing test before the change; test-after writes tests
# alongside it.
test-discipline = "test-first"

# What /session-end leaves behind: handoff | ticket | none
session-end = "handoff"

# The skills-listing character budget the auditor enforces. Raise it if your
# surface's real budget differs, rather than deleting skills to fit a number
# that is not yours.
listing-budget = 8000

# Which model runs what. An alias Claude Code resolves (opus | sonnet | haiku)
# or a full model id.
#
# workers is enforced: the orchestrator exports it as CLAUDE_CODE_SUBAGENT_MODEL
# before dispatching, so it governs every worker subagent in the session.
#
# orchestrator is advisory — a session cannot change the model it is already
# running as. It is read at session start and reported when the running model
# is not the one named here. Leave it empty for "no opinion".
#
# Keep table headers at the end of this file: a bare key written after one
# lands inside the table instead of at the top level.
[models]
orchestrator = ""
workers = "sonnet"
"""

DEFAULT_SURFACE_PROFILE = {
    "surface": "unknown",
    "capabilities": ["surface:cli", "surface:web"],
}

WORKSPACE_SPEC_STUB = """\
# {name}: Specification

<!-- Written by /specify -->
"""

WORKSPACE_PLAN_STUB = """\
# {name}: Plan

<!-- Written by /design -->
"""

WORKSPACE_CONTEXT_STUB = """\
# {name}: Context

<!-- ≤200-word worker brief — written by /specify in workspace mode -->
"""

WORKSPACE_HANDOVER_STUB = """\
# {name}: Session Handover

<!-- Written at session end. A new session reading this file can resume
     without additional context. -->

## Last task

- **ID**: <!-- e.g. lo-a3f8 -->
- **Title**: <!-- task title -->
- **Status at handover**: <!-- open | in_progress | done | blocked -->

## What was done this session

<!-- One-paragraph summary. Include commit SHAs if relevant. -->

## What remains

<!-- Bulleted list of sub-tasks or acceptance-criteria items not yet met. -->

## How to continue

1. Read `claude-arsenal/references/worker-loop.md` for the worker loop algorithm.
2. Fetch the `arsenal:task` issues, then run
   `claude-arsenal/scripts/task_select.py --issues <file>` for the next task.
3. Claim it with `claude-arsenal/bin/claim_task.sh <task_id>`; `lost` means
   another session has it, so take the next one.
"""

OVERVIEW_HEADER = """\
# Project Overview

<!-- ≤100-word project description. Updated by /init --workspace. -->

## Workspaces

| Name | Root | Spec | Plan |
|------|------|------|------|
"""

# Bundle lives in this skill's assets/ so it travels with the skill when the
# skill folder is flattened into a consumer's .claude/skills/ (Claude Code web).
# skills/init/scripts/init.py -> skills/init -> skills/init/assets
_BUNDLE_DIR = Path(__file__).resolve().parent.parent / "assets"


def _bundle_dir(override: Path | None = None) -> Path:
    path = override or _BUNDLE_DIR
    if not path.is_dir():
        sys.exit(f"init: bundle not found at {path}")
    return path


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _has_shebang(path: Path) -> bool:
    """True when the file begins with a #! shebang (i.e. it is a script)."""
    try:
        with path.open("rb") as fh:
            return fh.read(2) == b"#!"
    except OSError:
        return False


# Host-owned bundle paths the init only SCAFFOLDS: a template is written once
# when absent, but NEVER overwritten on re-run — these hold live host data
# (AGENTS.md marks session/ and project/ "host-owned; never touched by /init
# re-run"). Clobbering them wipes the consumer's handover and plans on every
# `init --silent` at session start. Only session/ ships a template today;
# project/ is listed defensively so a future bundle file under it can't
# introduce the same data loss.
_SCAFFOLD_ONCE = ("session/", "project/")


def _refresh_bundle(bundle: Path, target: Path, silent: bool = False) -> None:
    """Copy bundle files into target, refreshing only stale files.

    Files under a _SCAFFOLD_ONCE prefix are written only when absent and left
    untouched if they already exist (host-owned live data, not bundle content).
    """
    for src in bundle.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(bundle)
        dst = target / rel
        if rel.as_posix().startswith(_SCAFFOLD_ONCE) and dst.exists():
            if not silent:
                print(f"  preserved (host-owned): {rel}")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists() and _sha256(src) == _sha256(dst):
            if not silent:
                print(f"  up to date: {rel}")
        else:
            shutil.copy2(src, dst)
            # copy2 already mirrors the source mode; restore +x only for files
            # that are actually scripts (a #! shebang) in case the checkout
            # dropped the bit. Keying off a missing suffix would make arbitrary
            # extensionless data files executable.
            if _has_shebang(src):
                dst.chmod(dst.stat().st_mode | 0o111)
            print(f"  refreshed:  {rel}")
    _prune_bundle(bundle, target)


# Directories the bundle owns outright: everything in them comes from upstream,
# so a file there that upstream no longer ships is a leftover, not host data.
# `references/` is swept for the same reason as the script dirs: a retired
# reference left behind is protocol the bundle no longer means, sitting in the
# tree a session reads on demand.
_PRUNABLE_DIRS = ("bin", "scripts", "references")


def _prune_bundle(bundle: Path, target: Path) -> None:
    """Delete installed bundle files upstream no longer ships.

    Refreshing by checksum updates and adds, but never removed — so an upgrade
    left every retired script sitting in the bundle, still executable. Those are
    not inert leftovers: they are the previous architecture, and a session that
    finds `claim.sh` can still run it against a queue that is no longer the
    board. Only the two upstream-owned directories are swept; host trees are
    never touched.
    """
    for dirname in _PRUNABLE_DIRS:
        src_dir, dst_dir = bundle / dirname, target / dirname
        if not dst_dir.is_dir():
            continue
        shipped = {p.name for p in src_dir.iterdir() if p.is_file()} if src_dir.is_dir() else set()
        for installed in sorted(dst_dir.iterdir()):
            if not installed.is_file() or installed.name in shipped:
                continue
            installed.unlink()
            print(f"  removed (no longer shipped): {dirname}/{installed.name}")


def _parse_version(text: str) -> tuple[int, ...] | None:
    """(major, minor, patch), or None when this is not a plain numeric version.

    None means "cannot compare", and the caller then behaves as it always did:
    a hand-edited or pre-release marker must not be able to wedge an install shut.
    """
    parts = text.strip().split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        return None
    try:
        return tuple(int(part) for part in parts)
    except ValueError:
        # CPython caps int() on very long digit strings. A garbage marker is
        # "cannot compare", never a crash in the one step every session runs.
        return None


def _check_bundle_version(bundle: Path, arsenal: Path) -> tuple[str, str] | None:
    """Print an upgrade banner; REPORT a downgrade instead of performing one.

    Returns (installed, bundle) when the host's committed bundle is newer than
    this skill's vendored copies, and None otherwise. That direction used to be
    invisible: the refresh is by checksum, so an older vendored copy differs from
    a newer installed one exactly as a newer copy does, and step 0b — which a
    session runs before it knows what kind of session it is — quietly replaced
    upstream fixes with the versions that predate them. A session that trusts it
    then ships the regression inside whatever PR it opens next (#220).
    """
    bundle_ver_path = bundle / ".bundle-version"
    installed_ver_path = arsenal / ".bundle-version"
    if not bundle_ver_path.exists() or not installed_ver_path.exists():
        return None
    bundle_ver = bundle_ver_path.read_text(encoding="utf-8").strip()
    installed_ver = installed_ver_path.read_text(encoding="utf-8").strip()
    if installed_ver == bundle_ver:
        return None
    installed_parsed, bundle_parsed = _parse_version(installed_ver), _parse_version(bundle_ver)
    if installed_parsed and bundle_parsed and installed_parsed > bundle_parsed:
        return installed_ver, bundle_ver
    print(
        f"Upgrading claude-arsenal bundle: {installed_ver} → {bundle_ver}"
    )
    return None


def _register_statusline(repo_path: Path) -> None:
    """Register statusline_capture.sh as the host statusLine command.

    Writes/merges .claude/settings.json. A user's existing statusLine is never
    clobbered — the budget guard is best-effort and must not override a custom
    status line the user already configured.
    """
    settings_path = repo_path / ".claude" / "settings.json"
    block = {
        "type": "command",
        "command": "bash claude-arsenal/bin/statusline_capture.sh",
    }
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            if not isinstance(settings, dict):
                settings = {}
        except json.JSONDecodeError:
            print("  settings.json: unparseable — skipping statusLine registration")
            return
        if "statusLine" in settings:
            print("  settings.json: statusLine already set — skipping")
            return
        settings["statusLine"] = block
    else:
        settings = {"statusLine": block}

    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    print("  settings.json: registered statusLine (statusline_capture.sh)")


# --- vendoring --------------------------------------------------------------
# Vendoring is the only mechanism that reaches every surface. A cloud session
# runs on a fresh clone and never sees ~/.claude/, and — verified against a live
# session, not inferred from docs — it does not act on a repo's
# `extraKnownMarketplaces` / `enabledPlugins` either: skills there arrive by
# account-level sync, and the web runtime never fetches a git marketplace at
# session start. What it does read is `.claude/skills/` and the hooks in
# `.claude/settings.json`, both of which are part of the clone.
#
# So the skills are copied in, and the gate that plugin hooks would otherwise
# provide is written into settings.json alongside them.
_MARKETPLACE = "claude-arsenal"
_VENDOR_MARKER = ".arsenal-vendored"
_GATE_HOOK = "claude-arsenal/bin/check_skill_workshop_loaded.sh"
_MARK_HOOK = "claude-arsenal/bin/mark_skill_workshop_loaded.sh"
_MARK_PROMPT_HOOK = "claude-arsenal/bin/mark_skill_workshop_loaded_from_prompt.sh"


def _read_settings(settings_path: Path) -> dict | None:
    """Parse .claude/settings.json, or None when it exists and is unparseable."""
    if not settings_path.exists():
        return {}
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return settings if isinstance(settings, dict) else {}


def _source_skills_dir() -> Path:
    """The skills/ directory this script's own skill lives in.

    Works from the plugin cache and from a vendored copy alike: init is always
    `<skills>/init/scripts/init.py`, so its grandparent is the library to copy.
    """
    return Path(__file__).resolve().parent.parent.parent


def _vendor_skills(repo_path: Path, silent: bool = False) -> None:
    """Copy the sibling skills into .claude/skills/ so every surface can load them.

    Only folders carrying the marker are ever replaced or removed — a skill the
    consumer authored is not ours to touch. Vendoring into itself (running from
    an already-vendored copy) is a no-op refresh.
    """
    source = _source_skills_dir()
    dest = repo_path / ".claude" / "skills"
    if source.resolve() == dest.resolve():
        return  # running from the vendored copy; nothing to copy in

    available = {d.name for d in source.iterdir() if (d / "SKILL.md").is_file()}
    dest.mkdir(parents=True, exist_ok=True)

    for name in sorted(available):
        target = dest / name
        if target.exists() and not (target / _VENDOR_MARKER).is_file():
            print(f"  skills: {name} exists and is not arsenal-vendored — left alone")
            continue
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source / name, target)
        (target / _VENDOR_MARKER).write_text("", encoding="utf-8")

    # Prune skills a previous version vendored that this one no longer ships.
    removed = []
    # Materialised first: iterdir() walks a live scandir, and rmtree inside the
    # loop can make it skip the entry that follows a deleted one.
    for d in sorted(dest.iterdir()):
        if d.is_dir() and (d / _VENDOR_MARKER).is_file() and d.name not in available:
            shutil.rmtree(d)
            removed.append(d.name)

    if not silent or removed:
        print(f"  skills: vendored {len(available)} into .claude/skills/")
    for name in removed:
        print(f"  skills: pruned {name} (no longer shipped)")


def _register_gate_hook(repo_path: Path) -> None:
    """Wire the skill-edit gate into .claude/settings.json.

    A plugin ships this as a plugin hook, but plugin hooks do not travel with
    vendored skills — which is why vendored skill authoring was ungated for as
    long as vendoring has existed. Settings hooks are part of the clone, so they
    reach a cloud session too.
    """
    settings_path = repo_path / ".claude" / "settings.json"
    settings = _read_settings(settings_path)
    if settings is None:
        print("  settings.json: unparseable — skipping gate-hook registration")
        return

    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        print("  settings.json: unexpected 'hooks' value — skipping gate-hook registration")
        return

    wanted = {
        "PreToolUse": ("Edit|Write|MultiEdit|Bash", _GATE_HOOK),
        "PostToolUse": ("Skill", _MARK_HOOK),
        "UserPromptSubmit": (None, _MARK_PROMPT_HOOK),
    }
    changed = False
    for event, (matcher, command) in wanted.items():
        entries = hooks.setdefault(event, [])
        if not isinstance(entries, list):
            continue
        if any(command in json.dumps(e) for e in entries):
            continue
        entry: dict = {"hooks": [{"type": "command", "command": f"bash {command}"}]}
        if matcher:
            entry["matcher"] = matcher
        entries.append(entry)
        changed = True

    if changed:
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
        print("  settings.json: registered the skill-edit gate")


def _retire_plugin_declaration(repo_path: Path) -> None:
    """Remove a marketplace declaration written by v1.0.0 through v1.1.0.

    Those versions declared the plugins in the host repo's settings, on the
    belief that a cloud session would install them. It does not. Left in place
    beside the vendored copies it does nothing in the cloud and produces
    duplicate skills on the CLI — `specify` and `core:specify` both live, both
    answering.
    """
    settings_path = repo_path / ".claude" / "settings.json"
    settings = _read_settings(settings_path)
    if not settings:
        return

    changed = False
    markets = settings.get("extraKnownMarketplaces")
    if isinstance(markets, dict) and _MARKETPLACE in markets:
        markets.pop(_MARKETPLACE)
        if not markets:
            settings.pop("extraKnownMarketplaces")
        changed = True

    enabled = settings.get("enabledPlugins")
    if isinstance(enabled, dict):
        stale = [k for k in enabled if k.endswith(f"@{_MARKETPLACE}")]
        for key in stale:
            enabled.pop(key)
        if stale:
            changed = True
        if not enabled:
            settings.pop("enabledPlugins")

    if changed:
        settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
        print("  settings.json: retired the plugin declaration (vendored copies supersede it)")


def _add_gitignore_entry(repo_path: Path, entry: str) -> None:
    gitignore = repo_path / ".gitignore"
    if gitignore.exists():
        lines = gitignore.read_text(encoding="utf-8").splitlines()
        if entry in lines:
            return
        with gitignore.open("a", encoding="utf-8") as f:
            f.write(f"\n{entry}\n")
    else:
        gitignore.write_text(f"{entry}\n", encoding="utf-8")
    print(f"  .gitignore: added {entry}")


def _replace_managed_block(content: str) -> str | None:
    """Return content with the managed block replaced, or None if there is none.

    The block is delimited by the two markers. Repos installed before the end
    marker existed have only the opening one, and their block runs to the
    `@claude-arsenal/AGENTS.md` import that terminates the template — match that
    so an upgrade repairs them too, instead of skipping the one file that tells
    every session what to do.
    """
    start = content.find(CLAUDE_MD_MARKER)
    if start == -1:
        return None
    end = content.find(CLAUDE_MD_END_MARKER, start)
    if end != -1:
        end += len(CLAUDE_MD_END_MARKER)
    else:
        # The tail string also appears *inline*, inside step 4 of the block
        # itself. An unanchored find() therefore stops at that mention and cuts
        # the block in half, stranding the rest of it — steps 5 and 6 and the
        # real import — below the closing marker as if it were host content.
        # Only a line that IS the import terminates the block, and if the block
        # names it more than once, the last such line is the end of it.
        offsets, pos = [], 0
        for line in content[start:].splitlines(keepends=True):
            if line.strip() == LEGACY_BLOCK_TAIL:
                offsets.append(start + pos + len(line.rstrip("\r\n")))
            pos += len(line)
        if not offsets:
            # An opening marker with no recognisable end: replacing to the end of
            # the file would eat host-owned content, so leave it and say so.
            return ""
        end = offsets[-1]
    return content[:start] + CLAUDE_MD_BLOCK + content[end:]


def _inject_claude_md(repo_path: Path) -> None:
    claude_md = repo_path / "CLAUDE.md"
    if not claude_md.exists():
        claude_md.write_text(f"{CLAUDE_MD_BLOCK}\n", encoding="utf-8")
        print("  CLAUDE.md: created with session-protocol block")
        return

    content = claude_md.read_text(encoding="utf-8")
    if CLAUDE_MD_MARKER not in content:
        claude_md.write_text(content.rstrip("\n") + f"\n\n{CLAUDE_MD_BLOCK}\n", encoding="utf-8")
        print("  CLAUDE.md: injected session-protocol block")
        return

    # The block is labelled auto-managed, so manage it. It was previously written
    # once and never touched again, which meant an upgrade that rewrote the
    # protocol left every consumer running the old one — naming paths that had
    # moved and scripts that had been deleted.
    replaced = _replace_managed_block(content)
    if replaced == "":
        print(
            "  CLAUDE.md: managed block has no end marker and no recognisable tail — "
            "left alone; review it against the current protocol"
        )
        return
    if replaced is None or replaced.rstrip("\n") == content.rstrip("\n"):
        print("  CLAUDE.md: session-protocol block up to date")
        return
    claude_md.write_text(replaced.rstrip("\n") + "\n", encoding="utf-8")
    print("  CLAUDE.md: session-protocol block refreshed (was out of date)")


def _upsert_overview(repo_path: Path, workspace: str, root: str, spec: str, plan: str) -> None:
    overview = repo_path / "arsenal" / "project" / "overview.md"
    if not overview.exists():
        overview.write_text(OVERVIEW_HEADER, encoding="utf-8")
    content = overview.read_text(encoding="utf-8")
    row = f"| {workspace} | {root} | {spec} | {plan} |"

    # Match an existing row by workspace name (the first table cell) so a
    # re-run with changed root/spec/plan updates in place instead of appending
    # a duplicate.
    lines = content.splitlines()
    for i, line in enumerate(lines):
        cells = [c.strip() for c in line.split("|")[1:-1]]
        if len(cells) == 4 and cells[0] == workspace:
            if line == row:
                print(f"  overview.md: workspace {workspace} already listed")
            else:
                lines[i] = row
                overview.write_text("\n".join(lines) + "\n", encoding="utf-8")
                print(f"  overview.md: updated workspace {workspace}")
            return

    content = content.rstrip("\n") + f"\n{row}\n"
    overview.write_text(content, encoding="utf-8")
    print(f"  overview.md: added workspace {workspace}")


# The queue automation workflow. It lives outside the bundle prefix because
# GitHub only reads workflows from .github/workflows/, so it is installed
# rather than vendored — but the copy under claude-arsenal/workflows/ stays the
# source of truth, and this keeps the installed file identical to it.
_QUEUE_WORKFLOW = "arsenal-queue.yml"


def _queue_automation_setting(config: Path) -> str | None:
    """The recorded queue-automation decision: `true`, `false`, or None if never set."""
    if not config.is_file():
        return None
    for line in config.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*queue-automation\s*=\s*(\S+)", line)
        if match:
            return match.group(1).strip().strip('"').lower()
    return None


def _upsert_bare_key(config: Path, key: str, value: str) -> None:
    """Upsert `<key> = <value>` in arsenal/config.toml, above the first table."""
    if config.is_file():
        text = config.read_text(encoding="utf-8")
        if re.search(rf"^\s*{re.escape(key)}\s*=", text, re.MULTILINE):
            text = re.sub(
                rf"^\s*{re.escape(key)}\s*=.*$",
                f"{key} = {value}",
                text,
                count=1,
                flags=re.MULTILINE,
            )
        else:
            # A bare key has to go above the first [table] header — appended at
            # the end of a file that ends in `[models]` it would be read as
            # `models.<key>`, an unknown key the loader ignores, so opting out
            # of the workflow would silently stop working.
            lines = text.rstrip("\n").split("\n")
            table_at = next(
                (i for i, line in enumerate(lines) if line.lstrip().startswith("[")), None
            )
            entry = f"{key} = {value}"
            if table_at is None:
                lines.append(entry)
            else:
                lines[table_at:table_at] = [entry, ""]
            text = "\n".join(lines) + "\n"
    else:
        text = f"{key} = {value}\n"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(text, encoding="utf-8")


def _record_queue_automation(config: Path, value: str) -> None:
    """Upsert `queue-automation = <value>` in arsenal/config.toml."""
    _upsert_bare_key(config, "queue-automation", value)


def _install_queue_workflow(repo_path: Path, arsenal: Path, silent: bool = False) -> None:
    """Install .github/workflows/arsenal-queue.yml, and say plainly what it does.

    Installed by default because the whole point is that queue upkeep does not
    depend on anyone remembering it — a workflow a repo has to opt into is one
    more setup step to forget, and the sessions that most need the cleanup are
    the ones that ended badly. But a file that grants itself write access to
    issues and contents should never appear silently, so the first install
    prints exactly what it will do and what it can touch.

    Deleting the file has to be a real opt-out, and that needs a record: the
    session-start protocol runs `init.py --silent` every session, so a purely
    file-based check would reinstall a workflow the user deliberately removed —
    on every single start, re-granting write access they had revoked and
    dirtying their checkout each time. So the decision lives in
    `arsenal/config.toml`, which an upgrade never overwrites:

      * no key       — never offered here. Install it and record `true`.
      * `true`, file present — refresh/no-op, as for any vendored file.
      * `true`, file gone    — deleted since the install. Record `false`, say so
                               once, and never reinstall.
      * `false`      — opted out. Do nothing, silently. Set the key back to
                       `true` to opt in again.

    A workflow the user has edited is left alone — clobbering local changes on
    every session start is how vendored files lose people's trust.
    """
    source = arsenal / "workflows" / _QUEUE_WORKFLOW
    if not source.is_file():
        return
    target = repo_path / ".github" / "workflows" / _QUEUE_WORKFLOW
    config = repo_path / "arsenal" / "config.toml"
    setting = _queue_automation_setting(config)

    if setting == "false":
        return

    if target.exists():
        if setting is None:
            _record_queue_automation(config, "true")
        if _sha256(source) == _sha256(target):
            if not silent:
                print(f"  .github/workflows/{_QUEUE_WORKFLOW}: up to date")
        else:
            print(
                f"  .github/workflows/{_QUEUE_WORKFLOW}: differs from the shipped version "
                f"— left as is. Diff it against {source.relative_to(repo_path)} to pick up "
                "upstream changes."
            )
        return

    if setting == "true":
        # Installed before, gone now: the user removed it. Honour that.
        _record_queue_automation(config, "false")
        print(
            f"  .github/workflows/{_QUEUE_WORKFLOW}: removed by you — recorded "
            "`queue-automation = false` in arsenal/config.toml so it is not reinstalled. "
            "Merging still completes a task; only the automatic upkeep (stale claims, "
            "missing handles) is off. Set the key back to `true` to restore it."
        )
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    _record_queue_automation(config, "true")
    print(
        f"""
  INSTALLED .github/workflows/{_QUEUE_WORKFLOW} — GitHub now keeps the queue current:
    * a merged task PR whose `Closes` keyword did not fire closes its task anyway
    * a task PR closed WITHOUT merging releases its claim, back onto the board
    * a task file merged to the default branch gets its issue handle immediately
    * a claim held over 24h with no open PR is released (crashed session)
    * a task PR that would merge without closing anything fails its check first
  It asks GitHub for `issues: write` (close/label/comment on task issues) and
  `contents: write` (archive a merged task file). It never runs code from a pull
  request. Delete the file to opt out — that choice is recorded in
  arsenal/config.toml, so it is not reinstalled on the next session start."""
    )


def init_base(
    repo_path: Path,
    bundle_override: Path | None = None,
    silent: bool = False,
    allow_downgrade: bool = False,
) -> bool:
    """True when the install ran; False when it refused to downgrade (nothing written)."""
    bundle = _bundle_dir(bundle_override)
    arsenal = repo_path / "claude-arsenal"

    if not silent:
        print("Initializing claude-arsenal/...")

    # Version check — upgrade banner when behind, a hard stop when AHEAD.
    newer_installed = _check_bundle_version(bundle, arsenal)
    if newer_installed is not None:
        installed_ver, bundle_ver = newer_installed
        # Printed whatever --silent says: this is the one line that tells a
        # refresh from a revert, and the caller is usually the session-start
        # protocol, which runs silent.
        print(
            f"init: the installed bundle ({installed_ver}) is NEWER than this skill's "
            f"vendored copies ({bundle_ver}) — nothing written. Update the plugin so its "
            f"copies catch up. To overwrite {installed_ver} with {bundle_ver} anyway, "
            f"pass --allow-downgrade."
        )
        if not allow_downgrade:
            return False
        print(f"init: --allow-downgrade — DOWNGRADING {installed_ver} → {bundle_ver}")

    # Scaffold directories. `claude-arsenal/` is upstream's and may be
    # overwritten freely; `arsenal/` is the host's and is created once, never
    # written again by an upgrade — that separation is what lets a consumer
    # vendor the bundle without an update ever touching their tasks or config.
    for d in ["bin", "scripts", "agents"]:
        (arsenal / d).mkdir(parents=True, exist_ok=True)
    home = repo_path / "arsenal"
    for d in ["tasks", "specs", "plans", "project", "session"]:
        (home / d).mkdir(parents=True, exist_ok=True)

    # Refresh bundle files
    if not silent:
        print("Refreshing bundle files:")
    _refresh_bundle(bundle, arsenal, silent=silent)

    # Host configuration. Seeded once and never rewritten, so a preference set
    # here survives every bundle upgrade — unlike one stored in a vendored skill,
    # which is build output and gets replaced.
    config = home / "config.toml"
    if not config.exists():
        config.write_text(_CONFIG_TEMPLATE, encoding="utf-8")
        print(f"  created: {config.relative_to(repo_path)}")

    # Create session handover
    handover = home / "session" / "handover.md"
    if not handover.exists():
        handover.write_text(
            "# Session Handover\n\n<!-- Written at session end. -->\n",
            encoding="utf-8",
        )
        print(f"  created: {handover.relative_to(repo_path)}")

    # Default surface profile (gitignored — overwritten by detect_surface.sh hook)
    profile = home / "session" / "surface_profile.json"
    if not profile.exists():
        profile.write_text(
            json.dumps(DEFAULT_SURFACE_PROFILE, indent=2) + "\n", encoding="utf-8"
        )
        print(f"  created: {profile.relative_to(repo_path)}")

    # .gitignore — surface profile, the statusLine-written rate-limit snapshot,
    # and the per-session dispatch-round counter (all live, machine-local state)
    for entry in (
        "arsenal/session/surface_profile.json",
        "arsenal/session/rate_limits.json",
        "arsenal/session/budget_iterations.json",
        "arsenal/session/worktree_isolation",
        "arsenal/session/host_branch",
        # Rescue metadata is machine-local too; it was previously omitted, so a
        # forced-restore snapshot could be swept into a task commit (#140).
        "arsenal/session/rescue_refs",
    ):
        _add_gitignore_entry(repo_path, entry)

    # GitHub-side queue upkeep (see the function's docstring for why by default)
    _install_queue_workflow(repo_path, arsenal, silent=silent)

    # statusLine command feeding budget_check.sh (token-budget stop)
    _register_statusline(repo_path)

    # Vendor the skills and wire the gate — the only path that reaches a cloud
    # session — then retire a plugin declaration an older init may have written.
    _vendor_skills(repo_path, silent=silent)
    _register_gate_hook(repo_path)
    _retire_plugin_declaration(repo_path)

    # CLAUDE.md
    _inject_claude_md(repo_path)

    ver_path = arsenal / ".bundle-version"
    if silent:
        if ver_path.exists():
            print(f"claude-arsenal {ver_path.read_text(encoding='utf-8').strip()}")
    else:
        print(f"\ninit: claude-arsenal/ ready at {repo_path}")
    return True


def init_workspace(
    repo_path: Path,
    workspace: str,
    root: str,
    spec: str,
    plan: str,
    bundle_override: Path | None = None,
    allow_downgrade: bool = False,
) -> None:
    # The workspace name becomes a directory under arsenal/project/ — host-owned,
    # so a bundle upgrade never touches a workspace's spec, plan, or context.
    # Strip Windows-style trailing dots/spaces before checking (they normalize
    # to ".." on NTFS) and retain the substring ".." guard for defence-in-depth.
    normalized = workspace.rstrip(". ")
    bad = (not normalized or normalized in (".", "..") or ".." in workspace
           or "/" in workspace or "\\" in workspace or "|" in workspace
           or "\n" in workspace or "\r" in workspace)
    if bad or any(c in p for p in (root, spec, plan) for c in ("|", "\n", "\r")):
        sys.exit("init: invalid workspace name or paths (must not contain '|' or newlines)")

    arsenal = repo_path / "claude-arsenal"

    # Ensure base exists first. A refusal there wrote nothing, so registering a
    # workspace on top would report one ready over an uninitialized bundle.
    if not (arsenal / "bin").is_dir() and not init_base(
        repo_path, bundle_override, allow_downgrade=allow_downgrade
    ):
        sys.exit("init: workspace not registered — the bundle refused to install (see above)")

    ws_dir = repo_path / "arsenal" / "project" / workspace
    ws_dir.mkdir(parents=True, exist_ok=True)
    print(f"Registering workspace {workspace!r}...")

    stubs = {
        "spec.md": WORKSPACE_SPEC_STUB.format(name=workspace),
        "plan.md": WORKSPACE_PLAN_STUB.format(name=workspace),
        "context.md": WORKSPACE_CONTEXT_STUB.format(name=workspace),
        "handover.md": WORKSPACE_HANDOVER_STUB.format(name=workspace),
    }
    for filename, content in stubs.items():
        fp = ws_dir / filename
        if not fp.exists():
            fp.write_text(content, encoding="utf-8")
            print(f"  created: {fp.relative_to(repo_path)}")
        else:
            print(f"  exists:  {fp.relative_to(repo_path)}")

    _upsert_overview(repo_path, workspace, root, spec, plan)
    print(f"\ninit: workspace {workspace!r} ready at {ws_dir.relative_to(repo_path)}")


def main() -> None:
    p = argparse.ArgumentParser(description="Bootstrap or update claude-arsenal/ in a host repo.")
    p.add_argument("--repo-path", default=".", help="Path to the host repository root.")
    p.add_argument("--workspace", metavar="NAME", help="Register a workspace.")
    p.add_argument("--root", default=None, help="Workspace root dir (default: ./<NAME>/).")
    p.add_argument("--spec", default=None, help="Spec file path override.")
    p.add_argument("--plan", default=None, help="Plan file path override.")
    p.add_argument("--bundle-dir", help="Override path to plugin bundle/ (for testing).")
    p.add_argument(
        "--silent", action="store_true",
        help="Suppress 'up to date' lines; only print refreshed files and version banner.",
    )
    p.add_argument(
        "--allow-downgrade", action="store_true",
        help="Overwrite a NEWER installed bundle with this skill's older copies.",
    )
    args = p.parse_args()

    repo_path = Path(args.repo_path).resolve()
    bundle_override = Path(args.bundle_dir) if args.bundle_dir else None

    if args.workspace:
        name = args.workspace
        root = args.root or f"./{name}/"
        spec = args.spec or f"arsenal/project/{name}/spec.md"
        plan = args.plan or f"arsenal/project/{name}/plan.md"
        init_workspace(repo_path, name, root, spec, plan, bundle_override,
                       allow_downgrade=args.allow_downgrade)
    else:
        init_base(repo_path, bundle_override, silent=args.silent,
                  allow_downgrade=args.allow_downgrade)


if __name__ == "__main__":
    main()
