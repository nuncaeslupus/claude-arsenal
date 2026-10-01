---
name: skill-workshop
description: Authors, edits, reviews, validates and audits Claude Code skills; opens before any SKILL.md, reference, script or eval is touched. Use when the user is working on a skill. Not for routine code edits, feature work or unrelated debugging.
---

# skill-workshop

Authoring rules, validator and auditor for Claude Code skills. The rules are
distilled from `docs/research/claude-skill-system_v1.17.md`; open that only
when extending the rule set.

CANARY: skill-workshop-loaded-2026-08-22-ceb6dc3efb38428d

## When to load

Load it before any file under a `skills/<name>/` folder changes (`SKILL.md`,
`references/`, `scripts/`, `assets/`, `evals/`), including through Bash; when
reviewing a skill diff; when a skill fails to load or trigger; and when
running the validator or auditor by hand.

## At work-done — the gate

Before reporting skill work as finished, run both passes on every skill folder
changed this session, because load and routing failures are silent at runtime
and only these checks surface them.

### The two passes

1. **Mechanical.** `validate.py <skill-path>` for each changed skill (exit 0
   clean, 1 failure, 2 internal error), then one `audit_library.py
   <library-root>` per changed library for the listing budget and cross-skill
   checks. It takes under a second per skill, so it always runs.
2. **Semantic.** Walk `references/skill-rules.md`, then
   `references/content-quality-rules.md`, against the current state of the
   files changed this session. A `must` finding stops the gate until the user
   fixes, dismisses or defers it; a `should` finding is reported and the gate
   proceeds. The tiers and findings format are in `skill-rules.md`.

Walk every changed skill when there are up to about five, and name any
deferred one in the report. Above that, ask the user whether to walk all, walk the
likeliest regressions (most edited, largest, siblings of a cross-cutting
change), or defer to a later `audit_alignment.py` bulk pass.

The gate fires only when Claude edits. Hand edits get the mechanical pass from
a pre-commit hook or CI calling `validate.py`; the semantic pass needs a
session.

Also confirm, for new or renamed skills, that `loading_verification.json` has
a unique canary and a negative-control fact, and that the description does not
overlap a sibling. When a check fails, fix the skill rather than widening the
rule.

## Commands

Scripts live in `${CLAUDE_SKILL_DIR}/scripts/` and need only stdlib plus
pyyaml; `uv run python` works as well as `python3`.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/init_skill.py" my-skill               # scaffold folders, frontmatter, fresh canary
python3 "${CLAUDE_SKILL_DIR}/scripts/validate.py" .claude/skills/my-skill  # one skill; --severity warn|fail
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_library.py" .claude/skills      # overlap, listing budget, duplicates
python3 "${CLAUDE_SKILL_DIR}/scripts/sync_duplicates.py" --check           # sibling copies whose SHAs differ
python3 "${CLAUDE_SKILL_DIR}/scripts/sync_duplicates.py" --apply <path>    # copy the canonical onto its siblings
python3 "${CLAUDE_SKILL_DIR}/scripts/validate_memory.py" --root .          # CLAUDE.md / AGENTS.md checks
```

## References

- [Skill rules](references/skill-rules.md) — load at the gate for the structural walk.
- [Content quality rules](references/content-quality-rules.md) — load at the gate after `skill-rules.md`.
- [Frontmatter and naming](references/frontmatter-and-naming.md) — load when writing or fixing the YAML header.
- [Model prompting](references/model-prompting.md) — load when writing or reviewing prompt text, or when a `content.style-*` finding needs its reason.
- [Body and style](references/body-and-style.md) — load when a body passes 400 lines or reads poorly.
- [References and chunking](references/references-and-chunking.md) — load when splitting a body into references.
- [Scripts and CLI conventions](references/scripts-and-cli-conventions.md) — load before adding or reviewing a script.
- [Workspace and composition](references/workspace-and-composition.md) — load when deciding where a skill lives.
- [Inter-document boundary](references/inter-document-boundary.md) — load when choosing between a skill, `CLAUDE.md` and `docs/`.
- [Validation and evals](references/validation-and-evals.md) — load when extending the validator, writing an eval or reading an audit report.
- [Refactor cookbook](references/refactor-cookbook.md) — load when splitting, merging, retiring or redirecting skills.
- [Improvements log](references/improvements-log.md) — load when recording a new gotcha or planning a refactor pass.
- [Research coverage](references/research-coverage.md) — load when the validator misses a real failure or a deferred rule is questioned.
- [Bash gate mechanics](references/bash-gate-mechanics.md) — load when a Bash command is blocked for touching a skill folder and the reason is unclear.

## Gotchas

- **The gate covers Bash as well as the edit tools.** `sed -i`, `tee`, a
  heredoc redirect or a `python3 -c` one-liner can write a `SKILL.md` without
  naming it in `file_path`, so the hook keys on what a command writes.
- **`@`-import does not work inside a `SKILL.md`.** It is a memory-layer
  feature of `CLAUDE.md` / `AGENTS.md`; skills load references through
  markdown links.
- **Auto Memory rewrites `MEMORY.md` between sessions.** Durable agent rules
  belong in `CLAUDE.md` / `AGENTS.md`, which it leaves alone.
- **`findings.md` is gitignored.** Leave it out of the staged paths.
