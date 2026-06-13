---
name: loop-upgrade
description: When the user wants to upgrade .loop/core/. Avoid if already at the current plugin version.
user-invocable: true
argument-hint: "[--dry-run] [--apply]"
---

# loop-upgrade

Upgrades the `.loop/core/` framework tree in the host repository to the version bundled with the installed plugin. A semver gate blocks MAJOR mismatches and prompts on MINOR behind; PATCH upgrades are silent. `.loop/state/` is never modified.

CANARY: loop-upgrade-loaded-2026-06-13-fb78d23e-44351da5f05038c3

## When to load

Load this skill when:

- The user says "upgrade the loop", "update loop-orchestrator", or "/loop-upgrade".
- `loop-init` aborts because an existing `.loop/core/VERSION` differs from the plugin version.
- After updating the `loop-orchestrator` plugin to a new version.

## How to use

```bash
# Preview what would change (no writes)
bash .claude/skills/loop-upgrade/scripts/upgrade.sh --dry-run

# Apply the upgrade
bash .claude/skills/loop-upgrade/scripts/upgrade.sh --apply
```

The upgrade script:

1. Reads `.loop/core/VERSION` → `current_version`.
2. Reads the plugin bundle VERSION → `upstream_version`.
3. MAJOR mismatch → hard stop with migration instructions.
4. Minor behind → prompt to confirm before proceeding.
5. PATCH or already current → silent apply.
6. Overwrites `.loop/core/` entirely; `.loop/state/` is untouched.

## Gotchas

- **Always run `--dry-run` first.** The diff shows which core files will be replaced; custom files accidentally placed in `core/` will be overwritten without warning.
- **State migrations are manual.** If the new version adds a field to `queue.jsonl`, existing rows keep the old schema; new rows use the new schema. Readers must tolerate both.
