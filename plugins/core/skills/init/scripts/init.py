#!/usr/bin/env python3
"""init.py - Bootstrap or update claude-arsenal/ in a host repository."""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

CLAUDE_MD_MARKER = "<!-- claude-arsenal: auto-managed -->"

CLAUDE_MD_BLOCK = """\
<!-- claude-arsenal: auto-managed -->
## Automatic session protocol

Every session, without waiting to be asked:

1. Read `claude-arsenal/project/overview.md` (project + workspace index).
2. Read `claude-arsenal/session/handover.md` for last session activity.
3. Run `claude-arsenal/bin/queue_eval.sh`.
   - **Tasks available** → start worker loop (see `@claude-arsenal/AGENTS.md`).
   - **Queue empty + workspace plans exist** → seed from each workspace's plan, then workers.
   - **Queue empty + `status/plan.md` exists** → seed from it, then workers.
   - **Nothing** → ask what to work on.
4. After any session with tasks: update workspace handover + global session handover.

@claude-arsenal/AGENTS.md"""

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

1. Read `claude-arsenal/AGENTS.md` for the worker loop algorithm.
2. Run `claude-arsenal/bin/queue_eval.sh` to get the next unblocked task.
3. If the last task is still `in_progress` with no active assignee, run:
   `claude-arsenal/bin/release.sh <task_id> open` to requeue it first.
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


def _refresh_bundle(bundle: Path, target: Path) -> None:
    """Copy bundle files into target, refreshing only stale files."""
    for src in bundle.rglob("*"):
        if src.is_dir():
            continue
        rel = src.relative_to(bundle)
        dst = target / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists() and _sha256(src) == _sha256(dst):
            print(f"  up to date: {rel}")
        else:
            shutil.copy2(src, dst)
            # Preserve executable bit for shell scripts
            if src.suffix in (".sh",) or not src.suffix:
                dst.chmod(dst.stat().st_mode | 0o111)
            print(f"  refreshed:  {rel}")


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


def _inject_claude_md(repo_path: Path) -> None:
    claude_md = repo_path / "CLAUDE.md"
    if claude_md.exists():
        content = claude_md.read_text(encoding="utf-8")
        if CLAUDE_MD_MARKER in content:
            print("  CLAUDE.md: session-protocol block already present — skipping")
            return
        new_content = content.rstrip("\n") + f"\n\n{CLAUDE_MD_BLOCK}\n"
        claude_md.write_text(new_content, encoding="utf-8")
        print("  CLAUDE.md: injected session-protocol block")
    else:
        claude_md.write_text(f"{CLAUDE_MD_BLOCK}\n", encoding="utf-8")
        print("  CLAUDE.md: created with session-protocol block")


def _upsert_overview(repo_path: Path, workspace: str, root: str, spec: str, plan: str) -> None:
    overview = repo_path / "claude-arsenal" / "project" / "overview.md"
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


def init_base(repo_path: Path, bundle_override: Path | None = None) -> None:
    bundle = _bundle_dir(bundle_override)
    arsenal = repo_path / "claude-arsenal"

    print("Initializing claude-arsenal/...")

    # Scaffold directories
    for d in ["bin", "project", "queue", "session", "agents"]:
        (arsenal / d).mkdir(parents=True, exist_ok=True)

    # Refresh bundle files
    print("Refreshing bundle files:")
    _refresh_bundle(bundle, arsenal)

    # Create empty queue
    queue_file = arsenal / "queue" / "tasks.jsonl"
    if not queue_file.exists():
        queue_file.write_text("", encoding="utf-8")
        print(f"  created: {queue_file.relative_to(repo_path)}")

    # Create session handover
    handover = arsenal / "session" / "handover.md"
    if not handover.exists():
        handover.write_text(
            "# Session Handover\n\n<!-- Written at session end. -->\n",
            encoding="utf-8",
        )
        print(f"  created: {handover.relative_to(repo_path)}")

    # Default surface profile (gitignored — overwritten by detect_surface.sh hook)
    profile = arsenal / "session" / "surface_profile.json"
    if not profile.exists():
        profile.write_text(
            json.dumps(DEFAULT_SURFACE_PROFILE, indent=2) + "\n", encoding="utf-8"
        )
        print(f"  created: {profile.relative_to(repo_path)}")

    # .gitignore
    _add_gitignore_entry(repo_path, "claude-arsenal/session/surface_profile.json")

    # CLAUDE.md
    _inject_claude_md(repo_path)

    print(f"\ninit: claude-arsenal/ ready at {repo_path}")


def init_workspace(
    repo_path: Path,
    workspace: str,
    root: str,
    spec: str,
    plan: str,
    bundle_override: Path | None = None,
) -> None:
    # The workspace name becomes a directory under claude-arsenal/project/.
    # Strip Windows-style trailing dots/spaces before checking (they normalize
    # to ".." on NTFS) and retain the substring ".." guard for defence-in-depth.
    normalized = workspace.rstrip(". ")
    bad = (not normalized or normalized in (".", "..") or ".." in workspace
           or "/" in workspace or "\\" in workspace or "|" in workspace)
    if bad:
        sys.exit(f"init: invalid workspace name {workspace!r}")

    arsenal = repo_path / "claude-arsenal"

    # Ensure base exists first
    if not (arsenal / "bin").is_dir():
        init_base(repo_path, bundle_override)

    ws_dir = arsenal / "project" / workspace
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
    args = p.parse_args()

    repo_path = Path(args.repo_path).resolve()
    bundle_override = Path(args.bundle_dir) if args.bundle_dir else None

    if args.workspace:
        name = args.workspace
        root = args.root or f"./{name}/"
        spec = args.spec or f"claude-arsenal/project/{name}/spec.md"
        plan = args.plan or f"claude-arsenal/project/{name}/plan.md"
        init_workspace(repo_path, name, root, spec, plan, bundle_override)
    else:
        init_base(repo_path, bundle_override)


if __name__ == "__main__":
    main()
