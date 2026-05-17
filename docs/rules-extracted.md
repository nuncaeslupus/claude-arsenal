# Skill System Rule Catalog (extracted from claude-skill-system v1.17)

This is a derived view of `tmp/claude-skill-system_v1.17.md`. The research doc is the source of truth — when in doubt, read the rule's full statement there.

Each rule is tagged:

- **Tags:** [skill] (procedural) / [reference] (factual); [portable] / [claude-code-only]
- **Class:** MECHANICAL (deterministic check) · SEMANTIC (LLM/agent judgment) · HYBRID
- **Severity:** fail · warn · info
- **Status:** VALIDATED · PROPOSED
- **Scope:** per-skill · library (cross-skill) · meta-skill-only · project-root · cadence/judge

The validator-aligned, more terse twin of this file lives at `skills/skill-validator/references/rule-catalog.md`.

## Table of contents

- [Per-skill rules](#per-skill-rules)
  - [Frontmatter (R-FM-*)](#frontmatter-r-fm-)
  - [Body (R-BODY-*, R-CTX-*)](#body-r-body--r-ctx-)
  - [Naming (R-NAME-*)](#naming-r-name-)
  - [Skill vs reference content (R-SR-*, R-REF-*, R-LOG-REJECT)](#skill-vs-reference-content-r-sr-)
  - [References & chunking (R-CHUNK-*, R-LAZYLOAD-*)](#references-and-chunking-r-chunk-)
  - [Memory & security (R-MEM-7..9)](#memory-and-security-r-mem-7-9)
  - [Composition (R-COMP-*)](#composition-r-comp-)
  - [Parallelism (R-PAR-*)](#parallelism-r-par-)
  - [Delegation (R-DEL-*)](#delegation-r-del-)
  - [Conducting (R-CONDUCT-*)](#conducting-r-conduct-)
  - [Failure semantics (R-FAIL-*)](#failure-semantics-r-fail-)
  - [Self-update (R-RETRO-*, R-SELF-*, R-DRIFT-*, R-EXTRACT-*, R-DESTRUCT-*, R-VC-*, R-ROLLBACK-*)](#self-update-rules)
  - [Cross-pollination single-skill (R-XPOLL-1/2/3/5/6/7/8/10)](#cross-pollination-single-skill)
  - [System organization (R-SYS-*, R-IDX-1)](#system-organization-r-sys-)
  - [Helpers (R-HELP-*)](#helpers-r-help-)
  - [Loading verification (R-LOAD-*)](#loading-verification-r-load-)
- [Library / cross-skill rules](#library-cross-skill-rules)
  - [Description disambiguation (R-XPOLL-4)](#description-disambiguation-r-xpoll-4)
  - [Workspace topology (R-WORKSPACE-*, R-MONO-*)](#workspace-topology-r-workspace--r-mono-)
  - [Shared scripts (R-SHARE-*)](#shared-scripts-r-share-)
  - [Reference location (R-REFLOC-*, R-REF-SHARE-1)](#reference-location-r-refloc-)
  - [Hallucination canaries (R-CROSS-1)](#hallucination-canaries-r-cross-1)
  - [Cross-skill composition (R-COMP-3, R-CONDUCT-2)](#cross-skill-composition)
- [Meta-skill-only rules (R-META-*, R-XPOLL-9)](#meta-skill-only-rules-r-meta--r-xpoll-9)
- [Project-root rules (R-BOUNDARY-1..9, R-MEM-1..6, R-MEM-10, R-AUTODREAM-*)](#project-root-rules)
- [Governance / cadence (R-LLMJ-*, R-CADENCE-*, R-LOAD-* governance)](#governance-cadence)
- [API surface (R-API-1)](#api-surface-r-api-1)
- [Discarded-Alternatives reminders (DA-*)](#discarded-alternatives-reminders)
- [Conflicts and ambiguity](#conflicts-and-ambiguity)

---

## Per-skill rules

### Frontmatter (R-FM-*)

#### R-FM-1 — require name and description
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Both `name` and `description` MUST be present and non-empty in YAML frontmatter.
- **Heuristic:** Open as UTF-8 (errors=`strict`); require leading `---\n` and closing `\n---\n` fence; pass body to `yaml.safe_load`. Reject if not dict or `name`/`description` missing/empty after `.strip()`.
- **Why:** Both are the routing surface — `name` is the slash-command, `description` is the retrieval key.
- **Source:** agentskills.io; platform.claude.com Agent Skills overview.

#### R-FM-2 — name kebab-case, ≤64 chars, not reserved
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** `name` matches `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 chars, equals the folder name, and is not in `{anthropic, claude, mcp, agent}`.
- **Heuristic:** regex + length + reserved-list check.
- **Why:** Reserved-word skills shadow native slash commands; non-kebab names break filesystem invariants.
- **Source:** Anthropic API rule; claude-code Issue #44199.

#### R-FM-3 — description ≤1024 chars, non-empty
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** `description` is non-empty, ≤1,024 Unicode code points, and contains both what + when.
- **Heuristic:** `len(description.strip()) > 0 and len(description) <= 1024`. What/when content is enforced by R-XPOLL-5 and R-BODY-9.
- **Why:** The listing is truncated past 1024; front-loaded triggers determine routing.
- **Source:** platform.claude.com agent-skills/best-practices.

#### R-FM-4 — description + when_to_use ≤1536 chars (Claude Code)
- **Tags:** [skill] [claude-code-only]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** When `when_to_use` is present, combined `description` + `when_to_use` ≤1,536 chars.
- **Heuristic:** Sum lengths; vacuous when `when_to_use` absent.
- **Why:** Avoids truncation in the `<available_skills>` block. Override via `SLASH_COMMAND_TOOL_CHAR_BUDGET`.
- **Source:** code.claude.com/docs/en/skills frontmatter table (v1.5).

#### R-FM-5 — no XML brackets, no manual namespace
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** No `<` or `>` in any frontmatter string. No `/` in `name` — plugin distribution handles namespacing automatically.
- **Heuristic:** Walk frontmatter recursively (including `metadata`); regex-check each string value.
- **Why:** XML brackets inject instructions; manual `org/skill` prefixes break loading silently.

#### R-FM-6 — frontmatter key allow-list
- **Tags:** [skill] [claude-code-only]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Frontmatter keys are limited to the surface's allow-list.
- **Heuristic:** `set(frontmatter.keys()) ⊆ ALLOWED[surface]`. Surfaces: `skills-api` (5 keys: name, description, license, allowed-tools, metadata), `claude-code` (15 keys: name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell), `both` (permissive union).
- **Why:** Unexpected keys break Claude.app import (anthropics/skills Issue #37).
- **Source:** code.claude.com/docs/en/skills (fetched 2026-05-02).

#### R-FM-7 — allowed-tools declares CLI pre-approval
- **Tags:** [skill] [claude-code-only]
- **Class:** MECHANICAL · **Severity:** info · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** `allowed-tools` declares deterministic CLI access (e.g., `Bash(python *) Bash(git status *)`).
- **Heuristic:** Presence-only lint — actual enforcement is at the permissions layer (claude-code Issues #18837/#37683 confirm `allowed-tools` is parsed-but-not-enforced; it is declarative-intent only).
- **Source:** code.claude.com/docs/en/skills.

### Body (R-BODY-*, R-CTX-*)

#### R-BODY-1 — body ≤500 lines
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail at >500, warn at >400 · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** SKILL.md body ≤500 lines.
- **Heuristic:** Strip frontmatter; count newlines + 1.
- **Why:** Anthropic best-practices canonical 500 — longer bodies degrade adherence.

#### R-BODY-2 — body ≤5,000 tokens
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** warn · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** SKILL.md body SHOULD be ≤5,000 tokens.
- **Heuristic:** `tiktoken.get_encoding("o200k_base").encode(body)` length > 5000 → warn. Encoding switched cl100k → o200k in v1.4.
- **Why:** Re-attach budget per skill is 5K; bodies over 5K survive compaction only partially.

#### R-BODY-3 — no required headings + no Windows backslash paths
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail (backslash-path lint only) · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Anthropic does not mandate any heading structure. Validator MUST NOT fail for missing headings. *Separate* lint enforced under the same id: no Windows-style `..\file.md` paths in body.
- **Heuristic:** Outside fenced code blocks, scan for `\\.{1,80}\.(md|py|sh|json)` → fail.
- **Why:** The id is shared by two co-residents in the research doc; the structural recommendation is advisory only.

#### R-BODY-4 — reference TOC at >100 lines
- **Tags:** [reference] [portable]
- **Class:** MECHANICAL · **Severity:** fail at >100, warn at >200 · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Reference files >100 lines start with `## Contents` (or `## Table of Contents`).
- **Heuristic:** First 30 non-blank lines must contain `^##\s+(Table of Contents|Contents)\s*$` (case-insensitive). Aligned with R-CHUNK-1 / R-BOUNDARY-9 — treat the three as one check.
- **Why:** Anthropic-supremacy at 100 lines (revised from skill-creator's 300).

#### R-BODY-5 — no README.md or AGENTS.md inside skill
- **Tags:** [reference] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** No `README.md` (any case) and no `AGENTS.md` inside a skill folder.
- **Heuristic:** Glob for those names.
- **Why:** Anthropic Complete Guide disallows; AGENTS.md is repo-level only (R-BOUNDARY-6).

#### R-BODY-6 — per-reference and aggregate token caps (PROPOSED)
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** warn/fail per thresholds · **Status:** PROPOSED · **Scope:** per-skill
- **Rule:** Per-file: warn at 10K tokens, fail at 25K. Aggregate across all references: warn at 25K, fail at 50K.
- **Heuristic:** tiktoken(o200k_base) per file and sum.
- **Source:** agent-ecosystem/skill-validator v1.1.0.

#### R-BODY-7 — no unclosed code fences (PROPOSED)
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** PROPOSED · **Scope:** per-skill
- **Rule:** Detect unclosed ` ``` ` / `~~~` in SKILL.md and `references/**`.
- **Heuristic:** state-machine count of opens vs. closes.

#### R-BODY-8 — descriptions include negative counter-examples
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL (heuristic) · **Severity:** warn · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Description SHOULD contain a negative-trigger phrase.
- **Heuristic:** Soft-warn if description lacks any of `{Do NOT, Avoid, not for, except for}`.
- **Source:** anthropics/skills/{docx,pptx,pdf}/SKILL.md exemplars.

#### R-BODY-9 — imperative body, third-person description
- **Tags:** [skill] [portable]
- **Class:** MECHANICAL (heuristic) · **Severity:** warn · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Body uses imperative/infinitive (verb-first); description uses third person.
- **Heuristic:** (a) warn on `\b(you|your|yours)\b` in body outside fenced blocks; (b) warn if description starts with imperative verb other than `{is, provides, contains, manages}`; (c) grandfather anthropics/skills/{pdf,docx,pptx}.
- **Source:** anthropics/skills skill-development SKILL.md.

#### R-CTX-3 — SKILL.md is sticky for the session
- **Tags:** [reference] [claude-code-only]
- **Class:** SEMANTIC · **Severity:** info · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Claude Code does NOT re-read SKILL.md on later turns; write as standing instructions.
- **Heuristic:** deferred to agent-driven checklist.

#### R-CTX-4 — front-load standing constraints in first 5K tokens
- **Tags:** [skill] [portable]
- **Class:** SEMANTIC · **Severity:** info · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Re-attachment after auto-compaction keeps the first 5,000 tokens per skill; 25,000 combined.
- **Heuristic:** deferred; cross-link to R-BODY-2.

### Naming (R-NAME-*)

#### R-NAME-1 — exactly `SKILL.md`
- **Tags:** [reference] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Filename is literally `SKILL.md`. Case-sensitive.
- **Heuristic:** `os.listdir(skill_dir)` contains `SKILL.md`; reject `Skill.md`, `skill.md`, `SKILL.MD`.

#### R-NAME-2 — folder = frontmatter name, kebab-case
- **Tags:** [reference] [portable]
- **Class:** MECHANICAL · **Severity:** fail · **Status:** VALIDATED · **Scope:** per-skill
- **Rule:** Folder name kebab-case AND equals `frontmatter['name']`.
- **Heuristic:** `os.path.basename(skill_dir.rstrip("/")) == name and re.fullmatch(r"^[a-z0-9]+(-[a-z0-9]+)*$", name)`.

### Skill vs reference content (R-SR-*)

#### R-SR-1 — procedural → SKILL.md body or references/<variant>.md
- **Tags:** [skill] [portable] · MECHANICAL · warn · VALIDATED · per-skill
- **Heuristic:** Markdown-link graph from SKILL.md; warn on any chain of length ≥2 (superseded by R-CHUNK-4 graph BFS).

#### R-SR-2 — descriptive reference filenames (PROPOSED)
- **Tags:** [skill] [portable] · SEMANTIC · info · PROPOSED · per-skill
- **Heuristic:** Deferred. Weak proxy: regex `^(doc|file|untitled|temp)\d*\.md$` flags egregious cases.

#### R-SR-3 — assets/ for templates, fonts, images
- **Tags:** [reference] [portable] · SEMANTIC · info · VALIDATED · per-skill
- **Heuristic:** deferred to agent-driven checklist.

#### R-SR-4 — scripts/ for executable code
- **Tags:** [skill] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- **Heuristic:** Same backslash-path check as R-BODY-3 applied to every `.md` in skill folder.

#### R-SR-5 — references load only when SKILL.md links them by name
- **Tags:** [reference] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- **Heuristic:** Every file under `references/**` must appear by basename as a literal string in SKILL.md body.

#### R-SR-6 — relative markdown links resolve (PROPOSED)
- **Tags:** [skill] [portable] · MECHANICAL · fail · PROPOSED · per-skill
- **Heuristic:** Every relative `.md` link in SKILL.md and `references/**` resolves to an existing file. External `https?://` excluded.

#### R-SR-7 — orphan detection (PROPOSED)
- **Tags:** [skill] [portable] · MECHANICAL · warn · PROPOSED · per-skill
- **Heuristic:** Build reachability set from SKILL.md by literal-path containment (plus Python `from X import Y` resolution and `__init__.py` bridging); flag unreachable `scripts/` / `references/` / `assets/` files.

#### R-REF-FM-1 — reference frontmatter whitelist (PROPOSED MAY)
- **Tags:** [reference] [portable] · MECHANICAL · fail · PROPOSED · per-skill
- **Heuristic:** Reference frontmatter keys ⊆ `{title, summary, load_when}`.

#### R-REF-SUPERSEDE-1 — `<details>` for deprecated content (PROPOSED MAY)
- **Tags:** [reference] [portable] · SEMANTIC · info · PROPOSED · per-skill

#### R-REF-SECRETS-1 — no secrets in references (PROPOSED SHOULD)
- **Tags:** [reference] [portable] · MECHANICAL · warn · PROPOSED · per-skill
- **Heuristic:** Same secret-pattern scan as R-MEM-9.

#### R-LOG-REJECT — no runtime log.md in references/ (PROPOSED MUST NOT)
- **Tags:** [reference] [portable] · MECHANICAL · fail · PROPOSED · per-skill
- **Heuristic:** `<skill>/references/log.md` or any `log.*` append-only file → reject.

### References and chunking (R-CHUNK-*)

#### R-CHUNK-1 — TOC at >100 lines
- **Tags:** [skill] [reference] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- **Rule:** Reference files >100 lines start with `## Contents` (or `## Table of Contents`).
- **Heuristic:** ToC heading within first 30 non-blank lines. Anthropic-supremacy 100 (correcting skill-creator's 300).

#### R-CHUNK-2 — split at 500 lines / 10K words / 10–15K tokens
- **Tags:** [skill] [reference] [portable] · MECHANICAL · warn · VALIDATED · per-skill
- **Rule:** Reference files >500 lines OR >10K words OR >10–15K tokens must split by domain.
- **Heuristic:** line + word + token count.

#### R-CHUNK-3 — grep example required at >10K words
- **Tags:** [skill] [reference] [portable] · HYBRID · warn · VALIDATED · per-skill
- **Rule:** SKILL.md MUST include at least one literal `grep` invocation example when any reference >10K words.

#### R-CHUNK-4 (v1.14) — one markdown-link hop from SKILL.md
- **Tags:** [skill] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- **Rule:** Every internal `.md` reference reachable in one markdown-link hop from SKILL.md; chained ref→ref forbidden; filesystem depth unrestricted.
- **Heuristic:** Build link graph rooted at SKILL.md (strip anchor fragments, skip `https?://`); fail on graph-distance >1. Cross-links between two depth-1 files emit LINT-Q016-1 info note only.
- **Why:** The `head -100` partial-read regression is triggered by graph distance, not filesystem depth (`anthropics/skills/claude-api` ships at 2-level filesystem depth with 1-level graph depth).

#### R-CHUNK-5 — Read-tool per-call ceiling (≤2,000 lines AND ≤10K tokens)
- **Tags:** [skill] [reference] [claude-code-only] · MECHANICAL · warn · VALIDATED · per-skill
- **Heuristic:** Files exceeding either threshold must split (R-CHUNK-2) or include explicit `Read(file, offset=N, limit=M)` examples in SKILL.md.

#### R-CHUNK-6 — no vector indexes in references/
- **Tags:** [skill] [reference] [portable] · HYBRID · warn · VALIDATED · per-skill
- **Heuristic:** Flag `*.faiss`, `*.chroma`, `embeddings.json`, `index*.pkl` inside `references/`. Header-anchored Grep+Read is canonical.

#### R-LAZYLOAD-1 — every ref linked from SKILL.md with when-to-load
- **Tags:** [skill] [reference] [portable] · MECHANICAL+SEMANTIC · fail/info · VALIDATED · per-skill
- **Heuristic:** Every `.md` under `references/**` appears by basename in SKILL.md (mechanical); each citation carries a "load this when…" descriptor (agent-driven semantic).

#### R-LAZYLOAD-2 — MANDATORY-READ pattern for must-not-skim refs
- **Tags:** [skill] [reference] [portable] · HYBRID · warn · VALIDATED · per-skill
- **Heuristic:** Presence of `MANDATORY` / `ENTIRE FILE` / `NEVER set any range limits` near such citations.

#### R-LAZYLOAD-3 — references <50 lines should be inlined (SHOULD)
- **Tags:** [skill] [reference] [portable] · SEMANTIC · info · VALIDATED · per-skill

### Memory and security (R-MEM-7..9)

#### R-MEM-7 — no hard-coded ~/.claude/ paths
- **Tags:** [memory] [portable] · MECHANICAL · fail · VALIDATED · per-skill
- **Heuristic:** Regex `(~/\.claude/|/home/\w+/\.claude/|/Users/\w+/\.claude/|/root/\.claude/)` outside fenced code blocks.

#### R-MEM-8 — no `../../` traversal in scripts
- **Tags:** [memory] [portable] · MECHANICAL · warn · VALIDATED · per-skill
- **Heuristic:** AST scan of `scripts/**` for string literals containing `(\.\./){2,}`, excluding comments.

#### R-MEM-9 — no hard-coded credentials
- **Tags:** [memory] [portable] · HYBRID · fail · VALIDATED · per-skill
- **Heuristic:** High-entropy regex set (`sk-ant-api03-…`, `AKIA…`, `ghp_…`, `xoxb-…`) plus `detect-secrets`. LLM-judge confirms vs. documentation placeholders.

### Composition (R-COMP-*)

#### R-COMP-1 — four-layer composition ladder
- **Tags:** [skill] [claude-code-only] · SEMANTIC · info · VALIDATED · per-skill
- **Rule:** Climb only when the lower rung is insufficient: (1) inline + progressive disclosure; (2) `context: fork` + `agent`; (3) custom subagent with `skills:` preload; (4) agent teams (EXPERIMENTAL).
- **Heuristic:** deferred to agent-driven checklist.

#### R-COMP-2 — sub-skill invocation is model-mediated
- **Tags:** [skill] [claude-code-only] · MECHANICAL · fail · VALIDATED · per-skill
- **Heuristic:** Reject programmatic skill-call constructs (`Skill(...)` literal, JSON-RPC `Skill` invocation) in SKILL.md body.

#### R-COMP-3 — embed shared helpers, no peer-skill symlinks
- **Tags:** [reference] [portable] · MECHANICAL · warn · VALIDATED · library
- **Heuristic:** Detect symlinks within `.claude/skills/<skill>/` pointing outside that skill — warn.

### Parallelism (R-PAR-*)

#### R-PAR-1 — `context: fork` for executable tasks only
- **Tags:** [skill] [claude-code-only] · HYBRID · warn · VALIDATED · per-skill
- **Heuristic:** Mechanical: if frontmatter has `context: fork`, scan first 200 lines for an imperative verb. Semantic: agent confirms actionability.

#### R-PAR-2 — fan-out budget 3–5 default, ≤8 ceiling
- **Tags:** [skill] [claude-code-only] · MECHANICAL · warn/fail · VALIDATED · per-skill
- **Heuristic:** Body regex `\b(\d+)\s+(subagents|branches|forks|workers)\b`; fail at N>8, warn at N>5.

#### R-PAR-3 — independence test before fan-out
- **Tags:** [skill] [portable] · SEMANTIC · warn · VALIDATED · per-skill
- **Heuristic:** deferred to agent-driven checklist.

#### R-PAR-4 — forked skills inherit CLAUDE.md, not conversation
- **Tags:** [reference] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill
- **Heuristic:** doc lint only.

### Delegation (R-DEL-*)

#### R-DEL-1 — composition depth ≤2
- **Tags:** [skill] [claude-code-only] · MECHANICAL · fail · VALIDATED · per-skill
- **Heuristic:** Parse skill graph; reject chains length >2.

#### R-DEL-2 — subagent skills:[] must not include disable-model-invocation skills
- **Tags:** [skill] [claude-code-only] · MECHANICAL · fail · VALIDATED · per-skill

#### R-DEL-3 — subagent task brief carries 4 fields
- **Tags:** [skill] [portable] · HYBRID · warn · VALIDATED · per-skill
- **Heuristic:** Mechanical keyword scan for objective / output format / tools-sources / boundaries.

### Conducting (R-CONDUCT-*)

#### R-CONDUCT-1 — default to implicit model-mediated conduction
- **Tags:** [skill] [claude-code-only] · SEMANTIC · info · VALIDATED · per-skill

#### R-CONDUCT-2 — paths-glob overlap is unresolved
- **Tags:** [reference] [claude-code-only] · HYBRID · warn · VALIDATED · library
- **Heuristic:** Pairwise textual overlap of `paths` glob patterns across all skills.

#### R-CONDUCT-3 — disable-model-invocation ⇒ paths empty
- **Tags:** [skill] [claude-code-only] · MECHANICAL · fail · VALIDATED · per-skill

#### R-CONDUCT-4 — agent-teams require EXPERIMENTAL caveat
- **Tags:** [skill] [claude-code-only] · MECHANICAL · warn · VALIDATED — EXPERIMENTAL · per-skill

### Failure semantics (R-FAIL-*)

#### R-FAIL-1 — 25K combined / 5K per-skill re-attach budget (reference)
- **Tags:** [skill] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill
- **Heuristic:** Doc lint — any documentation must mention per-context-window isolation.

#### R-FAIL-2 — PostToolBatch for parallel fan-in
- **Tags:** [skill] [claude-code-only] · HYBRID · warn · VALIDATED · per-skill

#### R-FAIL-3 — subagent failure is natural-language summary
- **Tags:** [reference] [claude-code-only] · MECHANICAL · warn · VALIDATED · per-skill

#### R-FAIL-4 — parallel hook exit-2 blocks only its own call
- **Tags:** [skill] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill

#### R-FAIL-5 — pre-approve subagent permissions at fan-out
- **Tags:** [skill] [claude-code-only] · HYBRID · fail · VALIDATED · per-skill

### Self-update rules

R-RETRO-*, R-SELF-*, R-DRIFT-*, R-EXTRACT-*, R-DESTRUCT-*, R-VC-*, R-ROLLBACK-* — see the validator-aligned catalog at `skills/skill-validator/references/rule-catalog.md#self-update-governance` for the full per-rule heuristics. Summary:

- **R-RETRO-1..6 — VALIDATED (R-RETRO-5 PROPOSED).** When and how retros fire (Stop / SessionEnd hooks). SessionEnd MUST NOT carry merge step. Stop hooks check `stop_hook_active`. `once: true` honored only in skill/plugin frontmatter.
- **R-SELF-1..5 — VALIDATED.** File targeting: retros write to `references/gotchas.md`; body edits only for behavioral corrections; no `errata/`; gotchas schema; pending-retro path is `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/`.
- **R-DRIFT-1..5 — VALIDATED (DRIFT-4 PROPOSED).** Description-vs-errata drift: N=3 retros trigger description-optimization pass; no regression; ≤1024 chars; no hidden frontmatter; preserve scope-set.
- **R-EXTRACT-1..3 — EXTRACT-1 PROPOSED, EXTRACT-2/3 VALIDATED.** Promote on-the-fly scripts to permanent skills (N≥3 / 14-day threshold; skill-creator scaffolds; ≥20-prompt trigger eval before marketplace).
- **R-DESTRUCT-1..3 — VALIDATED.** `disable-model-invocation: true` interaction: retros do not auto-apply; meta-skill merge subcommand carries the flag; no raw `patch`/`sed`/`awk`.
- **R-VC-1..3 — VC-3 VALIDATED, VC-1/2 PROPOSED.** Version-control discipline: commit prefix, semver-by-diff-scope, never land on `main` directly.
- **R-ROLLBACK-1..5 — ROLLBACK-1/2/5 VALIDATED, ROLLBACK-3/4 PROPOSED.** Pre-retro tag; revert re-validation; ≤1 merge per session; dependent-skill eval re-run; marketplace version pinning.

### Cross-pollination single-skill

#### R-XPOLL-1 — descriptions are retrieval keys (third person)
- **Tags:** [skill] [portable] · SEMANTIC · info · VALIDATED · per-skill

#### R-XPOLL-2 — name `-ing` suffix (PROPOSED)
- **Tags:** [skill] [portable] · HYBRID · warn · PROPOSED · per-skill

#### R-XPOLL-3 — description has both what and when
- **Tags:** [skill] [portable] · HYBRID · warn · VALIDATED · per-skill

#### R-XPOLL-5 — trigger-shaped clause in description
- **Tags:** [skill] [portable] · MECHANICAL · fail · VALIDATED (PROPOSED in v1.4 Q-005 — but R-BOUNDARY-7 reaffirms; treat as VALIDATED with strict-default) · per-skill
- **Heuristic:** `\b(Use when|When the user|Triggered by|Activate when|Use this (skill|when))\b`, case-insensitive.

#### R-XPOLL-6 — concrete examples (and self-update needs external signal)
- **Tags:** [skill] [claude-code-only] · SEMANTIC · info · VALIDATED · per-skill

#### R-XPOLL-7 — consistent terminology (PROPOSED)
- **Tags:** [reference] [portable] · SEMANTIC · info · PROPOSED · per-skill

#### R-XPOLL-8 — deterministic helper outputs are facts (no reasoning prose between bash and output)
- **Tags:** [skill] [portable] · HYBRID · warn · VALIDATED · per-skill
- **Heuristic:** Detect bash code blocks followed by reasoning-prose markers (`Now I will check...`, `Let me verify...`). Also incorporates a time-sensitivity regex check (`\b(20[12][0-9]|January|February|March|April|May|June|July|August|September|October|November|December)\b` outside fences and `<details><summary>Legacy...`).

#### R-XPOLL-10 — keyword-stuffing description detection (PROPOSED)
- **Tags:** [skill] [portable] · MECHANICAL · warn · PROPOSED · per-skill

### System organization (R-SYS-*)

#### R-SYS-1 — skills folders single-depth
- **Tags:** [reference] [claude-code-only] · MECHANICAL · fail · VALIDATED · library

#### R-SYS-2 — skills precedence enterprise > personal > project
- **Tags:** [reference] [claude-code-only] · MECHANICAL · info · VALIDATED · project-root
- **Note:** Inverse of CLAUDE.md precedence — surface in onboarding.

#### R-SYS-3 — no top-level skills index file
- **Tags:** [reference] [claude-code-only] · MECHANICAL · fail · VALIDATED · library

#### R-SYS-4 — split skill at >500 lines or mutually-exclusive variants
- **Tags:** [skill] [portable] · MECHANICAL · warn · VALIDATED · per-skill

#### R-SYS-5 — cross-skill composition mechanisms
- **Tags:** [skill] [claude-code-only] · MECHANICAL · info · VALIDATED · per-skill

#### R-IDX-1 — references/_index.md MAY exist (PROPOSED)
- **Tags:** [reference] [portable] · MECHANICAL · info · PROPOSED (MAY) · per-skill

### Helpers (R-HELP-*)

#### R-HELP-1..7 — VALIDATED (R-HELP-1 Python preference is PROPOSED)
- **Tags:** [skill] [portable] · mostly SEMANTIC · info · per-skill
- **Rules:** Scripts at `<skill>/scripts/<verb_object>.py`; stable CLI (positional + named flags, `--help`, JSON stdout, stderr+non-zero on error); document every invocation in SKILL.md; `${CLAUDE_SKILL_DIR}/scripts/<file>` paths; `allowed-tools` pre-approval; extract when repeated; `#!/usr/bin/env python3` shebang, executable bit optional.
- **Validator self-test:** in CI, `validate.py skill-validator/ 2>summary.txt 1>output.json` — assert summary.txt non-empty and output.json valid JSON. Enforces stdout=JSON / stderr=human split.

### Loading verification (R-LOAD-*)

All R-LOAD-1..7 are PROPOSED (Q-008). Tag: `[skill] [loading]`.

- **R-LOAD-1 — canary phrase.** Each skill has a unique canary in body or referenced file.
- **R-LOAD-2 — negative-control test.** Folder rename or `disable-model-invocation: true` toggle, re-run canary query.
- **R-LOAD-3 — forbid "list your loaded skills" probe.** As the only verification.
- **R-LOAD-4 — bifurcated permission.** `PreToolUse matcher: "Skill"` permitted (advisory); `PostToolUse matcher: "Skill"` FORBIDDEN (Issue #43630); `InstructionsLoaded` for skills FORBIDDEN. Canonical observability: `claude_code.skill_activated` OTel event.
- **R-LOAD-5 — `evals/loading_verification.json` schema.** Required structure.
- **R-LOAD-6 — ≥1 canary AND ≥1 negative-control.**
- **R-LOAD-7 — both eval layers present.** `evals/evals.json` + `evals/loading_verification.json`.

## Library / cross-skill rules

### Description disambiguation (R-XPOLL-4)

- **Tags:** [skill] [portable] · MECHANICAL · warn at ≥0.85, fail at ≥0.95 · VALIDATED · library
- **Rule:** Pairwise cosine similarity of descriptions across the library.
- **Heuristic:** Embed every description via `sentence-transformers/all-MiniLM-L6-v2`; pairwise cosine. Cache by `(model_name, sha256(description))`. Info-level skip when `sentence-transformers` unavailable.
- **Why:** Near-duplicate descriptions cause router collapse (MRKL §4).

### Workspace topology (R-WORKSPACE-*, R-MONO-*)

- **R-WORKSPACE-1 — VALIDATED, MECHANICAL, fail.** Single-depth discovery. `find <scope>/.claude/skills -mindepth 3 -name SKILL.md` empty.
- **R-WORKSPACE-2 — VALIDATED, MECHANICAL, fail.** `--add-dir <root>` is the supported launch-time exception. Reject `additionalDirectories`.
- **R-WORKSPACE-3 — VALIDATED, HYBRID, warn.** Plugin distribution canonical for cross-scope sharing. Detect `<root>/.claude-plugin/plugin.json`.
- **R-WORKSPACE-4 — VALIDATED, MECHANICAL, warn.** `paths` gates auto-activation only.
- **R-WORKSPACE-5 — PROPOSED, MECHANICAL, warn.** Skill-folder symlinks fragile (Issue #14836).
- **R-WORKSPACE-6 — PROPOSED, MECHANICAL, warn.** Service-prefix tolerated, plugin-per-service preferred at T-PFX-1.

- **R-MONO-1 — VALIDATED-with-caveat, HYBRID, warn.** Nested auto-discovery broken in CLI ≥2.1.92 (`Bun.Glob.scan() dot:false` regression, Issue #44490).
- **R-MONO-2 — PROPOSED, SEMANTIC, warn.** Preferred topology for ≥3-service monorepos.
- **R-MONO-3 — VALIDATED, MECHANICAL, fail.** Cross-skill router/index links discouraged; reject `../<other-skill>/SKILL.md`.
- **R-MONO-4 — PROPOSED, MECHANICAL, warn.** Use `find` not `Glob` for `.claude/`-traversal on CLI ≥2.1.92.

### Shared scripts (R-SHARE-*)

- **R-SHARE-1 — VALIDATED, MECHANICAL, fail.** No peer-skill symlinks; embed-and-duplicate non-plugin helpers. (T-SHARE-1: ≥2 skills sharing helper → plugin-root.)
- **R-SHARE-2 — VALIDATED, MECHANICAL, fail.** No `.claude/scripts/` convention.
- **R-SHARE-3 — VALIDATED, MECHANICAL, warn.** `${CLAUDE_PLUGIN_ROOT}` only in JSON/YAML config, not `.md` body.
- **R-SHARE-4 — VALIDATED, MECHANICAL, fail.** Bundled-script refs use `${CLAUDE_SKILL_DIR}/…` or `${CLAUDE_PLUGIN_ROOT}/…`; reject absolute or `./` paths.

### Reference location (R-REFLOC-*, R-REF-SHARE-1)

- **R-REFLOC-1 — VALIDATED, MECHANICAL, fail.** No `..` paths in SKILL.md body or references.
- **R-REFLOC-2 — PROPOSED, HYBRID, warn.** Four reuse patterns (a)/(b)/(c)/(d).
- **R-REFLOC-2(c) clarification — VALIDATED, MECHANICAL, fail.** No `internal:` frontmatter key (DA-108); use `user-invocable: false` + `paths` instead. Description must start with `[internal — not portable]`.
- **R-REFLOC-3 — VALIDATED, MECHANICAL, fail.** If body >300 lines, `references/_index.md` exists; TOC paths inside skill folder unless `[internal — not portable]`.
- **R-REFLOC-4 — VALIDATED, MECHANICAL, warn.** `paths` matches `docs/**` + body has zero `references/` links → warn.
- **R-REF-SHARE-1 — PROPOSED, MECHANICAL, warn.** Cross-skill reference-doc sharing follows R-SHARE-1 ladder; plugin symlinks OK if target under plugin root.

### Hallucination canaries (R-CROSS-1)

- **R-CROSS-1 — VALIDATED, MECHANICAL, fail.** Reject `${CLAUDE_SKILLS_PATH}`, `skillsDirectories`, `Bun.Glob` direct invocation, `internal: true` frontmatter, `.claude/skill-memories/`, `injection.py` (CaveAgent — wrong runtime model). Updates per Q-009 v1.9 and Q-010.

### Cross-skill composition

- **R-COMP-3** (same as per-skill section above; embed-and-duplicate enforcement is library-scoped).
- **R-CONDUCT-2** — `paths`-glob overlap detection requires library scope.

## Meta-skill-only rules (R-META-*, R-XPOLL-9)

Full statements at `skills/skill-validator/references/rule-catalog.md#meta-skill--r-meta-`. Summary table:

| Rule | Class | Severity | Status | What it pins |
|---|---|---|---|---|
| R-META-1 | SEMANTIC | info | VALIDATED | Meta-skill conforms to its own spec |
| R-META-2 | MECHANICAL | fail | VALIDATED | Meta-skill frontmatter whitelist |
| R-META-3 | MECHANICAL | fail | PROPOSED | Declarative `.skill-spec.yaml` JSON Schema |
| R-META-4 | SEMANTIC | info | PROPOSED | 7-stage compiler pipeline |
| R-META-5 | MECHANICAL | fail | VALIDATED | Scaffold minimum + conditional subfolders |
| R-META-6 | SEMANTIC | info | VALIDATED | 4-prompt elicitation flow |
| R-META-7 | MECHANICAL | fail | VALIDATED | Validator gates at creation + finalization |
| R-META-8 | MECHANICAL | info | VALIDATED | Iteration cap = 3 |
| R-META-9 | MECHANICAL | fail | VALIDATED | No silent auto-fix; AST scan; `--fix` reserved hard-error |
| R-META-10 | MECHANICAL | fail | VALIDATED | No `anthropic` / `openai` / `requests` imports |
| R-META-11 | SEMANTIC | info | PROPOSED | Zero bundled examples; embedding-retrieved exemplars |
| R-META-12 | SEMANTIC | info | PROPOSED | 3-tier curriculum |
| R-META-13 | MECHANICAL | warn | VALIDATED | Description form `<verb-phrase>. Use when …` |
| R-META-14 | MECHANICAL | fail | VALIDATED | Meta-skill body ≤400 lines |
| R-META-15 | MECHANICAL | info | VALIDATED | Eval set = 3 behavioral + 20 trigger |
| R-META-16 | SEMANTIC | info | PROPOSED | ≥1 negative counter-example |
| R-META-17 | SEMANTIC | info | PROPOSED | Synthetic→organic lifecycle |
| R-META-18 | MECHANICAL | fail | PROPOSED | Bash-availability + grading.json path enforcement |
| R-META-19 | MECHANICAL | fail | VALIDATED | Meta-skill needs `Bash` in `allowed-tools` |

### R-XPOLL-9 — validator dogfoods (meta-skill-only)

- **Tags:** [system] [portable] · MECHANICAL · fail · PROPOSED (research) / treated as VALIDATED in plan · meta-skill-only
- **Rule:** Library mode asserts `<library>/skill-validator/SKILL.md` exists; the validator self-validates clean.
- **Heuristic:** Path assertion + self-test fixture.

## Project-root rules

### Boundary (R-BOUNDARY-1..9)

- **R-BOUNDARY-1 — VALIDATED, SEMANTIC, warn.** Multi-step procedures belong in skills, not CLAUDE.md/AGENTS.md.
- **R-BOUNDARY-2 — VALIDATED, MECHANICAL, warn.** Long-form descriptive material in `<skill>/references/<topic>.md`, one markdown-link hop (inherits R-CHUNK-4 v1.14).
- **R-BOUNDARY-3 — VALIDATED, MECHANICAL, warn (NOT fail).** `<root>/CLAUDE.md` target ≤200 lines. **Per DA-140, this is an adherence target, NOT a truncation cap.** Lint message MUST NOT imply truncation.
- **R-BOUNDARY-4 — VALIDATED, MECHANICAL, fail.** `@AGENTS.md` is the first content line of `<root>/CLAUDE.md` when present (LINT-Q015-11).
- **R-BOUNDARY-5 — VALIDATED, SEMANTIC, info.** Repo docs referenced via `@README.md`-style imports, not duplicated.
- **R-BOUNDARY-6 — VALIDATED, MECHANICAL, fail.** Skills MUST NOT carry an AGENTS-equivalent file or be `@`-imported/symlinked to one.
- **R-BOUNDARY-7 — VALIDATED, MECHANICAL, fail.** Description has what + when, ≤1024, third person (reaffirms R-FM-3 / R-XPOLL-5 / R-BODY-9).
- **R-BOUNDARY-8 — VALIDATED, SEMANTIC, info (qualitative).** ≥~50% of sessions → CLAUDE.md; <~50% → skill.
- **R-BOUNDARY-9 — VALIDATED, MECHANICAL, fail.** Reference files >100 non-blank lines must include a ToC within the first 30 non-blank lines (LINT-Q015-10).

### Memory (R-MEM-1..6, R-MEM-10)

- **R-MEM-1..6 — VALIDATED.** CLAUDE.md hierarchy, anti-duplication, `.claude/rules/*.md` with `paths:` glob, etc. Mostly reference-level (no per-skill validation).
- **R-MEM-10 — VALIDATED, CANONICAL, mechanical lint at project root.** `<root>/CLAUDE.md` is NOT a symlink to `<root>/AGENTS.md` (or vice versa); body's first content line is `@AGENTS.md` when `<root>/AGENTS.md` exists. Replaces demoted R-MEM-3.

### AutoDream (R-AUTODREAM-1..4) + R-MEM-1-CLARIFICATION

All `[reference]`, mostly SEMANTIC/info, scope project-root.

- **R-AUTODREAM-1 — VALIDATED.** Operates on `~/.claude/projects/<slug>/memory/`. Durable user constraints belong in CLAUDE.md/AGENTS.md, never MEMORY.md.
- **R-AUTODREAM-2 — PROPOSED.** Gated by `tengu_onyx_plover` flag + `autoDreamEnabled` setting.
- **R-AUTODREAM-3 — VALIDATED.** Orthogonal to Task Budgets, auto-compaction, R-FAIL-1 re-attach pool.
- **R-AUTODREAM-4 — PROPOSED.** Call it "AutoDream", not "KAIROS daemon". KAIROS is the umbrella for proactive autonomous-agent mode.
- **R-MEM-1-CLARIFICATION — VALIDATED, NEW v1.17.** R-MEM-1 hierarchy is cross-container; AutoDream MAY rewrite user-reinforced entries within MEMORY.md.

## Governance / cadence

These are documented but the v1 validator does NOT run them by default — opt-in via `--include-proposed`.

### LLM-judge (R-LLMJ-1..12)

All `[skill] [judge]`, PROPOSED Q-008.

- **R-LLMJ-1 — error.** Judge tier `downstream`; not in pre-commit hook.
- **R-LLMJ-2 — error.** `verdict` ∈ `{pass, warn, fail}`.
- **R-LLMJ-3 — error.** Per-rule judge prompt has intro + pinned eval steps + structured output schema.
- **R-LLMJ-4 — error.** `samples: 3`, `aggregation: majority_vote`.
- **R-LLMJ-5 — warn.** Default Sonnet 4.6; Opus 4.7 requires `--high-precision`.
- **R-LLMJ-6 — error.** `pointwise` default; `pairwise` only for R-DRIFT-5.
- **R-LLMJ-7 — error.** Output JSON schema.
- **R-LLMJ-8 — error.** ≥10-example `calibration/` per rule; TPR/TNR ≥0.80.
- **R-LLMJ-9 — warn.** DSPy-Suggest shape (soft), not `Assert` (halt).
- **R-LLMJ-10 — error.** Judge MUST NOT evaluate domain-content factuality or mechanical rules.
- **R-LLMJ-11 — warn.** Budget ≤30K input + ≤6K output per skill.
- **R-LLMJ-12 — error.** Body delimited with `<untrusted_data>…</untrusted_data>`.

### Cadence (R-CADENCE-1..5)

All `[skill] [cadence]`, PROPOSED Q-008.

- **R-CADENCE-1 — warn.** Monthly + quarterly + on-demand tiers configured.
- **R-CADENCE-2 — warn.** Routines primary OR GitHub Actions cron fallback.
- **R-CADENCE-3 — error.** Off-cadence triggers for 5 events.
- **R-CADENCE-4 — error.** `review-report.json` v1.0 schema.
- **R-CADENCE-5 — warn.** Quarterly tier tags `v<major>.<minor>.0-rules`.

### Contamination (R-CONTAM-1)

- **PROPOSED, HYBRID, warn at ≥0.5.** Cross-language contamination via 3-factor formula. `[skill] [portable]`.

## API surface (R-API-1)

- **Tags:** [reference] [claude-code-only] · MECHANICAL · fail · VALIDATED · deployment-manifest scope
- **Rule:** Messages API surface limit — up to 8 skills per request via `container.skills`.
- **Heuristic:** If a deployment manifest declares `container.skills`, assert `len(skills) <= 8`. Vacuously true otherwise.
- **Why:** API-side ceiling; aligns with R-PAR-2's fan-out ceiling.

## Discarded-Alternatives reminders

Only referenced inline where they sharpen a rule. The full DA list lives in the research doc.

- **DA-005** — Reject all-caps `MUST` / `ALWAYS` / `NEVER` in skill bodies (Anthropic skill-creator flags as yellow flag). Cited by R-BODY-3 prose.
- **DA-058** — Embed-and-duplicate is canonical for non-plugin helper sharing. Cited by R-SHARE-1.
- **DA-108** — No new `internal: true` frontmatter key; use `user-invocable: false` + `paths`. Cited by R-REFLOC-2(c).
- **DA-117** — `references/_index.md` MAY exist, MUST NOT be required. Cited by R-IDX-1.
- **DA-120** — R-LAZYLOAD-3 stays SHOULD (math is wrong by ~5x in Gemini-10's MUST upgrade attempt).
- **DA-121** — `injection.py` does not belong in Claude Code skills (CaveAgent's Python-kernel runtime ≠ Claude Code's stateless bash). Cited by R-CROSS-1.
- **DA-130** — Demote R-MEM-3 symlink rule; superseded by R-MEM-10 `@AGENTS.md` import.
- **DA-135** — OS-level symlinks from project-scope skills to `<root>/shared-refs/` rejected. Embed-and-duplicate, full stop.
- **DA-140** — R-BOUNDARY-3's 200-line figure is an adherence target, NOT a truncation cap. CLAUDE.md is loaded in full; MEMORY.md is the 200-line/25KB-capped file. Lints must WARN not FAIL.
- **DA-144** — R-BOUNDARY-9 threshold is 100 lines, not Gemini-15's 300.

## Conflicts and ambiguity

- **R-BODY-4 vs R-CHUNK-1.** Both target ToC for reference files. Both settle at 100 lines after v1.4 (R-BODY-4 was previously 300). Treat as one check.
- **R-BODY-3 prose vs validation-table.** Prose: "no required headings"; validation-table assigns the id to a Windows-backslash-path lint. Keep both: structural recommendation only + the backslash check.
- **R-BOUNDARY-3 200-line target.** Per DA-140, MUST emit WARN not FAIL, MUST NOT imply truncation.
- **R-XPOLL-8 dual semantics.** Same id is used for the ReWOO reasoning-prose detector AND the time-sensitivity regex (v1.4 addition).
- **R-XPOLL-5 status.** Validation-table labels PROPOSED (Q-005 false-positive concern); skill-spec + R-BOUNDARY-7 reaffirm canonical Anthropic anchor. Treat as VALIDATED in the `claude-code` profile; toggle via `--strict` in skills-api profile.
- **R-FAIL-1 budget figures.** Resting on a single canonical Tier-1 (`code.claude.com/docs/en/skills`); per Q-018, any documentation MUST mention per-context-window isolation and resist conflation with the five other 25K figures in the Anthropic ecosystem.
- **R-MONO-1 and R-WORKSPACE-1.** R-MONO-1 (broken nested discovery in CLI ≥2.1.92) is a runtime regression; R-WORKSPACE-1 (single-depth at every scope) is the spec invariant. Both apply.
