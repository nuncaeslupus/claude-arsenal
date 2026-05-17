# Rule Catalog (validator-aligned)

Derived from `tmp/claude-skill-system_v1.17.md`. The research doc is the source of truth.

Per-rule fields:
- **Tags:** [skill]/[reference] · [portable]/[claude-code-only]
- **Class:** MECHANICAL · SEMANTIC · HYBRID
- **Severity:** fail · warn · info
- **Status:** VALIDATED · PROPOSED
- **Scope:** per-skill · library · meta-skill-only · project-root · cadence/judge

SEMANTIC and HYBRID rules note what the validator can pre-check mechanically and what the agent-driven semantic checklist must cover.

## Contents

- [Frontmatter — R-FM-*](#frontmatter--r-fm-)
- [Body — R-BODY-*, R-CTX-*](#body--r-body-)
- [Naming — R-NAME-*](#naming--r-name-)
- [Skill-vs-reference content — R-SR-*, R-REF-*, R-LOG-REJECT](#skill-vs-reference-content--r-sr-)
- [Chunking & lazy-load — R-CHUNK-*, R-LAZYLOAD-*](#chunking--lazy-load--r-chunk-)
- [Memory & security — R-MEM-7..10, R-MEM-1..6](#memory--security--r-mem-)
- [Composition — R-COMP-*](#composition--r-comp-)
- [Parallelism — R-PAR-*](#parallelism--r-par-)
- [Delegation — R-DEL-*](#delegation--r-del-)
- [Conducting — R-CONDUCT-*](#conducting--r-conduct-)
- [Failure semantics — R-FAIL-*](#failure-semantics--r-fail-)
- [Cross-pollination — R-XPOLL-*, R-API-1](#cross-pollination--r-xpoll-)
- [Workspace — R-WORKSPACE-*](#workspace--r-workspace-)
- [Monorepo — R-MONO-*](#monorepo--r-mono-)
- [Shared scripts — R-SHARE-*](#shared-scripts--r-share-)
- [Reference location — R-REFLOC-*, R-REF-SHARE-1](#reference-location--r-refloc-)
- [Cross-cutting canary — R-CROSS-1](#cross-cutting-canary--r-cross-1)
- [Self-update governance — R-RETRO-*, R-SELF-*, R-DRIFT-*, R-EXTRACT-*, R-DESTRUCT-*, R-VC-*, R-ROLLBACK-*](#self-update-governance)
- [Boundary — R-BOUNDARY-1..9, LINT-Q015-*](#boundary--r-boundary-)
- [System organization — R-SYS-*, R-IDX-1](#system-organization--r-sys-)
- [Helpers — R-HELP-*](#helpers--r-help-)
- [Meta-skill — R-META-1..19](#meta-skill--r-meta-)
- [Loading verification — R-LOAD-1..7](#loading-verification--r-load-)
- [LLM-judge — R-LLMJ-1..12](#llm-judge--r-llmj-)
- [Cadence — R-CADENCE-1..5](#cadence--r-cadence-)
- [AutoDream — R-AUTODREAM-1..4](#autodream--r-autodream-)
- [AutoDream-adjacent — R-MEM-1-CLARIFICATION](#autodream-adjacent)
- [Contamination — R-CONTAM-1](#contamination--r-contam-1)

---

## Frontmatter — R-FM-*

### R-FM-1
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: REQUIRE `name` and `description` in SKILL.md frontmatter.
- Heuristic: Open as UTF-8 (errors=`strict`); require leading `---\n` and closing `\n---\n` fence; `yaml.safe_load(body)` must be a dict with non-empty `name` and `description` after `.strip()`.
- Citation: agentskills.io spec; platform.claude.com Agent Skills overview.

### R-FM-2
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: `name` matches `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 chars, equals folder name, not reserved.
- Heuristic: `re.fullmatch(r"^[a-z0-9]+(-[a-z0-9]+)*$", name) and len(name) <= 64 and name.lower() not in {"anthropic","claude","mcp","agent"}`.
- Citation: Anthropic API rule; claude-code Issue #44199.

### R-FM-3
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: `description` non-empty, ≤1024 Unicode code points; contains what + when.
- Heuristic: `len(description.strip()) > 0 and len(description) <= 1024` (code-point count, not bytes). The what/when content check is deferred — combine with R-XPOLL-5 trigger regex.
- Citation: platform.claude.com agent-skills/best-practices ("Maximum 1024 characters").

### R-FM-4
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: If `when_to_use` present: `len(description) + len(when_to_use) ≤ 1536`.
- Heuristic: vacuously true when `when_to_use` is absent. Override via env `SLASH_COMMAND_TOOL_CHAR_BUDGET`.
- Citation: code.claude.com/docs/en/skills frontmatter reference (v1.5).

### R-FM-5
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No XML angle brackets in any frontmatter value; no `/` in `name` (manual namespace prefix forbidden).
- Heuristic: Walk frontmatter (recursive under `metadata`); for every string value assert no `<` and no `>`. For `name` additionally assert no `/`.
- Citation: anthropics/skills repo conventions.

### R-FM-6
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Frontmatter keys must be in an allow-list scoped by `--surface`.
- Heuristic: `set(frontmatter.keys()) ⊆ ALLOWED[surface]`.
  - `skills-api`: `{name, description, license, allowed-tools, metadata}`.
  - `claude-code` (15 keys, v1.5): `{name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell}`.
  - `both`: union (permissive).
- Citation: code.claude.com/docs/en/skills frontmatter table (fetched 2026-05-02); anthropics/skills issue #37.

### R-FM-7
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: `allowed-tools` declares deterministic CLI access (pre-approval, not restriction).
- Heuristic: presence check only; advisory because `allowed-tools` is parsed-but-not-enforced per claude-code Issues #18837/#37683. Actual enforcement is at the permissions layer.
- Citation: code.claude.com/docs/en/skills.

## Body — R-BODY-*

### R-BODY-1
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail at >500, warn at >400 · Status: VALIDATED · Scope: per-skill
- Rule: SKILL.md body ≤500 lines.
- Heuristic: Strip frontmatter; `line_count = body.count("\n") + 1`; fail >500, warn >400.
- Citation: platform.claude.com agent-skills/best-practices.

### R-BODY-2
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: SKILL.md body ≤5,000 tokens.
- Heuristic: `len(tiktoken.get_encoding("o200k_base").encode(body)) > 5000` → warn. Encoding switched cl100k → o200k in v1.4.
- Citation: Anthropic skill-creator + best-practices.

### R-BODY-3
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: No required headings — but no Windows backslash paths in body either (rule was repurposed in validation table).
- Heuristic: Outside fenced code blocks, search `\\.{1,80}\.(md|py|sh|json)` for Windows backslash paths in path-like contexts → fail.
- Note: The prose rule (R-BODY-3 in skill-spec) says "no required headings"; the validation table assigns the same rule-id to the Windows-path check. Treat them as two co-residents: structural recommendation only, plus the backslash-path lint.
- Citation: research line 174-185 (no required headings) + research line 1867 (Windows-path lint).

### R-BODY-4
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail at >100, warn at >200 · Status: VALIDATED · Scope: per-skill
- Rule: Reference files >100 lines must begin with a ToC.
- Heuristic: For each `references/**/*.md` with `line_count > 100`: scan the first 30 non-blank lines for `^##\s+(Table of Contents|Contents)\s*$` (case-insensitive). Aligned with R-CHUNK-1 (which supersedes this rule). Anthropic-supremacy threshold (100, corrected from skill-creator's 300).
- Citation: platform.claude.com agent-skills/best-practices.

### R-BODY-5
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No `README.md` or `AGENTS.md` inside a skill folder.
- Heuristic: `glob("<skill>/**/(README|Readme|readme|AGENTS).md")` returns empty.
- Citation: Anthropic Complete Guide; agent-ecosystem/skill-validator (AGENTS.md extension v1.4).

### R-BODY-6
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn at 10K/file, fail at 25K/file; warn at 25K total, fail at 50K total · Status: PROPOSED · Scope: per-skill
- Rule: Per-reference and aggregate token caps.
- Heuristic: Per `references/**/*.md` tiktoken(o200k_base) count: >10K → warn, >25K → fail. Sum across all references: >25K → warn, >50K → fail.
- Citation: agent-ecosystem/skill-validator v1.1.0.

### R-BODY-7
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: PROPOSED · Scope: per-skill
- Rule: No unclosed code fences in SKILL.md or `references/**`.
- Heuristic: State machine counts ` ``` ` and `~~~` opens vs. closes; non-zero net at EOF → fail.
- Citation: agent-ecosystem/skill-validator (Tier-2).

### R-BODY-8
- Tags: [skill] [portable]
- Class: MECHANICAL (heuristic) · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Description should contain a negative-trigger phrase.
- Heuristic: Description lacks any of `{"Do NOT", "Avoid", "not for", "except for"}` → warn (soft, many valid descriptions don't need exclusions).
- Citation: anthropics/skills/{docx,pptx,pdf}/SKILL.md exemplars.

### R-BODY-9
- Tags: [skill] [portable]
- Class: MECHANICAL (heuristic) · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Body uses imperative/infinitive; description uses third person.
- Heuristic: (a) Body has second-person pronouns (`\b(you|your|yours)\b`) outside fenced code blocks → warn. (b) Description starts with imperative verb not in `{"is","provides","contains","manages"}` → warn. (c) Grandfather anthropics/skills/{pdf,docx,pptx}.
- Citation: anthropics/skills skill-development SKILL.md.

### R-CTX-3
- Tags: [reference] [claude-code-only]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: SKILL.md content is sticky for the session; write as standing instructions.
- Heuristic: deferred to agent-driven checklist — flag "one-time setup" framing in body.

### R-CTX-4
- Tags: [skill] [portable]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Front-load standing constraints in first 5,000 tokens (re-attach budget per skill).
- Heuristic: deferred to agent-driven checklist; cross-link to R-BODY-2.

## Naming — R-NAME-*

### R-NAME-1
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Filename is literally `SKILL.md` (case-sensitive).
- Heuristic: `os.listdir(skill_dir)` contains exactly `SKILL.md`; reject `skill.md`/`Skill.md`/`SKILL.MD`.
- Citation: Anthropic-supremacy over Hanchung deep-dive.

### R-NAME-2
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Folder is kebab-case and equals frontmatter `name`.
- Heuristic: `os.path.basename(skill_dir.rstrip("/")) == frontmatter["name"] and re.fullmatch(r"^[a-z0-9]+(-[a-z0-9]+)*$", folder)`.
- Citation: code.claude.com/docs/en/skills.

## Skill-vs-reference content — R-SR-*

### R-SR-1
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Procedural how-to → SKILL.md body OR `references/<variant>.md` (one level deep).
- Heuristic: Build markdown-link graph from SKILL.md → `references/*.md`; warn if any path is length ≥2 (supersedes by R-CHUNK-4 graph BFS).
- Citation: Anthropic best-practices.

### R-SR-2
- Tags: [skill] [portable]
- Class: SEMANTIC · Severity: info · Status: PROPOSED · Scope: per-skill
- Rule: Reference filenames descriptive.
- Heuristic: deferred to agent-driven checklist. Weak mechanical proxy: regex `^(doc|file|untitled|temp)\d*\.md$` flags egregious cases.

### R-SR-3
- Tags: [reference] [portable]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Templates/fonts/images → `assets/` (not loaded into context).
- Heuristic: deferred to agent-driven checklist (intent-dependent).

### R-SR-4
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Executable code → `scripts/`; same backslash-path check as R-BODY-3 applied to every `.md` in skill folder.
- Heuristic: For each `.md` in skill folder, run R-BODY-3 backslash-path check.

### R-SR-5
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: References load only when SKILL.md links them by name.
- Heuristic: For every file under `references/**`, assert filename or basename appears as a literal string in SKILL.md body.

### R-SR-6
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: PROPOSED · Scope: per-skill
- Rule: Relative markdown links resolve to existing files.
- Heuristic: For every relative `.md` link in SKILL.md and `references/**`, `Path(link).resolve(strict=True)` succeeds. External `http(s)://` excluded.
- Citation: agent-ecosystem/skill-validator.

### R-SR-7
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: per-skill
- Rule: No orphan files in `scripts/`, `references/`, `assets/`.
- Heuristic: Build reachability set from SKILL.md via literal-path containment (plus Python `from X import Y` resolution and `__init__.py` bridging). Files not in reachable set → warn `orphan file`.

## Chunking & lazy-load — R-CHUNK-*, R-LAZYLOAD-*

### R-CHUNK-1
- Tags: [skill] [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Reference files >100 lines must begin with `## Contents` (or `## Table of Contents`).
- Heuristic: For each ref file with `line_count > 100`, scan the first 30 non-blank lines for an H2 heading matching `^##\s+(Contents|Table of Contents)\s*$` (case-insensitive). Note this DUPLICATES R-BODY-4 — keep both, run once.
- Citation: platform.claude.com agent-skills/best-practices (Anthropic-supremacy 100 over skill-creator's 300).

### R-CHUNK-2
- Tags: [skill] [reference] [portable]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Reference files >500 lines OR >10K words OR >10–15K tokens must split by domain.
- Heuristic: line count, word count, tiktoken(o200k_base) count. Warn if any threshold exceeded.
- Citation: best-practices Pattern 2; v1.10 threshold tightening per Issues #45019, #40357.

### R-CHUNK-3
- Tags: [skill] [reference] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Reference files >10K words must include literal `grep` example in SKILL.md.
- Heuristic: Mechanical: presence of the literal token `grep` somewhere in SKILL.md when any ref file >10K words. Semantic: agent-driven check that the grep pattern is useful.

### R-CHUNK-4 (v1.14, markdown-link-graph)
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Every internal `.md` reference must be reachable in one markdown-link hop from SKILL.md. Chained ref→ref forbidden. Filesystem depth unrestricted.
- Heuristic: (1) Parse SKILL.md for relative `.md` links → set D1 (strip anchor fragments, skip `https?://`). (2) For each f in D1, parse f for relative `.md` links into the same skill. (3) FAIL if any target outside D1 ∪ {SKILL.md} ∪ non-`.md` files is reachable only via a transitive hop. (4) Cross-links between two D1 files → emit LINT-Q016-1 info note, not fail.
- Citation: Anthropic best-practices + canonical anthropics/skills/claude-api shape.

### R-CHUNK-5
- Tags: [skill] [reference] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Reference files ≤2,000 lines AND ≤10K tokens per file.
- Heuristic: Line count and tiktoken(o200k_base). Files exceeding either: warn unless SKILL.md includes an explicit `Read(file, offset=N, limit=M)` example for them.
- Citation: Issues #4002, #40357, #45019, claude-plugins-official #995.

### R-CHUNK-6
- Tags: [skill] [reference] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: No vector indexes / embeddings as primary lookup in `references/`.
- Heuristic: Mechanical: flag suspicious files inside `references/`: `*.faiss`, `*.chroma`, `embeddings.json`, `*.pkl` named `index*`. Semantic: deferred to agent-driven checklist for intent.

### R-LAZYLOAD-1
- Tags: [skill] [reference] [portable]
- Class: MECHANICAL · Severity: fail (presence) + SEMANTIC info (quality) · Status: VALIDATED · Scope: per-skill
- Rule: Every `references/*.md` linked by name from SKILL.md with one-sentence trigger condition.
- Heuristic: Mechanical: every `.md` under `references/**` appears by basename in SKILL.md. Semantic: agent-driven check that each citation carries a "load this when…" descriptor.

### R-LAZYLOAD-2
- Tags: [skill] [reference] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Must-not-skim refs use the MANDATORY-READ pattern verbatim.
- Heuristic: Mechanical: presence of `MANDATORY` / `ENTIRE FILE` / `NEVER set any range limits` near reference citations. Semantic: deferred to agent-driven checklist (does the ref actually merit the directive?).

### R-LAZYLOAD-3
- Tags: [skill] [reference] [portable]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: References should not be <50 lines unless genuinely modular (SHOULD-tier).
- Heuristic: Mechanical proxy: count `.md` files in `references/` with `line_count < 50`; emit info note. Semantic: agent-driven check on whether each tiny ref is genuinely modular.

## Memory & security — R-MEM-*

### R-MEM-7
- Tags: [memory] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No hard-coded user paths inside skills.
- Heuristic: Regex `(~/\.claude/|/home/\w+/\.claude/|/Users/\w+/\.claude/|/root/\.claude/)` outside fenced code blocks → fail.

### R-MEM-8
- Tags: [memory] [portable]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: No `../../` directory traversal in scripts.
- Heuristic: In `scripts/**`, AST scan for string literals containing `(\.\./){2,}`, excluding comments.

### R-MEM-9
- Tags: [memory] [portable]
- Class: HYBRID · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No hard-coded credentials.
- Heuristic: Mechanical: high-entropy regex set — `sk-ant-api03-[A-Za-z0-9]{40,}`, `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9]{36}`, `xoxb-[A-Za-z0-9-]+`, plus `detect-secrets` baseline. Semantic: agent-driven confirmation that flagged tokens are not documentation placeholders.

### R-MEM-1..6, R-MEM-10
- Tags: [reference] / [skill] [claude-code-only] / [portable]
- Class: mostly reference / SEMANTIC · Status: VALIDATED · Scope: project-root (not per-skill)
- Rule: CLAUDE.md hierarchy, anti-duplication, `@AGENTS.md` import canonical form.
- Heuristic: Only enforce at project-root scope. R-MEM-10 mechanical lint: at `<root>/CLAUDE.md`, FAIL if it is a symlink to `<root>/AGENTS.md` or vice versa; PASS if body's first content line is `@AGENTS.md` and `<root>/AGENTS.md` exists.
- Citation: code.claude.com/docs/en/memory.

## Composition — R-COMP-*

### R-COMP-1
- Tags: [skill] [claude-code-only]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Climb the four-layer ladder only when needed: inline → `context: fork` → custom subagent → agent teams.
- Heuristic: deferred to agent-driven checklist.

### R-COMP-2
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No programmatic skill-call construct in SKILL.md.
- Heuristic: Reject body content containing `Skill(...)`-literal, JSON-RPC `Skill` invocations, or `!!!skill ` direct-call markers in plain text.

### R-COMP-3
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: library
- Rule: No cross-skill symlinks; embed-and-duplicate helpers.
- Heuristic: For each `.claude/skills/<skill>/`, `find -type l`; warn if any symlink target resolves outside that skill's folder. Allow intra-skill symlinks.

## Parallelism — R-PAR-*

### R-PAR-1
- Tags: [skill] [claude-code-only]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: `context: fork` is for executable sub-tasks, not reference content.
- Heuristic: Mechanical: if frontmatter contains `context: fork`, scan first 200 body lines for an imperative verb (`Research|Generate|Validate|Run|Analyze|...`). Semantic: agent-driven confirmation the prompt is actionable.

### R-PAR-2
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: warn at >5, fail at >8 · Status: VALIDATED · Scope: per-skill
- Rule: Fan-out 3–5 default, hard ceiling 8.
- Heuristic: Body regex `\b(\d+)\s+(subagents|branches|forks|workers)\b`; fail when N>8, warn when N>5.

### R-PAR-3
- Tags: [skill] [portable]
- Class: SEMANTIC · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Fan-out only when sibling tasks are independent.
- Heuristic: deferred to agent-driven checklist.

### R-PAR-4
- Tags: [reference] [claude-code-only]
- Class: MECHANICAL · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Reference rule documenting `context: fork` inheritance table.
- Heuristic: doc-lint only — ensure bidirectional composition table is present in any spec mentioning `context: fork`.

## Delegation — R-DEL-*

### R-DEL-1
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Composition depth ≤2.
- Heuristic: Parse the skill graph (parent SKILL.md → child via `context: fork` or subagent `skills:[]`); reject chains length >2.

### R-DEL-2
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Subagents listing a skill in `skills:` require that skill not have `disable-model-invocation: true`.
- Heuristic: For every `.claude/agents/<name>.md` with `skills: [S, ...]`, assert S's frontmatter lacks `disable-model-invocation: true`.

### R-DEL-3
- Tags: [skill] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Subagent task brief carries 4 fields (objective, output format, tools/sources whitelist, task boundaries).
- Heuristic: Mechanical: scan subagent body for the four keywords. Semantic: agent-driven confirmation each is concretely populated.

## Conducting — R-CONDUCT-*

### R-CONDUCT-1
- Tags: [skill] [claude-code-only]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Default to implicit, model-mediated conduction.
- Heuristic: deferred to agent-driven checklist — does the body prescribe in-session multi-skill orchestration?

### R-CONDUCT-2
- Tags: [reference] [claude-code-only]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: library
- Rule: `paths` glob overlap is unresolved — design descriptions to disambiguate.
- Heuristic: Mechanical: pairwise textual overlap of `paths` glob patterns across all skills; warn if any token overlap. Semantic: agent-driven confirmation descriptions disambiguate.

### R-CONDUCT-3
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: `disable-model-invocation: true` ⇒ `paths` must be empty.
- Heuristic: If `disable-model-invocation: true` and `paths` is non-empty → fail.

### R-CONDUCT-4
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED — EXPERIMENTAL · Scope: per-skill
- Rule: Mentions of agent-teams require the EXPERIMENTAL caveat.
- Heuristic: If body contains `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` or `agent-teams`, assert the caveat ("v2.1.32+, Opus 4.6+, no nested teams, one team per session") is also present.

## Failure semantics — R-FAIL-*

### R-FAIL-1
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Reference — 25K combined / 5K per-skill re-attach budget.
- Heuristic: doc-lint that any documentation of the budget mentions per-context-window isolation.

### R-FAIL-2
- Tags: [skill] [claude-code-only]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Use `PostToolBatch` (not `PostToolUse`) for parallel-branch fan-in.
- Heuristic: Mechanical: if skill spawns >1 parallel branches (R-PAR-2 trigger), assert orchestration prompt or hooks config mentions `PostToolBatch`. Semantic: agent-driven confirmation of correct fan-in wiring.

### R-FAIL-3
- Tags: [reference] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Subagent failures surface as natural-language summary, not stderr/exit.
- Heuristic: Body scan for claims like "subagent returns exit code" / "subagent stderr is captured" → warn.

### R-FAIL-4
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Reference — sibling-hook exit-2 blocks only its own tool call.
- Heuristic: doc-lint only.

### R-FAIL-5
- Tags: [skill] [claude-code-only]
- Class: HYBRID · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Pre-approve all background-subagent permissions at fan-out.
- Heuristic: Mechanical: if skill spawns a background subagent, verify the spawn site lists explicit `allowed-tools` for every tool the subagent will use (parsed from prompt). Semantic: LLM-judge enumerates likely tools and flags missing pre-approvals.

## Cross-pollination — R-XPOLL-*

### R-XPOLL-1
- Tags: [skill] [portable]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Description in third person; treat as retrieval key.
- Heuristic: Mechanical proxy regex `\b(I |I'll |I can |you can use|use this to)\b` flags first/second-person. Semantic: agent-driven confirmation of clean third-person.

### R-XPOLL-2
- Tags: [skill] [portable]
- Class: HYBRID · Severity: warn · Status: PROPOSED · Scope: per-skill
- Rule: Name pattern recommendation (`-ing` suffix).
- Heuristic: Mechanical: warn if `name` does not end in `-ing`.

### R-XPOLL-3
- Tags: [skill] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Description has both "what" and "when".
- Heuristic: Mechanical "when": same regex as R-XPOLL-5. "What" half deferred to agent-driven checklist.

### R-XPOLL-4
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn at ≥0.85, fail at ≥0.95 · Status: VALIDATED · Scope: library
- Rule: Description-overlap cosine threshold.
- Heuristic: Library mode only. Embed every description via `sentence-transformers/all-MiniLM-L6-v2`; pairwise cosine ≥0.85 → warn, ≥0.95 → fail. Cache by `(model_name, sha256(description))`. Info-level skip when sentence-transformers unavailable.

### R-XPOLL-5
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED (research lists PROPOSED in Q-005 but R-BOUNDARY-7 reaffirms — treat as VALIDATED with strict-default) · Scope: per-skill
- Rule: Description contains trigger-shaped clause.
- Heuristic: `re.search(r"\b(Use when|When the user|Triggered by|Activate when|Use this (skill|when))\b", description, re.IGNORECASE)`.

### R-XPOLL-6
- Tags: [skill] [portable]
- Class: SEMANTIC · Severity: info · Status: VALIDATED · Scope: per-skill
- Rule: Concrete examples; self-update requires external verification signal.
- Heuristic: Mechanical proxy: warn if body has <2 `^### ` headings or no fenced code block. Semantic: agent-driven checklist.

### R-XPOLL-7
- Tags: [reference] [portable]
- Class: SEMANTIC · Severity: info · Status: PROPOSED · Scope: per-skill
- Rule: Consistent terminology; promotion-pass cap of 3 iterations.
- Heuristic: deferred to agent-driven checklist.

### R-XPOLL-8
- Tags: [skill] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED (also overlap-as-PROPOSED in v1.4 docs) · Scope: per-skill
- Rule: Deterministic helper outputs are facts, not observations — no reasoning prose between bash invocation and its output.
- Heuristic: Mechanical: detect ` ```bash` / ` ```sh` blocks immediately followed by reasoning-prose paragraphs (markers: `Now I will check…`, `Let me verify…`) in the same workflow section → warn. Mechanical anti-time-sensitivity regex (added v1.4): `\b(20[12][0-9]|January|February|March|April|May|June|July|August|September|October|November|December)\b` outside fences and outside `<details><summary>Legacy…` → warn.
- Note: research treats the time-sensitivity regex and the ReWOO reasoning-prose detection under the same R-XPOLL-8 id.

### R-XPOLL-9
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: meta-skill-only
- Rule: Validator dogfoods — `<library>/skill-validator/SKILL.md` exists; the validator validates itself.
- Heuristic: Library mode: assert path `<library>/skill-validator/SKILL.md` exists (configurable via `--self-path`). Self-test: validator must validate its own skill folder clean.

### R-XPOLL-10
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: per-skill
- Rule: Keyword-stuffing detection in description.
- Heuristic: Description with 5+ quoted strings AND surrounding prose having fewer words than the quote count → warn; description with 8+ comma-separated short segments (after excluding quotes) → warn.

### R-API-1
- Tags: [reference] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: project-root / deployment
- Rule: Messages API surface limit — ≤8 skills per request.
- Heuristic: If a deployment manifest declares `container.skills`, assert `len(skills) <= 8`. Vacuously true when no manifest.

## Workspace — R-WORKSPACE-*

### R-WORKSPACE-1
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: library
- Rule: Skills are single-depth at every scope.
- Heuristic: `find <scope>/.claude/skills -mindepth 3 -name SKILL.md` returns empty.

### R-WORKSPACE-2
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: project-root
- Rule: Subfolder-launch monorepo uses `--add-dir <root>` or plugin install.
- Heuristic: Reject any rule, settings doc, or skill body prescribing `additionalDirectories` for skill discovery.

### R-WORKSPACE-3
- Tags: [skill] [portable]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: library
- Rule: Plugin distribution canonical for cross-scope sharing.
- Heuristic: Mechanical: detect plugin manifest at `<root>/.claude-plugin/plugin.json`. Semantic: agent-driven check that topology fits T-MONO-1 (≥3 services).

### R-WORKSPACE-4
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: `paths` gates auto-activation only; not a discovery substitute.
- Heuristic: `paths` glob MUST NOT be used to make a skill discoverable from outside `.claude/skills/`; skill must be in a discovered scope.

### R-WORKSPACE-5
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: library
- Rule: Skill-folder symlinks are fragile.
- Heuristic: `os.lstat()` reports symlink at `<scope>/.claude/skills/<name>` → warn.

### R-WORKSPACE-6
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: library
- Rule: Service prefix tolerated, plugin-per-service preferred.
- Heuristic: Skill name matches `<service>-<rest>` AND ≥2 services in same monorepo → suggest plugin-per-service.

## Monorepo — R-MONO-*

### R-MONO-1
- Tags: [skill] [claude-code-only]
- Class: HYBRID · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: Nested-directory auto-discovery is broken in CLI ≥2.1.92.
- Heuristic: Mechanical: detect `--add-dir` flag in launch config. Semantic: agent-driven check that skill body does not assume nested discovery.

### R-MONO-2
- Tags: [skill] [claude-code-only]
- Class: SEMANTIC · Severity: warn · Status: PROPOSED · Scope: library
- Rule: Preferred topology for ≥3-service monorepos.
- Heuristic: deferred to agent-driven checklist.

### R-MONO-3
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Cross-skill router/index links DISCOURAGED.
- Heuristic: Body-link extraction: any markdown link of form `../<other-skill>/SKILL.md` → reject.

### R-MONO-4
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: per-skill
- Rule: Use `find` not `Glob` for `.claude/`-traversal on CLI ≥2.1.92.
- Heuristic: Body-content scan for `Glob` tool invocations targeting `.claude/**` → warn "use `find` instead".

## Shared scripts — R-SHARE-*

### R-SHARE-1
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: library
- Rule: No peer-skill symlinks (embed-and-duplicate non-plugin helpers).
- Heuristic: `find <skills-root> -type l` walking each `.claude/skills/<name>/`; reject any symlink pointing into another skill's folder.

### R-SHARE-2
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No `.claude/scripts/` convention exists.
- Heuristic: Body-content scan for reference to `.claude/scripts/` → reject.

### R-SHARE-3
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: `${CLAUDE_PLUGIN_ROOT}` only in JSON/YAML, not `.md` body.
- Heuristic: Body content scan for literal `${CLAUDE_PLUGIN_ROOT}` outside fenced YAML/JSON blocks → warn "use in JSON/YAML config or pass through script env".

### R-SHARE-4
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Bundled-script references use `${CLAUDE_SKILL_DIR}/…` or `${CLAUDE_PLUGIN_ROOT}/…`.
- Heuristic: Body-content scan: bundled-script references must use one of those two anchors; reject absolute `/abs/...` paths or relative `./…` paths.

## Reference location — R-REFLOC-*

### R-REFLOC-1
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No `..` paths in SKILL.md body or references.
- Heuristic: Body-link extraction; any link containing `..` that resolves outside skill folder → reject.

### R-REFLOC-2
- Tags: [reference] [portable]
- Class: HYBRID · Severity: warn · Status: PROPOSED · Scope: per-skill
- Rule: Repo-docs reuse patterns (a)/(b)/(c)/(d).
- Heuristic: Mechanical: classify link-target placement into pattern. Semantic: agent-driven check pattern matches portability declaration in description.

### R-REFLOC-2(c) clarification
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: No `internal:` frontmatter key (DA-108); use `user-invocable: false` + `paths` instead.
- Heuristic: Frontmatter `internal:` key present → reject.

### R-REFLOC-3
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: If SKILL.md body > 300 lines: `references/_index.md` MUST exist, TOC paths inside skill folder unless description starts with `[internal — not portable]`.
- Heuristic: body line count > 300 ⇒ presence + path-resolution check on `references/_index.md`.

### R-REFLOC-4
- Tags: [reference] [claude-code-only]
- Class: MECHANICAL · Severity: warn · Status: VALIDATED · Scope: per-skill
- Rule: `paths` is not a content-loading mechanism.
- Heuristic: `paths` matches `docs/**` AND body has zero links to `references/` → warn.

### R-REF-FM-1
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: PROPOSED (MAY) · Scope: per-skill
- Rule: Reference frontmatter restricted to `{title, summary, load_when}`.
- Heuristic: For any `<skill>/references/*.md` with YAML frontmatter, fail if keys outside the whitelist.

### R-REF-SUPERSEDE-1
- Tags: [reference] [portable]
- Class: SEMANTIC · Severity: info · Status: PROPOSED (MAY) · Scope: per-skill
- Rule: Deprecated reference content retained under `<details><summary>Legacy …</summary>…</details>`.
- Heuristic: deferred to agent-driven checklist.

### R-REF-SECRETS-1
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: per-skill
- Rule: Reference files SHOULD NOT contain credentials/PII.
- Heuristic: Same secret-pattern scan as R-MEM-9 applied to `references/**`.

### R-REF-SHARE-1
- Tags: [skill] [portable]
- Class: MECHANICAL · Severity: warn · Status: PROPOSED · Scope: library
- Rule: Cross-skill ref-doc sharing follows R-SHARE-1 ladder.
- Heuristic: For plugin-bundled skills, allow symlink whose target resolves under plugin root; otherwise embed-and-duplicate.

### R-LOG-REJECT
- Tags: [reference] [portable]
- Class: MECHANICAL · Severity: fail · Status: PROPOSED (MUST NOT) · Scope: per-skill
- Rule: No runtime `log.md` in `references/`.
- Heuristic: `<skill>/references/log.md` (or any `log.*` append-only file) exists → reject.

## Cross-cutting canary — R-CROSS-1

### R-CROSS-1
- Tags: [skill] [claude-code-only]
- Class: MECHANICAL · Severity: fail · Status: VALIDATED · Scope: per-skill
- Rule: Hallucination canary — reject `${CLAUDE_SKILLS_PATH}`, `skillsDirectories`, `Bun.Glob` direct invocation, `internal: true` frontmatter, `.claude/skill-memories/`, `injection.py`.
- Heuristic: Body + frontmatter + scripts scan for any of those tokens → reject.

## Self-update governance

### R-RETRO-1
- Tags: [skill] [portable] · MECHANICAL · info · VALIDATED · per-skill
- Rule: Retrospective fires on `Stop` / `SessionEnd`; `SessionEnd` MUST NOT carry merge step.
- Heuristic: lint meta-skill frontmatter `hooks:`; reject `SessionEnd` hooks running merge actions.

### R-RETRO-2
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: Stop-hook checks `stop_hook_active` and exits 0 when true.
- Heuristic: Static analysis of Stop-hook script: pattern `if .*stop_hook_active.*: exit 0` or JSON-output equivalent.

### R-RETRO-3
- Tags: [skill] [portable] · SEMANTIC · info · VALIDATED · per-skill
- Rule: User correction is inferred from transcript, not a programmatic event.
- Heuristic: deferred to agent-driven checklist.

### R-RETRO-4
- Tags: [skill] [portable] · MECHANICAL · warning · VALIDATED · per-skill
- Rule: Stop/SubagentStop retrospective hooks SHOULD use `type: prompt` or `type: agent`.
- Heuristic: Frontmatter `hooks:` declaration check.

### R-RETRO-5
- Tags: [skill] [portable] · MECHANICAL · info · PROPOSED · per-skill
- Rule: Async retrospective writes preferred; sync ceiling <30s.
- Heuristic: If `async: true` absent and timeout unset, warn if implied sync ceiling exceeds 30s.

### R-RETRO-6
- Tags: [skill] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill
- Rule: `once: true` honored only in skill/plugin frontmatter.
- Heuristic: Validator confirms `once: true` not used in settings.json/agent frontmatter.

### R-SELF-1
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: Routine retros write to `references/gotchas.md`, not SKILL.md body.
- Heuristic: Reject retro commits diffing SKILL.md body without explicit behavioral-correction flag in commit message.

### R-SELF-2
- Tags: [skill] [portable] · HYBRID · warning · VALIDATED · per-skill
- Rule: Body edits only for behavioral corrections; require minor version bump (R-VC-2).
- Heuristic: Detect body diff in retro commit; require user-accept gate (procedural).

### R-SELF-3
- Tags: [skill] [portable] · MECHANICAL · warning · VALIDATED · per-skill
- Rule: No `errata/` at skill root; use `references/`.
- Heuristic: `<skill>/errata/` exists → warn (fail if skill tagged `[portable]`).

### R-SELF-4
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: `gotchas.md` entries include date, trigger event, evidence anchor, proposed fix, status.
- Heuristic: Each entry must contain regex-matchable date + trigger-event ∈ {Stop, SessionEnd, PostToolUseFailure, inferred} + evidence + status ∈ {PROPOSED, VALIDATED, PROMOTED, RETIRED}.

### R-SELF-5
- Tags: [skill] [claude-code-only] · MECHANICAL · error · VALIDATED · per-skill
- Rule: Pending-retro path is `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/<skill>-<timestamp>.diff`.
- Heuristic: Reject writes outside this path for any retro of a `disable-model-invocation: true` skill.

### R-DRIFT-1
- Tags: [skill] [portable] · MECHANICAL · info · VALIDATED · per-skill
- Rule: After N=3 accepted retros, invoke skill-creator description-optimization pass.
- Heuristic: Counter file `${CLAUDE_PLUGIN_DATA}/<plugin>/retro-counters.json`; verify trigger fired and optimization completed.

### R-DRIFT-2
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: New description must not regress on held-out test (40% split).
- Heuristic: Parse skill-creator log; reject regressions.

### R-DRIFT-3
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: Description ≤1024 chars; no errata digest appended.
- Heuristic: Same as R-FM-3 raw char count.

### R-DRIFT-4
- Tags: [skill] [portable] · MECHANICAL · warning · PROPOSED · per-skill
- Rule: No hidden frontmatter fields like `applies_to_examples`.
- Heuristic: Frontmatter keys outside live schema → warn; specific known-hallucinated names → error.

### R-DRIFT-5
- Tags: [skill] [portable] · SEMANTIC · error · VALIDATED · per-skill
- Rule: Description regen preserves original `when_to_use` scope-set.
- Heuristic: deferred to agent-driven checklist (or NLI in R-DRIFT-5-IMPL).

### R-EXTRACT-1
- Tags: [skill] [portable] · MECHANICAL · info · PROPOSED · per-skill
- Rule: Same script reused N≥3 in one session or ≥3 sessions in 14d → extraction trigger.
- Heuristic: Hash-equivalent script-content tracking across transcripts.

### R-EXTRACT-2
- Tags: [skill] [portable] · MECHANICAL · info · VALIDATED · per-skill
- Rule: Extraction performed by skill-creator.
- Heuristic: Confirm new skill scaffolded under R-SYS-1 / R-NAME-1/2 conventions.

### R-EXTRACT-3
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: Newly extracted skill passes ≥20-prompt trigger eval before marketplace publication.
- Heuristic: Eval log archived under `${CLAUDE_PLUGIN_DATA}/<plugin>/extract-evals/`.

### R-DESTRUCT-1
- Tags: [skill] [claude-code-only] · MECHANICAL · error · VALIDATED · per-skill
- Rule: `disable-model-invocation: true` retros do not auto-apply.
- Heuristic: Any retro auto-merge attempt against such a skill → reject; require pending-diff path + user invocation.

### R-DESTRUCT-2
- Tags: [skill] [portable] · MECHANICAL · warning · VALIDATED · meta-skill-only
- Rule: Meta-skill merge subcommand uses `disable-model-invocation: true`.
- Heuristic: If meta-skill has `--apply-retro` (or equivalent) without `disable-model-invocation: true` → warn.

### R-DESTRUCT-3
- Tags: [skill] [claude-code-only] · MECHANICAL · error · VALIDATED · meta-skill-only
- Rule: No raw shell `patch`/`sed`/`awk` in merge subcommand source.
- Heuristic: AST scan of merge-execution path; any `subprocess.run(["patch", ...])`/`sed`/`awk` invocation → reject. Edit-tool or pre-compiled `bin/` binary required.

### R-VC-1
- Tags: [skill] [portable] · MECHANICAL · warning · PROPOSED · per-skill
- Rule: Self-update commits use prefix `skill(retro): <skill-name> <YYYY-MM-DD>`.
- Heuristic: Commit-message regex; pre-commit hook.

### R-VC-2
- Tags: [skill] [portable] · MECHANICAL · warning · PROPOSED · per-skill
- Rule: Semver bump matches diff scope: `references/`-only → patch; body → minor; description → major.
- Heuristic: Map diff scope to semver delta; mismatch → warn.

### R-VC-3
- Tags: [skill] [portable] · MECHANICAL · error · VALIDATED · per-skill
- Rule: Self-modifications land on `skill/auto-update`, not `main`.
- Heuristic: Branch-target check at merge time.

### R-ROLLBACK-1
- Tags: [skill] [portable] · MECHANICAL · warning · VALIDATED · per-skill
- Rule: Pre-retro git tag `pre-retro-<skill>-<YYYYMMDD>` must exist.
- Heuristic: `git tag --list "pre-retro-<skill>-*"` non-empty before merge.

### R-ROLLBACK-2
- Tags: [skill] [portable] · MECHANICAL+procedural · error · VALIDATED · per-skill
- Rule: After revert, re-validate; second consecutive failure → mark `health: degraded`.
- Heuristic: pass/fail counter + health-flag write.

### R-ROLLBACK-3
- Tags: [skill] [portable] · MECHANICAL · error · PROPOSED · per-skill
- Rule: ≤1 merge / ≤3 attempts per skill per session.
- Heuristic: `${CLAUDE_PLUGIN_DATA}/<plugin>/retro-counters.json`.

### R-ROLLBACK-4
- Tags: [skill] [portable] · MECHANICAL+expensive · warning · PROPOSED · per-skill
- Rule: Retro touching shared reference re-runs dependent skills' evals; regression blocks.
- Heuristic: Graph-traversal cache between merges.

### R-ROLLBACK-5
- Tags: [skill] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill
- Rule: Marketplace skills' `version:` matches a `v<major>.<minor>.<patch>` git tag.
- Heuristic: `git tag --list "v[0-9]*.*.*"` membership check.

## Boundary — R-BOUNDARY-*

### R-BOUNDARY-1
- Tags: [skill] [portable] · SEMANTIC · warning · VALIDATED · project-root
- Rule: Multi-step procedures live in SKILL.md, not CLAUDE.md/AGENTS.md.
- Heuristic: Scan CLAUDE.md/AGENTS.md for numbered procedural steps; warn (subject to agent-driven semantic judgment).

### R-BOUNDARY-2
- Tags: [reference] [portable] · MECHANICAL · warning · VALIDATED · per-skill
- Rule: Long-form descriptive material lives in `<skill>/references/<topic>.md`, one markdown-link hop.
- Heuristic: Inherits R-CHUNK-4 v1.14 graph check.

### R-BOUNDARY-3
- Tags: [skill] [claude-code-only] · MECHANICAL · WARN (not FAIL) · VALIDATED · project-root
- Rule: `<root>/CLAUDE.md` target ≤200 lines (adherence target, not truncation cap per DA-140).
- Heuristic: `<root>/CLAUDE.md` non-blank line count > 200 → warn. Message MUST NOT imply truncation; only adherence-quality risk.

### R-BOUNDARY-4
- Tags: [skill] [portable] · MECHANICAL · fail · VALIDATED · project-root
- Rule: `@AGENTS.md` is the first content line of `<root>/CLAUDE.md` when present.
- Heuristic: LINT-Q015-11. If `<root>/CLAUDE.md` body contains `@AGENTS.md` AND that token is preceded by any non-frontmatter, non-HTML-comment, non-blank line → fail.

### R-BOUNDARY-5
- Tags: [reference] [portable] · SEMANTIC · info · VALIDATED · project-root
- Rule: Repo docs (`README.md`, `ARCHITECTURE.md`, ADR, runbooks) referenced, not duplicated.
- Heuristic: deferred to agent-driven checklist.

### R-BOUNDARY-6
- Tags: [skill] [claude-code-only] · MECHANICAL · fail · VALIDATED · per-skill
- Rule: Skills MUST NOT carry an AGENTS-equivalent file or be `@`-imported / symlinked to one.
- Heuristic: Reject `<skill>/AGENTS.md`; reject any symlink from a skill root to an AGENTS-named target.

### R-BOUNDARY-7
- Tags: [skill] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- Rule: Description encodes what + when; ≤1024 chars; third person. Reaffirms R-FM-3 + R-XPOLL-5 + R-BODY-9.
- Heuristic: combine R-FM-3 + R-XPOLL-5 + R-BODY-9.

### R-BOUNDARY-8
- Tags: [skill] [claude-code-only] · SEMANTIC · info · VALIDATED · project-root
- Rule: Knowledge needed ≥~50% of sessions in CLAUDE.md; <~50% in a skill.
- Heuristic: deferred to agent-driven checklist.

### R-BOUNDARY-9
- Tags: [reference] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- Rule: Reference files >100 non-blank lines must include a ToC near the top (within first 30 non-blank lines).
- Heuristic: LINT-Q015-10. Equivalent to R-CHUNK-1 + R-BODY-4 at the 100-line threshold.

## System organization — R-SYS-*, R-IDX-1

### R-SYS-1
- Tags: [reference] [claude-code-only] · MECHANICAL · fail · VALIDATED · library
- Rule: Skills folders are single-depth.
- Heuristic: Same as R-WORKSPACE-1.

### R-SYS-2
- Tags: [reference] [claude-code-only] · MECHANICAL · info · VALIDATED · project-root
- Rule: Skills precedence: enterprise > personal > project; plugin namespaced.
- Heuristic: Doc lint; warn if CLAUDE.md asserts inverse direction.

### R-SYS-3
- Tags: [reference] [claude-code-only] · MECHANICAL · fail · VALIDATED · library
- Rule: No top-level skills index file (`index.md`, `skills.json` at root).
- Heuristic: Reject existence of `<skills-root>/index.md` or `<skills-root>/skills.json`.

### R-SYS-4
- Tags: [skill] [portable] · MECHANICAL · warn · VALIDATED · per-skill
- Rule: Split a skill at >500 lines OR mutually-exclusive variants.
- Heuristic: Combine R-BODY-1 line count + R-CTX-2 mutually-exclusive paths semantic check.

### R-SYS-5
- Tags: [skill] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill
- Rule: Cross-skill composition uses subagent `skills:` preload OR `context: fork`.
- Heuristic: Doc lint.

### R-IDX-1
- Tags: [reference] [portable] · MECHANICAL · info · PROPOSED (MAY) · per-skill
- Rule: A skill MAY include `references/_index.md` when ≥3 ref files OR >5K total lines.
- Heuristic: If `references/_index.md` exists, each entry must carry a `load this when…` descriptor mirroring R-SR-5.

## Helpers — R-HELP-*

### R-HELP-1..7
- Tags: [skill] [portable]
- Class: mostly SEMANTIC · Severity: info · Status: VALIDATED (R-HELP-1 location validated, Python preference proposed) · Scope: per-skill
- Rule (combined): Scripts at `<skill>/scripts/<verb_object>.py`; stable CLI; documented invocation; `${CLAUDE_SKILL_DIR}/scripts/<file>` paths; `allowed-tools` pre-approval; extract-when-repeated; `#!/usr/bin/env python3` shebang.
- Heuristic: deferred to agent-driven checklist plus the script-path mechanical check in R-SHARE-4.
- Validator self-test rule (research line 1906): in CI, run `validate.py skill-validator/ 2>summary.txt 1>output.json`; assert summary.txt non-empty and output.json valid JSON. Enforces stdout=JSON / stderr=human split.

## Meta-skill — R-META-*

### R-META-1
- Tags: [skill] [claude-code-only] · SEMANTIC · info · VALIDATED · meta-skill-only
- Rule: Meta-skill (`skill-creator`) conforms to the same spec it generates.
- Heuristic: deferred to agent-driven checklist; validator self-test runs against meta-skill.

### R-META-2
- Tags: [reference] [portable] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: Frontmatter trigger-rich `description` ≤1024 chars; whitelist `{name, description, license, allowed-tools, metadata}`.
- Heuristic: R-FM-1 + R-FM-3 + R-FM-6 with `--surface skills-api` profile.

### R-META-3
- Tags: [skill] [portable] · MECHANICAL · fail · PROPOSED · meta-skill-only
- Rule: Declarative spec validates against JSON Schema before any LLM authorship.
- Heuristic: `jsonschema.validate(spec, SKILL_SPEC_SCHEMA)` in compile pipeline.

### R-META-4
- Tags: [skill] [claude-code-only] · SEMANTIC · info · PROPOSED · meta-skill-only
- Rule: Compiler step has 7-stage strict order (scaffold → frontmatter → body → description → optimize → validate).
- Heuristic: deferred to agent-driven checklist.

### R-META-5
- Tags: [skill] [portable] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: Scaffold drops minimum SKILL.md + `evals/evals.json`; conditional `scripts/`, `references/`, `assets/` only on `needs.*`.
- Heuristic: After scaffold, verify required files exist and optional subfolders gated on spec.

### R-META-6
- Tags: [skill] [portable] · SEMANTIC · info · VALIDATED · meta-skill-only
- Rule: Elicitation = exactly 4 prompts (what / when / output / evals).
- Heuristic: deferred to agent-driven checklist on `elicitation-flow.md`.

### R-META-7
- Tags: [skill] [portable] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: Validator runs at two gates (creation, finalization); meta-skill body invokes validator.
- Heuristic: Assert `.pre-commit-config.yaml` references `skill-validator` AND `skill-creator/SKILL.md` body invokes `scripts/validate.py`.

### R-META-8
- Tags: [reference] [portable] · MECHANICAL · info · VALIDATED · meta-skill-only
- Rule: Iteration cap = 3 for body refinement and description optimization.
- Heuristic: Static check on compile pipeline.

### R-META-9
- Tags: [skill] [portable] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: External verification = validator PASS AND user accept; no silent auto-fix; no `--fix`.
- Heuristic: AST scan of `validate.py`: no `os.replace`, `shutil.move`, `Path.write_text` outside guards on `args.fix`; `args.fix` itself is reserved as hard error.

### R-META-10
- Tags: [reference] [portable] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: Deterministic helpers do not import LLM SDKs.
- Heuristic: AST scan of validator: no imports of `anthropic`, `openai`, `requests` (whitelist `sentence_transformers` first-run download).

### R-META-11
- Tags: [skill] [claude-code-only] · SEMANTIC · info · PROPOSED · meta-skill-only
- Rule: Meta-skill bundles ZERO example skills; retrieves user's prior skills by embedding.
- Heuristic: deferred to agent-driven checklist.

### R-META-12
- Tags: [skill] [claude-code-only] · SEMANTIC · info · PROPOSED · meta-skill-only
- Rule: 3-tier curriculum gated on prior-skill count (0 / 1–9 / 10+).
- Heuristic: deferred to agent-driven checklist.

### R-META-13
- Tags: [skill] [portable] · MECHANICAL · warn · VALIDATED · meta-skill-only
- Rule: Compiler emits `description` of form `"<verb-phrase>. Use when <utterance triggers>."`.
- Heuristic: regex match against output description; warn if no `Use when` clause.

### R-META-14
- Tags: [skill] [claude-code-only] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: Meta-skill body ≤400 lines (stricter than R-BODY-1's 500).
- Heuristic: line count > 400 → fail, applied when `--meta-skill` or folder name in `{skill-creator}`.

### R-META-15
- Tags: [skill] [portable] · MECHANICAL · info · VALIDATED · meta-skill-only
- Rule: Eval set = 3 behavioral + 20 trigger (10 should / 10 should-not).
- Heuristic: Parse `evals/evals.json`; verify counts.

### R-META-16
- Tags: [skill] [portable] · SEMANTIC · info · PROPOSED · meta-skill-only
- Rule: At least 1 behavioral example is negative counter-example.
- Heuristic: deferred to agent-driven checklist.

### R-META-17
- Tags: [skill] [portable] · SEMANTIC · info · PROPOSED · meta-skill-only
- Rule: Synthetic-bootstrap → organic-trace lifecycle; `--inject-trace` swaps in real execution traces.
- Heuristic: deferred to agent-driven checklist.

### R-META-18
- Tags: [reference] [claude-code-only] · MECHANICAL · fail · PROPOSED · meta-skill-only
- Rule: Refuse benchmark publication when (a) Bash unavailable in `without_skill` baseline, (b) `grading.json` outside `<eval-name>/<config>/`, or (c) aggregate script glob mismatches.
- Heuristic: Pre-publish file-tree assertions.

### R-META-19
- Tags: [skill] [portable] · MECHANICAL · fail · VALIDATED · meta-skill-only
- Rule: Meta-skill `allowed-tools` includes `Bash` OR body has literal preflight `command -v bash`.
- Heuristic: Frontmatter+body presence check.

## Loading verification — R-LOAD-*

### R-LOAD-1
- Tags: [skill] [loading] · MECHANICAL · error · PROPOSED · per-skill
- Rule: Each skill contains a unique canary phrase in body or referenced file.
- Heuristic: Pattern match for `^[A-Z0-9-]{8,}` or UUID4 in body; uniqueness across the library.

### R-LOAD-2
- Tags: [skill] [loading] · MECHANICAL · error · PROPOSED · per-skill
- Rule: ≥1 negative-control test (folder rename or `disable-model-invocation: true` toggle).
- Heuristic: Parse `evals/loading_verification.json`; ≥1 entry of `type: negative_control`.

### R-LOAD-3
- Tags: [skill] [loading] · MECHANICAL · error · PROPOSED · per-skill
- Rule: "List your loaded skills" probe forbidden as the only verification.
- Heuristic: Regex match test queries against `\b(list (your )?loaded skills|tell me which skills)\b`; reject if no canary/negative-control exists alongside.

### R-LOAD-4
- Tags: [skill] [loading] · MECHANICAL · warn · PROPOSED · per-skill
- Rule: Bifurcated permission for hook-based introspection.
- Heuristic: Warn if `PostToolUse matcher: "Skill"` or `InstructionsLoaded` for skills is configured; `PreToolUse matcher: "Skill"` permitted but advisory-only.

### R-LOAD-5
- Tags: [skill] [loading] · MECHANICAL · error · PROPOSED · per-skill
- Rule: `evals/loading_verification.json` exists and conforms to schema.
- Heuristic: jsonschema validation against `{skill_name, verifications[{type, query, expected_canary?, must_appear, rename_to?}]}`.

### R-LOAD-6
- Tags: [skill] [loading] · MECHANICAL · error · PROPOSED · per-skill
- Rule: ≥1 canary AND ≥1 negative-control entry in `loading_verification.json`.
- Heuristic: Count by `type`.

### R-LOAD-7
- Tags: [skill] [loading] · MECHANICAL · warn · PROPOSED · per-skill
- Rule: Both `evals/evals.json` (trigger-rate) AND `evals/loading_verification.json` present.
- Heuristic: Presence check.

## LLM-judge — R-LLMJ-*

All R-LLMJ-1..12 are PROPOSED Q-008 rules governing the judge harness. Tag: `[skill] [judge]`.

### R-LLMJ-1
- MECHANICAL · error · PROPOSED · cadence/judge
- Rule: Judge tier is `downstream`; pre-commit hook MUST NOT reference judge binary.
- Heuristic: Config lint.

### R-LLMJ-2
- MECHANICAL · error · PROPOSED
- Rule: Judge output `verdict` ∈ `{pass, warn, fail}` (no Likert/numeric).
- Heuristic: Schema lint.

### R-LLMJ-3
- SEMANTIC · error · PROPOSED
- Rule: Per-rule judge prompt has task intro + pinned eval steps + structured JSON output schema.
- Heuristic: G-Eval smoke test; semantic check by judge self-test.

### R-LLMJ-4
- MECHANICAL · error · PROPOSED
- Rule: `samples: 3`, `aggregation: majority_vote`.
- Heuristic: Config lint.

### R-LLMJ-5
- MECHANICAL · warn · PROPOSED
- Rule: Default `model: claude-sonnet-4-6`; Opus 4.7 requires `--high-precision` opt-in.
- Heuristic: Config lint.

### R-LLMJ-6
- MECHANICAL · error · PROPOSED
- Rule: Default `mode: pointwise`; `pairwise` only for `R-DRIFT-5`.
- Heuristic: Config lint.

### R-LLMJ-7
- MECHANICAL · error · PROPOSED
- Rule: Judge output JSON schema: `{rule_id, verdict, critique, samples[]}`.
- Heuristic: jsonschema validation.

### R-LLMJ-8
- HYBRID · error · PROPOSED
- Rule: Each rule ships `calibration/` with ≥10 hand-labelled examples; TPR/TNR ≥ 0.80.
- Heuristic: presence + metric thresholds; semantic: judge self-rates calibration.

### R-LLMJ-9
- MECHANICAL · warn · PROPOSED
- Rule: Validator wraps judge calls in DSPy-Suggest shape (soft); not `Assert`.
- Heuristic: AST lint.

### R-LLMJ-10
- SEMANTIC · error · PROPOSED
- Rule: Judge prompt MUST NOT evaluate domain-content factuality, runtime correctness, or any mechanical rule.
- Heuristic: pre-flight check against rule-id allow-list.

### R-LLMJ-11
- MECHANICAL · warn · PROPOSED
- Rule: Per-skill audit budget ≤30K input + ≤6K output tokens.
- Heuristic: telemetry per audit run.

### R-LLMJ-12
- HYBRID · error · PROPOSED
- Rule: Body delimited with `<untrusted_data>…</untrusted_data>` tags in judge prompt.
- Heuristic: template lint; semantic: judge audit-pass verifies no instruction-following.

## Cadence — R-CADENCE-*

All R-CADENCE-* are PROPOSED Q-008 rules; `[skill] [cadence]`.

### R-CADENCE-1 · MECHANICAL · warn · PROPOSED
- Rule: Cadence config defines monthly + quarterly + on-demand tiers.
- Heuristic: Config presence.

### R-CADENCE-2 · MECHANICAL · warn · PROPOSED
- Rule: Cadence implementation is Routines (primary) or GitHub Actions cron (fallback).
- Heuristic: Config lint.

### R-CADENCE-3 · MECHANICAL · error · PROPOSED
- Rule: Off-cadence triggers configured for 5 events (skill-creator minor; validator major; ≥3 ROLLBACK; XPOLL-8 overlap; freshly-applied retro failure).
- Heuristic: Config lint per trigger.

### R-CADENCE-4 · MECHANICAL · error · PROPOSED
- Rule: Each run emits `review-report.json` v1.0 schema.
- Heuristic: jsonschema validation.

### R-CADENCE-5 · MECHANICAL · warn · PROPOSED
- Rule: Quarterly tier tags Conventional-Commits release `v<major>.<minor>.0-rules` on rule change.
- Heuristic: `git tag --list` membership check.

## AutoDream — R-AUTODREAM-*

### R-AUTODREAM-1
- Tags: [reference] [claude-code-only] · SEMANTIC · info · VALIDATED · project-root
- Rule: AutoDream operates on `~/.claude/projects/<slug>/memory/`; durable user constraints belong in CLAUDE.md/AGENTS.md, not MEMORY.md.
- Heuristic: deferred to agent-driven checklist.

### R-AUTODREAM-2
- Tags: [reference] [claude-code-only] · SEMANTIC · info · PROPOSED · project-root
- Rule: AutoDream gated by `tengu_onyx_plover` GrowthBook flag + `autoDreamEnabled` setting.
- Heuristic: documentation-only; no validation action.

### R-AUTODREAM-3
- Tags: [reference] [portable] · SEMANTIC · info · VALIDATED · project-root
- Rule: AutoDream is orthogonal to Task Budgets, auto-compaction, R-FAIL-1 re-attach pool.
- Heuristic: doc lint flagging cross-pollution language.

### R-AUTODREAM-4
- Tags: [reference] [claude-code-only] · SEMANTIC · info · PROPOSED · project-root
- Rule: Refer to the consolidator as "AutoDream"; KAIROS is umbrella for proactive autonomous-agent mode.
- Heuristic: doc lint.

## AutoDream-adjacent

### R-MEM-1-CLARIFICATION
- Tags: [reference] [claude-code-only] · SEMANTIC · info · VALIDATED · project-root
- Rule: R-MEM-1 hierarchy is cross-container only; AutoDream MAY rewrite user-reinforced entries within MEMORY.md.
- Heuristic: doc lint; recommend `autoDreamEnabled: false` if `MEMORY.md`-only constraints are detected.

## Contamination — R-CONTAM-1

### R-CONTAM-1
- Tags: [skill] [portable] · HYBRID · warn at ≥0.5 · PROPOSED · per-skill
- Rule: Cross-language contamination via 3-factor formula = multi_interface_tools(0.3) + language_mismatch(0.4) + scope_breadth(0.3).
- Heuristic: Mechanical proxy via language-category mapping; verdict deferred to agent-driven checklist for high scores.

---

## Notes on conflicts and ambiguity

- **R-BODY-4 vs R-CHUNK-1.** Both target ToC at reference-file thresholds. R-BODY-4 (v1.4) uses 100 lines, R-CHUNK-1 uses 100 lines too — they agree post-v1.4. Treat as one check (R-CHUNK-1 supersedes; R-BODY-4 retained for back-compat citations).
- **R-BODY-3 prose vs validation-table.** Skill-spec prose says "no required headings"; validation-table assigns the rule-id to Windows-backslash-path detection. Keep the lint for the backslash check; the structural recommendation is advisory only.
- **R-BOUNDARY-3 strict reading.** DA-140 explicitly rejects truncation framing. Lint MUST emit WARN (not FAIL), MUST NOT imply truncation.
- **R-XPOLL-8 dual semantics.** Research uses the same rule-id for the ReWOO reasoning-prose detector AND for the time-sensitive-content regex (v1.4). Implement both under one check; emit two distinct messages.
- **R-XPOLL-5 status.** Validation-table marks PROPOSED (Q-005 false-positive concern); skill-spec marks VALIDATED; R-BOUNDARY-7 reaffirms canonical Anthropic anchor. Treat as VALIDATED in `claude-code` profile; toggle via `--strict`.
- **R-FAIL-1 budget figures.** 25K combined / 5K per-skill stand on a single Tier-1 source per Q-018; lint MUST mention per-context-window isolation when documenting.
