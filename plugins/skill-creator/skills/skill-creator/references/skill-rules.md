# Skill rules

## Contents

- [Purpose](#purpose)
- [How to read this file](#how-to-read-this-file)
- [Gate protocol](#gate-protocol)
- [Findings format](#findings-format)
- [1. Frontmatter](#1-frontmatter)
- [2. Naming and folder layout](#2-naming-and-folder-layout)
- [3. Body length and style](#3-body-length-and-style)
- [4. References (lazy-load anatomy)](#4-references-lazy-load-anatomy)
- [5. Skill-versus-reference content boundary](#5-skill-versus-reference-content-boundary)
- [6. Workspace topology and discovery](#6-workspace-topology-and-discovery)
- [7. Scripts and CLI conventions](#7-scripts-and-cli-conventions)
- [8. Cross-skill hygiene](#8-cross-skill-hygiene)
- [9. Multi-task composition](#9-multi-task-composition)
- [10. Evals and loading verification](#10-evals-and-loading-verification)
- [11. Inter-document boundary](#11-inter-document-boundary)
- [12. Plugin packaging](#12-plugin-packaging)
- [13. Marketplace conventions](#13-marketplace-conventions)
- [14. Hardening](#14-hardening)
- [Out of scope for this checklist](#out-of-scope-for-this-checklist)

## Purpose

This file is the canonical, author-checkable rule list every skill in this
marketplace follows. Rules are distilled from
`docs/research/claude-skill-system_v1.17.md` (the tier-1 citation-bearing
research archive) and cross-checked against the topical references already
in this folder. The research IDs (e.g. `R-FM-2`, `R-BODY-1`) are preserved
so any rule can be traced back to the underlying Anthropic-source-of-truth
and discarded-alternatives log.

The research doc stays the source-of-truth archive; the topical
references stay the deep-dives; this file is the working ruleset Claude
walks at modification time and at every bulk audit.

## How to read this file

Each section corresponds to one topical reference in this folder. Each
rule has four parts:

- **ID** — research ID, stable across reorganisations.
- **Tier** — `must` (alignment failure surfaces as a must finding) or
  `should` (surfaces as a should finding).
- **Check** — one-line statement of what alignment looks like. The
  negation of this line is the finding message.
- **Deep dive** — pointer to the topical reference where the *why*
  and worked examples live.

If a rule's check needs more context than one line, the deep-dive
reference is the place to read.

## Gate protocol

The gate runs in two motions:

**1. Per-edit gate (mandatory, in-session).** When a commit touches
any file inside a skill folder — `SKILL.md`, anything under
`references/`, `scripts/`, `evals/`, or `assets/` — walk every rule in
this file against the **current state** of every file in that skill
folder (not the diff). The gate evaluates alignment, not change. A
file that has been quietly drifting for sessions surfaces now.

Skip only when the commit's diff is exclusively in skill-creator's own
tooling (the `validate.py`, `audit_library.py`, or `audit_alignment.py`
scripts under this skill's `scripts/` folder) and no rule is being
added or removed.

**Must behavior.** When a `must` finding fires, surface the list to
the user and stop. Do not auto-fix. The user fixes (Claude applies),
dismisses with a reason captured in the commit body, or defers
(recorded in `findings.md`; commit proceeds, the finding stays
visible).

**Should behavior.** Surface in the same findings list; the commit
proceeds regardless. The user acts when they choose.

**2. Bulk audit (periodic).** Run the `audit_alignment.py` runner under
this skill's `scripts/` folder against a target library to emit
per-skill prompt blocks (ruleset + skill contents + findings
template) that a Claude session walks one at a time. No Anthropic API
call; the runner is a prompt emitter, not an inference driver. Bulk
audit output appends to each skill's `findings.md` exactly like the
per-edit gate.

## Findings format

Each skill folder may carry an author-local `findings.md` (gitignored).
The gate appends one dated section per run. Each section reports the
alignment state of the skill **at that moment**, file-keyed, not
diff-keyed. Files that have no violations do not appear under that
date. A fully clean skill writes one line.

```
## 2026-05-14

references/foo.md is not aligned with the guidelines:
  must   line 42   Cited path .claude/skills/old-name/scripts/x.py does not exist (R-REFLOC-1)
  should line 88   Section over 100 lines without a Table of Contents (R-BOUNDARY-9)

plugins/core/skills/discovery/scripts/audit_repo.py is not aligned with the guidelines:
  should line 10   Argparse arg --env conflates two concepts (R-SR-4)

(other files in this skill are aligned)
```

A clean run writes a single line under the date:

```
## 2026-05-14 — all files aligned with guidelines
```

`findings.md` is gitignored: it is the author's living log, not part
of the PR diff. Two authors of the same skill keep separate local
logs.

---

## 1. Frontmatter

Deep dive: `references/frontmatter-and-naming.md`.

| ID | Tier | Check |
|---|---|---|
| R-FM-1 | must | SKILL.md frontmatter contains both `name` and `description`. |
| R-FM-2 | must | `name` matches `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 chars, equals the folder name, is not a reserved word (`anthropic`, `claude`, `mcp`, `agent`). |
| R-FM-3 | must | `description` is non-empty, ≤1024 chars, contains both *what* the skill does AND *when* to use it (trigger phrase). |
| R-FM-4 | must | If `when_to_use` is present, the combined `description` + `when_to_use` ≤1536 chars (Claude Code listing budget). |
| R-FM-5 | must | No XML angle brackets (`<` `>`) anywhere in frontmatter; no manual namespace prefix in `name` (e.g. `myorg/foo`). |
| R-FM-6 | should | `disable-model-invocation` and `user-invocable` are set explicitly when the skill is destructive (`disable-model-invocation: true`) or ambient (`user-invocable: false`). |
| R-FM-7 | should | When the skill ships deterministic CLI access, `allowed-tools` lists the specific Bash patterns it pre-approves. |
| R-XPOLL-5 | must | `description` contains a trigger phrase from the canonical set: `When the user`, `Triggered by`, `whenever`. |
| R-BODY-8 | should | `description` ends with a negative-trigger clause: `Do NOT use for ...`, `Avoid ...`, `not for ...`, or `except for ...`. |
| R-BODY-9 | must | `description` is written in third person (e.g. *"This skill should be used when..."*) — not second person, not imperative. |
| R-XPOLL-1 | should | `description` reads as a retrieval key in third person; no `I` / `you can` / `use this to` phrasings. |
| R-XPOLL-3 | should | `description` carries both a *what* clause and a *when* clause; the trigger half is mechanically checked by R-XPOLL-5. |
| R-XPOLL-10 | should | `description` is not keyword-stuffed: ≥5 quoted strings *or* ≥8 comma-separated short segments → warn (the retrieval signal is degrading). |

**Note (YAML colon-space trap).** An unquoted single-line YAML scalar
that contains `: ` reparses as a mapping and silently breaks the
frontmatter. Any edited frontmatter value containing `: ` must be
quoted.

**Note (capability-verb gerund substring trap).** `validate.py`'s
verb detection uses substring match: `"validate" in "validating"`
is `False` (the `e` becomes `ing`), `"audit" in "auditing"` is `True`.
When the description's intent verb changes, re-run `validate.py` to
confirm capability and workflow verb detection still fires correctly.

## 2. Naming and folder layout

Deep dive: `references/frontmatter-and-naming.md`, `references/workspace-and-composition.md`.

| ID | Tier | Check |
|---|---|---|
| R-NAME-1 | must | The skill body file is exactly `SKILL.md` (case-sensitive). |
| R-NAME-2 | must | Folder name is kebab-case, ≤64 chars, no underscores, no spaces, no capitals, equals the frontmatter `name`. |
| R-WORKSPACE-1 | must | The skill lives at `<scope>/.claude/skills/<name>/SKILL.md` or `plugins/<plugin>/skills/<name>/SKILL.md` — exactly one level deep. No container directories. |
| R-WORKSPACE-2 | must | Subfolder-launch monorepo discovery uses `--add-dir <root>` or plugin install — never `additionalDirectories` in settings as a discovery substitute. |
| R-WORKSPACE-5 | should | The skill folder is a real directory, not a symlink (symlinks misbehave in `/skills` listing and trigger transient "Unknown skill" errors). |
| R-WORKSPACE-6 | should | When a skill name matches `<service>-<rest>` AND ≥2 services share the same monorepo, prefer plugin-per-service over name-prefix scoping. |
| R-IDX-1 | should | A skill MAY include `references/_index.md` when ≥3 reference files OR >5K total reference lines. If present, each entry must carry a `load this when…` descriptor mirroring R-SR-5. |

## 3. Body length and style

Deep dive: `references/body-and-style.md`.

| ID | Tier | Check |
|---|---|---|
| R-BODY-1 | must | SKILL.md body ≤500 lines. (`should` at >400 — start splitting.) |
| R-BODY-2 | should | SKILL.md body ≤5000 tokens (Anthropic level-2 budget). The line-count check (R-BODY-1) is the canonical surrogate; the token check applies when content is code-dense. |
| R-BODY-3 | should | The body uses imperative voice ("Run X, then Y"), not declarative narration. No reliance on a specific heading structure — Anthropic does not mandate one. |
| R-BODY-4 | should | The first ~5000 tokens of the body front-load the standing constraints most likely to matter after auto-compaction; deep-dive procedure can come later. (Co-listed with R-CTX-4.) |
| R-BODY-5 | must | No `README.md`, `NOTES.md`, `CHANGELOG.md`, or other loose `.md` at the skill root. Documentation lives in `SKILL.md` or `references/`. |
| R-BODY-6 | should | Per-reference token budget: each `references/*.md` warns at >10K tokens, fails at >25K; aggregate references warn at >25K, fail at >50K. |
| R-BODY-7 | must | No unclosed code fences in `SKILL.md` or any `references/**`. The state machine that counts ``` ``` ``` and `~~~` opens vs. closes must end at zero net. |
| R-BODY-9 | must | The body uses imperative/infinitive verb-first voice; second-person pronouns (`you`, `your`, `yours`) outside fenced code blocks are not used. |
| R-CTX-3 | should | The body is written as standing instructions, not one-time setup — Claude Code does NOT re-read SKILL.md on later turns. |
| R-CTX-4 | should | The first 5000 tokens of the body front-load the constraints most likely to matter after auto-compaction. |
| R-BODY-(MUST-AVOID) | should | The body avoids heavy-handed `MUST` / `ALWAYS` / `NEVER` styling. Explain *why* the constraint exists rather than asserting it categorically. |

## 4. References (lazy-load anatomy)

Deep dive: `references/references-and-chunking.md`.

| ID | Tier | Check |
|---|---|---|
| R-SR-5 | must | Each `references/<topic>.md` is cited inline from SKILL.md with a one-line "load this when…" descriptor. Unreferenced reference files are dead weight. |
| R-BOUNDARY-2 | must | References are one markdown-link hop from SKILL.md. No chained references (`references/a.md` linking `references/b.md`) — chained links trigger `head -100`-style partial reads. |
| R-BOUNDARY-9 | must | Reference files >100 lines start with a `## Contents` table of contents. |
| R-CHUNK-1 | must | Every reference file >100 non-blank lines opens with `## Contents` (or `## Table of Contents`) inside the first ~30 lines. Same check as R-BOUNDARY-9 / R-BODY-4 — kept under one citation. |
| R-CHUNK-2 | should | Reference files >500 lines OR >10K words OR >10–15K tokens must split by domain. Warn at any threshold; the line cap is the cheapest signal. |
| R-CHUNK-3 | should | When any reference file exceeds 10K words, SKILL.md must include at least one literal `grep` invocation example so Claude can search-then-read rather than full-load. |
| R-CHUNK-4 | must | Every internal `.md` reference is reachable in exactly one markdown-link hop from SKILL.md. Filesystem depth is unrestricted; the graph constraint is what matters. |
| R-CHUNK-5 | should | Each reference targets ≤2000 lines AND ≤10K tokens to stay within the Claude Code Read tool ceiling. Files exceeding either MUST split per R-CHUNK-2 or carry explicit `Read(file, offset=N, limit=M)` examples. |
| R-LAZYLOAD-1 | must | Every `references/*.md` is named verbatim in SKILL.md and accompanied by a one-sentence trigger ("load when …"). Mechanical: basename appears in body. Semantic: the trigger is concrete, not topical. |
| R-REF-FM-1 | should | Any frontmatter on a reference file uses only the whitelist: `title:`, `summary:`, `load_when:`. Other keys are not sanctioned. |
| R-REF-SUPERSEDE-1 | should | Deprecated reference content is retained inside the same file under a `<details><summary>Old patterns / deprecated …</summary>` block, not deleted. |
| R-REF-SECRETS-1 | must | No hard-coded credentials, API keys, tokens, or PII in any reference file. Secrets live in env vars or runtime injection. |
| R-LOG-REJECT | must | No append-only `log.md` chronological journal inside `references/`. Activity logging belongs in CLAUDE.md or git, not the skill layer. |
| R-REFLOC-1 | must | No `..` paths in SKILL.md or its references. Skill references are self-contained within the skill folder. |
| R-REFLOC-2 | should | Repo-doc reuse routes through one of four patterns (a) inline copy with `canonical:` marker, (b) outbound link from a reference, (c) internal-only carve-out via `user-invocable: false` + `paths`, (d) `paths` glob. No new frontmatter keys (no `internal:`). |
| R-REFLOC-3 | must | If SKILL.md body >300 lines, `references/_index.md` MUST exist; its TOC paths must stay inside the skill folder unless the description starts with `[internal — not portable]`. |
| R-REFLOC-4 | should | `paths` glob is auto-activation gating only — not a content-loading mechanism. A `paths` matching `docs/**` with zero links to `references/` warns. |
| R-REF-SHARE-1 | should | Cross-skill reference-doc sharing follows the R-SHARE-1 ladder: plugin-bundled skills MAY symlink within the plugin root; non-plugin helpers embed-and-duplicate. |

## 5. Skill-versus-reference content boundary

Deep dive: `references/inter-document-boundary.md`.

| ID | Tier | Check |
|---|---|---|
| R-SR-1 | must | Procedural how-to (what to do, in what order) lives in SKILL.md or `references/<topic>.md` when variant-specific. Not in `assets/`, not in `scripts/`. |
| R-SR-2 | must | Factual / lookup content (schemas, option lists, exhaustive tables) lives in `references/<name>.md`. |
| R-SR-3 | must | Templates, fonts, images, schema files used in *output* live in `assets/`. They are not loaded into context; scripts read them. |
| R-SR-4 | must | Executable code Claude runs (rather than reads) lives in `scripts/`. The source code does not enter context; only stdout/stderr does. |
| R-BOUNDARY-1 | must | Multi-step procedures are authored as SKILL.md, never as CLAUDE.md or AGENTS.md content. |
| R-BOUNDARY-7 | must | The `description` encodes both *what* the skill does and *when* Claude should use it; ≤1024 chars; third person. (Re-affirmation of R-FM-3.) |
| R-BOUNDARY-8 | should | Knowledge expected in <~50% of sessions lives in a skill, not CLAUDE.md. Knowledge in ≥~50% of sessions and consisting of stable invariants MAY live in CLAUDE.md. |
| R-CTX-2 | should | When a skill describes mutually-exclusive variants of one procedure, the variants live in `references/<variant>.md` files; SKILL.md routes by trigger. Mixing variants in the body forces every load to pay the worst-case cost. |
| R-CONDUCT-1 | should | Default to implicit, model-mediated conduction; do not author an "orchestrator skill" for in-session multi-skill coordination. Reserve explicit orchestrators for the agent-teams tier. |
| R-CONDUCT-2 | should | When two skills' `paths` globs both match the same file, both descriptions surface to the model — no resolution order is documented. Author `description` fields narrow enough that the model can disambiguate. |
| R-CONDUCT-3 | must | A skill with `disable-model-invocation: true` MUST NOT also declare a `paths` glob. The combination is incoherent (`paths` is an auto-activation channel; the destructive flag forbids auto-activation). |
| R-CONDUCT-4 | should | Mentions of agent-teams in body prose carry the EXPERIMENTAL caveat (v2.1.32+, Opus 4.6+, no nested teams, one team per session). |

## 6. Workspace topology and discovery

Deep dive: `references/workspace-and-composition.md`.

| ID | Tier | Check |
|---|---|---|
| R-WORKSPACE-3 | should | When ≥2 services or contexts share a skill, the skill is packaged as a plugin (`plugins/<plugin>/skills/<name>/`) rather than duplicated across scopes. |
| R-WORKSPACE-4 | must | `paths` glob is treated as auto-activation gating only — not as a discovery mechanism and not as a content-loading router. |
| R-MONO-1 | should | Nested-directory auto-discovery is broken on Claude Code CLI ≥2.1.92 (`Bun.Glob.scan` `dot: false` default). Skill bodies must not assume nested discovery without `--add-dir`. |
| R-MONO-2 | should | For ≥3-service monorepos, prefer plugin-per-service topology over name-prefix scoping (`R-WORKSPACE-6` extends this with a mechanical proxy). |
| R-MONO-3 | must | SKILL.md bodies do not link via Markdown to sibling skill folders (`../<other-skill>/SKILL.md`). Cross-skill references are prose only; the model routes by description, not by link. |
| R-MONO-4 | should | When the skill body instructs the agent to find files inside `.claude/`, the canonical pattern is `find … -path '*/<skill-name>/scripts/<known-script>'`, not the `Glob` tool (Bun.Glob defaults to `dot: false` on CLI ≥2.1.92). |
| R-CROSS-1 | must | No reference to `${CLAUDE_SKILLS_PATH}`, `skillsDirectories`, or `internal: true` frontmatter — none of these exist. |

## 7. Scripts and CLI conventions

Deep dive: `references/scripts-and-cli-conventions.md`.

| ID | Tier | Check |
|---|---|---|
| R-SR-4 | must | Each `scripts/*.py` Claude invokes is owned by exactly one skill — present in that skill's `scripts/` folder or referenced via `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}`. |
| R-SR-6 | must | Every relative `.md` link in SKILL.md or `references/**` resolves to an existing file. External `http(s)://` links are excluded from the check. |
| R-SR-7 | should | No orphan files in `scripts/`, `references/`, or `assets/`. Each file is reachable from SKILL.md via literal-path containment or Python `from X import Y` resolution. |
| R-SHARE-1 | should | When a helper is needed by ≥2 skills in the same plugin, the helper lives at `plugins/<plugin>/scripts/_shared/` and each skill imports it. Cross-plugin helpers are duplicated with a sibling header. |
| R-SHARE-2 | must | No reliance on `<scope>/.claude/scripts/` — that convention does not exist. |
| R-SHARE-3 | must | `${CLAUDE_PLUGIN_ROOT}` is referenced only in JSON/YAML config (hooks.json, .mcp.json, frontmatter), never inside `.md` body content for surfaces where the variable does not expand. |
| R-SHARE-4 | must | For personal/project-scope skills (no plugin), bundled-script paths in SKILL.md use `${CLAUDE_SKILL_DIR}/<path>`, not relative or absolute paths. |
| R-HELP-1 | should | Each `scripts/*.py` exposes a stable CLI (argparse with `--help`), documented invocation in SKILL.md, `#!/usr/bin/env python3` shebang, and a `def main()` + `if __name__ == "__main__":` guard. |
| (arg-canon) | should | Argparse args follow the canonical set declared in the `CANONICAL_ARGS` table inside this skill's `validate.py`. Skill-domain-specific args are tolerated; generic synonyms are rewritten. |
| (verb-canon) | should | Script filenames start with a canonical verb (`analyze`, `audit`, `compare`, `create`, `fetch`, `init`, `query`, `run`, `sync`, `validate`). Modules without a `main()` live in `plugins/<plugin>/scripts/_shared/`, not in a skill's `scripts/`. |
| (output-dir) | must | Scripts that produce artefacts accept a strict `--output-dir` flag and never write to a hard-coded path. |
| (rename-completeness) | must | After any `git mv`, no stale references to the old name remain in `*.md`, `*.py`, `*.yaml`, `*.yml`, or `*.toml`. |
| (arg-semantic) | should | An argparse arg name does not mean two different things across skills (e.g. `--env` for runtime environment vs deployment environment). Either rename one side or document the disambiguation. |

**Note (rename verification).** When checking rename completeness, use
`grep -n` not `grep -l`. Substring overlap (`markdown_to_adf` matches
inside `run_markdown_to_adf.py`) makes a `-l` sweep mask the leftover.

## 8. Cross-skill hygiene

Deep dive: `references/refactor-cookbook.md`, `references/validation-and-evals.md`.

| ID | Tier | Check |
|---|---|---|
| R-COMP-3 | must | Cross-skill helpers are embedded (one copy per skill, sibling header) OR promoted to `plugins/<plugin>/scripts/_shared/`. Never symlinked across peer skills. |
| R-XPOLL-2 | should | Skill names favour the `-ing` suffix when the skill describes a capability ("triaging") rather than a noun ("triage"). Soft; the team-style decision is recorded in `references/research-coverage.md § Deferred families and why`. |
| R-XPOLL-4 | must | Pairwise description cosine <0.95 across siblings. (`should` at <0.85.) Two highly similar descriptions mean two skills overlap and one should re-scope or merge. |
| R-XPOLL-6 | should | Each SKILL.md body has at least two `### ` sub-sections AND at least one fenced code block — the mechanical proxy for "concrete examples". |
| R-XPOLL-7 | should | Terminology in body prose stays consistent: the same concept gets the same name throughout SKILL.md and its references. Promotion-pass cap of 3 iterations on each skill. |
| R-XPOLL-8 | should | Deterministic helper outputs in SKILL.md are facts, not observations: no reasoning prose (`Now I will check…`, `Let me verify…`) between a ```bash``` fence and the next sentence; no time-sensitive tokens (years, month names) outside fences. |
| R-XPOLL-9 | must | The validator dogfoods itself: this skill (the meta-skill) MUST validate clean against its own `validate.py`. Library mode: assert this skill's `SKILL.md` exists; running `validate.py` against the meta-skill folder returns zero findings. |
| R-XPOLL-10 | should | Description keyword-stuffing detection: ≥5 quoted strings AND surrounding prose having fewer words than quote count → warn; ≥8 comma-separated short segments after excluding quotes → warn. |
| (listing-budget) | must | Aggregate descriptions across the loaded plugin set stay under ~8000 chars (Claude Code listing budget). |

## 9. Multi-task composition

Deep dive: `references/workspace-and-composition.md`.

| ID | Tier | Check |
|---|---|---|
| R-COMP-1 | should | When composing multi-task work, climb the ladder only when needed: inline → `context: fork` → custom subagent → agent team. Don't reach for subagents on work that fits in one SKILL.md. |
| R-COMP-2 | must | No skill-to-skill programmatic call from inside SKILL.md content. Sub-skill invocation is model-mediated. |
| R-PAR-1 | must | `context: fork` is only set on skills with explicit, actionable instructions. Reference-style skills (style guides, conventions) stay inline. |
| R-PAR-2 | should | Fan-out targets 3–5 sibling tasks by default; warn at >5 subagents/branches/forks/workers, fail at >8 (the documented hard ceiling). |
| R-PAR-3 | should | Before authoring a fan-out, the sibling tasks pass the independence test: no shared mutable state, no consumer-of-output, order-of-completion-irrelevant. |
| R-PAR-4 | should | Any skill body documenting `context: fork` includes the bidirectional composition / inheritance table — the doc-lint surrogate for "the user understood what they enabled". |
| R-DEL-1 | must | Composition depth ≤2 — subagents cannot spawn subagents; forks cannot spawn forks. |
| R-DEL-2 | must | A subagent listing a skill in `skills:` requires that skill not have `disable-model-invocation: true`. Otherwise the subagent loads a skill it cannot invoke. |
| R-DEL-3 | should | A subagent task brief carries all four fields: objective, output format, tools/sources whitelist, explicit task boundaries. |
| R-FAIL-3 | should | Subagent failures surface as a natural-language summary, not as `stderr` or exit codes. Body claims that the subagent "returns exit code N" or "captures stderr" are wrong and warn. |
| R-FAIL-4 | should | Sibling-hook exit-2 blocks only its own tool call, not the whole session. Documentation that says otherwise misleads readers. |
| R-FAIL-5 | must | When a skill spawns a background subagent, every tool the subagent will use is pre-approved at the spawn site (explicit `allowed-tools` listing). |

## 10. Evals and loading verification

Deep dive: `references/validation-and-evals.md`.

| ID | Tier | Check |
|---|---|---|
| (eval-present) | must | `evals/loading_verification.json` exists with the four required keys: `skill`, `canary`, `negative_control`, `load_prompts`, `no_load_prompts`. |
| (canary-unique) | must | `canary` appears verbatim once in SKILL.md body, never in the description, and is globally unique across the library. |
| (negative-control) | should | `negative_control` is a deliberately false fact about the skill's domain — something the model could plausibly say if pattern-matching instead of loading. |
| (load-prompts) | should | `load_prompts` contains at least one realistic phrasing per "Triggers on" entry — not paraphrases of the description. |
| (no-load-prompts) | should | `no_load_prompts` contains plausibly-confusable requests that would tempt a sibling skill instead, not unrelated topics. |

## 11. Inter-document boundary

Deep dive: `references/inter-document-boundary.md`.

| ID | Tier | Check |
|---|---|---|
| R-BOUNDARY-3 | should | Repository `CLAUDE.md` targets ≤200 lines, holds project-wide always-on invariants and pointer-style imports — not long procedures. |
| R-BOUNDARY-4 | should | When the project targets non-Claude agents, tool-portable invariants live in `AGENTS.md`; `CLAUDE.md` starts with `@AGENTS.md` as the first content line. |
| R-BOUNDARY-5 | must | Repo docs (`README.md`, `ARCHITECTURE.md`, `docs/adr/`, runbooks) are *referenced*, not duplicated. From CLAUDE.md, `@README.md`-style imports. From a skill, outbound links from `references/<topic>.md` — leaf links, not chained references. |
| R-BOUNDARY-6 | must | No skill carries an AGENTS-equivalent file; no `@`-import to a parallel-name target; no symlink to such a target. SKILL.md is the sole entrypoint. |
| R-MEM-7 | must | No hard-coded user paths inside skills. `~/.claude/`, `/home/<user>/.claude/`, `/Users/<user>/.claude/`, `/root/.claude/` outside fenced code blocks → fail. |
| R-MEM-8 | should | No `../../` (two-or-more consecutive parent traversals) in string literals inside `scripts/`. The mechanical scan walks Python AST string literals. |
| R-MEM-9 | must | No hard-coded credentials. Mechanical scan against the high-entropy regex set (`sk-ant-api03-…`, `AKIA…`, `ghp_…`, `xoxb-…`, PEM private-key headers); semantic confirmation that flagged tokens are not documentation placeholders. |

## 12. Plugin packaging

Deep dive: `references/workspace-and-composition.md`.

| ID | Tier | Check |
|---|---|---|
| R-FM-5 | must | The `name` field in plugin-shipped skills does not carry a manual namespace prefix (e.g. `myorg/foo`). Plugin distribution adds the prefix automatically. |
| R-WORKSPACE-3 | should | Cross-scope sharing routes through plugin distribution (`plugins/<plugin>/skills/<name>/`), not through `--add-dir` for production use. |
| R-SHARE-1 | should | Plugin-shared helpers live at `plugins/<plugin>/scripts/_shared/` and are imported via the standard bootstrap pattern in each consumer skill. |

## 13. Marketplace conventions

Rules unique to the `claude-arsenal` marketplace layout. Generic
Claude-skill authors can ignore this section when porting a skill into
a different distribution.

| ID | Tier | Check |
|---|---|---|
| (cite-form) | must | Cross-skill section references use prose ("use the `<capability>` skill") or the single-backtick form `` `<plugin>:<skill> § references/<file>.md` `` — never split-backtick, never a markdown link into a peer skill. |
| (plugin-layout) | must | Skill files live under `<scope>/.claude/skills/<name>/` (personal/project scope) or `plugins/<plugin>/skills/<name>/` (plugin scope). Plugin slugs in this marketplace are `skill-creator` and `core`; new plugins land via `.claude-plugin/marketplace.json` + a per-plugin `.claude-plugin/plugin.json`. |
| (shared-bootstrap) | must | Plugin-shared modules are imported via the standard `_shared` bootstrap (Path-prepend at the top of the consumer script). Per-skill ad-hoc `sys.path.insert(...)` is replaced by the canonical bootstrap. |

## 14. Hardening

Deep dive: `references/research-coverage.md` for the deferred families.

| ID | Tier | Check |
|---|---|---|
| R-CONTAM-1 | should | Cross-language contamination score = `0.3·multi_interface_tools + 0.4·language_mismatch + 0.3·scope_breadth`; warn at ≥0.5. The score is a mechanical proxy; the canonical verdict requires an LLM judge and is deferred per `research-coverage.md`. A skill that auto-loads on prompts which actually live in a sibling skill's domain trips this. |

## Out of scope for this checklist

- Runtime budgets the author cannot influence (R-FAIL-1's 25K/5K
  re-attach budget, R-API-1's 8-per-request, R-CTX-4 token mechanics).
  These shape design but cannot be checked by reading a file.
- Validation tooling internals (rule implementations and severity
  gating inside `validate.py`). Those live in
  `references/research-coverage.md` and `references/validation-and-evals.md`.
- Hook-event semantics (R-FAIL-2..5, PostToolBatch / SubagentStop)
  beyond the documentation-shape checks above. Plumbing rules, not
  authoring rules.
- The full research doc's discarded-alternatives log. If a finding
  cites a DA-* item, link to the research doc, do not restate the
  rejection.
- Meta-only governance families (R-META-*, R-LLMJ-*, R-CADENCE-*,
  R-AUTODREAM-*, R-LOAD-*, R-DRIFT-*, R-RETRO-*, R-ROLLBACK-*,
  R-SELF-*, R-DESTRUCT-*, R-EXTRACT-*, R-VC-*, R-SYS-*). One-line
  intent + `§` anchor for each lives in
  `references/research-coverage.md § Deferred individual rule IDs`.
