#!/usr/bin/env python3
"""init_loop.py --repo-path PATH
Bootstrap .loop/ in a host repository from the plugin-bundled core/.
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

# Marker used to detect whether the session-protocol block is already present.
CLAUDE_MD_MARKER = "<!-- loop-orchestrator: auto-managed -->"

# Full block injected into CLAUDE.md — includes proactive session-start instructions
# and the @import for AGENTS.md mechanics.
CLAUDE_MD_BLOCK = """\
<!-- loop-orchestrator: auto-managed -->
## Task queue — automatic session protocol

This project uses loop-orchestrator. Every session, without waiting to be asked:

1. Check `.loop/state/handover.md` — read it if it has content beyond the template
   placeholder (look for filled-in "Last task" and "What was done" sections).
2. Run `.loop/core/scripts/queue_eval.sh`.
   - **Open tasks exist** → start the worker loop (see `@.loop/core/AGENTS.md`).
   - **Queue empty and `status/plan.md` exists** → seed the queue from the plan
     table then start workers (see "Queue seeding from plan.md" in AGENTS.md).
   - **Queue empty, no plan** → ask what to work on.
3. Before ending any session where tasks remain open: fill in `.loop/state/handover.md`.

@.loop/core/AGENTS.md"""

# Default surface profile written on init — permits all tasks when detect_surface.sh
# has not run (CC Web without hooks, or first CLI session before hook fires).
DEFAULT_SURFACE_PROFILE = {
    "surface": "unknown",
    "capabilities": ["surface:cli", "surface:web"],
}

# Bundle core/ is three levels up from this script:
# skills/loop-init/scripts -> skills/loop-init -> skills -> loop-orchestrator -> core
_BUNDLE_CORE = Path(__file__).resolve().parent.parent.parent.parent / "core"


def _bundle_core(override: Path | None = None) -> Path:
    path = override or _BUNDLE_CORE
    if not path.is_dir():
        sys.exit(f"init_loop: bundle core/ not found at {path}")
    return path


def init_loop(repo_path: Path, force: bool = False, bundle_override: Path | None = None) -> None:
    bundle = _bundle_core(bundle_override)
    bundle_version = (bundle / "VERSION").read_text(encoding="utf-8").strip()

    target_core = repo_path / ".loop" / "core"
    target_state = repo_path / ".loop" / "state"

    # Idempotency check
    if target_core.exists():
        version_file = target_core / "VERSION"
        if version_file.exists():
            existing = version_file.read_text(encoding="utf-8").strip()
            if existing != bundle_version and not force:
                sys.exit(
                    f"init_loop: .loop/core/VERSION={existing!r} differs from plugin "
                    f"version={bundle_version!r}. Run /loop-upgrade instead."
                )
        if not force:
            print(f"init_loop: .loop/core/ already at {bundle_version} — skipping core copy")
        else:
            shutil.rmtree(target_core)
            shutil.copytree(bundle, target_core)
            print(f"init_loop: replaced core/ ({bundle_version}) at {target_core}")
    else:
        shutil.copytree(bundle, target_core)
        print(f"init_loop: copied core/ ({bundle_version}) to {target_core}")

    # State scaffold
    target_state.mkdir(parents=True, exist_ok=True)
    (target_state / "tasks").mkdir(exist_ok=True)

    queue_file = target_state / "queue.jsonl"
    if not queue_file.exists():
        queue_file.write_text("", encoding="utf-8")
        print(f"init_loop: created {queue_file}")

    handover_file = target_state / "handover.md"
    if not handover_file.exists():
        template = target_core / "handover.md"
        if template.exists():
            shutil.copy(template, handover_file)
        else:
            handover_file.write_text(
                "<!-- handover.md — written by loop-start when a session ends mid-queue -->\n",
                encoding="utf-8",
            )
        print(f"init_loop: created {handover_file}")

    # Default surface profile — permits all tasks until detect_surface.sh overwrites it.
    profile_file = target_state / "surface_profile.json"
    if not profile_file.exists():
        profile_file.write_text(
            json.dumps(DEFAULT_SURFACE_PROFILE, indent=2) + "\n", encoding="utf-8"
        )
        print(f"init_loop: created default {profile_file}")

    # Wire CLAUDE.md with proactive session-start block + @import
    claude_md = repo_path / "CLAUDE.md"
    if claude_md.exists():
        content = claude_md.read_text(encoding="utf-8")
        if CLAUDE_MD_MARKER not in content:
            new_content = content.rstrip("\n") + f"\n\n{CLAUDE_MD_BLOCK}\n"
            claude_md.write_text(new_content, encoding="utf-8")
            print("init_loop: injected session-protocol block into CLAUDE.md")
        else:
            print("init_loop: CLAUDE.md already contains session-protocol block — skipping")
    else:
        claude_md.write_text(f"{CLAUDE_MD_BLOCK}\n", encoding="utf-8")
        print("init_loop: created CLAUDE.md with session-protocol block")

    print(f"init_loop: .loop/ initialized at {repo_path}")


def main() -> None:
    p = argparse.ArgumentParser(description="Bootstrap .loop/ in a host repository.")
    p.add_argument("--repo-path", default=".", help="Path to the host repository root.")
    p.add_argument("--force", action="store_true", help="Force re-copy even if core/ exists.")
    p.add_argument("--bundle-core", help="Override path to plugin bundle core/ (for testing).")
    args = p.parse_args()
    bundle_override = Path(args.bundle_core) if args.bundle_core else None
    init_loop(Path(args.repo_path).resolve(), force=args.force, bundle_override=bundle_override)


if __name__ == "__main__":
    main()
