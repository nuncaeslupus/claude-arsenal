---
name: skill-workshop
description: When the user is authoring, editing, reviewing, validating, auditing, or refactoring a Claude Code skill — the meta-skill that must open before touching any SKILL.md, reference, script, or eval. Do NOT use for routine code edits, feature work, or unrelated debugging.
---

# skill-workshop

This skill distills authoring rules from a tier-1 research effort across
Anthropic's official skill documentation, the `anthropics/skills`
shipping repository, and academic sources. The full citation-bearing
ruleset lives at `docs/research/claude-skill-system_v1.17.md`;
this body provides the actionable, codebase-specific distillation.
Open the research doc only when extending the rule set.

CANARY: skill-workshop-loaded-2026-08-22-ceb6dc3efb38428d

## When to load

Before any of:

- Creating a new skill (`init_skill.py <name>`)
- Editing a `SKILL.md`, a file under `references/`, `scripts/`, `assets/`, or `evals/`
- Reviewing another skill's diff or a refactor proposal
- Diagnosing why a skill failed to load or trigger
- Running the validator or auditor by hand
- Reaching work-done on any of the above — the mandatory gate below
  fires there, not just at commit time

If unsure, load it. The body is short; references are loaded on demand.

## At work-done — mandatory gate

Before telling the user that a skill authoring / editing / refactor
task is finished, run **both validation passes** on every skill
folder this session touched. This is the *work-done* gate, not a
"before commit" suggestion — it fires the moment Claude believes the
requested work is complete, whether or not a commit follows.

### The two passes

1. **Mechanical pass.** For each touched skill folder:

   ```bash
   python3 "${CLAUDE_SKILL_DIR}/scripts/validate.py" <skill-path>
   ```

   Sub-second per skill. Exits 0 (clean), 1 (failure), 2 (internal
   error). Then one `audit_library.py <library-root>` per touched
   library to confirm listing-budget and cross-skill checks still
   hold. This pass is always run — never skipped, never deferred.

2. **Semantic pass.** Walk both rubrics —
   `references/skill-rules.md` (structural) then
   `references/content-quality-rules.md` (interpretive) — against the
   current state of every file in each touched skill folder. Surface
   every `must` and `should` finding to the user. A `must` finding
   stops the gate; the user fixes (Claude applies), dismisses with a
   reason, or defers, and the choice is recorded in `findings.md`.
   A `should` finding surfaces but does not stop the gate.

### When the scope is large — ask first

If the semantic pass would take more than ~5 minutes of session time
(rough proxy: more than ~5 skills modified, or a deep refactor that
rewrites most files in a skill folder), **stop and ask the user**
before walking. Name the scope, state the rough cost, and offer:

- **Walk everything now** — full semantic pass before reporting done.
- **Walk a subset** — Claude picks the skills most likely to have
  regressed (most-edited, largest, siblings of a cross-cutting
  change) and walks those; the rest is deferred.
- **Defer the whole semantic pass** — proceed without the walk; the
  user takes responsibility for running `audit_alignment.py` as a
  bulk pass later.

The mechanical pass is sub-second per skill — it runs regardless of
the answer above.

### When the user edits a skill directly

This gate fires only when Claude is the editing agent. A user
editing `SKILL.md` by hand outside a Claude session bypasses the
semantic pass entirely; the mechanical pass can still be enforced
via a pre-commit hook or CI step calling `validate.py`. The semantic
pass has no shell-only enforcement path — it requires LLM judgment.

### Operational checklist applied at the gate

1. `validate.py <skill>` exits 0 for every touched skill.
2. `audit_library.py <library-root>` is clean; listing-budget total
   has not regressed.
3. Both rubric walks completed (or the deferral choice is recorded).
4. `loading_verification.json` has a unique canary phrase plus a
   negative-control fact (for new or renamed skills).
5. Description does not overlap a sibling skill (audit before merge).
6. No `..` in any link from `SKILL.md` or its references.
7. Cross-skill references use prose ("use the `<capability>` skill"),
   never markdown links to peer SKILL.md / scripts paths.
8. Any duplicated script carries the sibling header listing every copy.

If any check fails, fix the skill — don't widen the rule.

## What this skill owns

- **Rules** — frontmatter, body length, references, naming, workspace
  topology, inter-document boundary, validation, refactor patterns,
  script CLI conventions.
- **Scripts** — `init_skill.py` (scaffold), `validate.py` (per-skill
  check), `validate_memory.py` (CLAUDE.md / AGENTS.md check),
  `audit_library.py` (whole-library report),
  `sync_duplicates.py` (cross-skill helper drift).
- **Templates** — `skill-md.template`, `script.template.py`,
  `loading-verification.template.json`.
- **Improvements log** — rolling notes on observed gotchas.

## How to use

### Scaffold a new skill

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/init_skill.py" my-skill
# `uv run python` works too — the scripts depend only on stdlib + pyyaml (termcolor optional)
```

Fills in frontmatter from the template, scaffolds folders, creates a
canary-bearing `loading_verification.json`. Then write the body.

### Validate a single skill

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/validate.py" .claude/skills/my-skill
```

Exits 0 (clean), 1 (failures), 2 (internal error). Severity gating
with `--severity warn|fail` (default: failures only block exit code).

### Audit the whole library

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_library.py" .claude/skills
```

Reports: per-skill validate result; description-overlap matrix
(cosine ≥0.5 surfaced); listing-budget total in characters;
duplicate-group SHA-status; aggregate exit code.

### Detect / propagate cross-skill duplicate drift

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/sync_duplicates.py" --check
python3 "${CLAUDE_SKILL_DIR}/scripts/sync_duplicates.py" --apply <canonical-path>
```

`--check` reports any sibling group whose SHAs differ. `--apply` copies
the chosen canonical onto its declared siblings.

## References — load on demand

Each reference covers one topic. Load only what the current task needs.

- [Frontmatter and naming](references/frontmatter-and-naming.md) — load when writing or fixing the YAML header (name regex, length limits, allowed keys, trigger phrases).
- [Body and style](references/body-and-style.md) — load when the body is over 400 lines or readability needs work (line budget, code blocks, tone, what NOT to put in a SKILL).
- [References and chunking](references/references-and-chunking.md) — load when splitting an oversized SKILL into reference docs (when to split, ToC requirement, link-back rules).
- [Scripts and CLI conventions](references/scripts-and-cli-conventions.md) — load before adding a script or reviewing one (argument-name canon, output discipline, naming, duplication header, print conventions).
- [Workspace and composition](references/workspace-and-composition.md) — load when deciding where a skill lives (single-depth rule, scope tiers, plugin namespacing, cross-cwd discovery).
- [Inter-document boundary](references/inter-document-boundary.md) — load when deciding whether something belongs in a SKILL, in CLAUDE.md, or in a `docs/` page.
- [Validation and evals](references/validation-and-evals.md) — load when extending the validator, writing a new eval, or interpreting an audit report.
- [Refactor cookbook](references/refactor-cookbook.md) — load when restructuring the skill library (split, retire, merge, extract, redirect, duplicate).
- [Improvements log](references/improvements-log.md) — load when an observed gotcha needs recording, or before planning the next refactor pass.
- [Research coverage](references/research-coverage.md) — load when the validator misses a real failure mode, when planning to widen the rule set, or when defending a deferred-rule decision.
- [Skill rules](references/skill-rules.md) — load before committing any skill change. Canonical ruleset Claude walks against current file state to produce per-skill alignment findings; lists must/should rules grouped by topic plus the gate protocol.
- [Content quality rules](references/content-quality-rules.md) — load alongside `skill-rules.md` at every gate. Second, interpretive rubric covering prose shape, example currency, reference cost, evergreen-doc-style, and trigger-and-boundary quality. Walked by the same `audit_alignment.py` runner with `--input references/content-quality-rules.md`.

## Hard constraints (top-of-mind)

- **One capability per skill.** If a description uses "and" to join two
  purposes, split it.
- **Workflows orchestrate; capabilities act.** Workflow SKILLs name
  capability skills in prose; they never link to another skill's
  `references/` or `scripts/`.
- **Scripts live inside the skill that owns them.** Helpers shared
  by ≥2 skills in the same plugin may live at
  `plugins/<plugin>/scripts/_shared/` and be imported by every skill
  in the plugin. Cross-plugin or cross-library helpers are duplicated
  and labelled with a sibling header; drift is detected by
  `sync_duplicates.py`. See `references/scripts-and-cli-conventions.md`.
- **Single-depth folder layout.** `.claude/skills/<name>/SKILL.md`
  only. Nested container directories (e.g.
  `.claude/skills/services/<name>/`) are silently invisible to skill
  discovery.
- **Descriptions are third-person, ≤1024 chars, contain a trigger
  phrase, and are distinct** (cosine ≥0.85 warns; ≥0.95 fails).
- **Listing budget**: total descriptions across all skills must stay
  under ~8,000 chars.

## Gotchas

Real failures observed while authoring or validating skills. Each
entry says *what* goes wrong AND *why*, not just the prohibition.

- **The gate covers Bash, because Edit/Write/MultiEdit alone left a hole.**
  `sed -i`, `tee`, a heredoc redirect and a `python3 -c` one-liner all reach a
  SKILL.md without ever naming it in `file_path`, so a matcher scoped to the
  edit tools was bypassable by the edit style a session is often steered
  toward. The gate now inspects Bash commands too, and keys on *mutation*
  rather than mention — reading a skill file and redirecting the output
  elsewhere stays allowed, because a gate that fires on `grep … > out` is one
  people route around instead of through.
- **Container directories swallow skills silently.** Skill discovery
  walks one level under `.claude/skills/`. A SKILL.md nested as
  `.claude/skills/<scope>/<name>/SKILL.md` is invisible — no warning,
  it just never registers. Promote to `.claude/skills/<name>/`.
- **`description` widening masks a missing capability split.** If
  routing is ambiguous between two skills, the cure is rarely a
  longer description; it is usually that the two skills should merge,
  or that the calling workflow should orchestrate both. Widening
  collides with the ≤1024 char budget and the cosine-distinctness
  rule.
- **Loose `.md` files at the skill root accumulate.** `NOTES.md` /
  `README.md` / `CHANGELOG.md` look harmless but the validator fails
  on them, and they confuse readers. Promote each to `references/`
  or delete.
- **Cross-skill markdown links rot fast.** Linking
  `../<other-skill>/SKILL.md` ties two skills together and breaks the
  moment one of them moves. Prose references — "use the `<capability>`
  skill" — let the model route and survive renames.
- **`@`-import inside a SKILL.md is silently ignored or expanded
  inconsistently.** `@`-import is a project-memory-layer feature
  (`CLAUDE.md` / `AGENTS.md`); skills load references through
  markdown links, not import expansion. Mixing the two creates
  surprising load behaviour.
- **Canary phrases from old templates collide.** A skill copy-pasted
  from a sibling sometimes inherits the original canary verbatim —
  the loading-verification eval then fires on either skill. Use the
  scaffold script and let it generate a fresh canary.
- **Auto Memory edits `MEMORY.md` between sessions.** Durable rules
  for the agent must live in `CLAUDE.md` / `AGENTS.md` — those are
  not touched by Auto Memory. Anything stored in `MEMORY.md` may be
  rewritten or removed without warning.

## Before committing

The work-done gate above already covers the substantive checks. At
commit time, only the lightweight final pass remains:

- The gate's operational checklist passed (see "At work-done —
  mandatory gate" above).
- Staged paths are intentional — `git diff --cached` covers what was
  edited, nothing else.
- `findings.md` is gitignored and was not staged.
