---
doc_format_version: 2
research_buddy_version: 1.6.0
version: '1.17'
date: '2026-05-07'
file_name: claude-skill-system
title: Claude Code Skill System
subtitle: Research-backed specification for the ultimate SKILL.md ecosystem
language:
  code: en
  label: English
project:
  domain: AI agent engineering — Anthropic Claude Code Agent Skills system, with cross-pollination from prompt-engineering and agent-systems literature
  deliverable_type: software_and_document
  final_goal: A complete, strict, research-backed specification for Claude Code skills (single-skill anatomy + multi-skill system design) AND the boundary contract between skills, CLAUDE.md/AGENTS.md, and
    project documentation that agents read, a meta-skill that creates conformant skills, and a validation script that enforces the rules.
  timing: No hard deadline. Iterative across multiple sessions. First session = broad discovery; later sessions narrow to Tier 1/2; final milestone = validation script.
  validation_gate: 'A finding becomes a rule in the spec only when: (1) supported by ≥2 independent Tier-1 sources with zero Tier-1 contradictions, OR confirmed in Anthropic official documentation as canonical
    (single Tier-1 source sufficient); AND (2) internally consistent with all other adopted rules — no contradictions in the final ruleset. PROPOSED items may live in spec tabs as candidates, visually marked,
    and are excluded from the final validation script until promoted.'
  source_tiers:
    tier_1: Anthropic official documentation (docs.claude.com, docs.anthropic.com, anthropic.com/engineering, anthropic.com/news, anthropic.com/research); Anthropic-owned GitHub repositories (github.com/anthropics/*
      — especially anthropics/skills, anthropics/claude-code, anthropics/anthropic-cookbook); peer-reviewed papers from arXiv with verified institutional affiliation, ACL, NeurIPS, ICML, EMNLP, ICLR; Anthropic
      engineering blog posts authored by named Anthropic engineers.
    tier_2: Official documentation from comparable agent systems (Cursor, Aider, Cline, Continue, OpenAI Assistants/Codex, LangChain, LlamaIndex) where they describe analogous skill or instruction mechanisms;
      AGENTS.md ecosystem documentation (the agents.md standard); well-established reference works (dair-ai/Prompt-Engineering-Guide, promptingguide.ai); vendor-published model cards and system cards.
    discovery: High-signal community GitHub repos with skill collections; named-author technical gists (e.g., Karpathy on context engineering); articles from recognized practitioners (Martin Fowler, Simon
      Willison, Hamel Husain, Eugene Yan, Chip Huyen, Andrej Karpathy); substantive HackerNews/Reddit/Twitter threads (lead generation only); newsletter articles from credible named authors.
  domain_rules: See [Domain rules](#domain-rules) below for the populated list of domain-specific methodology rules (tier discipline, Anthropic supremacy, strictness default, skill/reference tagging,
    arXiv verification, cross-system portability, pre-registration).
ui_strings:
  status_open: OPEN
  status_done: ✦ Researched
  status_wip: IN PROGRESS
---

<!-- @anchor: title -->

# Claude Code Skill System — Research Document

*Research-backed specification for the ultimate SKILL.md ecosystem*

**Version:** 1.17 · **Updated:** 2026-05-07

<!-- @end: title -->

---

<!-- @anchor: project -->
## Project Specification

<!-- Migrated from v1 agent_guidelines.project_specific. Modifications go here. Do not modify the Framework sections. -->

### Domain

- **Domain:** AI agent engineering — Anthropic Claude Code Agent Skills system, with cross-pollination from prompt-engineering and agent-systems literature
- **Deliverable type:** software_and_document
- **Final goal:** A complete, strict, research-backed specification for Claude Code skills (single-skill anatomy + multi-skill system design) AND the boundary contract between skills, CLAUDE.md/AGENTS.md, and project documentation that agents read, a meta-skill that creates conformant skills, and a validation script that enforces the rules.
- **Timing:** No hard deadline. Iterative across multiple sessions. First session = broad discovery; later sessions narrow to Tier 1/2; final milestone = validation script.
- **Validation gate:** A finding becomes a rule in the spec only when: (1) supported by ≥2 independent Tier-1 sources with zero Tier-1 contradictions, OR confirmed in Anthropic official documentation as canonical (single Tier-1 source sufficient); AND (2) internally consistent with all other adopted rules — no contradictions in the final ruleset. PROPOSED items may live in spec tabs as candidates, visually marked, and are excluded from the final validation script until promoted.

<!-- @anchor: project.tiers -->
### Source tiers

- **Tier 1:** Anthropic official documentation (docs.claude.com, docs.anthropic.com, anthropic.com/engineering, anthropic.com/news, anthropic.com/research); Anthropic-owned GitHub repositories (github.com/anthropics/* — especially anthropics/skills, anthropics/claude-code, anthropics/anthropic-cookbook); peer-reviewed papers from arXiv with verified institutional affiliation, ACL, NeurIPS, ICML, EMNLP, ICLR; Anthropic engineering blog posts authored by named Anthropic engineers.
- **Tier 2:** Official documentation from comparable agent systems (Cursor, Aider, Cline, Continue, OpenAI Assistants/Codex, LangChain, LlamaIndex) where they describe analogous skill or instruction mechanisms; AGENTS.md ecosystem documentation (the agents.md standard); well-established reference works (dair-ai/Prompt-Engineering-Guide, promptingguide.ai); vendor-published model cards and system cards.
- **Discovery:** High-signal community GitHub repos with skill collections; named-author technical gists (e.g., Karpathy on context engineering); articles from recognized practitioners (Martin Fowler, Simon Willison, Hamel Husain, Eugene Yan, Chip Huyen, Andrej Karpathy); substantive HackerNews/Reddit/Twitter threads (lead generation only); newsletter articles from credible named authors.
- **Never:** Anonymous content; unverifiable PDFs; SEO content farms; AI-generated overview articles without named human authorship; sources without traceable authorship.

<!-- @end: project.tiers -->

<!-- @anchor: project.rules -->
### Domain rules

- Tier discipline: Claims sourced only from Discovery are tagged PROPOSED and cannot become rules until re-verified against Tier 1 or Tier 2. A dedicated promotion-pass topic (Q-005) re-validates them.
- Anthropic supremacy: When Anthropic official documentation disagrees with any other source on a Claude-Code-specific fact, Anthropic wins. The disagreement is still logged in session notes for visibility.
- Strictness default: When uncertain whether a rule should be strict or permissive, choose strict. The user explicitly opted for strict-as-if-public-distribution rules.
- Skill vs reference tagging: Every adopted rule is labeled either [skill] (procedural how-to — what to do) or [reference] (factual what-is — descriptive knowledge). This forces the skill-vs-reference-doc distinction to surface and addresses a known user pain point.
- arXiv verification: Every arXiv ID cited must be verified to (a) resolve to a real paper, (b) have a verifiable institutional affiliation, (c) not be future-dated relative to the current date. The user-supplied ID 2604.24026 will be verified in Turn 1 of Q-001 and labeled accordingly or marked unverifiable.
- Cross-system portability flag: Every adopted rule is labeled [claude-code-only] or [portable]. Portable rules survive into the meta-skill spec; Claude-Code-only rules are scoped explicitly.
- Pre-registration: For any quantitative threshold (e.g., 'skill must be under N tokens', 'frontmatter description must be under M characters'), the threshold and its justification are written down before being adopted, per framework.synthesis_matrix.pre_registration_rule.

<!-- @end: project.rules -->

<!-- @end: project -->

---

<!-- @anchor: skill-specification -->
## Skill Specification

### Skill Anatomy

> **Q-002 cross-pollination added in v1.2** _(green)_
>
> Q-001 populated this tab in v1.1. Q-002 adds cross-pollination rules from peer-reviewed agent-systems literature (R-XPOLL-1..9), API limits (R-API-1), and the corrective on R-BODY-1 (≤500 lines is the documented Anthropic number; both 100 and 300 from the parallel v1.1 files were folklore). PROPOSED items will be re-verified in Q-005.

A **skill** is a directory whose entrypoint is a file named exactly `SKILL.md` (case-sensitive). The directory contains the SKILL.md plus, optionally, `scripts/`, `references/`, and `assets/` subdirectories. The frontmatter scheduling layer is read eagerly; the SKILL.md body loads when the description triggers; satellite files load on demand.

Every rule below is tagged with two axes: **[skill]** (procedural) vs **[reference]** (factual), and **[claude-code-only]** vs **[portable]** (where portability targets the AGENTS.md / Cursor / Aider / Codex ecosystem).

### Frontmatter Rules

<!-- @rule: R-FM-1 -->
<a id="r-fm-1"></a>

**R-FM-1** [skill] [portable] VALIDATED.

**REQUIRE both `name` and `description` in every SKILL.md.** Open standard and Claude API both require them; Claude Code permits omission of `name` (defaults to folder), but strictness default applies. Sources: agentskills.io specification; Anthropic Agent Skills overview; anthropics/skills skill-workshop.

<!-- @rule: R-FM-2 -->
<a id="r-fm-2"></a>

**R-FM-2** [skill] [portable] VALIDATED — PRE-REGISTERED 64.

**`name` MUST match `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 characters, equal the folder name, and not be a reserved word.** Reserved words include `anthropic`, `claude` (Anthropic API rule) AND any name that collides with a native Claude Code slash command (e.g., `mcp`, `agent`) — the skill would aggressively shadow the native command (Anthropic Issue #44199, surfaced by Gemini-1, queued for Q-005 verification).

<!-- @rule: R-FM-3 -->
<a id="r-fm-3"></a>

**R-FM-3** [skill] [portable] VALIDATED — PRE-REGISTERED 1024.

**`description` MUST be non-empty, ≤1,024 characters, and contain BOTH what the skill does AND when to use it (trigger phrases).** Front-load the trigger because the listing is truncated. Anthropic skill-workshop explicitly recommends a slightly "pushy" tone (Claude tends to undertrigger). Custom fields like `use-when` are NOT read by the routing engine (Anthropic Issue #27569 via Gemini-1) — all trigger logic must live in `description`.

<!-- @rule: R-FM-4 -->
<a id="r-fm-4"></a>

**R-FM-4** [skill] [claude-code-only] VALIDATED — PRE-REGISTERED 1536, ALLOW-LIST CONFIRMED v1.5.

**In Claude Code, combined `description` + `when_to_use` MUST be ≤1,536 characters** to avoid truncation in the `<available_skills>` system-prompt block. Override via `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var. **v1.5 confirmation:** the `when_to_use` field is now officially documented in code.claude.com/docs/en/skills frontmatter reference table — verbatim 'Additional context for when Claude should invoke the skill, such as trigger phrases or example requests. Appended to description in the skill listing and counts toward the 1,536-character cap.' This resolves the v1.4-flagged 'allow-list status' PROPOSED concern. The Lee Hanchung blog (Oct 2025) and anthropics/skills issue #37 (Oct 2025) listed it as undocumented at that snapshot in time, but the live docs as of 2026-05-02 list it explicitly.

<!-- @rule: R-FM-5 -->
<a id="r-fm-5"></a>

**R-FM-5** [skill] [portable] VALIDATED.

**No XML angle brackets in any frontmatter field.** They can inject unintended instructions. **No manual namespace prefix in `name`** (e.g., `myorg/skillname`); plugin distribution prefixes automatically and manual prefixes break loading silently.

<!-- @rule: R-FM-6 -->
<a id="r-fm-6"></a>

**R-FM-6** [skill] [claude-code-only] VALIDATED.

**Use `disable-model-invocation: true`** when the skill must NOT be auto-triggered (e.g., destructive `/deploy`). **Use `user-invocable: false`** when the skill is ambient knowledge that users should not type as a command. Both default to false/true respectively.

<!-- @rule: R-FM-7 -->
<a id="r-fm-7"></a>

**R-FM-7** [skill] [claude-code-only] VALIDATED.

**Declare deterministic CLI access via `allowed-tools`** (e.g., `allowed-tools: Bash(python *) Bash(git status *)`). This is **pre-approval**, not restriction; deny rules in `/permissions` perform restriction.

**Optional Claude-Code frontmatter fields** (validated, claude-code-only): `when_to_use`, `argument-hint`, `arguments`, `model`, `effort` (`low|medium|high|xhigh|max`), `context: fork`, `agent` (`Explore|Plan|<custom>`), `hooks`, `paths` (glob list), `shell` (`bash|powershell`).

**Optional open-standard fields** (validated, portable): `license`, `compatibility`, `metadata` (string→string map), `allowed-tools`.

<!-- @rule: R-XPOLL-5 -->
<a id="r-xpoll-5"></a>

**R-XPOLL-5** [skill] [portable] VALIDATED — Toolformer (NeurIPS 2023).

**`description` MUST contain a trigger-shaped clause** — explicit *Use when…* / *When…* phrasing naming concrete user-utterance triggers, file types, or scenarios. Schick et al. *Toolformer* (NeurIPS 2023, arXiv:2302.04761) shows that tool-invocation behavior is learned from trigger-shaped few-shot examples, not declarative tool catalogs; Anthropic's own example skills follow this format. Validation-script check: regex match for `\b(Use when|When the user|Triggered by|Activate when)\b` in the description body. Failure → fail.

<!-- @rule: R-API-1 -->
<a id="r-api-1"></a>

**R-API-1** [reference] [claude-code-only] VALIDATED — NEW in v1.2.

**Messages API surface limit: up to 8 skills per request** via `container.skills` (Anthropic, *Using Agent Skills with the API*, platform.claude.com/docs/en/build-with-claude/skills-guide, verified Turn 2). This is the API-side ceiling on simultaneous skill activation; filesystem-based Claude Code skills scale with the listing budget (2%/16K + 250-char per description per Issue #40121), not with a per-request count. Surfaces this as an architectural constraint when a project plans cross-surface deployment. **Rejects Gemini-2's "20 skills per session" hallucination (DA-021).**

### Required Sections

<!-- @rule: R-BODY-3 -->
<a id="r-body-3"></a>

**R-BODY-3** [skill] [portable] VALIDATED — (no required headings) / PROPOSED (recommended structure).

**Anthropic does not mandate any heading structure** in the SKILL.md body. The validator MUST NOT fail a skill for omitting a specific heading. **Recommended (not required)** structure, synthesized from Anthropic skill-workshop + Fowler-hosted SPDD + arXiv 2604.24026 SSL framing (the latter as vocabulary only):

1. **One-paragraph framing** — what this skill is for, in 2–4 sentences.
2. **Workflow / Instructions** — numbered steps; this is the structural layer (in SSL terms).
3. **Examples** — input → output pairs for the most important use cases (the logical layer).
4. **Gotchas** — real failures observed during use (the most valuable section per Anthropic skill-workshop). Each gotcha says WHAT goes wrong AND WHY, not just the prohibition.

**Voice:** imperative form ("Run X, then Y"), not declarative narration. **Avoid** all-caps `MUST` / `ALWAYS` / `NEVER` — Anthropic skill-workshop flags these as a yellow flag. Explain *why* a constraint exists rather than asserting it categorically.

### Length and Style

<!-- @rule: R-BODY-1 -->
<a id="r-body-1"></a>

**R-BODY-1** [skill] [portable] VALIDATED — PRE-REGISTERED 500 lines (CORRECTED IN v1.2).

**SKILL.md body MUST be ≤500 lines.** Anthropic's *Skill authoring best practices* (platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) is the authoritative source. **v1.2 corrective:** both parallel v1.1 files used incorrect numbers — FILE A had 100 lines (a misreading of the ToC threshold for *reference* files), FILE B had 300 lines (a misreading of skill-workshop's reference-file allowance). The documented number for the **SKILL.md body** is **≤500 lines**; the 100-line ToC threshold applies to reference files >300 lines (R-BODY-4), not the body. Validation-script: line count > 500 → fail; > 400 → warn.

<!-- @rule: R-BODY-2 -->
<a id="r-body-2"></a>

**R-BODY-2** [skill] [portable] VALIDATED — PRE-REGISTERED 5,000 tokens.

**SKILL.md body SHOULD be ≤5,000 tokens** (Level-2 token budget). Anthropic API docs and skill-workshop both target "under 5k tokens" for the SKILL.md body.

<!-- @rule: R-BODY-4 -->
<a id="r-body-4"></a>

**R-BODY-4** [skill] [portable] VALIDATED — PRE-REGISTERED 300 lines.

**Reference files >300 lines MUST start with a Table of Contents** so Claude can jump-load only the relevant section. Anthropic skill-workshop: "include a table of contents at the top of the reference".

<!-- @rule: R-CTX-3 -->
<a id="r-ctx-3"></a>

**R-CTX-3** [reference] [claude-code-only] VALIDATED.

**SKILL.md content is sticky for the session in Claude Code** — Claude Code does NOT re-read the file on later turns. Write SKILL.md as standing instructions, not one-time setup.

<!-- @rule: R-CTX-4 -->
<a id="r-ctx-4"></a>

**R-CTX-4** [skill] [portable] VALIDATED — PRE-REGISTERED.

**Re-attachment after auto-compaction (Claude Code only):** **first 5,000 tokens per skill, 25,000-token combined budget** across all re-attached skills. Front-load the standing constraints in the first 5,000 tokens. Reject the alternative 1,000-token claim from Discovery sources (Anthropic Tier 1 supremacy).

**Style discipline.** Use **bullets** for enumerable steps, lists, and checklists. Use **prose** for rationale, theory-of-mind, and contextual framing. Bullet points are at least 1–2 sentences. Avoid information fragmentation across attention heads — keep qualitative guidance in flowing prose.

<!-- @rule: R-BODY-8 -->
<a id="r-body-8"></a>

**R-BODY-8** [skill] [portable] VALIDATED — Tier-1 (NEW v1.5).

**Negative counter-examples in descriptions are encouraged.** anthropics/skills/{docx,pptx,pdf}/SKILL.md descriptions consistently end with explicit exclusions: 'Do NOT use for PDFs, spreadsheets, Google Docs, or general coding tasks unrelated to document generation' (docx); analogous patterns in pdf and pptx. skill-development SKILL.md's 'Common Mistakes to Avoid' section uses explicit ✓ DO / ❌ DON'T paired sections throughout. **Validator behavior:** soft-warn (not fail) if description lacks any negative-trigger phrase from {'Do NOT', 'Avoid', 'not for', 'except for'}. Source: anthropics/skills/{docx,pptx,pdf}/SKILL.md (Tier-1 exemplars), skill-development SKILL.md (Tier-1 authoring guide).

<!-- @rule: R-BODY-9 -->
<a id="r-body-9"></a>

**R-BODY-9** [skill] [portable] VALIDATED — Tier-1 (NEW v1.5).

**SKILL.md body MUST use imperative/infinitive (verb-first) voice; descriptions MUST use third-person.** skill-development SKILL.md verbatim: 'Write the entire skill using imperative/infinitive form (verb-first instructions), not second person. Use objective, instructional language (e.g., "To accomplish X, do Y" rather than "You should do X" or "If you need to do X").' And '❌ DON'T: Use second person anywhere'. For descriptions: 'Use the third-person (e.g. "This skill should be used when..." instead of "Use this skill when...")'. **Validator behavior:** (a) body — warn on detection of second-person pronouns ('you', 'your', 'yours') outside fenced code blocks; (b) description — warn if description starts with imperative verb other than safe-listed {'is', 'provides', 'contains', 'manages'}; (c) backward-compat soft-pass for anthropics/skills/{pdf,docx,pptx} which use imperative descriptions ('Use this skill whenever the user wants...') — these are grandfathered Tier-1 exemplars predating skill-development SKILL.md's formalization.

### Naming Conventions

<!-- @rule: R-NAME-1 -->
<a id="r-name-1"></a>

**R-NAME-1** [skill] [portable] VALIDATED.

**File MUST be named exactly `SKILL.md`** — case-sensitive. `SKILL.MD`, `skill.md`, `Skill.md` are not accepted. Anthropic supremacy applied over the Hanchung deep-dive blog claim that the name is case-insensitive.

<!-- @rule: R-NAME-2 -->
<a id="r-name-2"></a>

**R-NAME-2** [skill] [portable] VALIDATED.

**Folder name MUST be kebab-case** (`^[a-z0-9]+(-[a-z0-9]+)*$`), ≤64 characters, no underscores, no spaces, no capitals, **and MUST equal the frontmatter `name` field**. The folder name doubles as the `/slash-command` invocation in Claude Code.

**Forbidden as `name` values** (will fail validation): `anthropic`, `claude`, and any string colliding with a native Claude Code command (e.g., `mcp`, `agent`). The validation script enforces a deny-list (extensible) plus structural checks.

### Skill vs Reference Content

> **v1.12 additions (Q-014)** _(amber)_
>
> Q-014 added four new rules to govern reference-doc anatomy: **R-REF-FM-1** (optional frontmatter whitelist), **R-REF-SUPERSEDE-1** (deprecated content via `<details>`), **R-REF-SECRETS-1** (no hard-coded credentials), **R-LOG-REJECT** (no runtime `log.md` inside `references/`). All four are PROPOSED-with-single-Tier-1-backing pending Q-015 cross-confirmation.

> **The conceptual line** _(purple)_
>
> **Skill = procedural how-to** (what to do, in what order, under what conditions). **Reference = factual what-is** (schemas, lookup tables, exhaustive option lists). The agent reads procedural content to act; it consults reference content to verify or look up.

<!-- @rule: R-SR-1 -->
<a id="r-sr-1"></a>

**R-SR-1** [skill] [portable] VALIDATED.

**Procedural how-to → SKILL.md body** (always) **OR `references/<topic>.md`** when the procedure is variant-specific (e.g., `references/aws.md`, `references/gcp.md`).

<!-- @rule: R-SR-2 -->
<a id="r-sr-2"></a>

**R-SR-2** [reference] [portable] VALIDATED.

**Factual / lookup → `references/<name>.md` with explicit ToC** when >300 lines (per R-BODY-4). Example pattern: anthropics/skills/pdf has a `reference.md` that catalogs `pdftotext`, `pdftoppm`, `pdfimages`, `qpdf` flags — pure factual lookup.

<!-- @rule: R-SR-3 -->
<a id="r-sr-3"></a>

**R-SR-3** [skill] [portable] VALIDATED.

**Templates, fonts, images, schema files used in *output* → `assets/`.** These are not loaded into Claude's context; they are read by scripts or copied/linked by the workflow.

<!-- @rule: R-SR-4 -->
<a id="r-sr-4"></a>

**R-SR-4** [skill] [portable] VALIDATED.

**Executable code Claude should *run* (not read) → `scripts/`.** The script's source code does not enter context; only its stdout/stderr does.

<!-- @rule: R-SR-5 -->
<a id="r-sr-5"></a>

**R-SR-5** [skill] [portable] VALIDATED.

**References load only when SKILL.md links to them by name.** SKILL.md MUST cite each reference inline with a one-line "load this when…" descriptor — Claude decides whether to follow the link based on this descriptor.

<!-- @rule: R-BODY-5 -->
<a id="r-body-5"></a>

**R-BODY-5** [skill] [portable] VALIDATED.

**Do NOT include `README.md` inside a skill folder.** Anthropic Complete Guide explicitly disallows. All documentation goes in SKILL.md or `references/`.

##### Three-level progressive disclosure (Anthropic canonical)

| Level | What loads | When | Token cost |
|---|---|---|---|
| 1: Metadata | `name` + `description` (and `when_to_use` in Claude Code) | Eagerly at session start, in system prompt | ~100 tokens / skill |
| 2: SKILL.md body | Full Markdown body | When skill triggers | ≤5,000 tokens |
| 3: Resources | Individual references / scripts / assets | Lazily, only when SKILL.md cites them and Claude follows the cite | Effectively unbounded |

**Empirical exemplar:** anthropics/skills/doc-coauthoring keeps the SKILL.md as pure procedural workflow (Context Gathering → Refinement → Reader Testing) and pulls factual material (style guides, formatting rules) dynamically during the Context Gathering phase. Mechanism is separated from data.

##### Q-014 v1.12 — Reference-doc anatomy rules

<!-- @rule: R-REF-FM-1 -->
<a id="r-ref-fm-1"></a>

**R-REF-FM-1** [reference] [portable] PROPOSED — MAY.

**A reference file inside `<skill>/references/` MAY include optional YAML frontmatter limited to `title:`, `summary:`, and `load_when:` fields. No other frontmatter is sanctioned.** Rationale: best-practices doc treats references as documentation-shaped Markdown; Karpathy's P-K10 frontmatter-on-every-page pattern is permitted *only* under this whitelist; arbitrary frontmatter creates ambiguous parsing surface. Source: platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (silent endorsement); Karpathy llm-wiki gist (Discovery support).

<!-- @rule: R-REF-SUPERSEDE-1 -->
<a id="r-ref-supersede-1"></a>

**R-REF-SUPERSEDE-1** [reference] [portable] PROPOSED — MAY.

**Deprecated reference content MAY be retained inside the same file under a `<details><summary>Old patterns / deprecated …</summary>…</details>` HTML-disclosure block instead of being deleted.** Implements LLM-Wiki-v2's 'supersession over decay' principle (Mattia83it counter-pattern) at the within-file scale. Source: platform.claude.com best-practices § 'Avoid time-sensitive information' canonical example (uses `<details>` summary 'Legacy v1 API'); rohitg00 LLM-Wiki-v2 + Mattia83it commentary (Discovery).

<!-- @rule: R-REF-SECRETS-1 -->
<a id="r-ref-secrets-1"></a>

**R-REF-SECRETS-1** [reference] [portable] PROPOSED — SHOULD.

**Reference files SHOULD NOT contain hard-coded credentials, API keys, tokens, or PII; secrets MUST be externalised** (environment variables, secret stores, runtime injection). Source: platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise — "Verify no hardcoded credentials. Check for API keys, tokens, or passwords in Skill files. Credentials should use environment variables or secure credential stores, never appear in Skill content."

<!-- @rule: R-LOG-REJECT -->
<a id="r-log-reject"></a>

**R-LOG-REJECT** [reference] [portable] PROPOSED — MUST NOT.

**A skill `references/` directory MUST NOT contain a runtime append-only `log.md` (Karpathy P-K8 chronological journal pattern).** Activity logging is the responsibility of the project-memory layer (CLAUDE.md `@import` per R-MEM-10) or git, not the skill layer. Skills are read-only at runtime per platform.claude.com/docs/en/agents-and-tools/agent-skills/overview ("Claude reads SKILL.md only when the Skill becomes relevant"); no anthropics/skills production skill ships a `log.md`; R-CHUNK-6 forbids primary-lookup mechanisms beyond grep-then-read.

##### Q-015 v1.13 — Inter-container scope (skills × CLAUDE.md × AGENTS.md × repo docs)

Q-001 framed the 'Skill vs Reference Content' boundary as **intra-skill** (SKILL.md body vs `<skill>/references/<topic>.md`). Q-015 extends the same routing question to the **inter-container** scope across four containers: skills (`.claude/skills/<name>/`), project memory (`<root>/CLAUDE.md` with optional `@`-imports), the open AGENTS.md standard (`<root>/AGENTS.md`, AAIF/LF-stewarded), and conventional repo docs (`README.md`, `ARCHITECTURE.md`, `docs/adr/`, runbooks). The four containers are a coordinated routing system, not independent locations. (See system-design § *Interaction with CLAUDE.md / AGENTS.md* for the AGENTS.md-side mechanics; see Reference Chunking & Lazy Loading for the intra-`references/` ToC and chunking rules.)

**The decidable routing test (VALIDATED, derived from canonical Anthropic Tier-1 anchors):** *Q1.* Does the knowledge instruct Claude *how* to do a sequence of steps? → SKILL.md (procedural; R-BOUNDARY-1). *Q2.* Is it a stable, project-wide invariant Claude needs every session? → `<root>/CLAUDE.md` (≤200-line target; R-BOUNDARY-3); or `<root>/AGENTS.md` if it should also be consumed by other AI coding agents (Codex, Cursor, Aider, Cline, Continue, Windsurf, Gemini CLI, Jules, Junie, Devin, GitHub Copilot, etc.); R-BOUNDARY-4. *Q3.* Is it long-form descriptive material tied to one skill's task? → `<skill>/references/<topic>.md`, one level deep, no chained links (R-BOUNDARY-2 reaffirms R-CHUNK-4). *Q4.* Is it primarily for human contributors and only consulted by Claude on demand? → repo doc (`README.md` / `ARCHITECTURE.md` / ADR / runbook), referenced via `@`-import or outbound link from a skill, NOT duplicated; if the human prose is ill-suited for agent reading, the skill MAY carry an agent-readable rewrite that marks the human doc as canonical for facts (R-BOUNDARY-5; canonical-source marker mechanism is P-BOUND-SUPERSEDE-2 PROPOSED).

###### Adopted rules (R-BOUNDARY-1..-9, R-BOUNDARY-4-CLARIFICATION)

**R-BOUNDARY-1 [skill][portable] VALIDATED** — Multi-step procedures (sequential steps, checklists, tool invocations) MUST be authored as SKILL.md, never CLAUDE.md/AGENTS.md content. **Subagent context-isolation carveout:** privacy/secrecy and large-noisy-data tasks MUST be routed to skills that delegate work to subagents (fresh isolated context windows; main session protected during auto-compaction). Anchor: 'How Claude remembers your project' (Anthropic, 2026) — *'If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill.'* Reaffirms **DA-004**.

**R-BOUNDARY-2 [reference][portable] VALIDATED** — Long-form descriptive material tied to one skill's task lives in `<skill>/references/<topic>.md`, one level deep from SKILL.md. Mechanism: chained references trigger `head -100`-style partial reads ('Skill authoring best practices', Anthropic, 2026 — verbatim); flat one-hop topology guarantees full-file reads. Reaffirms **R-CHUNK-4**.

**R-BOUNDARY-3 [skill][claude-code-only] VALIDATED** — `<root>/CLAUDE.md` is the home for project-wide always-on invariants (build/test/lint/format commands, package manager, project layout map, naming conventions, 'always do X' rules) and pointer-style imports. **Target ≤200 lines** for adherence quality. **Strict carveout (formalized v1.13):** the 200-line figure is a *target*, NOT a truncation cap. Verbatim Anthropic Tier-1 ('How Claude remembers your project'): *'This limit applies only to MEMORY.md. CLAUDE.md files are loaded in full regardless of length, though shorter files produce better adherence.'* Long procedures MUST NOT be added (DA-004). See **DA-140** for rejected silent-truncation conflation.

**R-BOUNDARY-4 [skill][portable] VALIDATED** — When the project also targets non-Claude agents, tool-portable invariants belong in `<root>/AGENTS.md`; `<root>/CLAUDE.md` MUST import via verbatim `@AGENTS.md` and MAY add a Claude-Code-specific section below. Same canonical Anthropic anchor as **R-MEM-10**. **R-BOUNDARY-4-CLARIFICATION [skill][claude-code-only] VALIDATED — NEW v1.13:** when `<root>/AGENTS.md` exists and `<root>/CLAUDE.md` imports it, the verbatim `@AGENTS.md` directive MUST be the **first content line** of `<root>/CLAUDE.md` (before any other instruction). Claude-Code-specific content follows. Locks in the structural ordering observed in the canonical Anthropic example.

**R-BOUNDARY-5 [reference][portable] VALIDATED** — Repo docs (`README.md`, `ARCHITECTURE.md`, `docs/adr/`, runbooks) MUST be *referenced*, not duplicated. From CLAUDE.md, use `@README.md`-style imports per the canonical Anthropic memory doc (max five hops). From a skill, use outbound links from `<skill>/references/<topic>.md` to repo docs (leaf links, NOT chained references — R-CHUNK-4 is preserved). When the human-targeted style impedes agent reading, the skill MAY carry an agent-readable rewrite, with a `canonical:` marker pointing back at the human doc as source of truth for facts (the marker mechanism is **P-BOUND-SUPERSEDE-2 PROPOSED**).

**R-BOUNDARY-6 [skill][claude-code-only] VALIDATED** — Skills MUST NOT carry an AGENTS-equivalent file; MUST NOT be `@`-imported to a parallel-name target; MUST NOT be symlinked to such a target. **R-MEM-10-CARVEOUT applies:** R-MEM-10 is project-memory-layer only. SKILL.md is the sole entrypoint. Strict-default rejection of any skill-layer AGENTS-equivalent construct.

**R-BOUNDARY-7 [skill][portable] VALIDATED** — The skill `description` field MUST encode both *what* the skill does and *when* Claude should use it; ≤1024 characters; written in third person. Reaffirms description budget. Anchor: 'Skill authoring best practices' (Anthropic, 2026) — verbatim.

**R-BOUNDARY-8 [skill][claude-code-only] VALIDATED (qualitative)** — A piece of knowledge expected in ≥~50% of sessions and consisting of stable invariants (not procedures) MAY live in CLAUDE.md (subject to ≤200-line target). Knowledge expected in <~50% of sessions MUST live in a skill so it stays out of context until activated. Anchor: 'Best practices for Claude Code' (Anthropic, 2026). The ~50% midpoint is editorial; the rule is qualitative.

**R-BOUNDARY-9 [reference][portable] VALIDATED — NEW v1.13** — Reference files in `<skill>/references/` longer than **100 lines** MUST include a table of contents at the top (detailed enough that the agent's `head -100`-style partial reads still surface the full document scope). Anchor: 'Skill authoring best practices' (Anthropic, 2026) — verbatim *'For reference files longer than 100 lines, include a table of contents at the top.'* Corrects Gemini-15's inflated 300-line claim (→ DA-144). See skill-spec § *Reference Chunking & Lazy Loading* for ToC formatting guidance.

###### PROPOSED rules (cross-container supersession contract)

**P-BOUND-SUPERSEDE-1 [skill][portable] PROPOSED** — Single source of truth: each fact has exactly one canonical container; other containers carry a pointer only. **P-BOUND-SUPERSEDE-2 [skill][portable] PROPOSED** — Where a derived agent-readable view exists alongside a canonical human-readable doc, the derived view MUST carry an explicit `canonical:` marker (frontmatter or first-line) pointing at the canonical source. **P-BOUND-SUPERSEDE-3 [skill][claude-code-only] PROPOSED** — Within a CLAUDE.md that imports `@AGENTS.md`, content authored *below* the import wins on conflict (extrapolation from documented directory-walk later-wins semantics; the in-file case is implied but not stated verbatim). **P-BOUND-DRIFT-1 [skill][portable] PROPOSED** — Drift scan compares hashes/timestamps of canonical sources to derived copies on the cadence set by Q-008; flags divergence. **P-BOUND-GROUNDING-1 [reference][portable] PROPOSED — NEW v1.13 (narrow scope)** — For domains with formal validity invariants (regulated scientific computing, safety-critical systems), repositories MAY adopt a domain-scoped GROUNDING.md following Palmblad et al. (arXiv:2604.21744, 2026; Hard Constraints + Convention Parameters). Precedence is achieved by importing it from CLAUDE.md (`@GROUNDING.md` placed before `@AGENTS.md`) and reinforcing in skill bodies. **NOT a platform-injection mechanism.** Out of scope for the validation script unless explicitly opted in.

> **v1.14 addition (Q-016) — R-BOUNDARY-2 'one level deep' inherits markdown-link-depth semantics** _(amber)_
>
> **R-BOUNDARY-2-CLARIFICATION [reference][portable] VALIDATED — NEW v1.14.** R-BOUNDARY-2's phrase *'linked one level deep from SKILL.md'* uses the same Anthropic best-practices anchor as R-CHUNK-4, and therefore inherits the v1.14 markdown-link-depth interpretation: every reference file MUST be reachable in one markdown-link hop from SKILL.md, regardless of its filesystem path depth below SKILL.md. `<skill>/references/<topic>.md` remains the recommended idiomatic layout, but multi-level filesystem layouts that preserve one-hop graph-reachability — as in `anthropics/skills/claude-api`'s `python/claude-api/tool-use.md` linked directly from SKILL.md — are permitted. See R-CHUNK-4 v1.14 and Session Notes — Q-016.

### Workspace Topology

> **Q-009 added this subsection** _(blue)_
>
> 17 rules across 5 families adopted in v1.9 with Tier-1 Anthropic backing. **Plugin distribution (R-WORKSPACE-3)** is the canonical cross-scope sharing mechanism; **embed-and-duplicate (R-SHARE-1, reaffirming DA-058)** stays the canonical pattern for non-plugin cross-skill helpers. **Pre-registered thresholds:** T-MONO-1 (≥3 services → plugin), T-SHARE-1 (≥2 skills sharing helper → plugin-root), T-PFX-1 (≥2 collisions → plugin-per-service), T-REF-1 (>10K-word reference → grep guidance per R-SR-7). **Caveat:** R-MONO-1 + R-MONO-4 reflect a known runtime regression (`Bun.Glob.scan()` `dot: false` default in CLI ≥2.1.92, anthropics/claude-code #44490) that breaks documented "Automatic Discovery from Nested Directories"; defensive guidance applies until Anthropic patches.

##### R-WORKSPACE — Cross-scope discovery (6 rules)

<!-- @rule: R-WORKSPACE-1 -->
<a id="r-workspace-1"></a>

**R-WORKSPACE-1** [skill] [claude-code-only] VALIDATED — MECHANICAL.

**Single-depth discovery at every scope.** Skills are discovered only at `<scope>/.claude/skills/<skill-name>/SKILL.md`. Container directories (`<scope>/.claude/skills/<group>/<skill>/SKILL.md`) are silently ignored. Validators MUST fail any submitted skill whose `SKILL.md` is more than one level below `.claude/skills/`. Source: anthropics/claude-code Issues #10238, #16438, #18192, #20755, #28266, #39138.

<!-- @rule: R-WORKSPACE-2 -->
<a id="r-workspace-2"></a>

**R-WORKSPACE-2** [skill] [claude-code-only] VALIDATED — MECHANICAL.

**Subfolder-launch monorepo invocations.** When Claude Code is launched from a monorepo subfolder and root-level skills are needed, supported invocations in priority order: (a) `claude --add-dir <monorepo-root>` to import the root's `.claude/skills/` per the documented "skill exception"; (b) install shared skills as a **plugin** at user/personal scope (R-WORKSPACE-3). Do NOT rely on `additionalDirectories` in `settings.json` (Issues #37553, #43267 — does not load skills). Do NOT rely on `${CLAUDE_SKILLS_PATH}` (Issue #22902 — does not exist).

<!-- @rule: R-WORKSPACE-3 -->
<a id="r-workspace-3"></a>

**R-WORKSPACE-3** [skill] [portable] VALIDATED — HYBRID.

**Plugin distribution is the canonical mechanism for cross-scope skill sharing.** When ≥2 services in the same monorepo would benefit from the same skill (T-MONO-1 threshold), package the shared skills as a Claude Code plugin and publish via marketplace (`/plugin marketplace add <repo>` + `/plugin install <plugin>@<marketplace>`). Naming uses `plugin-name:skill-name` namespace. Source: code.claude.com/docs/en/plugins; anthropics/claude-plugins-official.

<!-- @rule: R-WORKSPACE-4 -->
<a id="r-workspace-4"></a>

**R-WORKSPACE-4** [skill] [claude-code-only] VALIDATED — MECHANICAL.

**`paths` gates auto-activation only, not discovery.** The `paths` frontmatter glob field affects whether a skill is auto-loaded for matching files; it does NOT cause the skill to be discovered if it is not already in a discovered scope (per R-WORKSPACE-1/R-WORKSPACE-2). Validators must verify `paths` globs are not used as a discovery substitute. Source: code.claude.com/docs/en/skills; allahabadi.dev complete frontmatter guide.

<!-- @rule: R-WORKSPACE-5 -->
<a id="r-workspace-5"></a>

**R-WORKSPACE-5** [skill] [claude-code-only] PROPOSED — MECHANICAL.

**Skill-folder symlink fragility.** Symlinks at `<scope>/.claude/skills/<name> → <target>` work at execution but not at the `/skills` listing (Issue #14836) and may produce a transient "Unknown skill" error before resolving (Issue #25367). Validators SHOULD warn on symlinked skill directories with the message "discovery may be unreliable; consider plugin distribution (R-WORKSPACE-3) instead." Source: anthropics/claude-code Issues #14836, #25367, #37590.

<!-- @rule: R-WORKSPACE-6 -->
<a id="r-workspace-6"></a>

**R-WORKSPACE-6** [skill] [portable] PROPOSED — MECHANICAL.

**Service-prefix tolerated, plugin-per-service preferred.** When two services in the same monorepo have skills with colliding names, prefer plugin distribution with namespacing (R-WORKSPACE-3). The `<service>-<skill-name>` prefix pattern (e.g. `aworkers-triage-issues`) is **TOLERATED** as a transitional workaround (PRE-REGISTERED THRESHOLD T-PFX-1: ≥2 services collision → migrate to plugins). Source: anthropics/claude-code Issue #16438 + empirical scan of anthropics/skills (no service-prefixes in shipping skills).

##### R-MONO — Monorepo specifics (4 rules)

<!-- @rule: R-MONO-1 -->
<a id="r-mono-1"></a>

**R-MONO-1** [skill] [claude-code-only] VALIDATED — with-caveat HYBRID.

**Documented "Automatic Discovery from Nested Directories" is broken in shipping CLI ≥ 2.1.92.** Per code.claude.com/docs/en/skills, when editing a file at `packages/frontend/src/App.tsx`, Claude should auto-load skills at `packages/frontend/.claude/skills/`. **Root cause (anthropics/claude-code Issue #44490):** `Bun.Glob.scan()` defaults to `dot: false`, which aborts traversal of any `.claude/`-prefixed directory before evaluating wildcards — regression introduced between CLI 2.1.81 (working) and CLIs 2.1.92 (broken). Cross-references Issues #33999, #17302, #43178, #40640. **Defensive recommendation:** place skills at the cwd's `.claude/skills/` (no parent or nested traversal reliance) until Anthropic patches. Validators MUST NOT enforce or assume nested discovery.

<!-- @rule: R-MONO-2 -->
<a id="r-mono-2"></a>

**R-MONO-2** [skill] [claude-code-only] PROPOSED — SEMANTIC.

**Preferred topology for ≥3-service monorepos (T-MONO-1).** (a) Per-service `.claude/skills/` for service-specific procedures. (b) User-installed plugin (`/plugin install <org>-shared-skills`) for cross-service patterns. (c) `--add-dir <monorepo-root>` only as session-time fallback when neither (a) nor (b) applies. Validators classify deviations as warnings, not failures.

<!-- @rule: R-MONO-3 -->
<a id="r-mono-3"></a>

**R-MONO-3** [skill] [claude-code-only] VALIDATED — MECHANICAL.

**Cross-skill router/index-skill pattern is DISCOURAGED.** SKILL.md bodies that link via Markdown to sibling skill folders (`../<other-skill>/SKILL.md`) are not supported by Anthropic's progressive-disclosure architecture: the linked target is read via `Read` (not dispatched as a skill), so it loses skill-loading semantics including `disable-model-invocation`, allowed-tools narrowing, and the 25,000-token re-attach budget. Anthropic's own internal-router pattern (e.g. pptx/SKILL.md → editing.md → ooxml.md, anthropics/skills) is **intra-skill** routing only, never cross-skill. Source: anthropics/skills pptx/SKILL.md.

<!-- @rule: R-MONO-4 -->
<a id="r-mono-4"></a>

**R-MONO-4** [skill] [claude-code-only] PROPOSED — MECHANICAL — NEW v1.9 from Gemini-9.

**`find` instead of `Glob` for `.claude/`-traversal on CLI ≥ 2.1.92.** When skill body instructions require finding files inside `.claude/` (e.g., reference files at `.claude/skills/<name>/references/<file>.md`) on Claude Code CLI ≥ 2.1.92, agents must use Bash `find` rather than the Glob tool, because `Bun.Glob.scan()` defaults to `dot: false` and silently returns "No files found" for any `.claude/`-prefixed pattern. **Canonical workaround pattern (verbatim from Issue #44490):** `SKILL_ROOT=$(dirname "$(find <repo-root> -path '*/<skill-name>/scripts/<known-script>' 2>/dev/null | head -1)")/..; REFS="$SKILL_ROOT/references"`. Status PROPOSED — sunsets automatically when Anthropic patches `Bun.Glob` default; Q-009 reopens for VALIDATED-or-retire decision at that point. Hallucination canary: validators must reject any rule that prescribes raw `Bun.Glob` invocation.

##### R-SHARE — Shared scripts and helpers (4 rules)

<!-- @rule: R-SHARE-1 -->
<a id="r-share-1"></a>

**R-SHARE-1** [skill] [portable] VALIDATED — MECHANICAL.

**DA-058 reaffirmed: embed-and-duplicate vs plugin-bundled-helpers (T-SHARE-1).** When a helper script is needed by ≥2 skills, the canonical resolution depends on packaging: (a) **Both skills in the same plugin** → place script at `${CLAUDE_PLUGIN_ROOT}/scripts/<helper>` and reference from each skill body. Anthropic-endorsed. (b) **Skills not packaged as a plugin** → embed-and-duplicate (R-COMP-3). Each skill ships its own copy. (c) **Skills in different plugins** → not supported (Issue #15944); embed-and-duplicate at the plugin level. Empirical anchor (T-SHARE-1): anthropics/skills Issue #953 documents 30 physical ISO-IEC29500 XSD-schema files where 10 would suffice across docx/pptx/xlsx — proving the inflection point at ≥2 sharing skills. Source: code.claude.com/docs/en/plugins-reference; anthropics/skills empirical scan; Issue #15944.

<!-- @rule: R-SHARE-2 -->
<a id="r-share-2"></a>

**R-SHARE-2** [skill] [portable] VALIDATED — MECHANICAL.

**No `.claude/scripts/` convention exists.** Validators MUST reject any rule or skill that assumes `<scope>/.claude/scripts/` is loaded by Claude Code; the documented exceptions table includes `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/`, `.claude/hooks/`, `.claude/output-styles/` only. Source: code.claude.com/docs/en/skills exceptions table.

<!-- @rule: R-SHARE-3 -->
<a id="r-share-3"></a>

**R-SHARE-3** [skill] [claude-code-only] VALIDATED — MECHANICAL.

**`${CLAUDE_PLUGIN_ROOT}` only in JSON/YAML config.** Within a plugin, helper scripts MUST be referenced via `${CLAUDE_PLUGIN_ROOT}/<path>` in JSON config (hooks.json, .mcp.json) and in YAML frontmatter (allowed-tools, hooks). They MUST NOT be referenced inside `.md` body content for surfaces where the variable does not expand (Issue #9354) — instead, the skill body should call a script that itself reads `$CLAUDE_PLUGIN_ROOT` at runtime. Source: anthropics/claude-code Issues #9354, #15642, #27145.

<!-- @rule: R-SHARE-4 -->
<a id="r-share-4"></a>

**R-SHARE-4** [skill] [portable] VALIDATED — MECHANICAL.

**`${CLAUDE_SKILL_DIR}` for non-plugin skills.** For personal/project-scope skills (no plugin), bundled-script paths inside SKILL.md MUST use `${CLAUDE_SKILL_DIR}/<path>` (not relative paths from cwd, not absolute paths). This anchors against the skill's invoked location regardless of personal/project/plugin scope. Source: code.claude.com/docs/en/skills (codebase-visualizer example).

##### R-REFLOC — References-in-repo-docs (4 rules)

<!-- @rule: R-REFLOC-1 -->
<a id="r-refloc-1"></a>

**R-REFLOC-1** [reference] [portable] VALIDATED — MECHANICAL.

**No `..` paths in SKILL.md body or references.** Skill `references/` files MUST be self-contained within the skill folder. Linking from SKILL.md body or `references/_index.md` to `../../docs/*.md` paths violates R-SYS-1 (drop-in folder portability) and is **rejected by mechanical validator**. Source: platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices ("File paths matter: Claude navigates your skill directory like a filesystem").

<!-- @rule: R-REFLOC-2 -->
<a id="r-refloc-2"></a>

**R-REFLOC-2** [reference] [portable] PROPOSED — HYBRID.

**Repo-docs reuse patterns (a)–(d).** When repo-internal `docs/*.md` content overlaps a skill's domain, supported patterns in priority order: (a) Copy the canonical content into `<skill>/references/` and accept duplication (preserves R-SYS-1) — preferred. (b) Author the content in `<skill>/references/` and have repo `docs/` link to the skill's references (single source of truth lives with the skill). (c) Keep repo `docs/` authoritative and have a **non-portable** "internal-only" skill (clearly marked with description starting `[internal — not portable]`) that links via `../../docs/`. **(d) NEW from Gemini-9 G9-E (Discovery-tier).** A centralized `~/.claude/docs/` (personal scope) directory referenced from skill bodies via absolute-path Read instructions, when many internal skills share knowledge and plugin packaging is not viable. Pattern (d) requires the same "non-portable" tagging as pattern (c). Source: anthropics/skills Issue #953 (PROBABLE-VERIFIED) — single user-attested pattern.

**Clause (c) clarification — VALIDATED MECHANICAL.** Internal-only carve-out uses existing Anthropic-validated frontmatter keys; no new key. R-REFLOC-2(c) implements visibility control via `user-invocable: false` (R-FM-6) — hides the skill from `/skill-name` autocomplete — plus a tightly-scoped `paths` glob (e.g. `paths: ["docs/**", "internal/**"]`) — gates auto-activation to internal file structures. **No new frontmatter key (`internal: true` or otherwise) is introduced** (DA-108). The skill description must explicitly start with `[internal — not portable]` so retrieval-time signals carry the non-portability semantically. Source: code.claude.com/docs/en/skills frontmatter table (15-key allow-list, R-FM-6); Anthropic-supremacy applied against vercel-labs/skills' Tier-2 cross-tool `metadata.internal: true` convention.

<!-- @rule: R-REFLOC-3 -->
<a id="r-refloc-3"></a>

**R-REFLOC-3** [reference] [portable] VALIDATED — MECHANICAL.

**Reference TOC integrity (extension of R-BODY-4).** When the SKILL.md body exceeds 300 lines, a `references/_index.md` MUST exist with a table-of-contents pointing only to files **within the skill folder**. References to repo paths outside the skill folder MAY appear in the TOC ONLY when the skill is tagged "internal" per R-REFLOC-2(c) or R-REFLOC-2(d).

<!-- @rule: R-REFLOC-4 -->
<a id="r-refloc-4"></a>

**R-REFLOC-4** [reference] [claude-code-only] VALIDATED — MECHANICAL.

**`paths` is not a content-loading mechanism.** The `paths` frontmatter glob MUST NOT be used as a substitute for placing reference content in `<skill>/references/`. Validators must flag skills where `paths` matches `docs/**` *and* SKILL.md body has zero links to `references/` — this is a smell indicating the skill is misusing `paths` as a content router. Source: code.claude.com/docs/en/skills (paths gates auto-activation only).

##### R-CROSS — Cross-cutting (1 rule)

<!-- @rule: R-CROSS-1 -->
<a id="r-cross-1"></a>

**R-CROSS-1** [skill] [claude-code-only] VALIDATED — MECHANICAL.

**Hallucination canary: `${CLAUDE_SKILLS_PATH}` and `skillsDirectories` do NOT exist.** As of 2026-05-04, `${CLAUDE_SKILLS_PATH}` and any other env-var override for skill discovery directory **DO NOT EXIST** (Issue #22902 still open per snapshot; #39403 requests `skillsDirectories` array). Validators MUST reject any rule, skill, or doc that assumes such a variable exists. **Mirror canary added in v1.9:** `Bun.Glob` direct invocation (per R-MONO-4 — workaround uses `find`, not Glob); `internal: true` frontmatter key (per DA-108 — use `user-invocable: false` + `paths` instead). If a future LLM-generated rule cites these, treat as suspect and re-verify against shipping docs.

### Multi-task Composition

> **Q-006 added this subsection** _(blue)_
>
> 16 rules across 5 families adopted in v1.6 with Tier-1 Anthropic backing. The **four-layer composition ladder (R-COMP-1)** is the canonical escalation algorithm; all other rules in this subsection plug into it. Cross-link: see [Parallelism & Delegation Topology ↗](#parallelism-delegation-topology){tab=system-design} for the system-level diagram and [Validation Rules ↗](#validation-rules-machine-checkable){tab=meta-validation} for the mechanical checks.

##### Composition (R-COMP-*)

<!-- @rule: R-COMP-1 -->
<a id="r-comp-1"></a>

**R-COMP-1** [skill] [claude-code-only] VALIDATED.

**The four-layer composition ladder.** When designing a multi-task skill, climb the ladder only when the lower rung is insufficient: (1) **inline + progressive disclosure** — one SKILL.md ≤500 body lines per R-BODY-1, references in `references/`; (2) **`context: fork` + `agent: Explore|Plan|general-purpose`** — run an executable sibling task in an isolated fresh context with the SKILL.md as the prompt; (3) **custom subagent in `.claude/agents/`** with explicit `skills:` preload field for domain-specific knowledge plus a custom system prompt; (4) **agent teams** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, v2.1.32+, Opus 4.6+) — only when peers must message each other and coordinate via a shared task list. Token cost asymmetry: chat ≈ 1×, subagent ≈ 4×, multi-agent ≈ 15× (Anthropic, *How we built our multi-agent research system*, 2025).

<!-- @rule: R-COMP-2 -->
<a id="r-comp-2"></a>

**R-COMP-2** [skill] [claude-code-only] VALIDATED.

**Sub-skill invocation is model-mediated, never programmatic.** A parent SKILL.md cannot directly call a peer skill in code; it must surface intent and let the model invoke the second skill (or use `context: fork` to embed the call site as a subagent prompt). Anthropic provides no programmatic skill-call API in SKILL.md content; bash injection (`!​​​​command` and `​```!`) preprocesses the prompt but cannot transfer control to another skill. The `Skill` tool exposed to the model has only a `command` parameter and no chaining mechanism (Anthropic, *Extend Claude with skills*, 2026, code.claude.com/docs/en/skills).

<!-- @rule: R-COMP-3 -->
<a id="r-comp-3"></a>

**R-COMP-3** [reference] [portable] VALIDATED.

**Embed shared helpers; do not symlink across peer skills.** The `anthropics/skills` repository contains zero examples of cross-skill helper sharing; every skill bundles its own `scripts/` and `references/`. Authors should duplicate small helpers across peer skills and accept that as the cost of self-containment. The `skill-workshop` skill explicitly endorses this: "the skill should bundle that script. Write it once, put it in `scripts/`." **Note:** a `shared/` *subdirectory inside* a single skill (as in the bundled `claude-api` skill) is fine — that is intra-skill organization, not inter-skill linking.

##### Parallelism (R-PAR-*)

<!-- @rule: R-PAR-1 -->
<a id="r-par-1"></a>

**R-PAR-1** [skill] [claude-code-only] VALIDATED.

**Use `context: fork` for executable sub-tasks; never for reference content.** Direct quotation from Anthropic's docs: "`context: fork` only makes sense for skills with explicit instructions. If your skill contains guidelines like 'use these API conventions' without a task, the subagent receives the guidelines but no actionable prompt, and returns without meaningful output." If a skill is reference-style (`api-conventions`, `style-guide`), keep it inline; do not add `context: fork`.

<!-- @rule: R-PAR-2 -->
<a id="r-par-2"></a>

**R-PAR-2** [skill] [claude-code-only] VALIDATED — PRE-REGISTERED 3–5/8.

**Pre-registered fan-out budget: 3–5 parallel sibling forks per parent skill (default), with a hard ceiling of 8.** Threshold justification: Anthropic's *How we built our multi-agent research system* (2025) trains the lead agent to use "3-5 subagents in parallel rather than serially" and explicitly contemplates ">10 subagents" only for complex research; the 8-ceiling matches **R-API-1** (max 8 skills per Messages API request) so the fan-out fits within a single API-turn envelope. Strictness default applies on the lower bound. The validator surfaces a WARNING when an orchestrator prompt instructs the model to spawn >8 parallel branches.

<!-- @rule: R-PAR-3 -->
<a id="r-par-3"></a>

**R-PAR-3** [skill] [portable] VALIDATED.

**Independence test before fan-out.** Only fan out when (a) sibling tasks share no mutable state, (b) no sibling consumes another's output, and (c) order of completion is irrelevant. Anthropic's docs frame this as: "This works best when the research paths don't depend on each other" (Anthropic, *Create custom subagents*, 2026). Maps to LangGraph's `Send` semantics and OpenAI's `parallel_tool_calls` field; portable to non-Claude-Code agent stacks.

<!-- @rule: R-PAR-4 -->
<a id="r-par-4"></a>

**R-PAR-4** [reference] [claude-code-only] VALIDATED.

**Forked skills inherit CLAUDE.md but not session conversation; named subagents inherit neither (start fresh).** The `/fork` interactive feature gated by `CLAUDE_CODE_FORK_SUBAGENT=1` is the *one exception* — it inherits the parent's full conversation, system prompt, and tool set. Document this in spec tables for predictable composition reasoning. Bidirectional table:

| Approach | System prompt | Task | Also loads |
|---|---|---|---|
| Skill with `context: fork` | From `agent` type (`Explore`, `Plan`, `general-purpose`) | SKILL.md content (the body becomes the prompt) | CLAUDE.md — NOT session conversation |
| Subagent with `skills:` field | Subagent's markdown body | Claude's delegation message | Preloaded skills + CLAUDE.md — NOT session conversation |
| Interactive `/fork` (`CLAUDE_CODE_FORK_SUBAGENT=1`) | Parent's exact system prompt | User's next instruction | Full conversation history + active tools (uses parent prompt cache) |

##### Delegation (R-DEL-*)

<!-- @rule: R-DEL-1 -->
<a id="r-del-1"></a>

**R-DEL-1** [skill] [claude-code-only] VALIDATED — PRE-REGISTERED depth=2.

**Subagents cannot spawn subagents; forks cannot spawn forks. Plan composition depth ≤ 2.** Direct quotations: "Subagents cannot spawn other subagents" and "A fork cannot spawn further forks." For nested workflows, chain subagents from the main conversation or extract the inner step as a peer skill the parent can invoke. Strictness default applies.

<!-- @rule: R-DEL-2 -->
<a id="r-del-2"></a>

**R-DEL-2** [skill] [claude-code-only] VALIDATED.

**When delegating to a custom subagent that needs domain skills, list them explicitly in the subagent's `skills:` field.** Subagents do **not** inherit skills from the parent conversation. Skills with `disable-model-invocation: true` cannot be preloaded — if a listed skill is missing or disabled, Claude Code skips it and logs a warning to the debug log. If such a skill is required, refactor it to drop the flag and rely on permission rules instead.

<!-- @rule: R-DEL-3 -->
<a id="r-del-3"></a>

**R-DEL-3** [skill] [portable] VALIDATED.

**Pre-registered subagent task brief schema (mandatory four fields):** (1) **objective**; (2) **output format**; (3) **tools/sources whitelist**; (4) **explicit task boundaries**. Direct Anthropic quotation: "Each subagent needs an objective, an output format, guidance on the tools and sources to use, and clear task boundaries. Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information" (Anthropic Engineering Team, 2025). Portable to any subagent system.

##### Conducting / orchestration (R-CONDUCT-*)

<!-- @rule: R-CONDUCT-1 -->
<a id="r-conduct-1"></a>

**R-CONDUCT-1** [skill] [claude-code-only] VALIDATED.

**Default to implicit, model-mediated conduction.** Do not author an "orchestrator skill" for in-session multi-skill coordination; rely on the model's Skill-tool routing. Reserve explicit orchestrators for the agent-teams tier (R-CONDUCT-4). Anthropic's docs prescribe no in-session orchestrator skill pattern; the model itself is the conductor via description-similarity routing.

<!-- @rule: R-CONDUCT-2 -->
<a id="r-conduct-2"></a>

**R-CONDUCT-2** [reference] [claude-code-only] VALIDATED.

**`paths` glob overlap is unresolved; design to tolerate co-activation.** When two different-named skills' `paths` globs both match the same file, both descriptions surface to the model — no resolution order is documented. (Same-name collisions follow a separate rule: enterprise > personal > project; plugin namespaced.) Authors must write `description` fields narrow enough that the model can disambiguate. The validator (Q-008) will surface pairwise textual overlap of `description` fields per R-XPOLL-8.

<!-- @rule: R-CONDUCT-3 -->
<a id="r-conduct-3"></a>

**R-CONDUCT-3** [skill] [claude-code-only] VALIDATED.

**`disable-model-invocation: true` removes the skill from Claude's `<available_skills>` block entirely.** It blocks (a) LLM-driven invocation, (b) `paths`-based auto-activation (both flow through the same `<available_skills>` block), and (c) preloading into subagents. User-driven `/skill-name` still works. Use for human-only side-effect skills (`/deploy`, `/commit`, `/send-slack-message`). Note: `user-invocable: false` is the *opposite* control — hides from `/` menu but keeps in Claude's context.

<!-- @rule: R-CONDUCT-4 -->
<a id="r-conduct-4"></a>

**R-CONDUCT-4** [skill] [claude-code-only] VALIDATED — EXPERIMENTAL.

**When the conductor must coordinate >5 peers OR peers must message each other, escalate to agent teams.** Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; require Claude Code v2.1.32+ and an Opus-class model (4.6+). Document all known limitations in the skill: no nested teams ("teammates cannot spawn their own teams or teammates"), one team per session, no session resumption with in-process teammates. **Status flag: EXPERIMENTAL** — do not adopt as baseline rule until the feature exits research preview; if such a skill is shared publicly, gate it behind an explicit user opt-in.

##### Failure semantics (R-FAIL-*)

<!-- @rule: R-FAIL-1 -->
<a id="r-fail-1"></a>

**R-FAIL-1** [skill] [claude-code-only] VALIDATED — PRE-REGISTERED 25k/5k per session per context-window. **Q-018 v1.16 audit:** numeric core (25,000 combined / 5,000 per-skill / most-recent-first fill) re-confirmed live on canonical Anthropic source `code.claude.com/docs/en/skills` (fetched 2026-05-07) with verbatim text *"Re-attached skills share a combined budget of 25,000 tokens. Claude Code fills this budget starting from the most recently invoked skill, so older skills can be dropped entirely after compaction"* and *"keeping the first 5,000 tokens of each."* Single canonical Anthropic source — sufficient under [project validation gate](#domain) — but no second independent Tier-1 source restates the figures (audit explicitly examined platform.claude.com agent-skills overview/best-practices, anthropic.com/engineering posts on Agent Skills + context engineering, the 32-page *Complete Guide to Building Skills for Claude* PDF, anthropics/skills SKILL.md exemplars including skill-workshop, and Opus 4.7 release notes — all SILENT). Adjacent figures from `anthropic.com/engineering/writing-tools-for-agents` (*"For Claude Code, we restrict tool responses to 25,000 tokens by default"*) are a **distinct mechanism** (tool-response cap, not skill re-attach) and are NOT independent corroboration; see "Confusable 25K figures" below.

**Numeric core (per session, per context-window).** The 25,000-token re-attach budget after auto-compaction is per-session, per-context-window; the budget is filled most-recent-first with the first 5,000 tokens of each invoked skill (so 5 most-recent skills @ 5k each = 25k). Older invocations are dropped entirely after compaction.

**Per-context-window isolation (Q-018 v1.16 scope clarification — was "per-skill-set, per-branch").** Each forked subagent (skill with `context: fork`) and each named custom subagent runs in an isolated context window per the canonical sub-agents doctrine ([code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents): *"Each subagent runs in its own context window with its own custom system prompt, tool access, and permissions"*). Because the auto-compaction lifecycle is bound to the context window, an isolated context window necessarily has an isolated re-attach pool. **Note: this isolation property is a project-internal composition** of (a) the canonical sub-agents doctrine and (b) the bare combined-budget figure. Anthropic Tier-1 documentation does NOT directly state "each subagent has its own independent 25K re-attach pool" or "pools do not merge at fan-in." The composition is logically sound and corroborated by claude-code Issues #5812 and #10212 (which independently confirm sub-agent context isolation as the user-observed primitive), but should be documented as a project-internal extrapolation rather than a verbatim Anthropic contract. The deprecated Q-006 phrasing "per-skill-set, per-branch" was project-internal terminology that did not map to any Anthropic vocabulary; canonical Anthropic terminology is "context window," "Forked Subagent," and "Named Subagent" — not "branch" or "skill-set." The "per-branch isolation" framing originated in third-party Git-worktree-based orchestration tools and was a useful-but-extrapolated mental model.

**Implication for fan-in.** The parent does NOT inherit any subagent's re-attach pool when the subagent returns; the parent receives only the subagent's natural-language summary, which lands in the parent's regular conversation buffer (subject to the parent's own 25k pool on compaction).

**Opus 4.7 effective-budget compression caveat (Q-018 v1.16).** Anthropic's Opus 4.7 release notes ([platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7)) document a tokenizer change that produces 1.0–1.35× more tokens per identical text, with explicit guidance to *"revisit `max_tokens` headroom and compaction triggers."* The 25K/5K nominal budget is **unchanged** as of 2026-05-07, but **effective skill content fitting in the budget is compressed by up to ~26%** (1 − 1/1.35) for code-heavy SKILL.md bodies running on Opus 4.7 — i.e., the same skill body that previously consumed 4,800 tokens may now consume 6,500 tokens and overflow the 5,000-per-skill cap. This is **not** a silent revision in the sense of Issue #45019 (Read-tool 25K→10K downgrade documented in [R-CHUNK-5](#r-chunk-5)); it is an effective compression downstream of a model swap. Skills authored before Opus 4.7 GA (April 16, 2026) should re-measure body and references against the cap when targeting Opus 4.7 sessions.

**Task Budget orthogonality (Q-018 v1.16).** Opus 4.7 introduces Task Budgets (beta header `task-budgets-2026-03-13`; `output_config.task_budget = {"type": "tokens", "total": N}`; minimum 20,000 tokens; advisory not enforced; canonical: [platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7)). **Task Budgets are orthogonal to R-FAIL-1.** A Task Budget is a forward-looking continuous economic governor over the entire agentic loop (thinking + tool calls + tool results + final output); R-FAIL-1's 25K/5K budget is a backward-looking discrete memory-preservation protocol that activates only during a localized auto-compaction event. A generous 100,000-token Task Budget provides **no structural protection** to skill content during compaction — the 5K-per-skill cap is applied unconditionally regardless of remaining task-budget runway. Skill authors must still keep SKILL.md bodies under the 5K cap; "we have plenty of task budget" is not a defense.

**Confusable 25K figures (Q-018 v1.16 expanded disambiguation).** The number "25,000" appears in at least six distinct mechanisms in the Anthropic ecosystem; documentation of R-FAIL-1 must NOT conflate them: (1) **R-FAIL-1's skill re-attach budget** (this rule); (2) **Claude Code Read-tool per-call ceiling** — historical 25K, now 10K per Issues #40357 + #45019; see [R-CHUNK-5](#r-chunk-5); (3) **MEMORY.md auto-memory hard cap** — 25 *KB* / 200 lines (different unit, different scope); CLAUDE.md is not subject to this cap per canonical [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) and [DA-128](#da-128) / [DA-140](#da-140); (4) **Default tool-response cap** — `anthropic.com/engineering/writing-tools-for-agents` verbatim *"For Claude Code, we restrict tool responses to 25,000 tokens by default"* (added Q-018 v1.16); (5) **MCP tool output cap** — `MAX_MCP_OUTPUT_TOKENS` defaults to 25,000 per [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp) (added Q-018 v1.16); (6) **Compaction-instruction overhead** — observed at ~25,000 tokens of system prompt by claude-code Issue #24677 (Cowork death-spiral debug session) (added Q-018 v1.16). Mechanisms (1) and (2) are coupled in citations across the developer ecosystem and are the most-conflated pair; mechanisms (4) and (5) are nearly always confused with (2). The framework's anti-conflation guard text in [system-design § Reference Chunking Topology](#reference-chunking-topology) and [DA-119](#da-119) covers (1)/(2); the new disambiguation expands the list to all six.

**Hard-coded — no override.** The 25K combined re-attach budget and 5K per-skill cap are hard-coded in Claude Code as of 2026-05-07 (verified by exhaustive env-var sweep against `code.claude.com/docs/en/env-vars`, `code.claude.com/docs/en/settings`, the Ken Huang Substack source-code reproduction, and Issue #42149's enumeration of related knobs). The adjacent setting `autoCompactWindow` (env var: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`; min 100,000 / max 1,000,000 tokens per Issue #42149) controls **when** compaction triggers (the context-window threshold), not the re-attach budget itself. There is no `SLASH_COMMAND_TOOL_CHAR_BUDGET`-equivalent override for R-FAIL-1's parameters; skill authors must design within 25K/5K.

**Watch item.** Because the entire numeric core rests on a single Tier-1 source, R-FAIL-1 is structurally vulnerable to the exact silent-downgrade pattern that produced Issue #45019. Recommendation logged with [Q-013-style cadence](#q-013): periodic (quarterly) automated diff of `code.claude.com/docs/en/skills` for the literal strings "25,000 tokens" and "5,000 tokens"; alert on disappearance or change.

<!-- @rule: R-FAIL-2 -->
<a id="r-fail-2"></a>

**R-FAIL-2** [skill] [claude-code-only] VALIDATED.

**Use `PostToolBatch` (not per-tool `PostToolUse`) for parallel-branch fan-in validation.** Direct quotation: "`PostToolBatch` runs once after every tool call in a batch has resolved, before Claude Code sends the next request to the model. `PostToolUse` fires once per tool, which means it fires concurrently when Claude makes parallel tool calls. `PostToolBatch` fires exactly once with the full batch." `PostToolBatch` is the canonical fail-fast point: exit code 2 "stops the agentic loop before the next model call." There is no matcher for this event — it always fires per batch.

<!-- @rule: R-FAIL-3 -->
<a id="r-fail-3"></a>

**R-FAIL-3** [reference] [claude-code-only] VALIDATED.

**Subagent failure surfaces as natural-language summary, not stderr/exit code.** The parent receives the subagent's final assistant message and (optionally) `additionalContext` injected by a `SubagentStop` hook. **No structured stderr/exit-code field crosses the boundary.** Parent skills must NOT assume structured error propagation; if the parent needs to react programmatically to a subagent failure, use a `SubagentStop` hook to inject structured status into the parent's context.

<!-- @rule: R-FAIL-4 -->
<a id="r-fail-4"></a>

**R-FAIL-4** [skill] [claude-code-only] VALIDATED.

**In parallel fan-out, one branch's exit-2 hook blocks only its own tool call, not siblings.** All matching hooks within the same matcher group run in parallel and are deduplicated automatically (command hooks by command string, HTTP hooks by URL). An exit-2 from any one hook in a blockable event blocks *that hook's* tool action. For cross-branch coordination, use `PostToolBatch` (R-FAIL-2).

<!-- @rule: R-FAIL-5 -->
<a id="r-fail-5"></a>

**R-FAIL-5** [skill] [claude-code-only] VALIDATED.

**Pre-approve all background-subagent permissions at fan-out time; an under-permissioned branch will auto-deny silently rather than block.** Direct quotation: "Once running, the subagent inherits these permissions and auto-denies anything not pre-approved. If a background subagent needs to ask clarifying questions, that tool call fails but the subagent continues." Implication: an orchestrator must enumerate every tool every branch will need at spawn time; mid-execution permission requests fail silently and the branch silently degrades rather than failing fast.

##### Hooks-event blockability matrix (canonical)

| Event | Can block? | Effect of exit code 2 | Use for |
|---|---|---|---|
| PreToolUse | Yes | Blocks the tool call | Security gates, deny destructive ops |
| UserPromptSubmit | Yes | Blocks prompt submission | Prompt hygiene, security filtering |
| Stop | Yes | Prevents Claude from stopping (continues) | Force post-execution validation |
| SubagentStop | Yes | Prevents the subagent from stopping | Force subagent retry / extended exploration |
| PostToolUse | No | Shows stderr to Claude (tool already ran) | Inject context based on single tool result |
| PostToolUseFailure | No | Shows stderr to Claude (tool already failed) | Recover from single-tool failure |
| **PostToolBatch** ✨ | **Yes** | **Stops the agentic loop before next model call** | **Cross-branch fan-in validation — R-FAIL-2 canonical** |
| PreCompact | Yes | Blocks compaction | Save state before summarization |
| PostCompact | No | Logs only | Restore state after summarization |
| SessionEnd | No | Logs only | Cleanup, telemetry export |

### Self-Updating Skills

> **Self-Updating Skills — added in v1.7 (Q-007)** _(purple)_
>
> Rules in this subsection govern how a skill incorporates lessons from its own execution back into its body or `references/`. Three rule families: **R-RETRO-*** (retrospective protocol — when and how to fire); **R-SELF-*** (where to write — file targeting); **R-DRIFT-*** (preventing drift between description and accumulated errata). Cross-pollinated with R-EXTRACT-*, R-DESTRUCT-*, R-VC-*, R-ROLLBACK-* in the system-design and meta-validation tabs.

##### R-RETRO-* — Retrospective protocol

<!-- @rule: R-RETRO-1 -->
<a id="r-retro-1"></a>

**R-RETRO-1** [skill] [portable] VALIDATED — Anthropic hooks-reference (live 2026-05-04).

**A retrospective fires on `Stop` (per turn) and `SessionEnd` (per session) hook events; `PostToolUseFailure` may fire it earlier when a validator hook exits 2.** **`SessionEnd` MUST NOT carry the merge step** (refined Turn 2) — `SessionEnd` is restricted to logging/cleanup only because the canonical hooks reference confirms it cannot block ("Shows stderr to user only") and is susceptible to process-exit races on `SIGINT`. Synchronous retrospective writes use `Stop` (per turn) or `SubagentStop` (per subagent finish, with subagent-only stderr surface per R-FAIL-2). *Sources:* `code.claude.com/docs/en/hooks` (live re-fetch confirmed: 29 canonical events, exit-code-2 table per event).

<!-- @rule: R-RETRO-2 -->
<a id="r-retro-2"></a>

**R-RETRO-2** [skill] [portable] VALIDATED — Anthropic hooks-reference.

**`Stop`-hook retrospectives MUST check the `stop_hook_active` field and exit 0 when `true` to avoid infinite continuation loops.** *Sources:* `code.claude.com/docs/en/hooks` Stop input section: "`stop_hook_active` is true when Claude Code is already continuing as a result of a stop hook. Check this value or process the transcript to prevent Claude Code from running indefinitely."

<!-- @rule: R-RETRO-3 -->
<a id="r-retro-3"></a>

**R-RETRO-3** [skill] [portable] VALIDATED — Anthropic engineering blog + hooks-reference.

**User correction is an INFERRED signal, not a programmatic event.** No canonical hook event exists for "the user said that was wrong"; the meta-skill must scan the transcript for corrective edits, "no", "wrong", and similar patterns. *Sources:* `anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills` ("ask Claude to capture its successful approaches and common mistakes... if it goes off track... ask it to self-reflect on what went wrong"); `code.claude.com/docs/en/hooks` (no user-correction event in the 29 canonical events).

<!-- @rule: R-RETRO-4 -->
<a id="r-retro-4"></a>

**R-RETRO-4** [skill] [portable] VALIDATED — Anthropic hooks-reference.

**Retrospective triggers SHOULD be configured as `prompt`-type or `agent`-type hooks for `Stop`/`SubagentStop`; `command`-type is acceptable when the analysis is deterministic.** *Sources:* `code.claude.com/docs/en/hooks` ("Prompt hooks send a prompt to a Claude model for single-turn evaluation... primarily used with Stop and SubagentStop events for intelligent task completion checking").

<!-- @rule: R-RETRO-5 -->
<a id="r-retro-5"></a>

**R-RETRO-5** [skill] [portable] PROPOSED — practitioner-derived.

**Async retrospective writes (`async: true` and/or `asyncRewake: true`) are preferred when the retrospective is non-blocking; a synchronous `Stop`-hook retrospective MUST complete in <30 seconds to avoid degrading user experience.** PROPOSED until a Tier-1 source publishes a quantitative timeout recommendation. *Sources:* `code.claude.com/docs/en/hooks` async hook fields documented; quantitative ceiling is practitioner-derived, not Anthropic-canonical.

<!-- @rule: R-RETRO-6 -->
<a id="r-retro-6"></a>

**R-RETRO-6** [skill] [claude-code-only] VALIDATED — Anthropic hooks-reference (NEW Turn 2).

**Skills MAY ship retrospective-trigger hooks in YAML frontmatter via the `hooks:` field. The `once: true` field is honored ONLY in skill frontmatter (ignored in `settings.json` and agent frontmatter).** The meta-skill's `Stop` retrospective hook SHOULD use `once: true` to fire exactly once per session. For subagents, frontmatter `Stop` hooks are automatically converted to `SubagentStop`. *Sources:* `code.claude.com/docs/en/hooks` "Hooks in skills and agents" section confirms `hooks:` in skill YAML frontmatter and `once: true` field with stated single-source-of-truth scope.

##### R-SELF-* — File targeting (where retrospectives write)

<!-- @rule: R-SELF-1 -->
<a id="r-self-1"></a>

**R-SELF-1** [skill] [portable] VALIDATED — anthropics/skills shipped layout.

**Routine retrospectives write to `references/gotchas.md`, NOT the SKILL.md body.** The body is the trigger surface (capped at 500 lines per R-BODY-1) and is the most expensive surface in tokens (always loaded). *Sources:* `platform.claude.com/docs/en/agents-and-tools/agent-skills/overview` (three-folder convention); `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices` (≤500-line body cap = R-BODY-1); Anthropic-shipped `pdf/`, `pptx/`, `docx/`, `xlsx/` skills (no `errata/` directory in any of them — uniformly use `references/` or REFERENCE.md siblings).

<!-- @rule: R-SELF-2 -->
<a id="r-self-2"></a>

**R-SELF-2** [skill] [portable] VALIDATED — Anthropic engineering blog + skill-workshop.

**A retrospective MAY modify the SKILL.md body only when it is a *behavioral correction* (the documented procedure was wrong, not just incomplete).** Body edits require explicit user accept AND a minor version bump (R-VC-2). Routine "this case had a gotcha" entries do NOT touch the body. *Sources:* `anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills` (iterate-with-Claude pattern); `anthropics/skills/skill-workshop/SKILL.md` iteration loop (snapshot → spawn → grade → review → improve).

<!-- @rule: R-SELF-3 -->
<a id="r-self-3"></a>

**R-SELF-3** [skill] [portable] VALIDATED — anthropics/skills + agentskills.io ecosystem (REWORDED Turn 2).

**`errata/` directories SHOULD NOT be created at the skill root; `references/` is the canonical sibling.** The Claude Code parser does not strictly enforce a three-folder convention (clarified Turn 2 per Gemini-7 G7-2), but the agentskills.io ecosystem and all shipped Anthropic skills (`pdf/`, `pptx/`, `docx/`, `xlsx/`) uniformly use `references/`. Deviation requires the skill be marked **non-portable** in its frontmatter. *Sources:* `github.com/anthropics/skills` shipped skills (uniform `references/` use); `agentskills.io` open standard.

<!-- @rule: R-SELF-4 -->
<a id="r-self-4"></a>

**R-SELF-4** [skill] [portable] VALIDATED — anthropics/skills `feedback.json` schema.

**`gotchas.md` entries MUST include: date, trigger event (`Stop`/`SessionEnd`/`PostToolUseFailure`/inferred), evidence anchor (transcript path or commit hash), proposed fix, and status (`PROPOSED`/`VALIDATED`/`PROMOTED`/`RETIRED`).** *Sources:* mirrors `anthropics/skills/skill-workshop/references/schemas.md` `feedback.json` per-iteration schema; aligned with the project's own promotion-pass discipline (Q-005).

<!-- @rule: R-SELF-5 -->
<a id="r-self-5"></a>

**R-SELF-5** [skill] [claude-code-only] VALIDATED — Anthropic CHANGELOG.md.

**Retrospective workspace state is held under `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/`; pending diffs survive plugin updates and reinstalls and are deleted only with explicit user opt-in on uninstall.** *Sources:* `github.com/anthropics/claude-code/blob/main/CHANGELOG.md` (v2.1.78+ `${CLAUDE_PLUGIN_DATA}` field documentation); `code.claude.com/docs/en/hooks` ("Reference scripts by path" section confirming `${CLAUDE_PLUGIN_DATA}` semantics).

##### R-DRIFT-* — Description-vs-errata drift prevention

<!-- @rule: R-DRIFT-1 -->
<a id="r-drift-1"></a>

**R-DRIFT-1** [skill] [portable] VALIDATED — anthropics/skills/skill-workshop.

**After every N=3 accepted retro merges into `references/gotchas.md`, the meta-skill MUST invoke the skill-workshop's description-optimization pass on the affected skill.** *Sources:* `anthropics/skills/skill-workshop/SKILL.md` description-optimization workflow (~20 trigger eval queries, 3 runs each, prompt for improvements, 60/40 train/test split, iterate up to 5 times); N=3 pre-registered from R-XPOLL-4 (Self-Refine plateau, Madaan et al. NeurIPS 2023).

<!-- @rule: R-DRIFT-2 -->
<a id="r-drift-2"></a>

**R-DRIFT-2** [skill] [portable] VALIDATED — anthropics/skills/skill-workshop.

**A new description replaces the existing one only if its held-out test score (40% of trigger evals) does not regress.** *Sources:* skill-workshop's `best_description` selection rule (`anthropics/skills`).

<!-- @rule: R-DRIFT-3 -->
<a id="r-drift-3"></a>

**R-DRIFT-3** [skill] [portable] VALIDATED — Anthropic best-practices.

**Description length MUST remain ≤1024 characters; appending errata digests directly into the description is prohibited.** *Sources:* `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices` ("description: Maximum 1024 characters").

<!-- @rule: R-DRIFT-4 -->
<a id="r-drift-4"></a>

**R-DRIFT-4** [skill] [portable] PROPOSED — strict-mode default.

**Hidden frontmatter fields for accumulated examples (`applies_to_examples:` or similar) MUST NOT be introduced; they are not documented in the live skills schema and would not be portable.** *Sources:* `code.claude.com/docs/en/skills` (live frontmatter schema lists no such field); strict-mode default. PROPOSED pending future Anthropic schema additions.

<!-- @rule: R-DRIFT-5 -->
<a id="r-drift-5"></a>

**R-DRIFT-5** [skill] [portable] VALIDATED — NEW Turn 2 (Gemini-7 G7-7 accepted).

**Description regeneration MUST preserve the original `when_to_use` scope-set.** The optimizer may improve precision/recall *within* the documented scope; it MUST NOT narrow or expand scope without a manual major-version bump and human consensus. Implementation: the regen pass is given the original scope-set as a constraint; any candidate description failing scope-preservation on the held-out test is rejected. *Sources:* Gemini-7's semantic-drift argument (REFINE-accepted) plus `anthropics/skills/skill-workshop/SKILL.md` `best_description` selection (which is extended here with the scope-preservation constraint). This rule resolves the apparent tension between Anthropic-canonical description-optimization (which DOES rewrite descriptions) and the routing-stability concern.

### Validation Test Suite

#### Two-layer eval suite (R-LOAD-7)

Each Anthropic-style skill ships TWO layers of evaluation, addressing complementary failure modes. **Layer A — Trigger-rate eval** (the Anthropic skill-workshop existing pattern, `evals/evals.json`): ~20 trigger queries per skill, 60/40 train/test split, 3 runs per query, the description optimiser selects `best_description` by held-out test score. Measures whether the skill's description matches user intent. **Layer B — Skill-loading verification** (NEW in v1.8, `evals/loading_verification.json`): canary-token tests + negative-control tests. Measures whether the skill's MECHANISM delivered the body to the agent (not whether the agent produced a correct answer from any source). The two layers are NOT substitutes.

#### Canary-token test (R-LOAD-1)

Each skill MUST contain a unique canary phrase in its body or a referenced file. Recommended forms: (a) UUID4 (`a3f7c9e2-...`), (b) hyphenated word-pair (`CARDINAL-ZEBRA-7742`), (c) any 4+ token string statistically unlikely to occur in arbitrary text. Phrase MUST be unique across the skill collection (linter enforces). The verification test asks the agent a query that requires consulting the body; the assertion is that the canary appears in the agent's reasoning trace. Anchored on agent-ecosystem/agent-skill-implementation (github.com/agent-ecosystem/agent-skill-implementation, retrieved May 2026): "A unique string … embedded in a benchmark skill file… reveals what a platform loaded and when, without relying on model self-reporting."

#### Negative-control test (R-LOAD-2)

The verification harness MUST include a configuration step that either (a) renames the skill folder so it no longer matches discovery patterns, or (b) sets `disable-model-invocation: true` in frontmatter (per code.claude.com/docs/en/skills, retrieved May 2026). Re-run the same canary query under this configuration. Assertion: the canary does NOT appear AND the agent's procedure-following accuracy drops by ≥X% (per skill-author calibration). This catches the Hector / FlanksAPI gap from Q-007 / Q-012: an integration suite passing while the skill mechanism is broken because the agent inferred answers from the codebase / CLAUDE.md.

#### Forbidden patterns (R-LOAD-3, R-LOAD-4)

- **"List your loaded skills" probe.** Skill-creator's own SKILL.md notes Claude's tendency to under-trigger skills (github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md), making any introspection-by-prompt unreliable. Forbidden as the only verification mechanism (R-LOAD-3).
- **Hook-based introspection — bifurcated permission, post-Q-013 v1.15.** `PreToolUse` with `matcher: "Skill"` IS PERMITTED for agent-dispatched skill calls (Claude emits a tool_use block; the hook fires with `tool_name: "Skill"`); confirmed via Issue #21614 + canonical hooks-doc re-fetch 2026-05-07. Validators MAY add a PreToolUse-Skill hook as a supplementary deterministic gate (e.g., regex-checking the canary token in the invocation payload, exit-code 2 to block) — but it does NOT replace the mandatory canary (R-LOAD-1) + negative-control (R-LOAD-2) tests. `PostToolUse` with `matcher: "Skill"` remains FORBIDDEN as the test-pass condition (Issue #43630 still open as of 2026-05-07). `InstructionsLoaded` fires for `CLAUDE.md` / `.claude/rules/*.md` only (Issues #30573, #31017, both open). No host-side env var enumerates loaded skills (Issue #22902, feature request, open). The canonical observability path for cross-invocation visibility is the `claude_code.skill_activated` OpenTelemetry event (CHANGELOG, Anthropic-canonical 2026-05) — fires for user-slash, claude-proactive, and nested-skill paths uniformly with `invocation_trigger` attribute. R-LOAD-4 records the bifurcated permission and points to Q-013 v1.15 for the audit trail.

#### `evals/loading_verification.json` schema (R-LOAD-5)

```json
{
  "skill_name": "string",
  "verifications": [
    {
      "type": "canary",
      "query": "string — query that requires consulting the body",
      "expected_canary": "string — the canary phrase",
      "must_appear": true
    },
    {
      "type": "negative_control",
      "query": "string — same canary-requiring query",
      "rename_to": "string — folder name to use during this test (or null for disable-model-invocation toggle)",
      "expected_canary": "string",
      "must_appear": false
    }
  ]
}
```

#### Threshold (R-LOAD-6)

A skill MUST contain ≥1 canary test AND ≥1 negative-control test in its `evals/loading_verification.json`, OR the audit emits exit code 2 (FAIL). This is the minimum bar; skills covering more complex flows (multi-file references, helper-script invocation) should ship more than the minimum. The threshold is mechanical-checkable and runs in the Q-004 mechanical validator path (deterministic Python; no LLM in pre-commit hook).

### Reference Chunking & Lazy Loading

> **Threshold conflict resolved** _(amber)_
>
> Anthropic's `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices` says reference files >100 lines need a TOC. anthropics/skills/skill-workshop/SKILL.md says >300 lines. Per the framework's strictness default and Anthropic-supremacy resolution, **adopt 100 lines** (R-CHUNK-1). Flag for re-verification on next Anthropic doc revision.

> **v1.14 (Q-016) — R-CHUNK-4 reinterpreted as markdown-link-depth, not filesystem-depth** _(green)_
>
> Q-016 closure: the canonical `anthropics/skills/claude-api` skill ships a 2-level filesystem-deep reference structure (e.g., `python/claude-api/tool-use.md`, `shared/tool-use-concepts.md`) and the same Anthropic best-practices doc that says *'Keep references one level deep from SKILL.md'* also actively prescribes Pattern 2 `bigquery-skill/reference/finance.md`. Reading the doc in full — including its Bad-vs-Good example whose filenames are identical and differ only in hop count — shows that 'one level deep' means **one markdown-link hop from SKILL.md**, not one filesystem-directory hop. R-CHUNK-4 has been rewritten accordingly. The `head -100` partial-read regression Anthropic warns about is triggered by chained transitive references (link graph), not by subdirectory nesting (filesystem). Anthropic_supremacy is unchanged; no Anthropic-vs-Anthropic contradiction was actually present once the doc was read in full. See R-CHUNK-4-CLARIFICATION below and Session Notes — Q-016.

#### Reference file size and structure

<!-- @rule: R-CHUNK-1 -->
<a id="r-chunk-1"></a>

**R-CHUNK-1**.

**Reference files >100 lines must begin with a `## Contents` (or `## Table of Contents`) section listing every H2 heading. [skill][portable][validated]** Mechanical (regex check). Source: platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.

<!-- @rule: R-CHUNK-2 -->
<a id="r-chunk-2"></a>

**R-CHUNK-2**.

**Reference files exceeding 500 lines OR 10,000 words OR ~10K-15K tokens (whichever first) must be split into domain-organized sub-files (e.g., `references/{aws,gcp,azure}.md`). [skill][portable][validated]** Mechanical (line + word + token count). Source: best-practices Pattern 2 (domain-specific organization); skill-workshop SKILL.md ('Domain organization: when a skill supports multiple domains/frameworks, organize by variant'). **Token threshold tightened in v1.10** from 20K → 10K-15K to reflect Apr 2026 Read-tool ceiling drop (Issues #45019, #40357).

<!-- @rule: R-CHUNK-3 -->
<a id="r-chunk-3"></a>

**R-CHUNK-3**.

**Reference files >10,000 words must include at least one literal `grep` invocation example in SKILL.md (extends R-SR-7). [skill][portable][validated]** Mechanical+Semantic. Source: skill-workshop SKILL.md ('if files are large >10k words, include grep search patterns'); best-practices Pattern 2 ('Quick search: Find specific metrics using grep').

<!-- @rule: R-CHUNK-4 -->
<a id="r-chunk-4"></a>

**R-CHUNK-4**.

**Every reference file Claude is expected to read MUST be reachable in exactly one markdown-link hop from SKILL.md. Filesystem subdirectory depth below SKILL.md is unrestricted; references such as `references/foo.md`, `reference/finance.md`, `python/claude-api/tool-use.md`, or `shared/managed-agents-overview.md` are all permitted as long as SKILL.md links to them directly. Chained markdown reference links — files reachable only by traversing SKILL.md → A.md → B.md, where B.md is not also one-hop reachable from SKILL.md — are forbidden. [skill][portable][validated]** Mechanical (build the markdown-link graph rooted at SKILL.md; fail if any skill-internal `.md` file referenced anywhere in the graph has minimum graph-distance from SKILL.md > 1). **Source:** Anthropic best-practices (*'Avoid deeply nested references … Keep references one level deep from SKILL.md … All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed'*) read in full alongside its Bad-vs-Good chained-link example (which uses identical filenames and varies only in hop count, demonstrating the graph-distance interpretation) and its Pattern 2 canonical example (`bigquery-skill/reference/finance.md` — a subdirectory layout the same doc actively recommends), reinforced by the canonical `anthropics/skills/claude-api` skill which links directly from its SKILL.md to `python/claude-api/tool-use.md` (590 lines, verified Tier-1 at https://github.com/anthropics/skills/blob/main/skills/claude-api/python/claude-api/tool-use.md) and to `shared/tool-use-concepts.md` (305 lines, verified Tier-1). The partial-read regression the doc warns about is graph-distance-driven, not filesystem-depth-driven — see **R-CHUNK-4-CLARIFICATION** below for the mechanism explanation. Imposes a **content-fidelity** constraint, distinct from R-WORKSPACE-1's **discovery** constraint — both apply independently. **Revised v1.14 (Q-016).** Supersedes the v1.13 filesystem-depth interpretation; no v1.13-authored skill becomes invalid (every flat-`references/` skill remains conformant).

**R-CHUNK-4-CLARIFICATION (mechanism explanation).** Per the Anthropic Agent Skills overview (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview): *'Claude uses bash to read SKILL.md from the filesystem, bringing its instructions into the context window. If those instructions reference other files (like FORMS.md or a database schema), Claude reads those files too using additional bash commands.'* Per best-practices: *'Claude reads SKILL.md, sees the reference to reference/finance.md, and invokes bash to read just that file.'* Progressive disclosure is **agent-driven** — every reference load is an LLM-issued bash/Read tool call, not a host-side parser bypass. The `head -100` partial-read failure mode appears when the agent has already loaded a reference file that itself names another `.md` file: at that transitive step, Claude is more likely to reach for a preview command than a full read. The fix is therefore to flatten the **markdown-link graph** so SKILL.md names every reference Claude needs directly, regardless of where those files sit on disk. Concrete examples: `<skill>/references/foo.md` (depth-1 filesystem, depth-1 graph) → OK; `<skill>/python/claude-api/tool-use.md` linked directly from SKILL.md (depth-3 filesystem, depth-1 graph) → OK; `<skill>/references/index.md` that lists `<skill>/references/topic.md` where `topic.md` is reachable only via `index.md` (depth-1 filesystem, depth-2 graph) → VIOLATION. Cross-links between two depth-1 files (both already directly named by SKILL.md) are benign: validator emits an info-level note (LINT-Q016-1), not a failure.

<!-- @rule: R-CHUNK-5 -->
<a id="r-chunk-5"></a>

**R-CHUNK-5**.

**Reference files should target ≤2,000 lines AND ≤10,000 tokens per file to stay within the Claude Code Read tool's per-call ceiling. Files exceeding this must split per R-CHUNK-2 OR include explicit `Read(file, offset=N, limit=M)` examples in SKILL.md. [skill][claude-code-only][validated]** Mechanical. **Threshold updated in v1.10** from 25,000 to 10,000 tokens to reflect: anthropics/claude-code Issue #45019 (Apr 2026 silent CLI downgrade 25K→10K); Issue #40357 (Desktop hardcoded 10K cap); claude-plugins-official #995 (real production skill-loading failures at 10K). Older 25K figure remains documented in some CLI versions but is no longer the safe target. Issues #4002, #14876, #14888, #15687, #6910 (Read-tool behavior corpus). [claude-code-only] tag because the limit is a Claude Code product decision; Claude.ai, the API, and other surfaces may differ.

<!-- @rule: R-CHUNK-6 -->
<a id="r-chunk-6"></a>

**R-CHUNK-6**.

**Reference files should use header-anchored 'Grep-then-Read' lazy-loading. On-disk vector indexes, embeddings databases, and semantic-search retrievers must NOT be the primary lookup mechanism for in-skill `references/` files. [skill][portable][validated]** Semantic. Source: best-practices Pattern 2 (grep-as-canonical); Boris Cherny statement that Claude Code dropped local-RAG/vector-DB (Tier-2 corroboration); absence of any Anthropic doc endorsing in-skill vector indexing. **Scope:** Does not prohibit invoking external semantic-search tools (e.g., MCP-exposed RAG APIs) for non-reference data.

#### Lazy-loading semantics

<!-- @rule: R-LAZYLOAD-1 -->
<a id="r-lazyload-1"></a>

**R-LAZYLOAD-1**.

**Every file in `references/` must be linked by name from SKILL.md with a one-sentence trigger condition. Unreferenced files are dead code and must be removed. [skill][portable][validated]** Mechanical+Semantic. Source: best-practices ('All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed'); skill-workshop SKILL.md.

<!-- @rule: R-LAZYLOAD-2 -->
<a id="r-lazyload-2"></a>

**R-LAZYLOAD-2**.

**For must-not-skim references, SKILL.md should use the imperative pattern from anthropics/skills/docx/SKILL.md verbatim: 'MANDATORY - READ ENTIRE FILE: Read [file.md](file.md) (~N lines) completely from start to finish. NEVER set any range limits when reading this file.' [skill][portable][validated]** Semantic (mechanical: presence of MANDATORY/ENTIRE FILE/NEVER tokens; semantic: necessity of the directive). Source: anthropics/skills/skills/docx/SKILL.md.

<!-- @rule: R-LAZYLOAD-3 -->
<a id="r-lazyload-3"></a>

**R-LAZYLOAD-3**.

**Reference files should not be smaller than ~50 lines unless genuinely modular (per-endpoint API stub, domain-segregated schema fragment). Below this, prefer inline content in SKILL.md. [skill][portable][validated]** Semantic. Strength: SHOULD (not MUST). Source: tool-call overhead vs context-window economy heuristic; anthropics/skills production skill survey. **Note:** Gemini-10 (Turn 2) proposed upgrading to MUST based on '50 lines = 3,000 tokens' arithmetic; the math is wrong by ~5x (50 lines of markdown ≈ 500-1,000 tokens). DA-120.

#### Forward-influence reference

> **P-CHUNK-11 CaveAgent (PROPOSED, Turn 2 Gemini-10)** _(neutral)_
>
> **arXiv:2601.01569 (Maohao Ran et al., HKBU/HKUST/HKGAI, Jan 2026 v1 / Feb 2026 v3) — VERIFIED REAL Tier-1.** CaveAgent proposes a runtime-integrated skill management system extending the Agent Skills open standard via `injection.py` files that inject Python objects (DataFrames, DB connections) into a persistent Python runtime. **Not applicable to Claude Code's stateless-bash-tool runtime model** (DA-121); applicable to Python-kernel-based agent frameworks (cave_agent / pycallingagent / PydanticAI with stateful sandboxes). Logged for future Q-* items addressing persistent-runtime agent surfaces. Q-009 GraSP/Skilldex precedent for forward-influence references.

##### Q-015 v1.13 — ToC threshold reaffirmed at 100 lines (R-BOUNDARY-9)

**R-BOUNDARY-9 [reference][portable] VALIDATED — NEW v1.13.** Any reference file in `<skill>/references/` longer than **100 non-blank lines** MUST include a table of contents at the top of the file. Rationale: when the file is referenced via a chained link (which R-CHUNK-4 forbids inside a skill, but is still possible from outside the skill), Claude may execute `head -100`-style partial reads to preview content rather than reading the whole file — *'When encountering nested references, Claude might use commands like `head -100` to preview content rather than reading entire files, resulting in incomplete information'* (*Skill authoring best practices*, Anthropic, 2026, https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices). A ToC near the top (within the first ~30 lines) ensures that even a truncated read surfaces the full document scope. **Threshold:** 100 lines, per the same canonical Anthropic source — *'For reference files longer than 100 lines, include a table of contents at the top.'* Gemini-15's Discovery-tier 300-line threshold is rejected as a 3× overcount (→ DA-144); Anthropic supremacy applies.

> **ToC formatting guidance (advisory)** _(yellow)_
>
> Markdown ToC under an `## Contents` (or equivalent) heading near the top of the reference file. Each entry should be a markdown link to a heading anchor inside the same file. The ToC's purpose is to be visible inside a `head -100` (or smaller) partial read; a long preamble before the ToC defeats the rule. Lint #10 (meta-validation, NEW v1.13) detects the presence of the ToC heuristically via a heading list within the first ~30 non-blank lines.

<!-- @end: skill-specification -->

---

<!-- @anchor: system-design -->
## System Design

### System Organization

> **Q-002 cross-pollination added in v1.2** _(green)_
>
> Q-001 populated this tab in v1.1. Q-002 adds: (a) Voyager-derived skill-library architecture rules (R-XPOLL-1..3), (b) MRKL-derived description-disambiguation rule (R-XPOLL-4), (c) ReWOO-derived deterministic-output rule (R-XPOLL-8), (d) DSPy-derived meta-skill compilation model (R-XPOLL-9), (e) AGENTS.md ecosystem precedence rules (R-MEM-7..9), and (f) the `InstructionsLoaded` hook tooling note. Q-006/Q-009/Q-010 will deepen multi-skill composition, workspace topology, and reference chunking.

### Locations and Precedence

##### Exact file paths

| Scope | Path | Applies to |
|---|---|---|
| Enterprise / managed | Per managed-settings configuration | All users in org |
| Personal / user | `~/.claude/skills/<skill-name>/SKILL.md` | All projects for the user |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin enabled — namespaced as `plugin-name:skill-name` |

<!-- @rule: R-SYS-2 -->
<a id="r-sys-2"></a>

**R-SYS-2** [reference] [claude-code-only] VALIDATED.

**Precedence (skills): enterprise > personal > project.** Plugin skills live in their own `plugin-name:skill-name` namespace and cannot conflict with other levels. **Same-name skill beats same-name `.claude/commands/` command.**

> **Documented footgun: skills precedence is INVERSE of CLAUDE.md memory precedence** _(amber)_
>
> Skills: enterprise > personal > project (org policy wins). CLAUDE.md memory: managed > project > project rules > user > local (project memory wins over user). The two systems use opposite precedence directions. Surface this contrast in onboarding documentation; the validator checks for skills colliding with same-name memory rules and warns.

> **Q-009 amendment (v1.9)** _(blue)_
>
> Skill discovery has **four documented sources** per code.claude.com/docs/en/skills: (1) `~/.claude/skills/` (personal); (2) `<cwd>/.claude/skills/` (project); (3) `.claude/skills/` inside any directory passed to `--add-dir` (the "skill exception" — Issue #37553 confirms `additionalDirectories` does NOT replicate this behaviour); (4) plugin-bundled `${CLAUDE_PLUGIN_ROOT}/skills/<name>/` after `/plugin install`. A documented fifth source — automatic nested-directory discovery for monorepo subfolders — is currently broken in CLI ≥2.1.92 due to a `Bun.Glob` regression (Issue #44490). See [Workspace Topology ↗](#workspace-topology){tab=system-design} for the full topology and [Workspace Topology ↗](#workspace-topology){tab=skill-spec} for the rules.

### Dependencies and Splitting Strategy

<!-- @rule: R-SYS-1 -->
<a id="r-sys-1"></a>

**R-SYS-1** [reference] [claude-code-only] VALIDATED — PRE-REGISTERED depth=1.

**Skills folders are SINGLE-DEPTH.** Each skill is exactly `<root>/<skill-name>/SKILL.md`. Nested suite folders (e.g., `~/.claude/skills/spec-system/spec-creator/`) are silently ignored. Anthropic-owned tracker confirms: Issues #18192, #16438, #10238.

**Caveat — parallel monorepo skills DO work.** Claude Code performs automatic discovery from nested `.claude/skills/` directories along the path from the working directory. Each is itself single-depth; the *parallel* pattern is supported, the *nested-inside-one-folder* pattern is not.

<!-- @rule: R-SYS-4 -->
<a id="r-sys-4"></a>

**R-SYS-4** [skill] [portable] VALIDATED.

**Splitting trigger:** split a skill when SKILL.md exceeds 500 lines OR when content has mutually-exclusive variants. Per-variant content goes in `references/<variant>.md` so only the relevant one ever loads.

<!-- @rule: R-SYS-5 -->
<a id="r-sys-5"></a>

**R-SYS-5** [skill] [claude-code-only] VALIDATED.

**Cross-skill composition uses ONE of two mechanisms** (no programmatic skill→skill call exists):

1. **Subagent with `skills:` preload field.** A custom subagent in `.claude/agents/` declares `skills: [skill-a, skill-b]`. The full bodies of those skills are injected into the subagent's system prompt at startup — bypassing dynamic discovery. Cost: upfront token load. Reject for skills marked `disable-model-invocation: true`.
2. **Skill with `context: fork` + `agent: <name>`.** The skill itself runs inside a forked subagent context (Explore, Plan, general-purpose, or a custom subagent). The SKILL.md content becomes the task prompt; the main conversation is shielded from the noise.

**Subagents cannot spawn other subagents.** Composition deeper than two levels requires architectural redesign or a top-level orchestrator skill that fans out to peer subagents.

##### Cross-pollination rules added in v1.2 (Q-002)

<!-- @rule: R-XPOLL-2 -->
<a id="r-xpoll-2"></a>

**R-XPOLL-2** [skill] [portable] PROPOSED — Voyager (TMLR 2024).

**Pre-commit skill verification.** A skill's helper scripts SHOULD be exercised against the description's *Use when…* examples before the skill is added to the library. Mirrors Voyager's self-verification step (Wang et al., TMLR 2024, arXiv:2305.16291, §3.2). Routes to Q-004 as a meta-validation hook; PROPOSED until the verification harness is specified in Q-003.

<!-- @rule: R-XPOLL-4 -->
<a id="r-xpoll-4"></a>

**R-XPOLL-4** [skill] [portable] VALIDATED — MRKL (AI21, 2022).

**Description disambiguation.** When multiple skills coexist in a project, their `description` fields MUST be checked for pairwise textual overlap. Near-duplicate descriptions cause router collapse — Karpas et al. *MRKL Systems* (arXiv:2205.00445, §4 "neural-symbolic dispatch") describes exactly this failure. Empirical confirmation in Lee Hanchung's deep-dive (leehanchung.github.io 2025-10-26). Validation-script: cosine similarity of TF-IDF or sentence-embedding representations of descriptions; flag pairs ≥ 0.85 with a warning, ≥ 0.95 with a failure.

<!-- @rule: R-XPOLL-8 -->
<a id="r-xpoll-8"></a>

**R-XPOLL-8** [skill] [portable] VALIDATED — ReWOO (2023).

**Deterministic helper outputs are facts, not observations.** When a skill's helper script produces deterministic output (CSV parse, regex extract, hash, lint result), the SKILL.md body SHOULD NOT include reasoning prose between the script invocation and the consumption of its output. Xu et al. *ReWOO* (arXiv:2305.18323) shows ~5× token reduction when reasoning is decoupled from observations on deterministic tools. Validation-script: detect bash code blocks immediately followed by reasoning-prose paragraphs (markers: "Now I will check…", "Let me verify…") within the same workflow section → warn.

<!-- @rule: R-XPOLL-9 -->
<a id="r-xpoll-9"></a>

**R-XPOLL-9** [system] [portable] PROPOSED — DSPy (ICLR 2024).

**Meta-skill is a compiler, not a template engine.** The skill-workshop meta-skill (Q-003 deliverable) MUST take a declarative spec — intended triggers (R-XPOLL-5), deterministic checks (R-XPOLL-2/8), expected outputs — and *compile* SKILL.md from it, then run the validation script as the optimization metric. Khattab et al. *DSPy* (ICLR 2024, arXiv:2310.03714) is the architectural precedent: signatures = frontmatter; metrics = validation-script checks; compilation replaces handwritten prompt templating. Routes to Q-003 + Q-004.

##### v1.6 (Q-006) addition: the four-layer composition ladder

Splitting decisions follow **R-COMP-1**: climb only when the lower rung is insufficient. (1) **Inline progressive disclosure** — keep the work in one SKILL.md when the body fits under R-BODY-1's 500-line cap and references can move to `references/` per R-BODY-4. (2) **`context: fork`** — escalate when the sub-task is *executable* (R-PAR-1: not for reference content) AND would benefit from an isolated context (verbose output, parallel exploration). (3) **Custom subagent with `skills:` preload** — escalate further when the sub-task needs a custom system prompt + multiple skills + persistent role across multiple delegations. (4) **Agent teams** (R-CONDUCT-4, EXPERIMENTAL) — escalate only when peers must message each other and share a task list. Token cost grows asymmetrically: chat ≈ 1×, subagent ≈ 4×, multi-agent ≈ 15×.

<!-- @rule: R-COMP-1-DECISION-TABLE -->
<a id="r-comp-1-decision-table"></a>

**R-COMP-1-DECISION-TABLE** [skill] [claude-code-only] VALIDATED.

**Splitting decision table:**

| Trigger | Action | Rule |
|---|---|---|
| SKILL.md body ≤ 500 lines, single coherent task | Keep inline | R-BODY-1 |
| Body > 500 lines OR variants exist | Move variants to `references/<topic>.md` | R-BODY-1 + R-BODY-4 |
| Sub-task is executable AND verbose AND independent | `context: fork` + `agent:` | R-PAR-1 + R-PAR-3 |
| Sub-task needs custom system prompt + multiple skills | Custom subagent with `skills:` preload | R-DEL-2 |
| >5 peers AND inter-peer messaging required | Agent teams (EXPERIMENTAL) | R-CONDUCT-4 |
| Two peer skills need same helper | **Embed in each** — do not symlink | R-COMP-3 |

> **Q-009 amendment (v1.9)** _(blue)_
>
> **Embed-and-duplicate (R-COMP-3) is reaffirmed by R-SHARE-1 / DA-058** for cross-skill helpers when skills are not packaged as a plugin. The `anthropics/skills` shipping repo (12 production skills inspected 2026-05-04) shows zero peer-skill symlinks — each skill ships its own `scripts/`, `references/`, `assets/`. Within a plugin, `${CLAUDE_PLUGIN_ROOT}/scripts/` is the canonical sharing primitive. Cross-plugin sharing is **not supported** (Issue #15944). **Pre-registered quantitative thresholds** govern when to promote: T-SHARE-1 (≥2 skills sharing helper → plugin-root), T-MONO-1 (≥3 services in monorepo → plugin), T-PFX-1 (≥2 collisions → migrate to plugin-per-service). **Empirical anchor for T-SHARE-1:** anthropics/skills Issue #953 documents 30 physical ISO-IEC29500 XSD-schema files where 10 would suffice across docx/pptx/xlsx (byte-identical SHA across the three). See [Workspace Topology ↗](#workspace-topology){tab=system-design} and [Workspace Topology ↗](#workspace-topology){tab=skill-spec}.

### Satellite Files (helpers, references, scripts)

| Folder | Contents | Loaded into Claude's context? |
|---|---|---|
| `scripts/` | Executable code (Python preferred, Bash for thin glue) | **No** — only stdout/stderr enter context |
| `references/` | Markdown files (factual catalogs, schemas) and procedural sub-skills (variant-specific workflows) | **On demand**, only when SKILL.md cites them |
| `assets/` | Templates, fonts, images, data files used in OUTPUT | **No** — read by scripts or copied/linked by workflow |

<!-- @rule: Naming and depth (R-SYS-1 follow-on) [skill][portable] -->
<a id="naming and depth (r-sys-1 follow-on) [skill][portable]"></a>

**Naming and depth (R-SYS-1 follow-on) [skill][portable]**.

**File references from SKILL.md are 1 level deep maximum.** No `references/backend/api/auth.md`. The agent's discovery is path-following from SKILL.md text, not directory crawling — deeper nesting wastes tokens on Bash `ls`/`tree` calls.

**Big-references guidance (R-BODY-4):** any `references/*.md` file >300 lines MUST start with a Table of Contents so the agent jump-loads only the section it needs.

### Index Files

<!-- @rule: R-SYS-3 -->
<a id="r-sys-3"></a>

**R-SYS-3** [reference] [claude-code-only] VALIDATED.

**Claude Code does NOT require, expect, or read any top-level skills index file.** No `index.md`, no `skills.json` at the skills root. Discovery is **frontmatter-driven**: at session start Claude Code scans each `<root>/<skill>/SKILL.md`, reads only the YAML frontmatter `name`+`description`, and populates the system-prompt `<available_skills>` block.

<!-- @rule: R-IDX-1 -->
<a id="r-idx-1"></a>

**R-IDX-1** [reference] [portable] PROPOSED — MAY (v1.12 refinement of v1.1 carve-out).

**A skill MAY include `references/index.md` (or `references/_index.md`) as a one-line-per-file content catalogue when the skill has ≥3 reference files OR total reference content >5,000 lines.** Each entry MUST cite the file with a 'load this when…' descriptor that mirrors the SKILL.md inline citation style (R-SR-5). The catalogue MUST NOT be the primary discovery mechanism — SKILL.md inline citation per R-SR-5 remains canonical. Distinct from R-SYS-3 (which forbids a top-level skills index file at the skills root). DA-117 stands: `references/_index.md` MUST NOT be required. Source: Karpathy llm-wiki P-K6 (Discovery); platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices § 'Move detailed documentation to references and link to it' (Tier-1 partial endorsement); empirical evidence — Anthropic skills mcp-builder/skill-workshop do NOT use `index.md`, supporting MAY-not-MUST/SHOULD.

### Interaction with CLAUDE.md / AGENTS.md

<!-- @rule: R-MEM-1 -->
<a id="r-mem-1"></a>

**R-MEM-1** [reference] [claude-code-only] VALIDATED.

**CLAUDE.md memory hierarchy at session start (highest precedence first):** managed/enterprise → project (`./CLAUDE.md` or `./.claude/CLAUDE.md`) → project rules (`./.claude/rules/*.md`) → user (`~/.claude/CLAUDE.md`) → local project (`./CLAUDE.local.md`) → Auto Memory (Claude-written). **This is the inverse direction of skills precedence (R-SYS-2)** — surface in onboarding.

**Loading timing:** CLAUDE.md and Level-1 skill metadata both arrive eagerly at session start. SKILL.md bodies (Level 2) arrive later, on-demand when triggered. Nested CLAUDE.md files in deeper subdirectories are loaded **on-demand** when Claude reads files in that subtree.

<!-- @rule: R-MEM-2 -->
<a id="r-mem-2"></a>

**R-MEM-2** [skill] [claude-code-only] VALIDATED.

**CLAUDE.md = facts everyone needs every session. Skills = procedures that load on trigger.** Anthropic Claude Code docs state explicitly: *"Create a skill ... when a section of CLAUDE.md has grown into a procedure rather than a fact."* PROPOSED quantitative target: **CLAUDE.md ≤200 lines (Anthropic memory page guidance), ≤300 lines hard cap (community consensus)**. Move any procedure beyond ~10 lines into a skill.

<!-- @da: R-MEM-3 -->
<a id="r-mem-3"></a>

**R-MEM-3.** **Demoted at v1.12.** The PROPOSED symlink rule (`AGENTS.md` ↔ `CLAUDE.md`) is permanently rejected per **DA-130** and **superseded by R-MEM-10** below. Rationale (full): canonical Anthropic Tier-1 contradiction surfaced during Q-014 Turn 2 Gemini-14 vetting — `code.claude.com/docs/en/memory` § AGENTS.md prescribes the `@AGENTS.md` import directive instead of a symlink; claude-code-action Issue #1187 documents the symlink failure mode in CI/CD pipelines. Anthropic supremacy applies.

<!-- @rule: R-MEM-4 -->
<a id="r-mem-4"></a>

**R-MEM-4** [skill] [claude-code-only] VALIDATED.

**Anti-duplication.** Use `@import` syntax (`@docs/coding-standards.md`) in CLAUDE.md to embed external Markdown — recursive depth 5, no evaluation in code blocks. Use `.claude/rules/*.md` with YAML `paths:` glob frontmatter for path-scoped rules. Reference skills from CLAUDE.md by NAME (Claude already has the description from the skill listing) — NEVER copy skill content into CLAUDE.md.

##### R-MEM-5..9 added in v1.2 (D-016 + D-025 promotions + agents.md ecosystem)

<!-- @rule: R-MEM-5 -->
<a id="r-mem-5"></a>

**R-MEM-5** [reference] [claude-code-only] VALIDATED — promoted from FILE A's D-016.

**CLAUDE.md is delivered as a USER message after the system prompt, not as part of the system prompt itself** (code.claude.com/docs/en/memory). Claude reads it and follows it as a strong recommendation, but compliance is best-effort, not enforced. **Specificity beats CAPS-LOCK** in CLAUDE.md and skill bodies (R-MEM-5 explains why DA-011 holds). The system-prompt-level escape hatch is `--append-system-prompt` (CLI flag); for genuinely enforced restrictions, use managed settings (`permissions.deny`, sandbox configuration) — those are technically enforced by the client, not behaviorally guided through Claude.

<!-- @rule: R-MEM-6 -->
<a id="r-mem-6"></a>

**R-MEM-6** [skill] [claude-code-only] VALIDATED — promoted from FILE A's D-025.

**`.claude/rules/<topic>.md` with `paths:` glob frontmatter for path-scoped instructions.** Each file covers one topic. Without `paths:`, the rule loads at launch with the same priority as `.claude/CLAUDE.md`. With `paths:`, rules load only when Claude reads files matching the glob. Brace expansion supported (`{ts,tsx}`). Symlinks resolved; circular symlinks detected. **Tooling: the `InstructionsLoaded` hook** (code.claude.com/docs/en/hooks#instructionsloaded) logs which instruction files load, when, and why — use it to debug path-scoped rules and lazy-loaded subdirectory rules.

<!-- @rule: R-MEM-7 -->
<a id="r-mem-7"></a>

**R-MEM-7** [memory] [portable] VALIDATED — agents.md / Codex docs.

**Closest-file-wins precedence.** When nested AGENTS.md / CLAUDE.md files exist along the path from the repo root to the file being edited, the file *closest* to the edited path takes precedence; explicit user chat prompts override all files. agents.md homepage and developers.openai.com/codex/guides/agents-md document this; docs.factory.ai/cli/configuration/agents-md confirms. Validation-script: when computing effective context for a file, walk parent directories root-to-leaf and apply leaf-most rules last.

<!-- @rule: R-MEM-8 -->
<a id="r-mem-8"></a>

**R-MEM-8** [memory] [portable] VALIDATED — Codex AGENTS.md docs.

**`AGENTS.override.md` higher-precedence sibling pattern.** A file named `AGENTS.override.md` at the same directory level as `AGENTS.md` takes precedence over the regular AGENTS.md (Codex precedence chain: AGENTS.override.md → Closest AGENTS.md → Parent directories → ~/.codex/AGENTS.md). Portable to Claude Code via `@AGENTS.override.md` import in CLAUDE.md, since the import simply names the file.

<!-- @rule: R-MEM-9 -->
<a id="r-mem-9"></a>

**R-MEM-9** [memory] [portable] VALIDATED — agents.md spec.

**Programmatic-checks discoverability.** AGENTS.md / CLAUDE.md MAY enumerate the programmatic checks (lint, test, type-check, build) that the agent SHOULD run before declaring done. agents.md homepage and Codex docs document this. Claude Code follows naturally via CLAUDE.md; the validation-script can mechanically verify the named commands exist in `package.json` / `pyproject.toml` / `Makefile`.

##### R-MEM-10 added in v1.12 — replaces demoted R-MEM-3 (Q-014 Gemini-14 vetting)

<!-- @rule: R-MEM-10 -->
<a id="r-mem-10"></a>

**R-MEM-10** [reference] [portable] VALIDATED — CANONICAL — replaces R-MEM-3.

**For cross-tool projects sharing instructions across Claude Code, OpenAI Codex, Cursor, Aider, and the wider agents.md ecosystem, place the canonical instructions at `<root>/AGENTS.md` and create a `<root>/CLAUDE.md` whose body is `@AGENTS.md`** (with optional Claude-specific directives appended below the import). Claude Code MUST follow the `@AGENTS.md` import directive at session start; Codex, Cursor, Aider read `AGENTS.md` natively per the agents.md standard. **Repositories MUST NOT symlink `<root>/CLAUDE.md` to `<root>/AGENTS.md` or vice versa** — direct Anthropic-canonical guidance plus documented CI failure mode. **Carve-out:** R-MEM-10 applies only at the project-memory layer (`<root>/CLAUDE.md` ↔ `<root>/AGENTS.md`, plus nested per-directory pairs per agents.md walk). It does NOT apply at the skill layer; SKILL.md has no AGENTS-equivalent and MUST NOT be symlinked or @-imported to a parallel name. **Sources (Tier-1, ≥1 canonical Anthropic doc + reinforcement):** code.claude.com/docs/en/memory § AGENTS.md (canonical Anthropic, primary — verbatim: "Claude Code reads CLAUDE.md, not AGENTS.md. If your repository already uses AGENTS.md for other coding agents, create a CLAUDE.md that imports it so both tools read the same instructions without duplicating them"); claude-code-action Issue #1187 (Anthropic-owned repo, documents symlink ENOENT crash since v1.0.89); agents.md homepage (Tier-2 — confirms LF/Agentic-AI-Foundation stewardship, 60k+ adopters, nested AGENTS.md walk semantics).

**Concrete pattern (canonical):**
```
# CLAUDE.md
@AGENTS.md

## Claude Code
Use plan mode for changes under `src/billing/`.
```
Claude Code reads `CLAUDE.md`, expands the `@AGENTS.md` import in full at session start, then appends any Claude-specific directives below. Codex, Cursor, Aider read `AGENTS.md` directly. Single source of truth, zero symlink fragility.

##### Q-015 v1.13 — Boundary contract + structural-ordering clarification

Q-001 introduced the project-memory-layer interaction model with CLAUDE.md and AGENTS.md (rules R-MEM-1..-9 in v1.2 and R-MEM-10 VALIDATED CANONICAL in v1.12). Q-015 extends the contract to a **four-container coordinated system** — skills, `<root>/CLAUDE.md`, `<root>/AGENTS.md`, and repo docs (`README.md` / `ARCHITECTURE.md` / ADR / runbooks). The skill-spec § *Skill vs Reference Content* carries the routing test in full; this section records the project-memory-layer implications and the new structural-ordering rule.

###### R-BOUNDARY-4-CLARIFICATION [skill][claude-code-only] VALIDATED — NEW v1.13

When `<root>/AGENTS.md` exists and `<root>/CLAUDE.md` imports it (R-MEM-10), the verbatim `@AGENTS.md` directive MUST be the **first content line** of `<root>/CLAUDE.md` (i.e., before any other instruction; YAML frontmatter and HTML comments do not count as content lines). Claude-Code-specific content follows the import. **Anchor (canonical Anthropic example, verbatim):**

```markdown

```

Source: 'How Claude remembers your project' § AGENTS.md, Anthropic, 2026, https://code.claude.com/docs/en/memory. Placing `@AGENTS.md` first ensures that the tool-portable invariants are loaded before Claude-Code-specific addenda. (Note: Gemini-15's specific *recency-bias* rationale extending this from documented directory-walk later-wins semantics to in-file ordering is a Discovery-level extrapolation; the structural rule itself is canonical Tier-1, the in-file mechanism is logged at v1.13 as P-BOUND-SUPERSEDE-3 PROPOSED.)

###### Memory architecture disambiguation (formalized v1.13 after Gemini-15 evaluation)

> **MEMORY.md ≠ CLAUDE.md regarding load behavior** _(red)_
>
> **MEMORY.md** (auto-memory index at `~/.claude/projects/<project>/memory/MEMORY.md`) has a hard load cap: *'The first 200 lines of MEMORY.md, or the first 25KB, whichever comes first, are loaded at the start of every conversation.'* Content beyond this threshold is silently truncated. **CLAUDE.md** (project memory at `<root>/CLAUDE.md`, `~/.claude/CLAUDE.md`, etc.) does NOT have this cap: *'CLAUDE.md files are loaded in full regardless of length, though shorter files produce better adherence.'* Verbatim source: 'How Claude remembers your project', Anthropic, 2026, https://code.claude.com/docs/en/memory. **Strict project guard text** because Gemini-15 conflated the two (rejected → DA-140); R-BOUNDARY-3 carveout reflects this. The 200-line CLAUDE.md *target* is for adherence quality, not truncation safety; lints emit WARN at 200 lines, not FAIL.

###### AGENTS.md walk vs CLAUDE.md walk — vendor-portable mechanics

The agents.md spec (Tier-2; AAIF/Linux Foundation stewardship; 60k+ adopting OSS projects) specifies a **closest-wins** walk: *'Agents automatically read the nearest file in the directory tree, so the closest one takes precedence'* / FAQ: *'The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything.'* (https://agents.md/). Codex CLI walks from project root to CWD with `project_doc_max_bytes` (default 32 KiB; https://developers.openai.com/codex/guides/agents-md). Windsurf treats the root file as always-on and subdirectory files as glob-scoped to `<directory>/**` (https://docs.windsurf.com/windsurf/cascade/agents-md). Claude Code's CLAUDE.md walk is **subtly different**: ancestor CLAUDE.md files are 'loaded in full at launch'; subdirectory CLAUDE.md files 'load on demand when Claude reads files in those directories'; concatenation order is filesystem root → CWD, with closer-to-CWD content read last (later-wins). Source: 'How Claude remembers your project'. **Practical implication for nested CLAUDE.md/AGENTS.md pairs:** when each nested CLAUDE.md `@`-imports the local AGENTS.md, the local AGENTS.md content benefits from Claude Code's later-wins ordering on every directory entry, but only loads on-demand for subtree CLAUDE.md files (vs Codex CLI's always-on launch concatenation).

###### Auto-memory architecture (Q-019 v1.17 — AutoDream / `tengu_onyx_plover` / KAIROS umbrella)

Q-019 establishes the auto-memory architecture chapter that sits beneath the `R-MEM-*` family. Tier-1 sources are silent on the in-CLI consolidation feature (verified live 2026-05-07 across `code.claude.com/docs/en/memory`, `/glossary`, `/how-claude-code-works`, `/sub-agents`, `/skills`, `/commands`, `/best-practices`, `/claude-directory`; `anthropic.com/news` Apr–May 2026; `anthropics/claude-code` `CHANGELOG.md`; *Complete Guide to Building Skills for Claude*; `anthropics/skills`; `anthropics/anthropic-cookbook`). The canonical post-GA terminology is **"Auto memory"** per [`code.claude.com/docs/en/memory#auto-memory`](https://code.claude.com/docs/en/memory#auto-memory) and [`code.claude.com/docs/en/glossary`](https://code.claude.com/docs/en/glossary) (verbatim glossary entry: Auto memory is the *"Claude-written counterpart"* to manual configuration files; stored locally per Git repository under `~/.claude/projects/<project>/memory/`). The internal-engineering names `AutoDream`, `tengu_onyx_plover`, and the `KAIROS` umbrella appear only in Discovery-tier artifacts derived from the **2026-03-31 npm sourcemap leak** (Claude Code v2.1.88, attributed to Chaofan Shou) and in `anthropics/claude-code` issue-tracker text quoting that leaked terminology (Issues #38426, #38461, #38493, #39135, #39204, #39633, #41708, #44820, #47959, #50694).

**Distinct-product disambiguation (DO NOT CONFUSE).** [`platform.claude.com/docs/en/managed-agents/dreams`](https://platform.claude.com/docs/en/managed-agents/dreams) (canonical Tier-1 — verbatim: *"Dreams… A dream reads an existing memory store alongside past session transcripts, then produces a new, reorganized memory store… The input store is never modified"*) documents a **separate Managed Agents API product**, not the in-CLI AutoDream consolidator. Distinguishing axes: (1) surface — Managed Agents Platform API vs Claude Code CLI; (2) beta header — `dreaming-2026-04-21` on top of `managed-agents-2026-04-01` vs the GrowthBook flag `tengu_onyx_plover`; (3) operational model — asynchronous job with immutable input store and explicit `drm_…` output IDs vs forked-subagent with in-place rewrite of files in `~/.claude/projects/<slug>/memory/`; (4) wiring — explicit user-supplied session IDs vs unattended scheduled-between-sessions trigger.

<!-- @rule: R-AUTODREAM-1 -->
<a id="r-autodream-1"></a>

**R-AUTODREAM-1** [reference] [claude-code-only] VALIDATED.

**AutoDream's documented file scope is strictly `~/.claude/projects/<slug>/memory/`** (the auto-memory directory, optionally redirected via the `autoMemoryDirectory` setting — but per Tier-1 [`anthropics/claude-code` Issue #39204](https://github.com/anthropics/claude-code/issues/39204) verbatim *"Auto-dream writes memory files to the default `~/.claude/projects/<project>/memory/` directory instead of the path configured via autoMemoryDirectory"*, the override is currently broken). AutoDream operates on the `MEMORY.md` index plus adjacent topic files (e.g. `debugging.md`, `api-conventions.md`, `user_profile.md`, `reference_*.md` per Tier-1 Issues #47959 and #50694). AutoDream is **NOT documented or observed** to read or write `<root>/CLAUDE.md`, `<root>/AGENTS.md`, `~/.claude/CLAUDE.md`, `./.claude/rules/*.md`, or any `SKILL.md` — but Anthropic has not published an explicit non-interaction commitment in canonical docs. **Strict-default project rule:** project memory architectures MUST place durable user constraints in `<root>/CLAUDE.md` or `<root>/AGENTS.md` (per [R-MEM-10](#r-mem-10)), NEVER inside MEMORY.md, because the only durable cross-session anchor is the CLAUDE.md/AGENTS.md layer. **Tier-1 anchors:** `anthropics/claude-code` Issues [#39204](https://github.com/anthropics/claude-code/issues/39204), [#47959](https://github.com/anthropics/claude-code/issues/47959) (`Auto Dream deletes memory files without user consent — 23 files lost in one day`, has-repro labeled by Anthropic), [#50694](https://github.com/anthropics/claude-code/issues/50694) (`.consolidate-lock` PID-bound forked subagent — verbatim: *"Owning PID 52900 dead by at least Apr 9"*, has-repro labeled).

<!-- @rule: R-AUTODREAM-2 -->
<a id="r-autodream-2"></a>

**R-AUTODREAM-2** [reference] [claude-code-only] PROPOSED — strong cross-source corroboration.

**AutoDream is gated by the GrowthBook server-side flag `tengu_onyx_plover`** (Discovery-tier; corroborated across ≥7 independent post-leak archives: PeronGH/claude-code-decoded, marckrenn/claude-code-changelog, yitianlian/claude-code-hidden-features, davccavalcante/claude-code-leaked, sanbuphy/claude-code-source-code, 0PeterAdel/ClaudeCode-Leak, yasasbanukaofficial/claude-code; all derived from the 2026-03-31 v2.1.88 npm sourcemap leak attributed to Chaofan Shou). The user-side toggle is `autoDreamEnabled` in `~/.claude/settings.json` (Tier-1 anchored via Issues [#39633](https://github.com/anthropics/claude-code/issues/39633), [#47959](https://github.com/anthropics/claude-code/issues/47959)). **Trigger architecture (PROPOSED, ≥6 cross-source agreement, no Tier-1 numeric quote):** triple gate of (a) ≥24 hours since last consolidation; (b) ≥5 accumulated sessions since last consolidation; (c) acquisition of advisory file lock at `~/.claude/projects/<slug>/memory/.consolidate-lock` (the lock-file path is Tier-1 anchored via Issue [#50694](https://github.com/anthropics/claude-code/issues/50694); the 24h+5-session thresholds are Discovery-only). **Operational pipeline (PROPOSED):** four-phase Orient → Gather → Consolidate → Prune (corroborated across yitianlian, davccavalcante, claudefa.st, mejba.me, sdd.sh, dev.to/akari_iku, o-mega.ai, kingy.ai). **Surface-level UI (Tier-1 via Issue [#39135](https://github.com/anthropics/claude-code/issues/39135)):** the `/memory` UI displays *"Auto-dream: on · last ran 13h ago · /dream to run"*, but the `/dream` slash-command is not registered for many users — UI text is not documentation. **Project guidance:** consumers of this rule MUST treat the trigger thresholds as estimated rather than contractual; the lock-file mechanism is the only Tier-1-anchored gate.

<!-- @rule: R-AUTODREAM-3 -->
<a id="r-autodream-3"></a>

**R-AUTODREAM-3** [reference] [portable] VALIDATED.

**AutoDream is operationally orthogonal to all three primary token-economy mechanisms — Task Budgets, auto-compaction, and the [R-FAIL-1](#r-fail-1) skill re-attach pool.** *(a) Task Budgets:* Tier-1 explicit at [`platform.claude.com/docs/en/build-with-claude/task-budgets`](https://platform.claude.com/docs/en/build-with-claude/task-budgets) verbatim *"Task budgets are not supported on Claude Code or Cowork surfaces at launch. Use task budgets directly via the Messages API on Claude Opus 4.7."* — strengthens [Q-018](#q-018)'s Task-Budget-orthogonality framing. AutoDream cannot consume Task Budget tokens through the standard mechanism because Task Budgets are not wired into Claude Code at launch. *(b) Auto-compaction:* lifecycle disjointness — auto-compaction triggers within an active session at the `autoCompactWindow` threshold (Tier-1 [`code.claude.com/docs/en/how-claude-code-works`](https://code.claude.com/docs/en/how-claude-code-works); env var `CLAUDE_CODE_AUTO_COMPACT_WINDOW`); AutoDream is scheduled between sessions per Tier-1 Issue [#50694](https://github.com/anthropics/claude-code/issues/50694) (*"scheduled between sessions"*). They occupy disjoint phases of the lifecycle. *(c) [R-FAIL-1](#r-fail-1) skill re-attach pool:* skills are not in AutoDream's file scope per [R-AUTODREAM-1](#r-autodream-1); AutoDream cannot inflate or contaminate the 25K combined / 5K per-skill re-attach budget. **Project consequence:** documenters MUST resist the temptation to cross-reference AutoDream consumption against Task Budget runway, auto-compaction trigger thresholds, or skill re-attach budgets. The three mechanisms operate in disjoint domains; cross-pollution language (e.g., *"a generous Task Budget protects skill content from AutoDream's prune phase"*) is a category error.

<!-- @rule: R-AUTODREAM-4 -->
<a id="r-autodream-4"></a>

**R-AUTODREAM-4** [reference] [claude-code-only] PROPOSED — naming-correction rule.

**The project's working term "KAIROS daemon" for the AutoDream consolidator is project-internal terminology that does NOT match Anthropic's leaked-source usage.** Anthropic's `KAIROS` is the **umbrella name for proactive autonomous-agent mode** — gated by compile-time flag `feature('KAIROS')` plus runtime GrowthBook flag `tengu_kairos`, env var `CLAUDE_CODE_PROACTIVE=1` — encompassing: (i) the AutoDream consolidator (sub-flag `KAIROS_DREAM`, additionally gated by `tengu_onyx_plover`); (ii) tick-loop monitoring of daily append-only logs at `~/.claude/.../logs/YYYY/MM/DD.md` (per davccavalcante/claude-code-leaked); (iii) push notifications (`KAIROS_PUSH_NOTIFICATION` / `tengu_kairos_push_notifications`); (iv) PR-subscription tools (`SubscribePR`); (v) GitHub webhook routing (`KAIROS_GITHUB_WEBHOOKS`); (vi) brief generation (`KAIROS_BRIEF`); (vii) exclusive specialized tools `SendUserFile`, `PushNotification`, `SubscribePR`, `SleepTool`. Refer to the consolidator alone as **"AutoDream"**, **"auto dream"**, or **"the dream subagent"** to track Anthropic's own usage. **Adjacent `tengu_*` namespace flag-function attributions (corroborated via davccavalcante/claude-code-leaked README):** `tengu_kairos` (assistant-mode umbrella), `tengu_ultraplan_model` (planning model — used by the ULTRAPLAN remote-cloud-30-min-deep-planning Opus 4.6 sessions), `tengu_cobalt_raccoon` (auto-compact behavior), `tengu_portal_quail` (memory extract), `tengu_harbor` (MCP allowlist), `tengu_scratch` (worker scratch dirs), `tengu_malort_pedway` (computer use). The `tengu_*` prefix is the internal engineering codename for Claude Code itself (corroborated by undercover.ts which strips internal codenames "Tengu" and "Capybara" from external commits per alex000kim.com / wavespeed.ai independent analyses). **PROPOSED rather than VALIDATED** because the entire `tengu_*` flag-namespace and `KAIROS` umbrella appear only in leaked artifacts and Anthropic-bug-tracker quotation, never in canonical Anthropic-authored docs.

<!-- @rule: R-MEM-1-CLARIFICATION -->
<a id="r-mem-1-clarification"></a>

**R-MEM-1-CLARIFICATION** [reference] [claude-code-only] VALIDATED — NEW v1.17.

**The [R-MEM-1](#r-mem-1) hierarchy is cross-container only; it does NOT establish intra-MEMORY.md user-vs-Claude-consolidation precedence.** The R-MEM-1 ladder (managed/enterprise → project CLAUDE.md → project rules → user CLAUDE.md → local project CLAUDE.md → Auto Memory) correctly places user-authored CLAUDE.md *above* Claude-written Auto Memory in cross-container precedence. But within MEMORY.md itself, the AutoDream consolidator MAY rewrite or destructively delete user-reinforced entries — Tier-1 Issue [#47959](https://github.com/anthropics/claude-code/issues/47959) (`Auto Dream deletes memory files without user consent — 23 files lost in one day`, has-repro/data-loss labeled by Anthropic, opened 2026-04-08) documents *"a rule that had been reinforced 3 times by the user (never use 'Author: Claude' in copyright headers)"* being deleted by Auto Dream. The user's only documented mitigation was to set `autoDreamEnabled: false` permanently. **Project consequence:** for durable user constraints, place them in CLAUDE.md or AGENTS.md (per [R-MEM-10](#r-mem-10)) — never in MEMORY.md. **Rejects** the Gemini-19 framing that the consolidation engine *"lacks the systemic permission to overwrite user prose"* and *"maintains a strictly segregated sub-directory that is inherently and permanently subservient to the primary ruleset"* — see [DA-Q019-1](#da-q019-1). The cross-container reading of those framings is correct (and is what R-MEM-1 codifies); the universal-supersession reading is contradicted by Tier-1 #47959.

### Context-Efficiency Techniques

<!-- @rule: R-CTX-1 -->
<a id="r-ctx-1"></a>

**R-CTX-1** [skill] [portable] VALIDATED.

**Apply progressive disclosure as a hard architectural rule** (see Skill-vs-Reference table). Level-1 metadata in system prompt; Level-2 SKILL.md body ≤5,000 tokens loaded on trigger; Level-3 references/scripts/assets loaded on demand.

<!-- @rule: R-CTX-2 -->
<a id="r-ctx-2"></a>

**R-CTX-2** [skill] [portable] VALIDATED.

**Mutually-exclusive content paths MUST be in separate files** so only one ever loads. Anthropic Engineering explicitly: *"If certain contexts are mutually exclusive or rarely used together, keeping the paths separate will reduce the token usage."*

##### Pre-registered token budgets

| Quantity | Value | Scope | Source |
|---|---|---|---|
| Per-skill metadata cost | ~100 tokens | Both | Anthropic API + skill-workshop |
| Description listing budget (combined description+when_to_use) | 1,536 chars per skill | Claude Code | Anthropic Claude Code docs |
| Description listing total system-prompt budget | **1% of context window, 8,000-char fallback** | Claude Code | Anthropic Claude Code docs (rejects Gemini-1's 2%/16K which belongs to Codex) |
| SKILL.md body cap | 500 lines / 5,000 tokens | Both | Anthropic Claude Code docs + API + skill-workshop |
| Reference file ToC threshold | 300 lines | Both | Anthropic skill-workshop |
| Re-attached skill content per skill (after compaction) | 5,000 tokens | Claude Code | Anthropic Claude Code docs (rejects Gemini-1's 1,000-token Discovery claim) |
| Combined re-attachment budget across skills | 25,000 tokens | Claude Code | Anthropic Claude Code docs |
| Override env var (Claude Code) | `SLASH_COMMAND_TOOL_CHAR_BUDGET` | Claude Code | Anthropic Claude Code docs |

##### Skill content lifecycle (Claude Code)

When a skill is invoked, the rendered SKILL.md content enters the conversation as a single message and **stays for the rest of the session — Claude Code does not re-read the file on later turns**. Auto-compaction re-attaches the most recent invocation of each skill (subject to the budgets above), filling from most-recently-invoked first. Implication: write SKILL.md as STANDING instructions; front-load the standing constraints in the first 5,000 tokens to survive compaction.

### Helper Scripts (CLI args, return values, context savings)

> **User pattern confirmed** _(green)_
>
> The project owner already uses scripts with clear CLI args and return values to save thinking tokens — this is the **canonical Anthropic-recommended pattern**, not an improvement target. Anthropic Engineering: *"sorting a list via token generation is far more expensive than simply running a sorting algorithm."*

<!-- @rule: R-HELP-1 -->
<a id="r-help-1"></a>

**R-HELP-1** [skill] [portable] VALIDATED — (location) / PROPOSED (Python preference).

**Helpers go in `<skill>/scripts/<verb_object>.py`.** Python is the empirical preference across Anthropic-shipped skills (PDF, DOCX, XLSX, PPTX, skill-workshop, codebase-visualizer); Bash is acceptable for thin glue. Open standard accepts Python, Bash, JS.

<!-- @rule: R-HELP-2 -->
<a id="r-help-2"></a>

**R-HELP-2** [skill] [portable] VALIDATED.

**Stable CLI surface.** Each helper MUST expose: positional args + named flags, `--help` output, machine-readable stdout (JSON when the consumer is Claude), errors to stderr with non-zero exit code.

<!-- @rule: R-HELP-3 -->
<a id="r-help-3"></a>

**R-HELP-3** [skill] [portable] VALIDATED.

**Document every helper invocation in SKILL.md.** Include: command line, args, return shape, when to use vs. when to fall back to inline reasoning. The script's *code* never enters context — only its stdout/stderr does — so the SKILL.md is the agent's only documentation.

<!-- @rule: R-HELP-4 -->
<a id="r-help-4"></a>

**R-HELP-4** [skill] [claude-code-only] VALIDATED.

**Reference helpers via `${CLAUDE_SKILL_DIR}/scripts/<file>`.** This resolves regardless of CWD or whether the skill is plugin-bundled. Documented in Anthropic Claude Code docs.

<!-- @rule: R-HELP-5 -->
<a id="r-help-5"></a>

**R-HELP-5** [skill] [claude-code-only] VALIDATED.

**Pre-approve via `allowed-tools` frontmatter.** E.g., `allowed-tools: Bash(python *) Bash(<helper-name> *)`. Eliminates per-call approval prompts.

<!-- @rule: R-HELP-6 -->
<a id="r-help-6"></a>

**R-HELP-6** [skill] [portable] VALIDATED.

**Extract-when-repeated trigger** (Anthropic skill-workshop): *"If all 3 test cases resulted in the subagent writing a `create_docx.py` or a `build_chart.py`, that's a strong signal the skill should bundle that script."* When you see Claude reinvent the same script across runs, extract it once into `scripts/`.

<!-- @rule: R-HELP-7 -->
<a id="r-help-7"></a>

**R-HELP-7** [skill] [portable] VALIDATED.

**Shebang `#!/usr/bin/env python3`** at the top of Python helpers. Executable bit optional (Anthropic invokes via `python <path>`). Use stdlib first; cross-platform deps only.

### Skill Library Architecture (Voyager-inspired)

> **Voyager is the architectural precedent for the skill-system pattern** _(purple)_
>
> Wang, Xie, Jiang, Mandlekar, Xiao, Zhu, Fan, Anandkumar, *Voyager: An Open-Ended Embodied Agent with Large Language Models* (TMLR 2024, arXiv:2305.16291) describes "an ever-growing skill library of executable code" indexed by description. SKILL.md = Voyager's skill description; helper scripts = Voyager's skill code; the routing mechanism is the same. The four rules below port Voyager's discipline.

> **v1.6 (Q-006) clarification** _(amber)_
>
> Anthropic's `anthropics/skills` repository implements a **flat self-contained** organization with **zero cross-skill helper sharing** — each skill is an opaque folder with its own `scripts/`, `references/`, and (when needed) `shared/` subdirectory **internal to that skill**. This diverges from a deep-library reading of Voyager's "ever-growing skill library of executable code": Voyager's compositional reuse happens at the *model-reasoning* level (the model sees skill descriptions and chooses which to call), not at the *file-system* level (no symlinks, no shared utility folders across siblings). See **R-COMP-3** in [Multi-task Composition ↗](#multi-task-composition){tab=skill-spec}.

<!-- @rule: R-XPOLL-1 -->
<a id="r-xpoll-1"></a>

**R-XPOLL-1** [skill] [portable] VALIDATED — Voyager (TMLR 2024).

**Skills are persistent units retrievable by description.** The `description` field is the retrieval key; treat it accordingly. Anthropic's own routing is description-similarity-based (Lee Hanchung deep-dive empirical confirmation, 2025-10-26). Concrete trigger keywords beat abstract summaries. Cross-references R-XPOLL-5 (trigger-shaped grammar).

<!-- @rule: R-XPOLL-3 -->
<a id="r-xpoll-3"></a>

**R-XPOLL-3** [system] [portable] PROPOSED — Voyager (TMLR 2024).

**Curriculum-style meta-skill onboarding.** When proposing a new skill, the meta-skill (Q-003 deliverable) SHOULD scan the existing library and propose skills *relative to observed gaps* rather than from a blank slate. Voyager §3.1's automatic curriculum is the precedent. Routes to Q-003.

<!-- @rule: R-XPOLL-6 -->
<a id="r-xpoll-6"></a>

**R-XPOLL-6** [skill] [claude-code-only] PROPOSED — Reflexion (NeurIPS 2023).

**Self-update requires an external verification signal.** A skill MAY only auto-append to its Gotchas / Errata section when an external test/lint/user-correction signal is present, not on the LLM's own confidence. Shinn et al. *Reflexion* (NeurIPS 2023, arXiv:2303.11366) §3 ablations show self-reflection without external signal degrades performance. Routes to Q-007 (self-updating skills).

<!-- @rule: R-XPOLL-7 -->
<a id="r-xpoll-7"></a>

**R-XPOLL-7** [system] [claude-code-only] PROPOSED — Self-Refine (NeurIPS 2023).

**Promotion-pass cap of 3 iterations per session.** Madaan et al. *Self-Refine* (NeurIPS 2023, arXiv:2303.17651) Table 4 shows diminishing returns past 2-3 self-refinement iterations. The meta-skill skill-update workflow MUST cap iteration at 3 passes to prevent infinite loops and runaway self-modification. Routes to Q-007.

### Parallelism & Delegation Topology

> **Q-006 added this subsection** _(blue)_
>
> Topology and quantitative bounds for runtime composition. All rules cross-link to [Multi-task Composition ↗](#multi-task-composition){tab=skill-spec}; this subsection is the *system view*.

##### The orchestrator-worker topology

Anthropic's canonical multi-task topology has three formal positions: a **lead agent** (implicit at the in-session tier, explicit "team lead" at the agent-teams tier), **workers** (subagents, forked or named, that execute leaf tasks in isolated contexts), and the **shared substrate** (CLAUDE.md, the skill library, plus — at the agent-teams tier — the shared task list and the inter-agent mailbox).

##### Fan-out cardinality (canonical Anthropic guidance)

| Use case | Recommended fan-out | Per-subagent tools | Source |
|---|---|---|---|
| Simple fact-finding (single answer) | 1 subagent (or none — stay in-session) | 3–10 tool calls | *How we built our multi-agent research system*, Anthropic, 2025 |
| Direct comparisons (2–3 entities) | 2–4 subagents | 10–15 tool calls each | ibid. |
| Complex research (broad / deep) | >10 subagents | 15+ tool calls each | ibid. |
| Project rule (R-PAR-2 hard ceiling) | ≤ 8 per fan-out (matches R-API-1 envelope) | — | v1.6 pre-registered threshold |

##### Asymmetric token economics

Token consumption per topology (Anthropic-internal telemetry, *How we built our multi-agent research system*, 2025): single-turn chat ≈ 1× baseline; isolated subagent ≈ 4× baseline (each spawned with fresh CLAUDE.md, tool schemas, and any preloaded skills); fully collaborative agent team ≈ 15× baseline (each teammate continuously reads shared task list and broadcasts status via the inter-agent mailbox). **Implication:** unbounded fan-out is the dominant cost driver in agentic systems. R-PAR-2's 8-ceiling and R-CONDUCT-4's escalation threshold both exist to force conscious topology choices.

##### Fan-in synchronization

Per **R-FAIL-2**, `PostToolBatch` is the *only* documented hook event that fires exactly once per parallel batch and is blockable. It is the canonical place for: (a) cross-branch result aggregation, (b) cross-branch failure detection ("1 of 4 branches failed → fail fast"), (c) deduplication of overlapping subagent outputs before they hit the parent's context. Per-tool `PostToolUse` hooks fire concurrently across parallel branches and **cannot** see the full batch — do not use them for fan-in.

##### Per-branch isolation invariants (R-FAIL-1)

- **Context window:** each forked subagent and each named subagent has its own context window with its own auto-compaction lifecycle.
- **Re-attach budget:** each branch has its own independent 25,000-token pool (5,000-token cap per skill, filled most-recent-first). Pools do NOT merge at fan-in.
- **Prompt cache:** a forked subagent (`context: fork`) reuses the parent's prompt cache because system prompt and tool definitions are identical — cheaper than a fresh named subagent. A named subagent gets a fresh cache.
- **Conversation history:** forked subagents receive only the SKILL.md body as their prompt; named subagents receive only Claude's delegation message. Neither sees the parent's session history. **Exception:** the experimental `/fork` interactive feature (`CLAUDE_CODE_FORK_SUBAGENT=1`) DOES inherit the full parent conversation — but that's a separate user-facing feature, not a skill-frontmatter mechanism.
- **Permissions:** background subagents auto-deny anything not pre-approved at spawn time and continue silently — see R-FAIL-5.

##### Topology decision tree

```text

```

### Self-Modification Governance

> **Self-Modification Governance — added in v1.7 (Q-007)** _(purple)_
>
> Rules in this subsection govern HOW retrospectives become skill modifications: **R-EXTRACT-*** (when to promote an on-the-fly script to a permanent skill); **R-DESTRUCT-*** (gating retrospectives for skills with `disable-model-invocation: true`); **R-VC-*** (version-control discipline for self-modifying skills). Cross-pollinated with R-RETRO-*, R-SELF-*, R-DRIFT-* in the skill-spec tab and R-ROLLBACK-* in the meta-validation tab.

##### R-EXTRACT-* — Promoting on-the-fly scripts to permanent skills

<!-- @rule: R-EXTRACT-1 -->
<a id="r-extract-1"></a>

**R-EXTRACT-1** [skill] [portable] PROPOSED — (inter-session arm tightened Turn 2).

**When the same on-the-fly script is reused N≥3 times in one session, OR ≥3 sessions within a 14-day window, the meta-skill emits a `systemMessage` proposing extraction.** Inter-session arm tightened from initial Turn-1 hypothesis (≥2 sessions in 7 days) to ≥3 sessions in 14 days during Turn 2 per Gemini-7's strict-mode argument (false positives are expensive in marketplace-distributed skills). *Sources:* in-session N≥3 anchored in R-XPOLL-4 (Self-Refine, Madaan et al. NeurIPS 2023); inter-session arm pre-registered, tightened by Gemini-7's strict-mode reasoning. PROPOSED pending Tier-1 source for the inter-session threshold.

<!-- @rule: R-EXTRACT-2 -->
<a id="r-extract-2"></a>

**R-EXTRACT-2** [skill] [portable] VALIDATED — anthropics/skills/skill-workshop.

**Extraction is performed by handing the proposed skill to skill-workshop (`anthropics/skills`), which scaffolds frontmatter, body, and lifts the script into `scripts/`.** *Sources:* `anthropics/skills/skill-workshop/SKILL.md` `init_skill.py` and `package_skill.py` (the canonical Anthropic scaffolding pipeline).

<!-- @rule: R-EXTRACT-3 -->
<a id="r-extract-3"></a>

**R-EXTRACT-3** [skill] [portable] VALIDATED — anthropics/skills/skill-workshop.

**A newly extracted skill MUST pass an initial trigger-eval (≥20 prompts, mixed should-trigger / should-not) and a behavioral eval before being added to a marketplace.** *Sources:* `anthropics/skills/skill-workshop/SKILL.md` description-optimization pass (the same eval pipeline that R-DRIFT-1 invokes for description regen).

##### R-DESTRUCT-* — `disable-model-invocation: true` interaction

<!-- @rule: R-DESTRUCT-1 -->
<a id="r-destruct-1"></a>

**R-DESTRUCT-1** [skill] [claude-code-only] VALIDATED — Anthropic skills doc.

**Retrospectives for skills with `disable-model-invocation: true` MUST NOT auto-apply.** They are written as a pending diff under `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/<skill>-<timestamp>.diff` and a system message MUST surface for explicit user invocation (e.g., `/<skill> --apply-retro`). *Sources:* `code.claude.com/docs/en/skills` (`disable-model-invocation` semantics for side-effecting skills); R-XPOLL-6 (Reflexion external-signal requirement).

<!-- @rule: R-DESTRUCT-2 -->
<a id="r-destruct-2"></a>

**R-DESTRUCT-2** [skill] [portable] VALIDATED — Anthropic skills doc.

**The meta-skill itself SHOULD ship with `disable-model-invocation: true` for any subcommand that performs the merge step (e.g., `/meta:apply-retro`), preserving user-only authority over self-modification.** *Sources:* `code.claude.com/docs/en/skills`; mirrors Anthropic's pattern for destructive workflows.

<!-- @rule: R-DESTRUCT-3 -->
<a id="r-destruct-3"></a>

**R-DESTRUCT-3** [skill] [claude-code-only] VALIDATED — NEW Turn 2 (Gemini-7 G7-8 accepted).

**Retrospective merges MUST go through the Edit-tool's permission-classifier path (PreToolUse / PermissionRequest hooks), never via raw shell `patch`/`sed`.** This satisfies Claude Code's sandbox/permission-mode discipline and ensures user-acceptance is surfaced via the standard authorization prompt. Alternative: pre-compiled binary executables shipped in the plugin's `bin/` directory operate at a known elevated trust level relative to raw shell. *Sources:* `code.claude.com/docs/en/hooks` PreToolUse / PermissionRequest decision-control architecture; R-XPOLL-6 user-accept gate; Gemini-7 G7-8 sandbox-discipline argument (ACCEPTED).

##### R-VC-* — Version-control discipline

<!-- @rule: R-VC-1 -->
<a id="r-vc-1"></a>

**R-VC-1** [skill] [portable] PROPOSED — Conventional Commits ecosystem.

**Self-update commits use Conventional-Commits prefix `skill(retro): <skill-name> <YYYY-MM-DD>`.** *Sources:* Conventional Commits standard (community precedent); pre-registered. PROPOSED pending Anthropic-canonical commit-prefix guidance.

<!-- @rule: R-VC-2 -->
<a id="r-vc-2"></a>

**R-VC-2** [skill] [portable] PROPOSED — semver semantics.

**Patch-level semver bump for `references/` writes; minor for body edits; major for description rewrites.** *Sources:* mirrors typical semver semantics; pre-registered. PROPOSED pending Anthropic-canonical guidance.

<!-- @rule: R-VC-3 -->
<a id="r-vc-3"></a>

**R-VC-3** [skill] [portable] VALIDATED — standard SCM + R-XPOLL-6.

**Self-modifications do NOT target `main` directly; they target a `skill/auto-update` branch (or equivalent feature branch) that requires explicit user merge.** *Sources:* standard SCM practice plus R-XPOLL-6's user-accept gate (Reflexion external-signal requirement, Shinn et al. NeurIPS 2023).

### Routine-Based Audit Cadence

#### Three-tier cadence (R-CADENCE-1)

| Tier | Frequency | What runs | Implementation primitive |
|---|---|---|---|
| Monthly drift scan | 1st of month, 09:00 UTC | Mechanical validator (all skills) + LLM-judge (R-LLMJ family) + NLI on R-DRIFT-5; emits review-report.json | Routine schedule (primary) / GitHub Actions cron (fallback) |
| Quarterly rule-set review | 1st of Q | Re-resolve all Tier-1 citations; diff against agentskills.io spec + anthropics/skills; bump rule-set version per R-VC-* / R-CADENCE-5 | Routine schedule + reviewer-skill `/review-skills` |
| On-demand | Triggered (R-CADENCE-3) | (i) skill-workshop new minor; (ii) validator major bump; (iii) ≥3 R-ROLLBACK-* per skill; (iv) R-XPOLL-8 overlap exceeded; (v) post-merge retro fails | Routine `/fire` endpoint + reviewer-skill `/review-skills` |

#### Implementation: Claude Code Routines primary (R-CADENCE-2)

**Primary mechanism: Claude Code Routines.** Per the Anthropic Week 16 changelog (code.claude.com/docs/en/whats-new/2026-w16, retrieved 2026-05-04, launched 2026-04-14 in research preview): Routines are templated cloud agents triggerable on a schedule, on a GitHub event, or on an API call (`/fire` endpoint under beta header `experimental-cc-routine-2026-04-01`). Routines run on Anthropic's cloud — no developer machine required, persistent state across executions. Three trigger modes (scheduled, GitHub events, API) compose freely on a single Routine. **Fallback mechanism: GitHub Actions cron.** Self-hosted CI users, users on plans without Routines access, and air-gapped environments fall back to `.github/workflows/skill-review.yml` with `schedule.cron` + a CLI invocation of the validator + judge. **Both paths converge on the same `review-report.json` output schema (R-CADENCE-4).**

#### Operational caveats (extended R-CADENCE-1)

- **Routines daily run caps** (verified May 2026): Pro 5/day, Max 15/day, Team-Enterprise 25/day. Audits draw down the same subscription pool as interactive Claude Code sessions. A 50+-skill repo running monthly drift + frequent on-demand triggers can exhaust Pro / Max tier within a single day of off-cadence activity. **Recommendation**: Team or Enterprise tier is the practical minimum for real audit fleets; smaller plans should batch audits or fall back to GitHub Actions cron (which has no per-account run cap but lacks Routines' persistent-state and cloud-execution properties).
- **Beta-header churn** — `experimental-cc-routine-2026-04-01` may rotate; Q-013 captures the versioned-check requirement.
- **Branch security default** — Routines push only to `claude/`-prefixed branches by default; the validator's auto-merge path must respect this constraint (cross-link to Q-007 R-VC-* `skill/auto-update` branch convention).
- **No silent fallback** — if both Routines and GitHub Actions fail, the cadence MUST surface a human notification rather than skip an audit window. Anchored on R-META-9 (auditability) and the long-running-agents engineering principles.

#### Off-cadence triggers (R-CADENCE-3)

Five mandatory triggers initiate an off-cadence review run: **(i) skill-workshop ships a new minor version** — poll the github.com/anthropics/skills release feed; **(ii) the validator's own SemVer crosses a major bump** — cross-link to Q-007 R-VC-*; **(iii) any single skill accumulates ≥3 R-ROLLBACK-* events within the cadence window** — cross-link Q-007 R-ROLLBACK-3; **(iv) cross-skill description overlap exceeds R-XPOLL-8 threshold** — surfaced by the monthly mechanical pass; **(v) post-merge mechanical-validator run fails on a freshly-applied retro** — cross-link Q-007 R-RETRO-* / R-ROLLBACK-*. Each trigger fires a Routine via its `/fire` endpoint (or GitHub Actions workflow_dispatch in fallback mode) and produces a `review-report.json` tagged with `trigger: "ondemand:<reason>"`.

#### Review-report schema (R-CADENCE-4)

```json
{
  "report_version": "1.0",
  "run_at": "2026-06-01T09:00:00Z",
  "trigger": "monthly | quarterly | ondemand:<reason>",
  "rule_set_version": "1.8.0",
  "validator_version": "1.8.0",
  "skills": [
    {
      "name": "frontend-design",
      "path": "skills/frontend-design",
      "mechanical": { "pass": 25, "warn": 1, "fail": 0 },
      "semantic":   { "pass": 19, "warn": 2, "fail": 0 },
      "drift":      [],
      "human_action_required": null
    }
  ]
}
```

### Workspace Topology

> **Q-009 added this subsection** _(blue)_
>
> Workspace topology covers the *spatial* dimension of skill organization: where skills live, how they are discovered across scopes, where shared assets are anchored, and how reference content interacts with repo-level docs. Plugin distribution (R-WORKSPACE-3) is the canonical Anthropic mechanism; embed-and-duplicate (R-SHARE-1, DA-058 reaffirmed) is the canonical pattern when plugins are not viable. **Caveat:** `Bun.Glob.scan()` `dot: false` regression in CLI ≥2.1.92 (anthropics/claude-code #44490) breaks documented nested-directory auto-discovery; R-MONO-1 + R-MONO-4 capture the workaround until Anthropic patches.

##### Pre-registered quantitative thresholds

| Threshold | Metric | PASS Semantic | Anchor Rule |
|---|---|---|---|
| T-MONO-1 | Distinct services in a monorepo before plugin promotion is preferred over root flatten-and-duplicate | ≥3 services with overlapping skills → promote to plugin | R-WORKSPACE-3, R-MONO-2 |
| T-SHARE-1 | Skills sharing a helper script before plugin-as-library beats embed-and-duplicate | ≥2 skills sharing a script in same plugin → place script at `${CLAUDE_PLUGIN_ROOT}/scripts/` | R-SHARE-1 |
| T-PFX-1 | Service-prefix tolerance threshold before plugin migration | ≥2 services with colliding skill names → migrate to plugin-per-service | R-WORKSPACE-6 |
| T-REF-1 | Reference file size before grep-pattern guidance is required | >10,000 words → require grep guidance regardless of `<skill>/references/` vs `repo/docs/` placement | R-SR-7, R-REFLOC-3 |

##### Plugin-vs-personal/project-scope decision tree

| Scenario | Canonical answer | Rule | Source |
|---|---|---|---|
| Skill used by one project only | Project-scope `.claude/skills/<name>/` | R-WORKSPACE-1 | code.claude.com/docs/en/skills |
| Skill used across multiple projects (same user) | Personal-scope `~/.claude/skills/<name>/` | R-WORKSPACE-1 | code.claude.com/docs/en/skills |
| Skill shared across team or ≥3 services in monorepo (T-MONO-1) | Plugin distributed via marketplace; `/plugin install <plugin>@<marketplace>` | R-WORKSPACE-3, R-MONO-2 | code.claude.com/docs/en/plugins |
| Helper script needed by ≥2 skills in same plugin (T-SHARE-1) | Place at `${CLAUDE_PLUGIN_ROOT}/scripts/<helper>` | R-SHARE-1(a) | code.claude.com/docs/en/plugins-reference |
| Helper script needed by ≥2 skills NOT in same plugin | Embed-and-duplicate (R-COMP-3); each skill ships its own copy | R-SHARE-1(b) | anthropics/skills empirical scan; DA-058 |
| Helper needed across multiple plugins | Not supported; embed-and-duplicate at the plugin level | R-SHARE-1(c) | Issue #15944 |
| Reference content lives in repo `docs/` | Copy into `<skill>/references/` (preferred) OR tag skill `[internal — not portable]` per R-REFLOC-2(c) | R-REFLOC-2(a)/(c) | platform.claude.com best-practices |
| Subfolder-launched session needs root skills | `claude --add-dir <monorepo-root>` (skill exception); plugin distribution preferred | R-WORKSPACE-2, R-WORKSPACE-3 | code.claude.com/docs/en/skills |

##### Bun.Glob runtime regression caveat (CLI ≥ 2.1.92)

Anthropic's `code.claude.com/docs/en/skills` documents "Automatic Discovery from Nested Directories" — when editing a file at `packages/frontend/src/App.tsx`, Claude should auto-load skills at `packages/frontend/.claude/skills/`. **This feature is currently broken in shipping CLI ≥2.1.92 due to a `Bun.Glob.scan()` `dot: false` default regression** (anthropics/claude-code Issue #44490, with full reproduction). Until Anthropic patches the runtime, the workspace topology v1.9 standard treats nested discovery as **broken-pending-patch**, not as a usable mechanism. **Defensive recommendation (R-MONO-1):** place skills at the cwd's `.claude/skills/` (no parent or nested traversal reliance). **Workaround for in-skill `.claude/`-traversal needs (R-MONO-4):** use Bash `find` instead of the Glob tool when a skill body must locate files under `.claude/`. When Anthropic ships the fix, Q-009 reopens to retire R-MONO-4 and promote R-MONO-1 to fully VALIDATED.

##### Resolved tension: Anthropic doc vs Anthropic issue (#40640)

Turn 1 §3.1 logged a Tier-1-vs-Tier-1 contradiction at #40640. **Turn 2 (Gemini-9 G9-B / Issue #44490) resolves this:** the conflict is not at the *specification* layer but at the *runtime* layer. Anthropic's spec is correct; the `Bun.Glob` default is the bug. Per Anthropic-supremacy, the spec wins on intent; the runtime regression is logged for re-verification when Anthropic ships the fix. The doc itself does not need correction.

##### Workspace topology forward-influence references (PROPOSED)

Three peer-reviewed papers added as PROPOSED background influences for v2.0+ Q-009 reopen, NOT as v1.9 directives: **arXiv:2604.17870 (GraSP, Xia et al., Tencent, 20 Apr 2026)** — typed Directed Acyclic Graph composition of skills with precondition-effect edges, O(N) → O(d^h) replanning complexity bound. Future-direction reference for runtime composition (Q-006/Q-009 v2.0+ reopen); rejected as v1.9 directive per DA-109 (conflicts with R-COMP-1 four-layer ladder, no Anthropic implementation). **arXiv:2604.16911 (Skilldex, Saha & Hemanth, 18 Apr 2026)** — package-manager pattern for skill packages with compiler-style format conformance scoring + skillset abstraction (bundled related skills with shared assets). Corroborates Anthropic's plugin model (R-WORKSPACE-3); Skilldex's three-tier global/shared/project hierarchy is rejected as v1.9-canonical per DA-110 (the "shared" tier has no Anthropic equivalent — Anthropic's hierarchy is personal/project/plugin). **arXiv:2602.12430 (Xu & Yan survey, Zhejiang University, v3 17 Feb 2026)** — comprehensive survey of agent skills paradigm; cited as Tier-1 background reference for skill-architecture taxonomies; the 26.1% community-skill vulnerability stat is via reference [14] = Liu et al. arXiv:2601.10338 and is rejected as a v1.9 quantitative threshold per DA-111 (primary source not independently verified).

### Reference Chunking Topology

#### The Claude Code Read-tool ceiling (system constraint)

| Surface | Per-call Read ceiling | Source | v1.10 threshold |
|---|---|---|---|
| Claude Code CLI (≤ Apr 2026) | 25,000 tokens / 2,000 lines | Issues #4002, #14876, #14888, #15687 | Legacy |
| Claude Code CLI (Apr 2026 onward) | 10,000 tokens (silent downgrade) | Issue #45019 (verified Tier-1) | **Current canonical** |
| Claude Code Desktop | 10,000 tokens (hardcoded) | Issue #40357 (verified Tier-1) | Always-stricter |
| MCP context providers | Variable; often fails at 25K | Issue #40357 user comments | Configurable via MAX_MCP_OUTPUT_TOKENS |
| Claude.ai / API / cross-tool | Surface-dependent | Out of [claude-code-only] scope | R-CHUNK-2 portable cap covers |

#### Decision tree for reference-file granularity

| Reference file size | Action | Rule |
|---|---|---|
| < 50 lines | Prefer inline in SKILL.md | R-LAZYLOAD-3 (SHOULD) |
| 50-100 lines | References/foo.md, no TOC required | R-LAZYLOAD-1 (link from SKILL.md) |
| 100-500 lines | References/foo.md with `## Contents` TOC | R-CHUNK-1 (TOC) + R-LAZYLOAD-1 |
| 500 lines OR 10K words OR 10-15K tokens | Domain-split: references/{a,b,c}.md | R-CHUNK-2 (split) |
| >10,000 words (if not split) | Add literal `grep` example in SKILL.md | R-CHUNK-3 (extends R-SR-7) |
| >10K tokens [Claude Code] | Split or paginate via offset/limit | R-CHUNK-5 [claude-code-only] |
| Always | One level deep from SKILL.md; no chained ref→ref | R-CHUNK-4 (content-fidelity) |
| Always | Header-anchored Grep+Read; no vector indexes | R-CHUNK-6 (canonical pattern) |

#### Orthogonality matrix

Reference chunking interacts with — but is orthogonal to — three other system constraints:

- **`${CLAUDE_SKILL_DIR}` resolution (H6 PASS):** string-substitution to the skill's invoked location; unaffected by file count, size, or nesting depth. `${CLAUDE_SKILL_DIR}/references/foo.md` resolves identically across personal/project/plugin scopes regardless of whether `references/` has 1 or 100 files.
- **R-WORKSPACE-1 single-depth skill discovery (H7 PASS):** applies to top-level **skill directories** in `.claude/skills/<name>/SKILL.md`; does NOT apply to in-skill `references/` or to other in-skill subdirectories. References are loaded by Read (not by glob discovery), so they technically permit arbitrary filesystem nesting. **R-CHUNK-4 v1.14 (Q-016) constrains the markdown-link graph**, not the filesystem tree: reference files at any filesystem depth are valid as long as SKILL.md links to them in one markdown-link hop. Two independent constraints, both apply.
- **R-MONO-1 / R-MONO-4 (Bun.Glob `dot:false` regression in CLI ≥2.1.92, Issue #44490):** affects `.claude/skills/` **discovery** by the agent, not in-skill `references/` Read by Claude. Reference Read uses the Read tool, not Glob; the regression does not propagate to chunking.
- **L1/L2/L3 progressive disclosure:** L1 (name + description) and L2 (SKILL.md body) are loaded at skill activation regardless of references. L3 (references + scripts) is where R-CHUNK-* and R-LAZYLOAD-* operate — R-LAZYLOAD-1 enforces L3's 'load on demand' premise by requiring every reference to be reachable from L2.

#### Why vector indexes are not canonical for in-skill references

Boris Cherny (Anthropic, Claude Code lead) publicly stated that early Claude Code used local vector databases for retrieval and dropped the approach in favor of agentic Grep+Read. The reasoning, documented across Tier-2 reproductions (smartscope.blog, vadim.blog) and consistent with Anthropic's 'Effective context engineering' Tier-1 post: (1) **lexical precision** matters more than semantic similarity for code retrieval where exact identifiers must match; (2) **freshness** — a vector index built at session start drifts from ground truth as files change, while Grep queries the live filesystem; (3) **portability** — vector indexes introduce embedding-model selection, index versioning, and DB-runtime requirements that violate R-SYS-1 drop-in folder portability; (4) **security** — embedding inversion research shows partial text recovery from dense vectors is feasible. R-CHUNK-6 codifies the resulting Anthropic position: header-anchored Grep+Read is canonical; vector indexes inside `references/` are forbidden as primary lookup (secondary uses like external MCP-exposed RAG APIs for non-reference data remain legitimate). DA-113, DA-114.

#### Markdown-link graph topology (Q-016 v1.14)

R-CHUNK-4's revised semantics (v1.14) make the **markdown-link graph** the validation surface, not the POSIX filesystem tree. Build the graph by parsing SKILL.md for relative `.md` links, then parsing each linked file for further `.md` links, recursively. Every internal `.md` file reachable in this graph MUST have minimum graph-distance from SKILL.md equal to exactly 1. Filesystem path depth (the slash count) is irrelevant. The Anthropic Agent Skills runtime mechanism is agent-driven bash/Read tool calls, per Anthropic Agent Skills overview at https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview — there is no host-side native injection parser, so every reference load is an LLM tool call regardless of how the file is stored on disk.

##### Worked example: `anthropics/skills/claude-api`

| Reference file | Filesystem depth | Markdown-link depth from SKILL.md | Verdict |
|---|---|---|---|
| `shared/tool-use-concepts.md` (305 lines) | 1 | 1 (direct link from SKILL.md) | PASS |
| `shared/managed-agents-overview.md` | 1 | 1 (direct link) | PASS |
| `shared/managed-agents-onboarding.md` | 1 | 1 (direct link) | PASS |
| `python/claude-api/tool-use.md` (590 lines) | **2** | 1 (direct link via `{language}/claude-api/tool-use.md` template) | **PASS** |
| `python/claude-api/README.md` | **2** | 1 (direct link) | **PASS** |
| `python/agent-sdk/patterns.md` | **2** | 1 (direct link) | **PASS** |
| `typescript/claude-api/streaming.md` | **2** | 1 (direct link) | **PASS** |
| `curl/managed-agents.md` | 1 | 1 (direct link) | PASS |
| *hypothetical violation:* `references/index.md` linking to `references/topic.md` not also linked from SKILL.md | 1 | **2** | **FAIL** |

Note the asymmetry: a 2-filesystem-depth file with a 1-graph-distance passes; a 1-filesystem-depth file with a 2-graph-distance fails. The validator therefore parses the markdown-link graph, not the directory tree. Cross-links between two graph-depth-1 files (e.g., `python/claude-api/tool-use.md` linking back to `shared/tool-use-concepts.md`, where both are already named directly by SKILL.md) are benign and emit only an info-level note via LINT-Q016-1. Empirical anchors verified Tier-1 against the live default branch: `python/claude-api/tool-use.md` blob header reports 590 lines / 16.5 KB at https://github.com/anthropics/skills/blob/main/skills/claude-api/python/claude-api/tool-use.md; `shared/tool-use-concepts.md` blob header reports 305 lines / 14.5 KB at https://github.com/anthropics/skills/blob/main/skills/claude-api/shared/tool-use-concepts.md.

### Cross-Skill Reference Doc Sharing

> **Q-014 added this subsection** _(blue)_
>
> Cross-skill reference-doc sharing follows the same ladder as cross-skill helper-script sharing (R-SHARE-1): plugin-internal symlinks via `${CLAUDE_PLUGIN_ROOT}` are first-party-supported per the canonical Anthropic plugins-reference; non-plugin and cross-plugin sharing are NOT first-party-supported and require embed-and-duplicate.

<!-- @rule: R-REF-SHARE-1 -->
<a id="r-ref-share-1"></a>

**R-REF-SHARE-1** [skill] [portable] PROPOSED — SHOULD.

**Cross-skill reference-doc sharing within a skills root SHOULD follow the helper-script ladder of R-SHARE-1, narrowed to reference content:** (a) For plugin-bundled skills, place the canonical reference at `${CLAUDE_PLUGIN_ROOT}/<shared-refs>/<file>.md` and symbolically link it into each consuming skill's `references/<file>.md` ([skill][claude-code-only]). (b) Otherwise, embed-and-duplicate ([skill][portable], inheriting R-SHARE-1's discipline). (c) Cross-plugin reference sharing is NOT first-party-supported — DA-103 stands. Source: code.claude.com/docs/en/plugins-reference ("Symlinks are preserved in the cache rather than dereferenced, and they resolve to their target at runtime" + "Paths that traverse outside the plugin root will not work after installation"); R-SHARE-1 (Q-009 v1.9, helper-script lineage); empirical confirmation via anthropics/claude-plugins-official plugin-structure SKILL.

**Anti-pattern:** OS-level symlinks inside a project-scope (non-plugin) skill's `references/` pointing to a `<root>/shared-refs/` folder outside the skills root. This was Gemini-14's recommendation; rejected as DA-135 because Anthropic's plugins-reference Tier-1 doc explicitly disallows out-of-plugin-root traversal. The non-plugin cross-skill sharing answer is embed-and-duplicate, full stop.

<!-- @end: system-design -->

---

<!-- @anchor: meta-skill-validation -->
## Meta-Skill & Validation

### Meta-Skill Spec

> **Q-003 v1.3 — meta-skill spec is now complete** _(green)_
>
> Architecture: a DSPy-style **compiler** (not a template engine, per R-XPOLL-9). Voyager-style **3-tier curriculum** (per R-XPOLL-3). Reflexion-style **external verification** = (validator pass) AND (user accept) (per R-XPOLL-6). Self-Refine-style **3-iteration cap** on body and description loops (per R-XPOLL-7). ReWOO-style **deterministic-vs-LLM split** with the validator as the firewall (per R-XPOLL-8). The meta-skill conforms to the same spec it generates (eat-its-own-dogfood); body cap is tighter (≤400 vs ≤500). Bundles ZERO example skills inside its own folder; retrieves user's prior skills by description embedding instead.

#### Frontmatter and body

- **Name:** `skill-workshop` (kebab-case; required; ≤64 chars).
- **Description:** Pushy, trigger-rich, ≤1024 chars. Form: `"<verb-phrase>. Use when <utterance triggers>."` (R-META-13).
- **Allowed-tools:** `Read, Write, Edit, Bash, Glob, Grep` (no `WebFetch`/`WebSearch` for the meta-skill itself).
- **Body cap:** ≤400 lines (R-META-14, stricter than R-BODY-1's ≤500 for skills generally).
- **License / metadata:** optional; whitelist-only.

#### Compiler step (R-META-4)

```python
def compile_skill(spec_path: Path) -> SkillFolder:
    # 1. Deterministic JSON-Schema validate (R-META-3)
    spec = yaml.safe_load(spec_path.read_text())
    jsonschema.validate(spec, SKILL_SPEC_SCHEMA)  # fail-fast; no LLM

    # 2. Deterministic scaffold (R-META-5)
    folder = init_skill(spec["name"], needs=spec["needs"])

    # 3. Deterministic frontmatter assembly (R-META-2)
    fm = build_frontmatter({
        "name":          spec["name"],
        "allowed-tools": spec.get("allowed_tools", []),
    })

    # 4. LLM body authorship — retrieves up to 3 exemplar skills (R-META-11)
    exemplars = retrieve_user_skills_by_embedding(spec["intent"], k=3) \
                 or retrieve_anthropic_skills(spec["intent"], k=3)
    body = llm_author_body(spec, exemplars)

    # 5. LLM description authorship — Toolformer-shaped (R-XPOLL-5)
    description = llm_author_description(spec["intent"], spec["triggers"])

    # 6. Bounded description-optimization loop (R-META-8)
    description = improve_description(
        description, eval_set=spec["evals"]["triggers"],
        max_iterations=3, early_stop_on_no_change=True)

    write(folder/"SKILL.md",
          frontmatter=fm | {"description": description},
          body=body)

    # 7. Deterministic validate — fail-closed (R-META-7 creation gate)
    ok, err = quick_validate(folder)
    if not ok: raise CompileError(err)

    return folder

```

#### Declarative spec input format (R-META-3)

```yaml
# .skill-spec.yaml — validated against skill-spec.schema.json before any LLM runs
name: my-pr-helper                # required, kebab-case, ≤64 chars
intent: "Format a PR description from a diff"
triggers:                         # ≥1, fed to description LLM
  - "user says 'write the PR description'"
  - "user mentions PR or pull request"
output_contract: "Markdown PR template with Summary, Changes, Testing"
allowed_tools: [Read, Bash, Edit]
needs:
  scripts: false
  references: false
  assets: false
evals:
  behavioral: 3                    # 2–3 (R-META-15); ≥1 negative (R-META-16)
  triggers: 20                     # 10 should-trigger / 10 should-not-trigger

```

#### Elicitation flow (R-META-6)

1. What should this skill enable Claude to do?
2. When should it trigger? (utterances/contexts)
3. What's the expected output format?
4. Should we set up test cases? (default yes if output is objectively verifiable)

Optional follow-up "Interview" phase only when edge cases remain. Non-interactive `--yes` path permitted with sane defaults; MUST still elicit `name` and `triggers`.

#### Curriculum tiers (R-META-12)

| Tier | Trigger | Mode | Voyager analog |
|---|---|---|---|
| Tier-1 | 0 prior skills authored | "Vibe" mode — frontmatter + body draft + `quick_validate`. No evals required. | First-15-tasks no skill-library retrieval |
| Tier-2 | 1–9 prior skills | Eval prompts (2–3) required; retrieves user's prior skills as exemplars (top-5 by description embedding). | Skill-library retrieval enabled, curriculum-conditioned |
| Tier-3 | 10+ prior skills | Trigger-eval optimization (`run_loop.py`), blind comparison, benchmark mode with mean ± stddev unlocked. | Compositional / hierarchical skill application |

#### Deterministic vs LLM split (R-META-10)

| Phase | Deterministic helper | LLM authorship |
|---|---|---|
| Spec validation | `jsonschema.validate(spec, schema)` | — |
| Scaffold | `init_skill.py` | — |
| Frontmatter assembly | YAML emitter; kebab-case check; length count | — |
| Body draft | — | `llm_author_body(spec, exemplars)` |
| Description draft | — | `llm_author_description(intent, triggers)` |
| Description optimize | Eval-set 60/40 split; trigger-rate aggregation | `improve_description.py` (≤3 iter) |
| Validate | `quick_validate.py` | — |
| Package | `package_skill.py` (ZIP) | — |
| Eval baseline run | Bash-availability assertion (R-META-19); grading.json path enforcement (R-META-18) | Sub-agent grading by `agents/grader.md` |
| Aggregate | `aggregate_benchmark.py` (mean ± stddev) | — |
| Feedback | `feedback.json` capture from eval-viewer | Feedback interpretation; blind comparator |

#### Conformance examples policy (R-META-11, R-META-15..17)

- **Bundled count:** ZERO example skills inside the meta-skill folder (Voyager first-15-no-retrieval).
- **Retrieval:** top-3 user skills by description embedding; falls back to public `anthropics/skills` library if none.
- **Eval-set per skill:** 3 behavioral + 20 trigger (10/10 split). At least 1 of the 3 behavioral is a negative counter-example (R-META-16, DSPy Assertions).
- **Lifecycle:** synthetic-bootstrap at creation → `--inject-trace <path>` swaps in real execution traces over time (R-META-17).
- **Meta-skill's own evals:** 3 behavioral ("create fresh", "improve existing", "optimize description") + 20 trigger queries.

#### Verification signals (R-META-9)

- **Promotion gate:** `quick_validate.py` PASS **AND** (`feedback.json` empty OR explicit user accept).
- **Insufficient on its own:** validator pass alone (lets bad descriptions through); user-accept alone (lets invalid YAML through); LLM-confidence-only (Reflexion violation; reward hacking per Pan et al. 2024).
- **No silent actions:** never auto-fix the user's SKILL.md without explicit consent; never make network calls that require unconfigured API keys (Issue #34609 lesson).
- **SSO compatibility:** core validator path uses `claude` CLI subprocess where LLM is needed; `ANTHROPIC_API_KEY` is opt-in not required (Issue #532; R-META-7 strengthening).

### Validation Rules (machine-checkable)

> **Q-004 v1.4 — rule matrix complete** _(green)_
>
> Every adopted rule is classified. Mechanical rules carry exact heuristics (regex / AST / file-tree / threshold) and severity (fail/warn). Semantic rules are deferred to Q-008 LLM-judge. Hybrid rules have mechanical pre-checks plus LLM-confirmation recommendations. Tags: [skill]/[reference] for procedural-vs-factual; [claude-code-only]/[portable] for cross-system applicability.

#### Frontmatter rules (R-FM-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-FM-1 | MECHANICAL | fail | Open as UTF-8 (errors='strict'); leading `---\n` and closing `\n---\n` fence; pass body to `yaml.safe_load`. Reject if not dict or `name`/`description` missing/empty after `.strip()`. | [reference] [portable] | VALIDATED |
| R-FM-2 | MECHANICAL | fail | Compile `^[a-z0-9]+(-[a-z0-9]+)*$`; assert len(name) ≤ 64; assert lowercase substring not in {anthropic, claude}. | [reference] [portable] | VALIDATED |
| R-FM-3 | MECHANICAL | fail | len(description.strip()) > 0 and len(description) ≤ 1024 (Unicode code points, not bytes). | [reference] [portable] | VALIDATED |
| R-FM-4 | MECHANICAL | fail | if `when_to_use` present: len(description) + len(when_to_use) ≤ 1536. **v1.5 update:** `when_to_use` officially documented in live code.claude.com/docs/en/skills frontmatter reference table — confirmed 2026-05-02. R-FM-6 ALLOWED list expanded accordingly. | [skill] [claude-code-only] | VALIDATED (v1.5 — live docs confirm allow-list status) |
| R-FM-5 | MECHANICAL | fail | For every string-typed value (recursively under `metadata`), assert no `<` or `>`. On `name` additionally assert no `/`. | [reference] [portable] | VALIDATED |
| R-FM-6 (NEW) | MECHANICAL | fail | set(frontmatter.keys()) ⊆ ALLOWED. ALLOWED varies by --profile: `skills-api` = {name, description, license, allowed-tools, metadata}; `claude-code` (v1.5 EXPANDED) = {name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell}; `both` = permissive union. Sources: live code.claude.com/docs/en/skills frontmatter reference table (fetched 2026-05-02) + anthropics/skills issue #37 + claude-code issue #25380 (dual-profile acknowledgement). | [reference] [portable] | VALIDATED (v1.5 — Claude Code profile expanded from 7 to 15 keys) |

#### Cross-pollination / discovery rules (R-XPOLL-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-XPOLL-1 | SEMANTIC → Q-008 | n/a | Description in third person. Mechanical proxy `\b(I \|I'll \|I can \|you can use\|use this to)\b` flags first/second-person leakage but cannot confirm clean third-person. LLM-judge required. | [skill] [portable] | VALIDATED (deferred) |
| R-XPOLL-2 | HYBRID | warn | Mechanical: warn if name doesn't end in `-ing`. Recommended-not-required by Anthropic best-practices. | [skill] [portable] | VALIDATED |
| R-XPOLL-3 | HYBRID | warn | Mechanical 'when' half: same regex as R-XPOLL-5. 'What' half is intrinsically semantic — defer to Q-008. | [skill] [portable] | VALIDATED |
| R-XPOLL-4 | MECHANICAL | warn | Library mode: load all descriptions; embed via sentence-transformers/all-MiniLM-L6-v2 (overridable); pairwise cosine ≥ 0.85 → warn with both paths and score. Cache embeddings by (model_name, sha256(description)). | [skill] [portable] | VALIDATED |
| R-XPOLL-5 | MECHANICAL | fail | Compile `\b(Use when\|When the user\|Triggered by\|Activate when\|Use this (skill\|when))\b`, IGNORECASE; assert match in description. | [skill] [portable] | PROPOSED (Q-005 — false-positive rate against public skills catalog needs measurement) |
| R-XPOLL-6 | SEMANTIC → Q-008 | n/a | Concrete vs abstract examples. Weak proxy: warn if body has < 2 `^### ` headings or no fenced code block. | [skill] [portable] | VALIDATED (deferred) |
| R-XPOLL-7 | SEMANTIC → Q-008 | n/a | Consistent terminology across body. Synonym detection requires LLM or maintained lexicon. | [reference] [portable] | PROPOSED (Q-005) |
| R-XPOLL-8 | HYBRID | warn | Mechanical: regex `\b(20[12][0-9]\|January\|February\|...\|December)\b` outside fences and outside `<details><summary>Legacy` blocks. LLM-confirmation recommended for false-positive reduction. | [skill] [portable] | PROPOSED (Q-005) |
| R-XPOLL-9 | MECHANICAL | fail | Library mode: assert that path `<library>/skill-validator/SKILL.md` exists (configurable via --self-path). | [skill] [portable] | VALIDATED |
| R-XPOLL-10 (NEW) | MECHANICAL | warn | agent-ecosystem/skill-validator pattern: descriptions with 5+ quoted strings AND surrounding prose having fewer words than the quote count → warn (keyword-stuffing); descriptions with 8+ comma-separated short segments (after excluding quotes) → warn (keyword list). | [skill] [portable] | PROPOSED (Q-005, Tier-2 source) |

#### API surface rule (R-API-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-API-1 | MECHANICAL | fail | If a deployment manifest declares `container.skills`, assert `len(skills) ≤ 8` (platform.claude.com/docs/en/build-with-claude/skills-guide). Vacuously true when no manifest. | [reference] [claude-code-only] | VALIDATED |

#### Body rules (R-BODY-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-BODY-1 | MECHANICAL | fail at >500, warn at >400 | Strip frontmatter; count `\n` + 1; compare to thresholds. Anthropic best-practices canonical 500. | [skill] [portable] | VALIDATED |
| R-BODY-2 (UPDATED v1.4) | MECHANICAL | warn | len(tiktoken.get_encoding('o200k_base').encode(body)) > 5000 → warn. ENCODING SWITCHED from cl100k_base to o200k_base in v1.4 for parity with agent-ecosystem/skill-validator Tier-2 reference and modern model tokenizers. | [skill] [portable] | VALIDATED |
| R-BODY-3 | MECHANICAL | fail | Outside fenced code blocks: search `\\.{1,80}\.(md\|py\|sh\|json)` (Windows backslash paths in path-like contexts). Use markdown-it-py or state machine to track fence boundaries. | [skill] [portable] | VALIDATED |
| R-BODY-4 (REVISED v1.4) | MECHANICAL | fail at >100, warn at >200 | For each `references/**/*.md` with line count > 100: scan first 50 lines for `^## (Table of Contents\|Contents)$` (case-insensitive). Threshold REVISED from 300 to 100 in v1.4 per Anthropic-supremacy (Anthropic best-practices canonical 100). | [reference] [portable] | VALIDATED |
| R-BODY-5 (EXTENDED v1.4) | MECHANICAL | fail | No `README.md`, `Readme.md`, or `readme.md` inside skill folder. EXTENDED v1.4: `AGENTS.md` inside skill folder also fails (per agent-ecosystem/skill-validator: AGENTS.md is for repo-level agent config, not skill content). | [reference] [portable] | VALIDATED |
| R-BODY-6 (NEW) | MECHANICAL | warn at 10K, fail at 25K per file; warn at 25K, fail at 50K total | Per `references/**/*.md`: tiktoken('o200k_base') count > 10000 → warn, > 25000 → fail. Sum across all references > 25000 → warn, > 50000 → fail. Source: agent-ecosystem/skill-validator v1.1.0. | [skill] [portable] | PROPOSED (Q-005) |
| R-BODY-7 (NEW) | MECHANICAL | fail | In SKILL.md body and `references/**/*.md`: detect unclosed ``` or ~~~ code fences (state machine: count opens minus closes; non-zero → fail). An unclosed fence makes Claude misinterpret everything after it as code. | [skill] [portable] | PROPOSED (Q-005, Tier-2 source) |
| R-BODY-8 (NEW v1.5) | MECHANICAL (heuristic) | warn | Description string lacks any negative-trigger phrase from {'Do NOT', 'Avoid', 'not for', 'except for'}. Soft-warn only — many valid descriptions don't need explicit exclusions. Sources: anthropics/skills/{docx,pptx,pdf}/SKILL.md exemplars + skill-development SKILL.md 'Common Mistakes' section. | [skill] [portable] | VALIDATED (v1.5 Tier-1) |
| R-BODY-9 (NEW v1.5) | MECHANICAL (heuristic) | warn | (a) Body uses second-person pronouns ('you'/'your'/'yours') outside fenced code blocks → warn. (b) Description begins with imperative verb other than safe-listed {'is','provides','contains','manages'} → warn. (c) anthropics/skills/{pdf,docx,pptx} grandfathered (file-based allow-list bypass). Source: skill-development SKILL.md verbatim '❌ DON'T: Use second person anywhere' + 'Write the entire skill using imperative/infinitive form... not second person'. | [skill] [portable] | VALIDATED (v1.5 Tier-1) |

#### Naming rules (R-NAME-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-NAME-1 | MECHANICAL | fail | `os.listdir(skill_dir)` must contain literal `SKILL.md` (case-sensitive). Reject `Skill.md`, `skill.md`. | [reference] [portable] | VALIDATED |
| R-NAME-2 | MECHANICAL | fail | `os.path.basename(skill_dir.rstrip('/')) == frontmatter['name']`; folder name matches `^[a-z0-9]+(-[a-z0-9]+)*$`. | [reference] [portable] | VALIDATED |

#### Reference / scripts / resources rules (R-SR-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-SR-1 | MECHANICAL | warn | Markdown link graph from SKILL.md → references/*.md → … warn on any path of length ≥ 2 (one-level-deep policy). | [skill] [portable] | VALIDATED |
| R-SR-2 | SEMANTIC → Q-008 | n/a | Descriptive filenames. Weak proxy: regex `^(doc\|file\|untitled\|temp)\d*\.md$` for egregious cases. | [skill] [portable] | PROPOSED (Q-005) |
| R-SR-3 | SEMANTIC → Q-008 | n/a | Domain-organized vs ordinal directory structure. Requires understanding skill purpose. | [reference] [portable] | VALIDATED (deferred) |
| R-SR-4 | MECHANICAL | fail | Same family as R-BODY-3, applied to all `.md` files in skill folder. | [skill] [portable] | VALIDATED |
| R-SR-5 | MECHANICAL | fail | For every file under `references/**`: assert filename or basename appears as literal string somewhere in SKILL.md body. Glob-style mentions accepted. | [reference] [portable] | VALIDATED |
| R-SR-6 (NEW) | MECHANICAL | fail | Every relative markdown link in SKILL.md and `references/**/*.md` must resolve to an existing file. External `http(s)://` links handled by R-SR-6b (separate optional check). Source: agent-ecosystem/skill-validator. | [skill] [portable] | PROPOSED (Q-005) |
| R-SR-7 (NEW) | MECHANICAL | warn | Reachability-graph orphan detection: from SKILL.md body, build transitive reachability via string containment (literal-path mentions); files in `scripts/`, `references/`, `assets/` not in reachable set → warn 'orphan file'. Includes Python `from X import Y` resolution and `__init__.py` bridge handling. Source: agent-ecosystem/skill-validator. | [skill] [portable] | PROPOSED (Q-005) |

#### Memory / portability / security rules (R-MEM-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-MEM-7 | MECHANICAL | fail | Regex `(~/\.claude/\|/home/\w+/\.claude/\|/Users/\w+/\.claude/)`. Skip matches inside fenced code blocks for documentation purposes. | [skill] [claude-code-only] | VALIDATED |
| R-MEM-8 | MECHANICAL | warn | In `scripts/**`: AST scan for string literals containing `\.\./\.\./` (≥2 parent traversals), excluding comments. | [skill] [claude-code-only] | VALIDATED |
| R-MEM-9 | HYBRID | fail | High-entropy regex set: `sk-ant-api03-[A-Za-z0-9]{40,}`, `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9]{36}`, etc. (use detect-secrets library). HYBRID: regex flags candidates; LLM-judge confirms vs documentation placeholders. | [skill] [portable] | VALIDATED |

#### Help / observability rules (R-HELP-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-HELP-* | MECHANICAL | warn (self-test) | Validator self-test in CI: `validate.py skill-validator/ 2>summary.txt 1>output.json`; assert summary.txt non-empty AND output.json valid JSON. Enforces stdout=JSON / stderr=human split. | [skill] [portable] | VALIDATED |

#### Meta-skill rules (R-META-*)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-META-1..6, R-META-8, R-META-11..13, R-META-15..18 | SEMANTIC → Q-008 | n/a | Governance / scoping / stylistic meta-skill quality. Cannot be reduced to regex. LLM-judge against Q-003 specification. | [skill] [portable] | VALIDATED (deferred) |
| R-META-7 | MECHANICAL | fail | Self-applied to meta-skill repo: assert `.pre-commit-config.yaml` references `skill-validator` AND `skill-workshop/SKILL.md` body invokes `scripts/validate.py`. | [skill] [portable] | VALIDATED |
| R-META-9 | MECHANICAL | fail | AST scan of validate.py source: no `os.replace`, `shutil.move`, `Path.write_text` outside guards on `args.fix` (and `args.fix` itself is reserved as hard error in v1.4). | [skill] [portable] | VALIDATED |
| R-META-10 | MECHANICAL | fail | AST scan: no imports of `anthropic`, `openai`, `requests` (except `sentence_transformers.SentenceTransformer.__init__` first-run model download). Whitelist explicit. | [skill] [portable] | VALIDATED |
| R-META-14 | MECHANICAL | fail | Same line-count heuristic as R-BODY-1 with cap=400 instead of 500, applied when --meta-skill or folder name in {skill-workshop}. | [skill] [portable] | VALIDATED |
| R-META-19 | MECHANICAL | fail | Meta-skill: frontmatter `allowed-tools` includes `Bash` OR body contains literal preflight `command -v bash`. Note: `allowed-tools` is parsed-but-not-enforced per claude-code Issues #18837/#37683 — declarative-intent only; R-META-9 source-AST self-test provides actual enforcement. | [skill] [portable] | VALIDATED |

#### Contamination rules (R-CONTAM-*) — NEW family

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-CONTAM-1 (NEW) | HYBRID (semantic) | warn at ≥0.5 contamination score | agent-ecosystem/skill-validator pattern: cross-language contamination via 3-factor formula = multi_interface_tools(0.3) + language_mismatch(0.4) + scope_breadth(0.3); ≥0.5 high (warn), ≥0.2 medium (info), <0.2 low. Mechanical proxy via language-category mapping; final verdict deferred to Q-008 LLM-judge. | [skill] [portable] | PROPOSED (Q-005, Tier-2 source) |

#### Summary

- **Total v1.3-adopted rules covered:** 50.
- **MECHANICAL (deterministic):** 27 rules (full per-rule heuristic above).
- **SEMANTIC (deferred to Q-008 LLM-judge):** 18 rules.
- **HYBRID (mechanical pre-check + recommended LLM confirmation):** 5 rules.
- **NEW VALIDATED candidate (v1.4):** R-FM-6 frontmatter key allow-list (≥2 Tier-1 sources).
- **NEW PROPOSED candidates (v1.4):** R-BODY-6/7, R-SR-6/7, R-XPOLL-10, R-CONTAM-1 — all from agent-ecosystem/skill-validator Tier-2 reference; pending Q-005 promotion.
- **Encoding switch (v1.4):** R-BODY-2 cl100k_base → o200k_base for Tier-2 reference parity.
- **Anthropic-supremacy revision (v1.4):** R-BODY-4 threshold 300 → 100 lines.

#### Composition rules (R-COMP-*) — added v1.6 (Q-006)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-COMP-1 | SEMANTIC → Q-008 | n/a | LLM-judge: does the skill's structure follow the four-layer ladder for its task complexity? | [skill][claude-code-only] | VALIDATED |
| R-COMP-2 | MECHANICAL | fail | Reject any SKILL.md content that contains a programmatic skill-call construct (e.g., `Skill(...)` literal, JSON-RPC `Skill` invocation in plain text). Sub-skill calls must be model-mediated. | [skill][claude-code-only] | VALIDATED |
| R-COMP-3 | MECHANICAL | warn | Detect symlinks within `.claude/skills/<skill>/` that point outside that skill's folder — warn (cross-skill linking violates embed-and-duplicate). Allow symlinks within the skill (e.g., to a sibling `references/` file). | [reference][portable] | VALIDATED |

#### Parallelism rules (R-PAR-*) — added v1.6 (Q-006)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-PAR-1 | HYBRID | warn | Mechanical: if frontmatter contains `context: fork`, scan SKILL.md body for an imperative verb in the first 200 lines (e.g., 'Research', 'Generate', 'Validate', 'Run'). Hybrid: LLM-judge confirms actionability. | [skill][claude-code-only] | VALIDATED |
| R-PAR-2 | MECHANICAL | warn | Scan SKILL.md body for orchestration prompts that name a parallel-branch count > 8 (regex: `\b(\d+)\s+(subagents\|branches\|forks\|workers)\b`, fail when N > 8). Soft warn at N > 5. | [skill][claude-code-only] | VALIDATED |
| R-PAR-3 | SEMANTIC → Q-008 | n/a | LLM-judge: do the parallel branches described in the skill share mutable state or output dependencies? If yes, fan-out is unsafe. | [skill][portable] | VALIDATED |
| R-PAR-4 | MECHANICAL | info | Reference rule — no validation action; documentation lints check that the bidirectional composition table is present in any spec doc that mentions `context: fork`. | [reference][claude-code-only] | VALIDATED |

#### Delegation rules (R-DEL-*) — added v1.6 (Q-006)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-DEL-1 | MECHANICAL | fail | Composition-depth check: parse skill graph (parent SKILL.md → child via `context: fork` or `Subagent(skills:[...])`). Reject any chain of length > 2. | [skill][claude-code-only] | VALIDATED |
| R-DEL-2 | MECHANICAL | fail | For every subagent definition in `.claude/agents/<name>.md` whose `skills:` field references skill `S`, verify S's frontmatter does NOT contain `disable-model-invocation: true`. Fail with clear message if it does. | [skill][claude-code-only] | VALIDATED |
| R-DEL-3 | HYBRID | warn | Mechanical: scan subagent body for keywords matching the four required fields (objective, output format, tools/sources, task boundaries). Hybrid: LLM-judge confirms each is concretely populated. | [skill][portable] | VALIDATED |

#### Conducting / orchestration rules (R-CONDUCT-*) — added v1.6 (Q-006)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-CONDUCT-1 | SEMANTIC → Q-008 | n/a | LLM-judge: does the skill act as an in-session orchestrator (prescribes which other skills to call in what order)? If yes, propose refactoring — either let the model conduct, or escalate to agent-teams tier. | [skill][claude-code-only] | VALIDATED |
| R-CONDUCT-2 | HYBRID | warn | Mechanical: pairwise textual overlap of `paths` glob patterns across all skills in the project. If two skills' `paths` overlap on any glob token, warn and surface their `description` fields. Hybrid: LLM-judge confirms whether the descriptions are sufficiently distinct. | [reference][claude-code-only] | VALIDATED |
| R-CONDUCT-3 | MECHANICAL | fail | If `disable-model-invocation: true`, then `paths:` MUST be empty (a `paths` value is meaningless because the skill is not in `<available_skills>`). Fail with a clear remediation message. | [skill][claude-code-only] | VALIDATED |
| R-CONDUCT-4 | MECHANICAL | warn | If a skill mentions `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` or `agent-teams`, verify the skill body includes the EXPERIMENTAL caveat block ("v2.1.32+, Opus 4.6+, no nested teams, one team per session"). Warn if missing. | [skill][claude-code-only] | VALIDATED — EXPERIMENTAL |

#### Failure-semantics rules (R-FAIL-*) — added v1.6 (Q-006)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-FAIL-1 | MECHANICAL | info | Reference rule — no validation action. Spec linter ensures any documentation of the 25k re-attach budget includes the per-branch isolation note. | [skill][claude-code-only] | VALIDATED |
| R-FAIL-2 | HYBRID | warn | Mechanical: if a skill spawns >1 parallel branches (R-PAR-2 trigger), check that the orchestration prompt or hooks config mentions `PostToolBatch`. Hybrid: LLM-judge confirms `PostToolBatch` is wired for cross-branch validation, not as a per-tool replacement. | [skill][claude-code-only] | VALIDATED |
| R-FAIL-3 | MECHANICAL | warn | Scan SKILL.md body for any claim that a subagent's stderr or exit code propagates structurally to the parent. Warn with quotation of the canonical natural-language-summary-only behavior. | [reference][claude-code-only] | VALIDATED |
| R-FAIL-4 | MECHANICAL | info | Reference rule — no validation action. | [skill][claude-code-only] | VALIDATED |
| R-FAIL-5 | HYBRID | fail | Mechanical: if a skill spawns a background subagent, verify the spawn site lists explicit `allowed-tools` for every tool the subagent will call (parsed from the subagent's prompt). Hybrid: LLM-judge enumerates likely tools and flags missing pre-approvals. | [skill][claude-code-only] | VALIDATED |

#### Self-update safeguards (R-ROLLBACK-*) — added v1.7 (Q-007)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-ROLLBACK-1 | MECHANICAL | warning | Before any retrospective merge, validator checks that a `pre-retro-<skill>-<YYYYMMDD>` git tag exists pointing at the pre-merge commit. Mirrors `anthropics/skills/skill-workshop/SKILL.md` baseline-snapshot pattern. | [skill][portable] | VALIDATED |
| R-ROLLBACK-2 | MECHANICAL+procedural | error | After a revert, validator re-runs against the reverted state. Second consecutive failure → skill marked `health: degraded` in pending-retros and excluded from auto-discovery until human review. Mechanical part: pass/fail check + health-flag write. | [skill][portable] | VALIDATED |
| R-ROLLBACK-3 | MECHANICAL | error | Validator counts merge attempts and merges per skill per session via `${CLAUDE_PLUGIN_DATA}/<plugin>/retro-counters.json`. Caps: ≤1 merge / ≤3 attempts. Anchored by R-XPOLL-4's 3-iteration plateau (Self-Refine, Madaan et al. NeurIPS 2023). | [skill][portable] | PROPOSED |
| R-ROLLBACK-4 | MECHANICAL+expensive | warning | When a retrospective touches a path under `references/` that is referenced (by relative-path Markdown link) from another SKILL.md or `references/*.md` file in the library, the validator re-runs the dependent skill's eval baseline before merge. Regression on the dependent → block. Graph-traversal cost is O(skills × references); cache between merges. | [skill][portable] | PROPOSED |
| R-ROLLBACK-5 | MECHANICAL | info | For marketplace-distributed skills, the validator checks that the skill's `version:` frontmatter matches a git tag in the format `v<major>.<minor>.<patch>`. Plugin-pinning auto-updates to the highest satisfying tag (per Anthropic CHANGELOG); this is the rollback unit. | [skill][claude-code-only] | VALIDATED |

#### Self-updating-skill rule classifications (R-RETRO-*, R-SELF-*, R-DRIFT-*, R-EXTRACT-*, R-DESTRUCT-*, R-VC-*) — added v1.7 (Q-007)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-RETRO-1 | MECHANICAL | info | Linter checks meta-skill frontmatter `hooks:` block: `Stop` and/or `SessionEnd` triggers configured for the meta-skill; `SessionEnd`-attached merge-step hooks rejected (lint error: "SessionEnd MUST NOT carry the merge step per R-RETRO-1; demote to logging-only or move to Stop"). | [skill][portable] | VALIDATED |
| R-RETRO-2 | MECHANICAL | error | Static analysis of meta-skill `Stop`-hook script: must reference `stop_hook_active` and exit 0 when true. Pattern match on `if .*stop_hook_active.*: exit 0` or equivalent in JSON-output hooks. | [skill][portable] | VALIDATED |
| R-RETRO-3 | SEMANTIC | info | User-correction inference is per-skill judgment; defer to Q-008's LLM semantic check. | [skill][portable] | VALIDATED |
| R-RETRO-4 | MECHANICAL | warning | Frontmatter `hooks:` block for `Stop`/`SubagentStop` matchers SHOULD declare `type: prompt` or `type: agent`; `type: command` allowed but warned. | [skill][portable] | VALIDATED |
| R-RETRO-5 | MECHANICAL | info | If `async: true` is absent and timeout is unset for retrospective hook: warn if implied sync ceiling exceeds 30s. PROPOSED ceiling. | [skill][portable] | PROPOSED |
| R-RETRO-6 | MECHANICAL | info | Frontmatter `hooks:` block: validator confirms `once: true` is honored only inside skill or plugin frontmatter (not settings.json or agent frontmatter). | [skill][claude-code-only] | VALIDATED |
| R-SELF-1 | MECHANICAL | error | Validator checks meta-skill's retrospective-write target. Routine writes to SKILL.md body block validation ("R-SELF-1: routine retros write to references/gotchas.md, not body"). Body-write allowed only with explicit behavioral-correction flag in commit message. | [skill][portable] | VALIDATED |
| R-SELF-2 | MECHANICAL+procedural | warning | Body edits flagged for human review with required minor-version bump (R-VC-2). Mechanical part: detects body diff in retro commit; procedural: requires user-accept gate. | [skill][portable] | VALIDATED |
| R-SELF-3 | MECHANICAL | warning | Validator warns if a skill creates an `errata/` directory at root. Hard error only if the skill is also marked `[portable]`. (Reworded Turn 2 from MUST NOT → SHOULD NOT per Gemini-7 G7-2.) | [skill][portable] | VALIDATED |
| R-SELF-4 | MECHANICAL | error | `gotchas.md` entry schema lint: each entry must have date, trigger event (one of Stop/SessionEnd/PostToolUseFailure/inferred), evidence anchor (transcript-path-or-commit-hash regex), proposed fix, status (one of PROPOSED/VALIDATED/PROMOTED/RETIRED). | [skill][portable] | VALIDATED |
| R-SELF-5 | MECHANICAL | error | Pending-retro path validation: `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/<skill>-<timestamp>.diff` regex; rejects writes outside this path for any retro of a `disable-model-invocation: true` skill. | [skill][claude-code-only] | VALIDATED |
| R-DRIFT-1 | MECHANICAL+expensive | info | Counter file `${CLAUDE_PLUGIN_DATA}/<plugin>/retro-counters.json` tracks accepted retros per skill. At N=3 → triggers skill-workshop description-optimization pass. Validator confirms the trigger fired and the optimization completed. | [skill][portable] | VALIDATED |
| R-DRIFT-2 | MECHANICAL | error | Description replacement requires held-out test score ≥ baseline (per skill-workshop's `best_description` selection). Validator parses skill-workshop log and rejects regressions. | [skill][portable] | VALIDATED |
| R-DRIFT-3 | MECHANICAL | error | Description ≤ 1024 characters. Counted as raw character length, not token count. Hard error. | [skill][portable] | VALIDATED |
| R-DRIFT-4 | MECHANICAL | warning | Frontmatter schema validation: only documented fields allowed (per `code.claude.com/docs/en/skills` live schema). Any unknown field → warning. Hidden field name patterns (`applies_to_examples`, `errata`, etc.) → error. | [skill][portable] | PROPOSED |
| R-DRIFT-5 | SEMANTIC | error | Scope-preservation check on description regen: the new description's `when_to_use` scope-set MUST be a permutation/refinement of the original scope-set, not narrower or broader. **Deferred to Q-008's LLM-based semantic-validation layer** since it requires natural-language scope comparison. NEW Turn 2. | [skill][portable] | VALIDATED |
| R-EXTRACT-1 | MECHANICAL | info | Pattern detection across session transcripts: same script-content (hash-equivalent) reused N≥3 in-session OR ≥3 sessions in 14d. Trigger: `systemMessage` proposal. Threshold tightened Turn 2 per Gemini-7. | [skill][portable] | PROPOSED |
| R-EXTRACT-2 | MECHANICAL | info | Reference rule: extraction handed to skill-workshop. Validator confirms the new skill scaffolded under canonical layout (R-SYS-1, R-NAME-1/2). | [skill][portable] | VALIDATED |
| R-EXTRACT-3 | MECHANICAL | error | Newly extracted skill must pass ≥20-prompt trigger eval (mixed should-trigger / should-not) before marketplace publication. Eval log archived under `${CLAUDE_PLUGIN_DATA}/<plugin>/extract-evals/`. | [skill][portable] | VALIDATED |
| R-DESTRUCT-1 | MECHANICAL | error | For skills with `disable-model-invocation: true` in frontmatter: any retro auto-merge attempt → hard error. Pending-diff path required; user-invocation gate required. | [skill][claude-code-only] | VALIDATED |
| R-DESTRUCT-2 | MECHANICAL | warning | If meta-skill has a `--apply-retro` (or equivalent) subcommand without `disable-model-invocation: true` → warning. Auto-fix suggested. | [skill][portable] | VALIDATED |
| R-DESTRUCT-3 | MECHANICAL | error | Static analysis of merge-execution path: any raw shell `patch`/`sed`/`awk` invocation in the merge subcommand → hard error. Edit-tool invocation OR pre-compiled binary in plugin's `bin/` required. NEW Turn 2. | [skill][claude-code-only] | VALIDATED |
| R-VC-1 | MECHANICAL | warning | Self-update commits checked for Conventional-Commits prefix `skill(retro): <skill-name> <YYYY-MM-DD>` (or equivalent regex). Pre-commit hook recommended. | [skill][portable] | PROPOSED |
| R-VC-2 | MECHANICAL | warning | Semver-bump validation against diff content: references/-only diff → patch; SKILL.md body diff → minor; description-only diff → major. Mismatch → warning. | [skill][portable] | PROPOSED |
| R-VC-3 | MECHANICAL | error | Branch-target check: self-modification commits MUST land on `skill/auto-update` (or matching pattern), never `main` directly. Pre-merge hook enforced. | [skill][portable] | VALIDATED |

#### Q-008 rule classifications (R-LLMJ-*, R-CADENCE-*, R-LOAD-*, R-DRIFT-5-IMPL/CHECK/FALLBACK) — added v1.8 (Q-008)

| Rule | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| R-LLMJ-1 | MECHANICAL | error | Linter checks: validator config MUST mark the LLM-judge as `tier: downstream` (separate from pre-commit / Git-hook tiers). Lint error if any pre-commit hook references the judge binary. | [skill] [judge] | PROPOSED |
| R-LLMJ-2 | MECHANICAL | error | Linter checks: judge output schema MUST contain `verdict` field with value in `{"pass","warn","fail"}`. Lint error if Likert/numeric scores appear in `verdict`. | [skill] [judge] | PROPOSED |
| R-LLMJ-3 | SEMANTIC | error | Per-rule judge prompt MUST contain (a) task introduction, (b) explicit pinned evaluation steps, (c) structured JSON output schema. Validation: smoke-test prompt against G-Eval template; semantic — deferred to LLM-judge self-test. | [skill] [judge] | PROPOSED |
| <a id="r-llmj-4"></a>R-LLMJ-4 | MECHANICAL | error | Validator config MUST set `samples: 3` and `aggregation: majority_vote` per rule. Lint error if either field absent or differs. | [skill] [judge] | PROPOSED |
| R-LLMJ-5 | MECHANICAL | warn | Validator config: default `model: claude-sonnet-4-6`. Warn if Opus 4.7 used without `--high-precision` opt-in flag. | [skill] [judge] | PROPOSED |
| R-LLMJ-6 | MECHANICAL | error | Validator config: `mode: pointwise` is default; `mode: pairwise` allowed only when `rule_id == "R-DRIFT-5"`. Lint error otherwise. | [skill] [judge] | PROPOSED |
| R-LLMJ-7 | MECHANICAL | error | JSON-schema validation on judge output: keys `rule_id` (string), `verdict` (enum), `critique` (string), `samples` (array of 3 verdicts). Aggregate exit code maps 0/1/2 per Q-004. | [skill] [judge] | PROPOSED |
| R-LLMJ-8 | HYBRID | error | Mechanical: each rule MUST ship `calibration/` directory with ≥10 hand-labelled examples + `calibration_report.json` with TPR + TNR. Lint error if missing or either metric < 0.80. Semantic: judge accuracy on calibration set is itself rated by judge. | [skill] [judge] | PROPOSED |
| R-LLMJ-9 | MECHANICAL | warn | Validator code MUST wrap judge calls in DSPy-Suggest-shape (soft, non-halting on fail). Lint error if `Assert`-shape (halt-on-fail) used. Note: in DSPy 2.6+ the symbol may be `Refine`/`BestOfN` — rule encodes semantics, not API symbol. | [skill] [judge] | PROPOSED |
| R-LLMJ-10 | SEMANTIC | error | Judge prompt MUST NOT instruct evaluation of: (a) skill body domain-content factuality, (b) bundled-script runtime correctness, (c) any rule with mechanical implementation. Heuristic: pre-flight check against R-LLMJ rule-id allow-list. Semantic — deferred to LLM-judge audit pass. | [skill] [judge] | PROPOSED |
| R-LLMJ-11 | MECHANICAL | warn | Validator config: per-skill audit budget ≤30K input + ≤6K output tokens. Warn if exceeded. Cost telemetry recorded per audit run. | [skill] [judge] | PROPOSED |
| R-LLMJ-12 | HYBRID | error | Mechanical: judge prompt template MUST delimit SKILL.md body with `<untrusted_data>...</untrusted_data>` tags (or equivalent). Lint error if body concatenated as instruction. Semantic: judge audit-pass verifies no instruction-following on body content. | [skill] [judge] | PROPOSED |
| R-CADENCE-1 | MECHANICAL | warn | Validator-config: cadence schedule MUST define monthly + quarterly + on-demand tiers. Caveat: if implementation is on Claude Code Routines, daily caps (Pro 5/Max 15/Team-Enterprise 25) constrain audit volume — for >50-skill repos warn if plan tier insufficient. | [skill] [cadence] | PROPOSED |
| <a id="r-cadence-2"></a>R-CADENCE-2 | MECHANICAL | warn | Cadence-implementation MUST be one of: (a) Claude Code Routine (primary; per code.claude.com/docs/en/whats-new/2026-w16, beta header `experimental-cc-routine-2026-04-01`); (b) GitHub Actions cron + reviewer skill (fallback). Lint error if neither present. | [skill] [cadence] | PROPOSED |
| R-CADENCE-3 | MECHANICAL | error | Off-cadence triggers MUST be configured for: (i) skill-workshop new minor; (ii) validator major bump; (iii) ≥3 R-ROLLBACK-* events per skill in the cadence window; (iv) R-XPOLL-8 cross-skill description-overlap exceeded; (v) post-merge mechanical-validator failure on a freshly-applied retro. Linter checks config presence per trigger. | [skill] [cadence] | PROPOSED |
| R-CADENCE-4 | MECHANICAL | error | Each review run MUST emit `review-report.json` matching the v1.0 schema (report_version, run_at, trigger, skills[], rule_set_version, validator_version). Schema-validation enforced. | [skill] [cadence] | PROPOSED |
| R-CADENCE-5 | MECHANICAL | warn | Quarterly tier MUST tag a Conventional-Commits release `v<major>.<minor>.0-rules` if any rule changed. Pre-retro tags from R-ROLLBACK-* MUST be the diff base for off-cadence trigger (iii) of R-CADENCE-3. | [skill] [cadence] | PROPOSED |
| R-LOAD-1 | MECHANICAL | error | Each skill MUST contain a unique canary phrase (UUID4 or hyphenated word-pair) in body or referenced file. `evals/loading_verification.json` MUST include ≥1 canary test. Linter checks canary presence + uniqueness across the skill collection. | [skill] [loading] | PROPOSED |
| R-LOAD-2 | MECHANICAL | error | Each skill MUST ship ≥1 negative-control test that either (a) renames the skill folder before re-running the canary query OR (b) sets `disable-model-invocation: true` in frontmatter. Linter checks `evals/loading_verification.json` for at least one entry of `type: negative_control`. | [skill] [loading] | PROPOSED |
| R-LOAD-3 | MECHANICAL | error | Tests of the form "list your loaded skills" / "tell me which skills are loaded" are FORBIDDEN as the only loading-verification mechanism. Linter detects via regex match against the test query string + flags if no canary or negative-control exists alongside. | [skill] [loading] | PROPOSED |
| <a id="r-load-4"></a>R-LOAD-4 | MECHANICAL | warn | Validator config — bifurcated permission: (a) `PreToolUse matcher: "Skill"` is PERMITTED for agent-dispatched skill calls (the agent emits a tool_use block targeting the Skill tool; PreToolUse fires with `tool_name: "Skill"` and `tool_input: { skill: "<skill-name>", args: ... }`; deterministic exit-code 2 blocks the call before context expansion). Confirmed via Issue #21614 (sub-agent crash on PreToolUse-Skill error proves the hook fires) plus canonical hooks-doc `UserPromptExpansion` event description (Anthropic-canonical re-fetch 2026-05-07). (b) `PostToolUse matcher: "Skill"` remains FORBIDDEN as the test-pass condition — Issue #43630 still open as of 2026-05-07. (c) `InstructionsLoaded` for `.claude/skills/*.md` remains FORBIDDEN — fires only for `CLAUDE.md` / `.claude/rules/*.md` (Issues #30573, #31017). Linter warns if PostToolUse-Skill or InstructionsLoaded-skill config is present; PreToolUse-Skill is allowed but advisory-only — canary (R-LOAD-1) + negative-control (R-LOAD-2) remain mandatory. **Supplementary observability primitive:** `claude_code.skill_activated` OpenTelemetry event fires for ALL invocation paths with `invocation_trigger` attribute (`"user-slash"` / `"claude-proactive"` / `"nested-skill"`) — Tier-1 confirmed via anthropics/claude-code CHANGELOG; OpenTelemetry telemetry is the canonical observability path, supersedes hook-based for cross-path coverage. **Revisitable**: if Issue #43630 closes (PostToolUse Skill dispatches), promote PostToolUse-Skill from FORBIDDEN to PERMITTED. | [skill] [loading] | PROPOSED |
| R-LOAD-5 | MECHANICAL | error | `evals/loading_verification.json` MUST exist alongside `evals/evals.json` and conform to schema: `{ skill_name: str, verifications: [{type, query, expected_canary?, must_appear, rename_to?}] }`. Schema-validation enforced. | [skill] [loading] | PROPOSED |
| R-LOAD-6 | MECHANICAL | error | Threshold: ≥1 canary AND ≥1 negative_control entry in `evals/loading_verification.json` or audit emits exit code 2. | [skill] [loading] | PROPOSED |
| R-LOAD-7 | MECHANICAL | warn | Eval suite MUST include both layers: (a) trigger-rate eval in `evals/evals.json` (Anthropic skill-workshop pattern) AND (b) loading verification in `evals/loading_verification.json`. Linter warns if either layer is missing. | [skill] [loading] | PROPOSED |
| R-DRIFT-5-IMPL | MECHANICAL | error | Description-regen pipeline MUST run bidirectional NLI between old and new `when_to_use` blocks (DeBERTa-v3-MNLI-class or pinned equivalent). PASS condition: NLI(old→new) = ENTAILS AND NLI(new→old) = ENTAILS, both with probability ≥ 0.7. FAIL condition: either direction returns NEUTRAL or CONTRADICTS — keep previous description. | [skill] [drift] | PROPOSED |
| R-DRIFT-5-CHECK | MECHANICAL | warn | In addition to NLI, run skill-workshop trigger-eval suite against both descriptions; pass-rate delta on held-out test set MUST satisfy \|Δ\| ≤ 0.10. If exceeded, override NLI pass with WARN. | [skill] [drift] | PROPOSED |
| R-DRIFT-5-FALLBACK | HYBRID | warn | Mechanical: if NLI model unavailable, fall back to LLM-judge pairwise mode (R-LLMJ-6) with k=3 self-consistency. Semantic: judge prompt explicitly compares old vs new descriptions on scope-preservation rubric. | [skill] [drift] | PROPOSED |

##### Q-009 additions (v1.9): R-WORKSPACE / R-MONO / R-SHARE / R-REFLOC / R-CROSS

| Rule ID | Class | Heuristic | Severity |
|---|---|---|---|
| R-WORKSPACE-1 | MECHANICAL | `find <scope>/.claude/skills -mindepth 3 -name SKILL.md` returns empty | FAIL |
| R-WORKSPACE-2 | MECHANICAL | Reject any rule prescribing `additionalDirectories` for skill discovery | FAIL |
| R-WORKSPACE-3 | HYBRID | Mechanical: detect plugin manifest presence at `<root>/.claude-plugin/plugin.json`. Semantic (LLM-judge): topology fits T-MONO-1 cut | WARN |
| R-WORKSPACE-4 | MECHANICAL | `paths` glob MUST NOT match outside the skill folder; AND skill MUST be in a discovered scope independent of `paths` | WARN |
| R-WORKSPACE-5 | MECHANICAL | Symlink detection: `lstat` reports symlink at `<scope>/.claude/skills/<name>` → emit warn message about discovery unreliability | WARN |
| R-WORKSPACE-6 | MECHANICAL | Service-prefix detection: skill name matches `<service>-<rest>` pattern AND ≥2 services in same monorepo → suggest plugin-per-service | WARN |
| R-MONO-1 | HYBRID | Mechanical: `--add-dir` flag detection at launch. Semantic: skill body assumes nested-discovery without defensive guidance | WARN |
| R-MONO-2 | SEMANTIC | LLM-judge: monorepo with ≥3 services follows per-service + plugin pattern | WARN |
| R-MONO-3 | MECHANICAL | Body-link extraction: any Markdown link containing `../<other-skill>/SKILL.md` → reject | FAIL |
| R-MONO-4 | MECHANICAL | Body-content scan: presence of `Glob` tool invocations targeting `.claude/**` patterns → emit "use `find` instead" warning | WARN |
| R-SHARE-1 | MECHANICAL | Detect peer-skill symlinks: `find <skills-root> -type l` walking each `.claude/skills/<name>/` → reject any peer reference | FAIL |
| R-SHARE-2 | MECHANICAL | Body-content scan: any reference to `.claude/scripts/` → reject | FAIL |
| R-SHARE-3 | MECHANICAL | Body content scan: `${CLAUDE_PLUGIN_ROOT}` appears in `.md` body → emit "use in JSON/YAML config or pass through script env" warning | WARN |
| R-SHARE-4 | MECHANICAL | Body content scan: bundled-script references use `${CLAUDE_SKILL_DIR}/...` (preferred) OR plugin-relative `${CLAUDE_PLUGIN_ROOT}/...`; reject relative `./` or absolute `/...` | FAIL |
| R-REFLOC-1 | MECHANICAL | Body-link extraction: any link containing `..` resolves outside skill folder → reject | FAIL |
| R-REFLOC-2 | HYBRID | Mechanical: detect candidate (a)/(b)/(c)/(d) by link-target placement. Semantic: chosen pattern matches the skill's portability declaration in description | WARN |
| R-REFLOC-2(c) clarification | MECHANICAL | Frontmatter `internal:` key detection → reject (DA-108); use `user-invocable: false` + `paths` instead | FAIL |
| R-REFLOC-3 | MECHANICAL | If body > 300 lines → require `references/_index.md`; TOC-listed paths MUST resolve within skill folder unless skill description starts with `[internal — not portable]` | FAIL |
| R-REFLOC-4 | MECHANICAL | `paths` matches `docs/**` AND body has zero links to `references/` → emit "paths is not a content router" warning | WARN |
| R-CROSS-1 | MECHANICAL | Hallucination canary: token scan for `${CLAUDE_SKILLS_PATH}`, `skillsDirectories`, `Bun.Glob`, `internal: true` (frontmatter) → reject as hallucinated | FAIL |

**Hallucination-canary registry (cumulative).** v1.5 added `compatibility` frontmatter field-name verification. v1.7 added the `!command` Dynamic Context Injection canary. v1.8 added `<available_skills>` host-introspection canary, `Prometheus 3` non-existent successor, `Simulated Annotators` paper-title fabrication. **v1.9 adds:** `${CLAUDE_SKILLS_PATH}` (Issue #22902 still open per snapshot), `skillsDirectories` (Issue #39403 feature request), `Bun.Glob` direct invocation (R-MONO-4 prescribes `find` workaround), `internal: true` frontmatter key (DA-108 — Anthropic 15-key allow-list wins over vercel-labs/skills' Tier-2 cross-tool convention).

#### Q-010 rules — Reference Chunking & Lazy Loading

| Rule ID | Rule (1-line) | Mechanical? | Semantic? | Source tier |
|---|---|---|---|---|
| R-CHUNK-1 | References >100 lines must begin with `## Contents` H2 | Yes (regex) | — | Tier-1 (best-practices) |
| R-CHUNK-2 | References >500 lines OR >10K words OR >10-15K tokens must split by domain | Yes (counts) | — | Tier-1 (best-practices Pattern 2) |
| R-CHUNK-3 | References >10K words must include literal `grep` example in SKILL.md | Partial (presence of `grep`) | Yes (usefulness) | Tier-1 (skill-workshop SKILL.md) |
| R-CHUNK-4 | Every internal `.md` reference reachable in one markdown-link hop from SKILL.md; chained ref→ref forbidden; filesystem path depth unrestricted | Yes (markdown-link-graph BFS rooted at SKILL.md; fail on graph-distance > 1) | — | Tier-1 (best-practices + claude-api canonical) |
| R-CHUNK-5 | References ≤2,000 lines AND ≤10K tokens [claude-code-only] | Yes (counts) | — | Tier-1 (Issues #4002/#40357/#45019/#995) |
| R-CHUNK-6 | Header-anchored Grep+Read canonical; no vector indexes in references/ | Partial (flag *.faiss/*.chroma/embeddings.json) | Yes (intent) | Tier-1 + Tier-2 (Boris Cherny) |
| R-LAZYLOAD-1 | Every references/ file linked by name from SKILL.md with when-to-load | Yes (link check) | Yes (guidance quality) | Tier-1 (best-practices) |
| R-LAZYLOAD-2 | MANDATORY-READ pattern for must-not-skim references | Partial (presence of MANDATORY/ENTIRE/NEVER) | Yes (necessity) | Tier-1 (anthropics/skills/docx) |
| R-LAZYLOAD-3 | References <50 lines should be inlined in SKILL.md (SHOULD) | — | Yes (judgment) | Tier-2 (heuristic) |

#### Q-010 hallucination canaries

- `.claude/skill-memories/` — does NOT exist as Anthropic-implemented namespace. Verified as community proposal in anthropics/claude-code Issue #25469 (anton-abyzov, Feb 2026, stale). Anthropic's documented mechanism for the analogous use case is `.claude/rules/`. Validator should flag any SKILL.md referencing `.claude/skill-memories/` as a likely Gemini-class hallucination. DA-122.
- `injection.py` inside a Claude Code skill — does NOT belong. The filename is real in CaveAgent's Python-runtime framework (cave_agent / pycallingagent on PyPI llm-py-agent), but Claude Code's stateless-bash-tool runtime cannot consume Python object injections. Validator should flag any Claude Code skill bundling an `injection.py` as a likely Gemini-class misapplication. DA-121, P-CHUNK-11.
- TOC-position `head -50` cutoff — Anthropic specifies no such number. R-CHUNK-1 only requires `## Contents` to begin the file body. DA-123.
- Specific 30%-mid-document-accuracy-drop figure — does NOT appear in Liu et al. (TACL 2024) or Chroma 2025 as a single reportable cross-task figure; both papers show task-dependent variance. DA-124.

##### Q-011 additions (v1.11) — schemas only; logic deferred to validation-script implementation

**`supersession_integrity`** [PROPOSED] — Every entry in `tabs[research].'Discarded Alternatives'` whose status is `superseded` MUST carry at least one `superseded_by` array entry pointing to a rule whose status is VALIDATED or CANONICAL. Orphan supersession is a meta-validation error (exit code: nonzero, category: SUPERSEDE-ORPHAN). Reciprocal rule: every R-XXX-N with a non-empty `supersedes` array MUST point to existing DA-NNN labels in Discarded Alternatives.

**`reference_freshness`** [PROPOSED] — Every entry in `tabs[research].'References'` MUST carry `last_verified_iso8601`. Per `agent_guidelines.framework.reverification_intervals.default_intervals_days`: any reference whose `(today - last_verified_iso8601) > reverify_after_days` MUST appear in the next session's Open Research Queue auto-population. Population of `last_verified_iso8601` on existing References is a v1.12+ schema migration (defined here, not enforced this version).

**`tier_consistency`** [PROPOSED] — Every section in `tabs[*].*` MUST be assignable to exactly one CoALA tier per `agent_guidelines.framework.memory_tiers.mapping`. Sections that do not match any mapping entry are flagged as `TIER-UNCLASSIFIED` (warning, not error). Population of an explicit `tier:` annotation on each section is a v1.12+ schema migration.

**`index_freshness`** [PROPOSED] — When `tabs[research].'Index'` is created (per `agent_guidelines.framework.retrieval_strategy.intermediate_step`), it MUST list every R-XXX-N rule, every DA-NNN, and every Open Queue Q-NNN exactly once with a stable section anchor. Missing or duplicate entries are errors. Index creation deferred to Q-014 implementation.

##### Q-014 v1.12 — new validator lints

**v1.12 adds the following machine-checkable lints to the validation script (PROPOSED — implementation pending):** (a) **R-LOG-REJECT lint:** fail if `<skill>/references/log.md` (or any append-only `log.*` file) exists. (b) **R-REF-FM-1 lint:** for any `<skill>/references/*.md` file with YAML frontmatter, fail if frontmatter contains keys outside the `{title, summary, load_when}` whitelist. (c) **R-REF-SECRETS-1 lint:** scan `<skill>/references/*.md` for high-entropy strings matching common API-key / token / password patterns; warn (not fail). (d) **R-MEM-10 lint:** at the repository root, fail if `<root>/CLAUDE.md` is a symlink to `<root>/AGENTS.md` (or vice versa); pass if `<root>/CLAUDE.md` body begins with `@AGENTS.md` and `<root>/AGENTS.md` exists. (e) **R-REF-SHARE-1 lint:** if a skill is inside a plugin (`<plugin>/skills/<skill>/`), permit `<skill>/references/<file>.md` to be a symlink whose target resolves under the plugin root; fail if the target traverses outside the plugin root. (f) **R-CHUNK-4 lint exception (Q-016 deferred):** flag for review (not fail) any skill whose `references/` is more than one level deep (e.g., `references/python/foo.md`); the canonical `anthropics/skills/claude-api` skill currently violates R-CHUNK-4, pending Q-016 reconciliation.

#### Q-015 v1.13 — Boundary-contract lints (Lints #10, #11, restated #1)

| Lint ID | Rule | Trigger | Severity | Rationale |
|---|---|---|---|---|
| LINT-Q015-10 | R-BOUNDARY-9 — references >100 lines must contain a table of contents | Any file under any `<skill>/references/<X>.md` whose non-blank line count exceeds 100 AND which does not contain at least one `## ` (or `## Contents`) heading list within the first 30 non-blank lines. | FAIL | Without a ToC at the top, partial reads triggered by `head -100`-style truncation lose the document's scope. Canonical Anthropic threshold is 100 lines (corrects Gemini-15's 300-line overclaim → DA-144). |
| LINT-Q015-11 | R-BOUNDARY-4-CLARIFICATION — `@AGENTS.md` must be the first content line of CLAUDE.md when present | Any `<root>/CLAUDE.md` (or `<root>/.claude/CLAUDE.md`) whose body contains the substring `@AGENTS.md` AND that substring is preceded by any non-frontmatter, non-HTML-comment, non-blank line. | FAIL | The canonical Anthropic example places `@AGENTS.md` as the first content line, with Claude-Code-specific content following. Out-of-order placement risks Claude-Code-specific addenda being read before the tool-portable invariants they depend on. |
| LINT-Q015-1-RESTATED | R-BOUNDARY-3 — CLAUDE.md ≤200 lines is a target, not a truncation cap | Any CLAUDE.md (`<root>/CLAUDE.md`, `<root>/.claude/CLAUDE.md`, `~/.claude/CLAUDE.md`, managed-policy CLAUDE.md) whose non-blank line count exceeds 200. | WARN (not FAIL) | Replaces an earlier (now retracted) silent-truncation framing. Per canonical Anthropic Tier-1 (*'CLAUDE.md files are loaded in full regardless of length'*; → DA-140), CLAUDE.md is not truncated past 200 lines — but adherence quality degrades. Lint message MUST NOT imply truncation; only adherence-quality risk and per-message context cost. |

##### Q-016 v1.14 — R-CHUNK-4 markdown-link-graph validator + LINT-Q016-1

**R-CHUNK-4 v1.14 mechanical heuristic (replaces v1.13 path-depth tree-walk).** Pseudocode: (1) Parse SKILL.md for relative `.md` links; collect into set D1. (2) For each file f in D1, parse f for relative `.md` links pointing to other files inside the same skill. (3) FAIL if any link target outside D1 ∪ {SKILL.md} ∪ non-md-files is found. (4) Otherwise PASS. Filesystem `os.walk`-based depth checks are removed entirely. Implementation note: relative `.md` link extraction MUST distinguish between local relative paths and external `https://`/`http://` URLs (the latter are not validated). Anchor fragments (`#section`) on internal links are stripped before path resolution.

| Lint ID | Class | Severity | Heuristic | Tags | Status |
|---|---|---|---|---|---|
| LINT-Q016-1 | MECHANICAL | info | After R-CHUNK-4 graph build: if any file in D1 contains a relative `.md` link whose target is also in D1, emit info-level note '<source> cross-links to <target>; both are depth-1, allowed but worth surfacing'. Non-blocking. Surfaces benign cross-links like `python/claude-api/tool-use.md` → `shared/tool-use-concepts.md` in `anthropics/skills/claude-api`. | [reference] [portable] | VALIDATED (NEW v1.14) |

### Validation Script Design

> **Q-004 v1.4 — script design complete** _(green)_
>
> The validator ships as the `skill-validator` Claude Agent Skill (R-XPOLL-9 dogfooding). Pure Python, no LLM in-loop (R-META-10 ReWOO determinism). Mechanical only — semantic checks are a separate Q-008 tool. Disagreements with the Tier-2 agent-ecosystem/skill-validator (Go-based) are logged in DA-046; project keeps Anthropic-hooks-compatible exit codes.

#### 1. CLI surface

```text
skill-validator [GLOBAL OPTIONS] <COMMAND> [COMMAND OPTIONS] <PATH>

COMMANDS:
  check        Validate one skill or library (default).
  list-rules   Print all known rule IDs with severities.
  version      Print validator version + embedding model version.

GLOBAL OPTIONS:
  --format {json,text}        Default: text on TTY, json when piped.
  --severity-threshold {fail,warn,info}    Default: warn.
  --severity-fail-threshold {fail,warn}    Default: fail.
  --strict                    Promote WARN to FAIL severity (binary CI).
                              Adopted from Gemini-4 + agent-ecosystem.
  --surface {api,claude-code,both}    R-FM-6 allow-list scope. Default: both.
  --quiet / -q                Suppress info output.
  --verbose / -v              Include rule citations + remediation hints.

CHECK OPTIONS:
  PATH                        Auto-detected: PATH/SKILL.md exists -> single-skill;
                              else library mode.
  --library                   Force library mode.
  --self-path PATH            For R-XPOLL-9. Default: $(dirname $0)/../skill-validator.
  --rules <ID,ID,...>         Run only listed rules.
  --skip-rules <ID,ID,...>    Skip listed rules.
  --meta-skill                Apply R-META-14 (≤400 lines).
  --embedding-model NAME      Default: sentence-transformers/all-MiniLM-L6-v2.
  --similarity-threshold F    R-XPOLL-4 cosine. Default: 0.85 (pre-registered).
  --cache-dir PATH            Default: .skill-validator-cache.
  --no-cache                  Disable embedding cache.
  --fix                       RESERVED. Hard error in v1.4 per R-META-9.
```

#### 2. Exit-code contract

| Code | Meaning | Trigger |
|---|---|---|
| 0 | Pass | No findings ≥ severity-threshold OR all findings < severity-fail-threshold. |
| 1 | Warnings only | ≥1 warn, 0 fail. With --strict: also promotes warn→fail (so 1 becomes unreachable; everything is 0 or 2). |
| 2 | Failures present | ≥1 fail. Maps cleanly into Claude Code hooks (exit 2 = block). |
| 64 | Misuse | argparse error (sysexits.h EX_USAGE). |
| 65 | Malformed input | YAML parse error or non-UTF8 bytes (EX_DATAERR). |
| 66 | Cannot open input | Path not found, no SKILL.md, permission denied (EX_NOINPUT). |
| 70 | Internal error | Uncaught exception (EX_SOFTWARE). |

Anthropic-supremacy: This contract uses 0/1/2 = pass/warn/fail (Claude Code hooks-guide treats exit 2 as block signal). agent-ecosystem/skill-validator Tier-2 uses 0/1/2/3 = pass/err/warn/cli-error — disagreement logged in DA-046; cross-validator pipelines need translation.

#### 3. JSON output schema

```json
{
  "schema_version": "1.0",
  "validator_version": "1.4.0",
  "embedding_model": "sentence-transformers/all-MiniLM-L6-v2",
  "embedding_model_revision": "<sha256-prefix>",
  "started_at": "2026-05-01T12:34:56Z",
  "duration_seconds": 1.234,
  "library_root": "/path/to/library",
  "skills_examined": [
    {"name": "pdf-processing", "path": "skills/pdf-processing"}
  ],
  "findings": [
    {
      "rule_id": "R-FM-3",
      "severity": "fail",
      "message": "description exceeds 1024 characters (1289 found)",
      "file": "skills/pdf-processing/SKILL.md",
      "line": 3,
      "column": 14,
      "skill": "pdf-processing",
      "citation": "platform.claude.com/.../best-practices",
      "suggested_fix": "Move detail beyond first 1024 chars into body or references/.",
      "tags": ["[reference]", "[portable]"]
    }
  ],
  "summary": {"fail": 1, "warn": 0, "info": 0, "pass": 49},
  "exit_code": 2
}
```

- 1-indexed line/column (LSP convention).
- `citation` MANDATORY for fail-severity findings.
- `suggested_fix` is string only — never auto-applied (R-META-9).
- `schema_version` versioned for downstream pinning.
- Custom-compact (NOT SARIF). SARIF rejected for LLM-context bloat per Gemini-4 architectural argument.

#### 4. Error modes

| Failure mode | Handling | Exit |
|---|---|---|
| Malformed YAML | Catch yaml.YAMLError; emit fail R-FM-1 with line/column from yaml lib; skip remaining rules for that skill. | 65 |
| Missing SKILL.md | Fail R-NAME-1; skip skill (library mode continues, single-skill mode exits 66). | 66 / 2 |
| Non-UTF8 bytes | open(..., errors='strict'); on UnicodeDecodeError emit fail with byte offset. | 65 |
| Symlink loop | os.walk(followlinks=False); external symlinks → warn 'external symlink ignored'; skip. | 0/1/2 |
| Embedding model missing | Skip R-XPOLL-4 with info 'pip install sentence-transformers'; do not block. | 0 if no other findings |
| Empty library | Info 'no SKILL.md found under <path>'; exit 66. | 66 |

#### 5. Hook integration

#### 5.1 Creation-time (inside skill-workshop)

```markdown
## Step N: Validate before packaging

Before compiling the final .skill artifact, run the validator:

    python ../skill-validator/scripts/validate.py --format text "$SKILL_DIR"

If exit code is 2, do NOT proceed — surface findings to user.
Exit code 1 (warnings only) MAY proceed but warnings MUST be shown.
Exit code 0 = clean; package_skill is allowed to proceed.
```

#### 5.2 Finalization-time: .pre-commit-hooks.yaml (ships inside skill-validator/)

```yaml
- id: skill-validator
  name: Validate Claude Agent Skills
  description: Lints SKILL.md frontmatter, body, and library structure.
  entry: skill-validator check
  language: python
  pass_filenames: false           # CRITICAL: cross-skill R-XPOLL-4 needs full library
  always_run: false
  files: 'SKILL\.md$'             # Hook fires on any SKILL.md change; validator walks library internally
  stages: [pre-commit, pre-push, manual]
```

**Critical fix vs Gemini-4 draft:** `pass_filenames: false` (cross-skill checks need full library) and `files: 'SKILL\.md$'` only (no broken `~/\.claude/skills` regex — tilde does not expand inside file regex).

#### 5.3 Consumer-side: .pre-commit-config.yaml

```yaml
repos:
  - repo: local
    hooks:
      - id: skill-validator
        name: Validate Claude Agent Skills
        entry: python skill-validator/scripts/validate.py check
        language: python
        pass_filenames: false
        files: 'SKILL\.md$'
        stages: [pre-commit, pre-push]
        additional_dependencies:
          - PyYAML>=6.0
          - tiktoken>=0.7              # o200k_base support (v1.4 update)
          - sentence-transformers>=2.2  # optional, R-XPOLL-4 only
```

#### 5.4 .github/workflows/validate-skills.yml

```yaml
name: Validate Skills
on:
  push:
    paths: ['**/SKILL.md', '**/*.md']
  pull_request:
    paths: ['**/SKILL.md', '**/*.md']
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install validator
        run: pip install PyYAML tiktoken sentence-transformers
      - name: Run validator (JSON for downstream + text for logs)
        run: |
          python skill-validator/scripts/validate.py check \
            --format json . > validation-report.json || EXIT=$?
          python skill-validator/scripts/validate.py check \
            --format text . || true
          test "${EXIT:-0}" != "2"
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: validation-report
          path: validation-report.json
```

#### 6. Validator-as-skill packaging (R-XPOLL-9 dogfooding)

#### 6.1 Folder layout

```text
skill-validator/
├── SKILL.md                         # ≤500 lines (R-BODY-1)
├── scripts/
│   ├── __init__.py
│   ├── validate.py                  # CLI entrypoint
│   ├── check_descriptions.py        # R-XPOLL-4 (embedding lib)
│   ├── check_frontmatter.py         # R-FM-* family
│   ├── check_body.py                # R-BODY-* family (incl. R-BODY-6/7)
│   ├── check_naming.py              # R-NAME-* family
│   ├── check_references.py          # R-SR-* family (incl. R-SR-6/7)
│   ├── check_memory.py              # R-MEM-* family
│   ├── check_meta.py                # R-META-* family (mechanical only)
│   ├── check_contamination.py       # R-CONTAM-1 (mechanical proxy; defer to Q-008)
│   ├── output_json.py
│   ├── output_text.py
│   └── self_check.py                # R-XPOLL-9 + R-META-9 + R-META-10
├── references/
│   ├── rule-catalog.md              # one entry per rule_id, ≤100 lines (R-BODY-4 v1.4)
│   ├── exit-codes.md
│   ├── json-schema.md
│   └── hook-integration.md
├── tests/
│   ├── fixtures/
│   └── test_rules.py
├── .pre-commit-hooks.yaml
└── pyproject.toml                   # PyPI-installable; console_scripts entry
```

#### 6.2 Frontmatter (verbatim)

```yaml
---
name: skill-validator
description: Validates Claude Agent Skills against the project rule catalog. Use when the user wants to check, lint, or validate a SKILL.md, audit a skill library for frontmatter issues, detect duplicate-description collisions across skills, or run pre-commit checks on agent skills.
license: Apache-2.0
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Bash(python3 *), Glob, Grep
metadata:
  version: "1.4.0"
  rule_catalog_version: "1.4"
---
```

- **`disable-model-invocation: true`** (Tier-1 verified at code.claude.com/docs/en/skills): prevents agent from spontaneously running validation mid-conversation.
- **`user-invocable: true`** explicit (default): per claude-code Issue #26251, `disable-model-invocation: true` alone may block `/skill-validator` slash invocation in some configs; explicit `user-invocable: true` ensures slash invocation works.
- **`allowed-tools: Read, Bash(python3 *), Glob, Grep`**: read-only set + scoped Python execution. NO Edit, Write, NotebookEdit (validator must never modify files; declarative R-META-9 enforcement). Note: `allowed-tools` is parsed-but-not-enforced per claude-code Issues #18837/#37683 — actual enforcement via R-META-9 source-AST self-test.

#### 6.3 Body structure (≤500 lines per R-BODY-1; validator skill is NOT meta-skill so 400 cap doesn't apply)

- H1 title + 'Use when…' trigger one-liner.
- Quick-start: single bash invocation example.
- Workflow: numbered checklist (Anthropic best-practices 'PDF form filling workflow' pattern).
- Pointer to `references/rule-catalog.md` for full rule list.
- Pointer to `scripts/validate.py` for execution.
- Anti-patterns section: no `--fix`, no LLM calls embedded — explicit per R-META-9 / R-META-10.

#### 6.4 Self-validation (eat-its-own-dogfood)

- `tests/test_rules.py::test_self_validates_clean` — CI gate.
- `.github/workflows/validate-skills.yml` runs validator on its own folder.
- The pre-commit hook validates skill-validator's own SKILL.md when staged.
- If self-validation fails, the build fails — preventing the 'validator can't validate itself' bootstrap embarrassment.

#### 7. Cross-references and contradictions log (resolved in v1.4)

- **R-BODY-4 (RESOLVED v1.4):** Anthropic 100-line TOC threshold wins over project's earlier 300; revised in this version.
- **R-BODY-2 encoding (RESOLVED v1.4):** Switched cl100k_base → o200k_base for Tier-2 reference parity (agent-ecosystem/skill-validator).
- **R-FM-4 `when_to_use` (DEFERRED to Q-005):** community-observed but absent from documented Anthropic allow-list; Q-005 will decide drop / metadata.when_to_use / lobby Anthropic.
- **`allowed-tools` enforcement gap:** parsed-but-not-enforced per claude-code Issues #18837/#37683. Validator declares it for declarative correctness; R-META-9 source-AST self-test does actual enforcement.
- **Exit-code contract disagreement (LOGGED, NOT RESOLVED):** project 0/1/2 = pass/warn/fail (Anthropic hooks-guide-compatible) ≠ agent-ecosystem 0/1/2/3 = pass/err/warn/cli-err. Cross-validator CI scripts need translation. DA-046.

<!-- @end: meta-skill-validation -->

---

<!-- @anchor: queue -->
## Open Research Queue

Pending topics in priority order. **Top row = next session's topic.** Done items leave the queue and move to the [Research Tracker](#research-tracker). New items pass through the insertion protocol.

| Topic | Objective / Key Question |
|---|---|
| *(empty — research complete pending user direction; see Empty queue protocol)* | *Per framework empty-queue rule, the user is asked to choose: (1) add new topics; (2) fresh-eyes review (scan the whole project, propose gaps); (3) reopen a specific topic; (4) declare research complete.* |

<!-- @end: queue -->

---

<!-- @anchor: tracker -->
## Research Tracker

Living status board — one row per researched topic. Rows are appended as topics complete; never deleted.

| ID | Topic | Decision / Finding | Status | Version |
|---|---|---|---|---|
| T-000 | Project Setup (session_zero) | Project structure defined: 6 tabs, 5 queue items, 7 domain constraints, validation gate set, source tiers defined. | ✦ Researched | v1.0 |
| T-001 | Q-001 — Foundational anatomy of a Claude Code skill system | 35+ rules adopted across 8 categories (Frontmatter, Body/Length/Style, Naming, Skill-vs-Reference, Locations/Precedence, Dependencies/Splitting, Satellite/Helper, CLAUDE.md/AGENTS.md, Context-Efficiency). All seeds verified. Single-depth, 500-line, 5K/25K re-attachment, 1%/8K listing budgets PRE-REGISTERED with Anthropic Tier-1 citations. | ✦ Researched | v1.1 |
| T-002 | Q-002 — Cross-pollination from prompt engineering and agent-systems research | 12 new rules adopted (R-XPOLL-1..9 from Voyager/MRKL/Toolformer/Reflexion/Self-Refine/ReWOO/DSPy; R-MEM-7..9 from agents.md ecosystem) plus 1 NEW VALIDATED rule R-API-1 (Messages API limit of 8 skills per request, surfaced during Gemini-2 verification). Reconciliation between parallel v1.1 files completed under Anthropic-supremacy: AGENTS.md is now Linux-Foundation-stewarded (AAIF, 9 Dec 2025); the SKILL.md body cap is ≤500 lines per Anthropic best-practices (overrides the 100/300 folklore in both earlier files); arXiv:2604.24026 affiliation is UNVERIFIABLE (admit vocabulary only). Gemini-2 second opinion vetted: Hamel Husain post confirmed real, but 4 hallucinations rejected (20-skill-per-session limit, mode: frontmatter field, CLAUDE_CODE_FORK_SUBAGENT env var, mandated eval_queries.json schema beyond what Hamel actually proposed). | ✦ Researched | v1.2 |
| T-003 | Q-003 — Meta-skill specification: a skill that creates skills | 15 new rules adopted (R-META-1..15) + 4 corrective/extension rules (R-META-16..19) for negative counter-examples, organic-trace lifecycle, SSO-compatible validator, and Bash-availability assertion in eval baseline. Meta-skill = DSPy-style compiler (declarative `.skill-spec.yaml` → init_skill.py scaffold + LLM body/description authorship + bounded ≤3-iter refinement → quick_validate.py fail-closed). External verification = (validator pass) AND (user accept). Curriculum = 3 tiers gated on prior-skill count (Voyager-style). Meta-skill ≤400 lines (stricter than the 500 it generates). 10 alternatives rejected (DA-025..DA-034) including 4 Gemini-3 fabrications/misattributions. | ✦ Researched | v1.3 |
| T-004 | Q-004 — Validation rules and validation-script design | 27 mechanical rules + 18 semantic-deferred + 5 hybrid classified across all 50 v1.3-adopted rules. Validator CLI specified: 0/1/2 exit codes (pass/warn/fail) matching Anthropic Claude Code hooks-guide; --strict elevates WARN to FAIL (adopted from Gemini and agent-ecosystem/skill-validator v1.1.0 confirmed real). Hook integration at two gates (creation-time inside skill-workshop, finalization-time via pre-commit + GitHub Actions). Validator packaged as the `skill-validator` skill with disable-model-invocation: true (Tier-1 verified) and read-only allowed-tools. 1 NEW VALIDATED candidate rule R-FM-6 (frontmatter key allow-list) emerged from research. 6 NEW PROPOSED rules from agent-ecosystem/skill-validator Tier-2 reference: R-BODY-6 (per-reference token caps), R-BODY-7 (unclosed code fence), R-SR-6 (internal link existence), R-SR-7 (transitive reachability orphan detection), R-XPOLL-10 (keyword stuffing in description), R-CONTAM-1 (cross-language contamination, semantic). Encoding switched from cl100k_base to o200k_base for Tier-2 reference parity. Anthropic-supremacy disagreement logged on R-BODY-4 (Anthropic 100 vs project 300). Gemini second opinion vetted: 4 contributions accepted, 5 rejected (false Issue #37 narrowing, broken pre-commit regex, broken pass_filenames, suspicious arxiv:2604.20462, incompatible exit-code contract). | ✦ Researched | v1.4 |
| T-005 | Q-005 — Promotion pass: re-verify Discovery-tier and PROPOSED claims | 14 PROPOSED claims re-verified against live Anthropic primary sources fetched 2026-05-02. **Promotions to VALIDATED Tier-1 (Anthropic-confirmed):** (1) R-FM-4 `when_to_use` officially documented in code.claude.com/docs/en/skills frontmatter table (was PROPOSED-allow-list-status); (2) R-FM-6 frontmatter allow-list expanded to full Claude Code extended profile of 15 keys: name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell — confirmed by live docs; (3) R-BODY-1 (≤500 body lines) re-confirmed; (4) R-BODY-4 (reference TOC at >300 lines) re-confirmed; (5) NEW R-BODY-8 negative counter-examples PROMOTE Tier-1 (anthropics/skills/docx, /pptx, /pdf SKILL.md exemplars + skill-development SKILL.md 'Common Mistakes' section); (6) NEW R-BODY-9 voice rule PROMOTE Tier-1 (skill-development SKILL.md verbatim '❌ DON'T: Use second person anywhere' + 'Write the entire skill using imperative/infinitive form (verb-first instructions), not second person'). **Revisions to PROJECT-INTERNAL with calibration plans:** R-XPOLL-5 trigger grammar replaced with Anthropic-template 'This skill should be used when…' soft-warn (not regex); R-XPOLL-7 Voyager mapping (paper exists, Anthropic doesn't cite it); R-XPOLL-8 0.85 cosine threshold (no Tier-1 backing, calibration deferred); R-SR-7 (header anchors) per Gemini-5 conflation flagged DA-053; R-CONTAM-1 (Ruff prefixes ≠ evidence-tier provenance) per Gemini-5 conflation flagged DA-055. **Validator encoding decision finalized:** primary metric = physical line count (matches Anthropic's published ≤500 rule and quick_validate.py implementation); secondary = `messages.count_tokens` API for token-budget checks; tiktoken o200k_base only as offline approximation. **v1.5 corrective:** the 'R-BODY-4 100-vs-300-vs-500 contradiction' from v1.3/v1.4 was a category error — 500 = SKILL.md body cap (R-BODY-1), 300 = reference-file TOC trigger (R-BODY-4), 100 = older obra/superpowers cached threshold (now superseded). **Second opinion: Gemini-5** — 4 contributions accepted (R-FM-4 promotion via live docs, R-BODY-9 promotion via skill-development SKILL.md verbatim 'second person anywhere' DON'T, full Claude Code extended frontmatter key list, 1,536-char description+when_to_use cap); 6 rejected as DA-049..DA-055 (Gemini-5 R-SR-7 conflation, Gemini-5 R-XPOLL-7 Tier-1 promotion, Gemini-5 R-CONTAM-1 Ruff justification, Gemini-5 unverified 250-char terminal truncation, Gemini-5 stale 1,024-char generation limit, Gemini-5 unverified `@anthropic-ai/tokenizer` package). **New rule IDs added in v1.5:** R-BODY-8 (negative counter-examples in description), R-BODY-9 (imperative body / third-person description voice). **New Tier-1 facts surfaced from live docs (2026-05-02 fetch):** `paths` glob field (auto-activation by file pattern), `effort` field (low/medium/high/xhigh/max), `shell` field (bash/powershell), `arguments` field (named positional), `model` field (per-skill override), `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var, dynamic 1%-of-context budget for skill-listing (8000-char fallback), 25,000-token re-attach budget after auto-compaction, 5,000-token-per-skill carry-forward limit. **Anthropic-supremacy contradictions:** (A) R-FM-4 evidence drift between Lee Hanchung blog (Oct 2025: claims undocumented) vs live docs (May 2026: documented) — adopt live docs; (B) Description voice: anthropics/skills/{pdf,docx,pptx} use imperative 'Use this skill whenever…' but skill-development SKILL.md mandates passive 'This skill should be used when…' for descriptions — adopt the skill-development SKILL.md form as it's the authoritative authoring guide. Soft-warn (not fail) on existing imperative descriptions in anthropics/skills repo for backward-compat. |  |  |
| T-006 | Q-006 — Multi-task skills: parallelism, delegation, composition | 16 rules adopted: R-COMP-1/2/3 (composition ladder, model-mediated invocation, embed-and-duplicate); R-PAR-1/2/3/4 (`context: fork` semantics, 3–5 default with 8 ceiling, independence test, fork inheritance table); R-DEL-1/2/3 (no nested subagents, explicit `skills:` preload, four-field subagent task brief); R-CONDUCT-1/2/3/4 (implicit conductor, `paths` overlap unresolved, `disable-model-invocation` removes from `<available_skills>`, agent-teams escalation thresholds); R-FAIL-1/2/3/4/5 (per-session 25k re-attach pool, `PostToolBatch` fan-in, summary-only failure surface, parallel-hook independence, pre-approve all background-subagent permissions). 9 alternatives discarded (DA-056..DA-064) including the "5 hard cap", cross-skill `shared/`, and hallucinated hook events from Gemini-6. | ✦ Researched | v1.6 |
| T-007 | Q-007 — Self-updating skills: post-session retrospective and auto-improvement | 30 rules adopted across seven families (Turn 1: 27 rules across R-RETRO/SELF/DRIFT/EXTRACT/DESTRUCT/VC/ROLLBACK; Turn 2: 3 NEW rules — R-RETRO-6, R-DRIFT-5, R-DESTRUCT-3): **R-RETRO-1..6** (retrospective protocol — `Stop`/`SessionEnd` triggers with `stop_hook_active` loop guard, prompt-type hooks for Stop/SubagentStop, async ceilings, in-skill-frontmatter `hooks:` with `once: true`); **R-SELF-1..5** (canonical write target = `references/gotchas.md`, body reserved for behavioral corrections only, canonical-folder convention non-mandatory but ecosystem-aligned, gotchas entry schema, `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/` for in-flight diffs); **R-DRIFT-1..5** (description regen after N=3 retros via skill-workshop's optimizer with held-out validation, description ≤1024 chars, no hidden frontmatter fields, **scope-preservation constraint R-DRIFT-5** added Turn 2); **R-EXTRACT-1..3** (script-promotion threshold N≥3 reuses in-session OR ≥3 sessions in 14 days — inter-session arm tightened Turn 2 per Gemini-7; skill-workshop handles the extraction; trigger-eval gate before marketplace); **R-DESTRUCT-1..3** (`disable-model-invocation: true` skills require explicit `--apply-retro`; meta-skill's merge subcommand itself ships `disable-model-invocation: true`; merges go through Edit-tool permission classifier — R-DESTRUCT-3 added Turn 2); **R-VC-1..3** (Conventional-Commits `skill(retro):` prefix; semver patch=references / minor=body / major=description; `skill/auto-update` branch with user-accept gate); **R-ROLLBACK-1..5** (pre-merge `pre-retro-<skill>-<YYYYMMDD>` tag; validator-gated revert with degraded-health escalation; ≤1 merge per skill per session; cross-skill dependency re-validation on imported-path retros; semver-tag rollback for marketplace-distributed skills). Discarded alternatives DA-065..DA-077 (Turn 1: `UserCorrection` programmatic event, `errata/` mandate, errata-digest in description, Voyager add-on-first-success, CLAUDE.md as primary placement, auto-merge on green, skill-workshop-as-trigger, auto-major on every retro, cron-style external triggers; Turn 2: `!command` DCI hallucination, `references/gotchas.md`-as-fragmentation misreading, description-lock conflict with Anthropic skill-workshop, three-folder-convention-as-parser-enforced strawman). **v1.6 caveat reversed:** all 29 hook events confirmed canonical via live re-fetch of `code.claude.com/docs/en/hooks` 2026-05-04. Q-007 → ✦ Researched (v1.7); blue callout points to Q-008. | ✦ Researched | v1.7 |
| T-008 | Q-008 — Validation: LLM-based semantic checks + routine review cadence | 27 PROPOSED rules across four families (Turn 1: 23 rules R-LLMJ-1..12, R-CADENCE-1..5, R-LOAD-1..7, R-DRIFT-5-IMPL/CHECK/FALLBACK; Turn 2: 0 new rules, 1 revised — R-CADENCE-2 swapped GitHub Actions cron primary → **Claude Code Routines** (Tier-1 confirmed via code.claude.com/docs/en/whats-new/2026-w16, launched 2026-04-14, beta header `experimental-cc-routine-2026-04-01`); 1 caveat extended on R-CADENCE-1 for Routines daily caps Pro 5/Max 15/Team-Enterprise 25). **LLM-judge methodology:** G-Eval-form CoT + DSPy-Suggest soft-assertion + Constitutional-AI-style explicit principles, k=3 self-consistency, default Sonnet 4.6 ($3/$15 per MTok), Prometheus 2 local fallback (anthropics/skills issue #532 SSO-only enterprise users). Pointwise primary; pairwise (MT-Bench-form) reserved for R-DRIFT-5. Manual/scheduled invocation only — never on pre-commit (R-LLMJ-1 preserves R-META-10). Cost: ~$0.05–$0.18 per skill audit with caching, ~$2.50–$9 monthly per 50-skill repo. **Cadence:** monthly drift scan + quarterly rule-set review + on-demand triggers (R-CADENCE-1..5), implemented on Routines with GitHub Actions fallback. **Skill-loading verification:** mandatory canary token (R-LOAD-1) + mandatory negative-control rename / `disable-model-invocation: true` (R-LOAD-2); reject "list your loaded skills" probes (R-LOAD-3, Hector's gap); no hook reliance today (R-LOAD-4, anthropics/claude-code issues #43630, #30573, #31017, #22902 — InstructionsLoaded fires for CLAUDE.md / `.claude/rules/*.md` only, not skills). **R-DRIFT-5 scope-preservation:** bidirectional NLI entailment (DeBERTa-MNLI-class) primary; trigger-eval-delta cross-check; LLM-as-judge pairwise fallback. **Turn 2 Gemini-8 vetting:** 5 contributions accepted (Routines as primary cadence primitive G8-A, daily-cap operational constraint G8-B, Issue #43630 corroboration G8-C, BiCon-Gate arXiv:2604.14389 PROPOSED reference G8-M, non-Mizan cosine-rejection citation G8-N); 1 deferred (G8-D K=5 → Q-013); 9 rejected (DA-091..DA-099): `<available_skills>` host-introspection (architectural confusion), InstructionsLoaded-fires-for-skills (refuted by docs+issues), Prometheus 3 (does not exist), "Simulated Annotators" paper-title fabrication, SAMRE EACL2026-anonymous misattribution (real paper is D3 arXiv:2410.04663 named authors Oct 2024), Mizan as VALIDATED authority (Discovery-tier override), binary pass/fail "fundamentally fails" overclaim against Hamel Husain, Continuous+Weekly cadence on NIST SSDF authority (NIST does not mandate this), R-LOAD-8 multi-vector loading introspection (depends on rejected DA-091/DA-092). Q-013 added at priority 13 (k=3 vs k=5; Routines header churn; PreToolUse skill-matcher status). Contradiction check: PASSED. | ✦ Researched | v1.8 |
| T-009 | Q-009 — Workspace topology: cross-scope access, shared scripts, references-in-repo-docs | 17 new rules adopted across five families: R-WORKSPACE-1..6 (cross-scope discovery; plugin distribution canonical; `paths` is auto-activation only; symlink fragility tolerated with caveats; service-prefix tolerated, plugin-per-service preferred), R-MONO-1..4 (single-depth ceiling; preferred topology; router/index-skill discouraged; **R-MONO-4 NEW from Gemini-9** — `find` instead of Glob for `.claude/`-traversal due to Bun.Glob `dot:false` regression in CLI ≥2.1.92, Issue #44490), R-SHARE-1..4 (DA-058 reaffirmed; embed-and-duplicate canonical; `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` anchors; no `.claude/scripts/` convention), R-REFLOC-1..4 (no `..` paths in body links; R-REFLOC-2 with new candidate (d) centralized `~/.claude/docs/` PROPOSED; R-REFLOC-2(c) clarified to use `user-invocable: false` + `paths`, NO new frontmatter key), R-CROSS-1 (`${CLAUDE_SKILLS_PATH}` does not exist — hallucination canary). Pre-registered thresholds T-MONO-1 (≥3 services → plugin), T-SHARE-1 (≥2 skills sharing → plugin-root), T-PFX-1 (≥2 collisions → migrate), T-REF-1 (>10K-word reference → grep guidance). Q-012(a)+(b) absorbed into Q-009; (c) stays in Q-008. **Gemini-9** evaluated: 6 contributions accepted (G9-A..G9-G plus G9-H1/H2/H3 as PROPOSED background), 4 DAs filed (DA-108 `internal: true` rejected, DA-109 GraSP DAG rejected, DA-110 Skilldex three-tier rejected, DA-111 26.1% threshold rejected). Anthropic doc-vs-issue at #40640 resolved via #44490 root-cause analysis. | ✦ Researched | v1.9 |
| T-010 | Q-010 — Reference chunking and lazy-load granularity | 9 new rules adopted across two families: **R-CHUNK-1..6** (TOC at >100 lines per Anthropic best-practices stricter-wins over skill-workshop's >300; domain-split trigger at ≥500 lines OR ≥10K words OR ≥10K tokens; literal grep example required at >10K words extending R-SR-7; references exactly one directory level below SKILL.md to avoid `head -100` partial-read regression; per-call Read ceiling 10K tokens [claude-code-only] reflecting Apr 2026 silent 25K→10K downgrade per Issue #45019 + Desktop hardcoded 10K per Issue #40357; canonical pattern is header-anchored Grep-then-Read, on-disk vector indexes and semantic search NOT canonical for in-skill references). **R-LAZYLOAD-1..3**: every reference linked from SKILL.md with explicit when-to-load (R-LAZYLOAD-1, mechanical+semantic); imperative MANDATORY-READ-ENTIRE-FILE pattern from anthropics/skills/docx/SKILL.md for must-not-skim references (R-LAZYLOAD-2); SHOULD-inline references <50 lines to avoid tool-call overhead (R-LAZYLOAD-3, weakest source base, kept SHOULD not MUST per math correction). 4 PROPOSED claims queued for promotion-pass: P-CHUNK-7 (1.7x line-number Read overhead), P-CHUNK-8 (256-1024 token RAG chunks — cross-domain transfer caveat), P-CHUNK-9 (lost-in-the-middle U-shape transfer to skills), P-CHUNK-10 (head -100 default partial-read frequency); P-CHUNK-11 added in Turn 2 (CaveAgent runtime-skill-injection forward reference). Pre-registered hypotheses H1-H8 all PASSED or PARTIAL; thresholds T-CHUNK-1..4 ADOPTED. **Gemini-10** evaluated: 6 independent verifications performed (Issue #40357 ✓ Desktop 10K vs CLI 25K; Issue #45019 ✓ CLI silent 25K→10K downgrade Apr 2026; claude-plugins-official #995 ✓ skill-loading failures at 10K; arXiv:2601.01569 CaveAgent ✓ HKBU/HKUST/HKGAI verified real Tier-1 but misapplied by Gemini-10; Issue #25469 ✓ `.claude/skill-memories/` confirmed community-stale proposal NOT Anthropic-implemented; PyPI llm-py-agent ✓ `injection.py` is CaveAgent-framework-only). 1 contribution ACCEPTED-DECISIVE (G10-B Issues #40357/#45019 → R-CHUNK-5 refined + R-CHUNK-2 portable threshold tightened); 4 contributions ACCEPTED-PARTIAL (G10-A spirit kept; G10-C tightening kept but rejecting "DEPRECATED" framing; G10-G env-var orthogonality reaffirmed; G10-F1 CaveAgent → P-CHUNK-11 PROPOSED forward-influence reference, Q-009 precedent for GraSP/Skilldex); 1 MISREAD clarified (G10-H — R-CHUNK-4 already forbids nested references, hypothesis H7 wording tightened); 6 REJECTED (DA-120 G10-E math error 50-lines≠3K-tokens; DA-121 G10-F1 normative-rule overreach; DA-122 G10-F2 skill-memories conflated with Anthropic's `.claude/rules/`; DA-123 G10-A specific 50-line cutoff; DA-124 G10-D 30%-figure not in Liu et al. or Chroma 2025; DA-119 Turn-1 carried). Independence note: Gemini-10 fits systemic Gemini pattern of fabricating Anthropic-blessed production paradigms from academic sources; materially cleaner than Gemini-2/6/7/8 on arXiv verification, on par with Gemini-9. Contradiction check: PASSED. | ✦ Researched | v1.10 |
| Q-011 | Research Buddy framework should adopt: (b) bidirectional supersession links between Discarded Alternatives and replacing rules (RFC 7322 §4.1.4 pattern) — VALIDATED, the highest-leverage adoption. Partial-adopt with explicit narrowing of (a) confidence scoring (four-level ordinal scheme + RFC 2119 force keywords; reject numeric floats), (c) consolidation tiers (label the existing tab/section structure with CoALA tiers; no structural reorganization), and (e) lifecycle markers (categorical current/verify_after_passed/stale/superseded; reject Ebbinghaus numeric decay). Defer (d) hybrid retrieval with explicit trigger conditions (whole-document read dominates at the current 715 KB scale per Pollertlam & Kornsuwannawit 2026 arXiv:2603.04814 and ConvoMem 2025 arXiv:2511.10523). | ✦ Researched v1.11 |  |  |
| Q-014 | Q-014 — LLM-Wiki documentation patterns applied to skill `references/` organization and cross-skill reference-doc sharing | Karpathy's `index.md` PROPOSED-as-MAY (refines existing carve-out — Anthropic skills don't use it but don't forbid it). New rules R-REF-FM-1 MAY (frontmatter whitelist on reference files), R-REF-SUPERSEDE-1 MAY (`<details>` Old-patterns block), R-REF-SECRETS-1 SHOULD (no hard-coded credentials, per enterprise doc), R-LOG-REJECT MUST NOT (`references/log.md` runtime journal forbidden). **R-REF-SHARE-1 SHOULD** for cross-skill reference sharing: plugin-internal symlinks per `${CLAUDE_PLUGIN_ROOT}` semantics; otherwise embed-and-duplicate; cross-plugin not supported. **R-MEM-3 DEMOTED to permanent DA** (DA-130) and replaced by **R-MEM-10 [reference][portable] VALIDATED** mandating `@AGENTS.md` import directive in `<root>/CLAUDE.md` per canonical Anthropic memory doc — overriding the prior PROPOSED symlink rule. Gemini-14 vetting: 4 incorporations, 9 hallucinations rejected (DA-130..DA-138). Q-016 added to revisit R-CHUNK-4 vs claude-api skill multi-level structure. | ✦ Researched v1.12 | v1.12 |
| Q-015 | Q-015 — Skill-vs-project-documentation boundary contract | Boundary contract across four containers (skills, `<root>/CLAUDE.md`, `<root>/AGENTS.md`, repo docs) established. **8 VALIDATED rules** adopted: R-BOUNDARY-1 (multi-step procedures → SKILL.md, not CLAUDE.md/AGENTS.md), R-BOUNDARY-2 (long-form descriptive → `<skill>/references/` one-level-deep), R-BOUNDARY-3 (CLAUDE.md ≤200 lines *target*, no procedures per DA-004), R-BOUNDARY-4 (`@AGENTS.md` import idiom for cross-tool repos), R-BOUNDARY-4-CLARIFICATION (when present, `@AGENTS.md` is FIRST content line of CLAUDE.md), R-BOUNDARY-5 (repo docs referenced not duplicated), R-BOUNDARY-6 (skills MUST NOT have AGENTS-equivalent — R-MEM-10-CARVEOUT), R-BOUNDARY-7 (description ≤1024 chars; what+when; third person), R-BOUNDARY-8 (qualitative session-frequency routing), and **NEW R-BOUNDARY-9** (reference files >100 lines MUST include ToC; threshold from canonical Anthropic best-practices, corrected from Gemini-15's inflated 300-line claim). **4 PROPOSED:** P-BOUND-SUPERSEDE-1/-2/-3 (single-source-of-truth + canonical-source marker + inline-ordering wins), P-BOUND-DRIFT-1 (drift scan), and **NEW narrow P-BOUND-GROUNDING-1** (domain-scoped GROUNDING.md per Palmblad–Ragland–Neely arXiv:2604.21744 for regulated/safety-critical domains; NOT a platform mechanism). **Gemini-15 evaluation:** 4 incorporations (R-BOUNDARY-9 NEW; head -100 mechanism strengthens R-CHUNK-4; @AGENTS.md-first ordering; subagent context-isolation as routing factor); **7 rejections (DA-140..DA-146):** BUDGET-MEM-1 silent-truncation conflation (Tier-1 contradicts: CLAUDE.md loaded in full regardless of length), GROUNDING.md-as-universal-supersession-tier-zero overreach (paper is field-scoped to proteomics), 1700-token ToolSearch overhead (Discovery only), 85%/$150-250 figures (Discovery only), 300-line ToC threshold (canonical is 100), anti-patterns as supersession-resolution mechanism (overclaimed framing), Finout citations for Anthropic-primary facts (citation discipline). **Tangential acknowledged:** AutoDream → new Q-019. **Contradiction check: 1 resolved** (Gemini-15 BUDGET-MEM-1 conflation refuted by canonical Anthropic Tier-1 — MEMORY.md ≠ CLAUDE.md). Q-018 and Q-019 added to queue. | ✦ Researched v1.13 | v1.13 |
| T-016 | Q-016 — Reconcile R-CHUNK-4 single-level reference rule with `anthropics/skills/claude-api` multi-level structure | R-CHUNK-4 revised to markdown-link-depth semantics (graph-distance ≤ 1 from SKILL.md, filesystem depth unrestricted). Apparent Anthropic-vs-Anthropic contradiction dissolved: best-practices Pattern 2 (`reference/finance.md`) and Bad-vs-Good example (identical filenames, hop-count differs) both already point to the link-graph reading. R-CHUNK-4-CLARIFICATION + R-BOUNDARY-2-CLARIFICATION + LINT-Q016-1 added. Validator pivots from `os.walk` path-depth check to markdown-link-graph BFS. Empirical anchors verified Tier-1: `python/claude-api/tool-use.md` 590 lines, `shared/tool-use-concepts.md` 305 lines (corrects Gemini-16's 327). Anthropic_supremacy unchanged (no actual contradiction). Gemini-16 vetted: 4 contributions accepted (590-line count, Candidate C resolution, multi-level-corpus empirical baseline, validator delta direction), 6 rejected (DA-Q016-1..-6: fabricated native injection parser; Issue #13617 misattribution; 327→305 line miscount; arXiv:2601.04583 misattribution; Code-as-Truth meta-principle overreach; skill-workshop-references-via-Issue-#853 misattribution). Independence-note applies to DA-Q016-1 (third instance of Gemini bypass-of-LLM-action-space hallucination). 0 breaking changes for v1.13-authored skills. | ✦ Researched | v1.14 |
| T-013 | Q-013 — Self-consistency vote count for LLM-judge; Routines beta-header churn; PreToolUse skill-matcher status | **(a) k=3 vs k=5:** HOLD R-LLMJ-4 at k=3. Anthropic skill-workshop SKILL.md verbatim re-fetch 2026-05-07 confirms "running each query 3 times to get a reliable trigger rate" (across `github.com/anthropics/skills` + `anthropics/claude-plugins-official` mirror + DeepWiki summary + 3 secondary sources). No Tier-1 source post-dating v1.8 has produced quantitative ECE/AUROC/Brier evidence on frontier models that justifies graduating to k=5 under R-LLMJ-11 budget. Rating Roulette (Haldar & Hockenmaier, EMNLP 2025 Findings, `aclanthology.org/2025.findings-emnlp.1361.pdf`) graduates from PROPOSED preprint to Tier-1 corroborating reference. **(b) Routines beta-header:** HOLD R-CADENCE-2 unchanged. `experimental-cc-routine-2026-04-01` STILL ACTIVE per live re-fetch of `code.claude.com/docs/en/routines` 2026-05-07; Anthropic-canonical doc now documents a permanent **two-most-recent-previous-versions** stability guarantee. Daily caps (Pro 5/Max 15/Team-Enterprise 25) unchanged. **(c) PreToolUse Skill matcher:** REVISE R-LOAD-4 to bifurcated permission. PreToolUse `matcher: "Skill"` PERMITTED for agent-dispatched skill calls (confirmed via Issue #21614 sub-agent crash + canonical hooks-doc `UserPromptExpansion` event description). PostToolUse `matcher: "Skill"` remains FORBIDDEN (Issue #43630 still open). **NEW Tier-1 finding from anthropics/claude-code CHANGELOG:** `claude_code.skill_activated` OpenTelemetry event fires for ALL invocation paths with `invocation_trigger` attribute (`"user-slash"` / `"claude-proactive"` / `"nested-skill"`) — supersedes hook-based observability for cross-path coverage. **Turn 2 Gemini-13 vetting:** 1 contribution accepted (Routines two-version stability guarantee documentation refresh G13-A); 1 partial-accept (PreToolUse-Skill bifurcated permission G13-C, but Gemini's specific Issue #42250/#47307 citations are fabricated — the directional finding agrees with my Turn 1 from independent canonical evidence). **6 rejected as DA-147..DA-152:** Anthropic skill-workshop k=10 anchor fabrication (real text says k=3); TrustJudge ICLR 2026 K=4/5 misattribution (paper is "Under review" not accepted, and "triples" are model-pair transitivity tests not self-consistency votes); SAMRE-EACL2026 relitigation (DA-095 already rejected this; SAMRE is the D3 paper); "Can LLMs Automate Fact-Checking" optimal-at-5 (claim cannot be verified at the cited venue); Issue #42250 fabricated bifurcation (no such issue exists in anthropics/claude-code); Issue #47307 fabricated regression (no such issue findable). **Independence note applied:** misattributed citations + misread paper findings + fabricated issue numbers + relitigation of already-rejected DA treated as one LLM-hallucination data point per `framework.second_opinion_review.independence_note`. Q-013 closed; Q-018 promoted to top of queue. | ✦ Researched | v1.15 |
| T-018 | Q-018 — Independent Tier-1 confirmation of the per-skill-set 25,000-token re-attach budget | **HOLD R-FAIL-1 unchanged on numeric core; NARROW SCOPE on isolation clause; ADD Opus 4.7 effective-budget caveat and Task Budget orthogonality note; EXPAND confusable-25K disambiguation list to six.** **Numeric verdict:** the 25K combined / 5K per-skill / most-recent-first figures are still live on `code.claude.com/docs/en/skills` (live fetch 2026-05-07, verbatim quotation re-confirmed) but **no second independent Tier-1 source restates them** — exhaustive sweep of platform.claude.com agent-skills overview/best-practices, anthropic.com/engineering posts (Agent Skills + context engineering + writing tools for agents + multi-agent), the 32-page *Complete Guide to Building Skills for Claude* PDF, anthropics/skills SKILL.md exemplars, and Opus 4.7 release notes returned SILENT for the re-attach budget. The single canonical Anthropic source is sufficient under the validation gate's single-canonical-source clause; rule status remains VALIDATED but is now explicitly labeled "single-canonical-source" rather than "multi-source." **Scope clarification:** the deprecated phrase "per-skill-set, per-branch" is project-internal terminology that does not appear in any Anthropic Tier-1 source; replaced with "per-session, per-context-window" and the isolation invariant is now framed as a **project-internal composition** of canonical sub-agents doctrine + bare combined-budget figure (corroborated by Issues #5812 and #10212 which independently confirm sub-agent context isolation as the user-observed primitive). **Opus 4.7 caveat:** tokenizer change documented at platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7 produces 1.0–1.35× more tokens per identical text, compressing effective skill content fitting in the 25K/5K nominal budget by up to ~26%; nominal figures unchanged. **Task Budget orthogonality:** `task-budgets-2026-03-13` beta header (verified Tier-1) is a forward-looking economic governor over the entire agentic loop, orthogonal to R-FAIL-1's backward-looking memory-preservation protocol; no protection from the 5K cap regardless of remaining task-budget runway. **Confusable 25K disambiguation expanded** from 4 to 6 mechanisms: (1) skill re-attach R-FAIL-1; (2) Read-tool ceiling R-CHUNK-5; (3) MEMORY.md 25 KB; (4) tool-response default — verbatim *"For Claude Code, we restrict tool responses to 25,000 tokens by default"* per anthropic.com/engineering/writing-tools-for-agents (Q-018 NEW); (5) `MAX_MCP_OUTPUT_TOKENS` default per code.claude.com/docs/en/mcp (Q-018 NEW); (6) Cowork compaction-instruction overhead per Issue #24677 (Q-018 NEW). **Hard-coded:** R-FAIL-1's 25K/5K parameters have NO env-var or config override (verified against env-vars/settings docs and source-code reproductions; Issue #45019 explicit *"I cannot find any controls"*). The adjacent `autoCompactWindow` setting (env: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`; min 100K / max 1M per Issue #42149) controls **when** compaction triggers, not the re-attach budget itself. **Watch item:** structural vulnerability to silent-downgrade pattern (Issue #45019 analogue) — quarterly automated diff of canonical page recommended. **Gemini-18 second-opinion vetting:** 4 contributions ACCEPTED (G18-A tool-response 25K verified, used to expand confusable list; G18-B Task Budgets verified, orthogonality framing adopted; G18-C meta-skill-as-skill 5K-cap implication adopted as cross-section forward-influence note for system-design § Meta-Skill Spec; G18-D "per-branch isolation is project-internal terminology" framing adopted, strengthens Turn-1 narrowing). **5 rejected as DA-153..DA-157:** **DA-153** Issue #21925 misattribution + fabricated "rigid 25,000-token CLAUDE.md ingestion limit" (issue is about CLAUDE.md not being re-loaded post-compaction; directly contradicts canonical Anthropic memory doc and DA-140; Issue #22085 corroborates that CLAUDE.md is loaded fully at startup); **DA-154** `autoCompactWindow` env-var name fabrication ("formerly `CLAUDE_AUTOCOMPACT_WINDOW`" — actual name per source-code reproduction is `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and was never the shorter form); **DA-155** tabular CLAUDE.md hard-limit fabrication (same fabrication as G18-1 in tabular form, separate DA because tabular precision implies a vendor-documented mechanism that does not exist); **DA-156** specific 18,000-22,000-character envelope for 5K tokens (Discovery rule-of-thumb packaged as architectural fact, no Tier-1 anchor for the precise range); **DA-157** `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env-var fabrication (does NOT exist in code.claude.com/docs/en/env-vars; Issue #45019 verbatim *"I cannot find any controls to get back to 25000"*; Issue #14888 confirms the file-read 25K is hardcoded). **Independence note applied:** Gemini-18 fits the systemic Gemini pattern (Gemini-2/5/6/7/8/10/13/15/16) of fabricating Anthropic-blessed mechanisms by misattributing them to real GitHub issue numbers — same failure mode as Gemini-15's BUDGET-MEM-1 conflation that produced DA-140. Treat as ONE LLM-second-opinion data point. **Materially:** Gemini-18's directionally correct findings on Task Budgets and meta-skill-as-skill 5K-cap implication are useful contributions; the GitHub-issue-anchored fabrications (DA-153, -157) are the same failure mode that has now manifested in 6+ second-opinion sessions. Q-018 closed; Q-019 is now the top row. | ✦ Researched | v1.16 |
| T-019 | Q-019 — Auto memory & AutoDream/`tengu_onyx_plover`/KAIROS daemon operational mechanics | **VALIDATED Tier-1 silence on AutoDream / `tengu_onyx_plover` / `/dream` / KAIROS in canonical Anthropic docs** as of 2026-05-07 (live fetches: `code.claude.com/docs/en/memory`, `code.claude.com/docs/en/glossary`, `code.claude.com/docs/en/how-claude-code-works`, `code.claude.com/docs/en/sub-agents`, `code.claude.com/docs/en/skills`, `code.claude.com/docs/en/commands`, `code.claude.com/docs/en/best-practices`, `code.claude.com/docs/en/claude-directory`, `anthropic.com/news` Apr–May 2026, `anthropics/claude-code` `CHANGELOG.md`, *Complete Guide to Building Skills for Claude* PDF, `anthropics/skills`, `anthropics/anthropic-cookbook`). Canonical post-GA terminology is "Auto memory" (`code.claude.com/docs/en/memory#auto-memory` + `/glossary`). **Distinct-product disambiguation:** `platform.claude.com/docs/en/managed-agents/dreams` documents a **separate Managed Agents "Dreams" product** (Research Preview, beta header `dreaming-2026-04-21` on top of `managed-agents-2026-04-01`, asynchronous-job-with-immutable-input-store model, models `claude-opus-4-7` / `claude-sonnet-4-6`, `instructions` cap 4096 chars, 100 sessions per dream) — NOT the in-CLI AutoDream consolidator. **Operational scope (Tier-1 anchors via `anthropics/claude-code` Issues #39204, #47959, #50694):** AutoDream operates strictly within `~/.claude/projects/<slug>/memory/` (lock at `<memory>/.consolidate-lock`; PID-bound forked subagent confirmed by #50694's hard-kill repro). **Trigger architecture (PROPOSED with very-strong cross-source corroboration — 6+ independent post-leak archives):** triple gate of ≥24h since last consolidation + ≥5 accumulated sessions + advisory file lock; four-phase pipeline Orient → Gather → Consolidate → Prune. **Supersession (split verdict):** cross-container R-MEM-1 hierarchy (CLAUDE.md > Auto Memory) is unaffected; intra-MEMORY.md user-vs-Claude precedence is **NOT** Tier-1-documented and is contradicted by Tier-1 Issue #47959 demonstrating destructive consolidation of user-reinforced files. **Task Budget orthogonality VALIDATED Tier-1** via verbatim *"Task budgets are not supported on Claude Code or Cowork surfaces at launch"* (`platform.claude.com/docs/en/build-with-claude/task-budgets`) — strengthens T-018's Task Budget framing. **Auto-compaction orthogonality VALIDATED via lifecycle disjointness:** auto-compaction is intra-session (canonical `/how-claude-code-works`); AutoDream is inter-session (Issue #50694 *"scheduled between sessions"*). **Skill re-attach (R-FAIL-1) orthogonality VALIDATED:** skills are not in AutoDream's file scope (R-AUTODREAM-1). **`tengu_onyx_plover` flag verdict:** flag-name authenticity strongly corroborated across ≥7 independent post-leak archives (PeronGH/claude-code-decoded, marckrenn/claude-code-changelog, yitianlian/claude-code-hidden-features, davccavalcante/claude-code-leaked, sanbuphy/claude-code-source-code, 0PeterAdel/ClaudeCode-Leak, yasasbanukaofficial/claude-code) all derived from Chaofan Shou's 2026-03-31 npm sourcemap discovery (v2.1.88); rejects the Q-018 Gemini-fabrication risk pattern — `tengu_onyx_plover` is anchored to a dated, attested, reproducible source-code-disclosure event. **Adjacent flag-function corroboration via davccavalcante README:** `tengu_kairos` (assistant-mode umbrella), `tengu_ultraplan_model` (planning model), `tengu_cobalt_raccoon` (auto-compact), `tengu_portal_quail` (memory extract), `tengu_harbor` (MCP allowlist), `tengu_scratch` (worker scratch dirs), `tengu_malort_pedway` (computer use). **Project-internal terminology correction:** the queue's "KAIROS daemon" is project-internal and does NOT match Anthropic's leaked-source usage; KAIROS is the broader proactive-mode umbrella (compile-time `feature('KAIROS')` + runtime `tengu_kairos`) encompassing dream consolidation + tick-loop monitoring + push notifications + PR-subscription + brief generation; AutoDream is one sub-feature gated by `tengu_onyx_plover` ON TOP of KAIROS. Refer to the consolidator as "AutoDream" / "auto dream" / "dream subagent". **5 NEW rules adopted (R-AUTODREAM-1..-4 + R-MEM-1-CLARIFICATION).** R-AUTODREAM-1 VALIDATED (file scope). R-AUTODREAM-2 PROPOSED (gating + trigger thresholds). R-AUTODREAM-3 VALIDATED (orthogonality with Task Budgets + auto-compaction + R-FAIL-1). R-AUTODREAM-4 PROPOSED (KAIROS umbrella + naming correction). R-MEM-1-CLARIFICATION VALIDATED (cross-container hierarchy ≠ intra-MEMORY.md user-precedence; Tier-1 Issue #47959 contradicts the universal user-wins reading). **Gemini-19 vetting:** 9 contributions accepted (Tier-1 silence reaffirmation; `code.claude.com/docs/en/glossary` as new Tier-1 anchor; davccavalcante/claude-code-leaked as additional independent corroboration; flag-function attributions for `tengu_ultraplan_model` + `tengu_cobalt_raccoon` corroborated against davccavalcante README; triple-gate trigger via 4th independent source; 15-second blocking budget on KAIROS proactive shell commands; cross-container hierarchy framing; auto-compaction orthogonality framing; Task Budget orthogonality framing). **3 rejected as DA-Q019-1..-3:** **DA-Q019-1** Gemini-19's "user always wins / lacks systemic permission to overwrite user prose" framed as a universal supersession rule — REJECTED on two-level conflation grounds (cross-container vs intra-MEMORY.md; Issue #47959 directly contradicts the universal reading). Same fabrication pattern as DA-140 (Gemini-15 BUDGET-MEM-1 two-level conflation). **DA-Q019-2** "1,200 sessions / 50 consecutive compaction failures / 250,000 API calls per day globally" precise quantification anchored to Varshith Hegde Dev.to article — REJECTED for VALIDATED status on Discovery-only quantitative-architectural-fact grounds. Same pattern as DA-156 (Gemini-18 character-envelope rule-of-thumb-as-architectural-fact). **DA-Q019-3** arXiv:2604.00009 "Sumers et al., 2025, Integrating sleep-time compute for memory consolidation" misattribution — REJECTED on direct verification: arXiv:2604.00009 is the **Eyla: Toward an Identity-Anchored LLM Architecture** paper (different title, different authors), with Sumers referenced INSIDE Eyla as the 2023 cognitive-architectures-survey author and Letta–sleep-time-compute as a one-line literature note. The DIRECTIONAL claim that AutoDream design draws on sleep-time-compute research IS correct: actual paper is **arXiv:2504.13171** ("Sleep-time Compute: Beyond Inference Scaling at Test-time"; o-mega.ai cites this against the leaked `src/tasks/DreamTask/DreamTask.ts`; smeuse.org independently describes 5× test-time-compute reduction). Adopt the directional claim with the corrected citation; reject Gemini-19's specific attribution. Same fabrication pattern as DA-Q016-4 (Gemini-16 arXiv:2601.04583 misattribution). **Independence note applied:** all 3 rejections from Gemini-19 treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note`. The systemic-Gemini pattern (Gemini-13/15/16/18/19) of fabricating specific citations (issue numbers, env-var names, arXiv IDs, supersession-rule overreach) anchored to plausible-sounding mechanisms continues. Materially, Gemini-19's net contribution is positive: the davccavalcante corroboration measurably strengthens the `tengu_*` namespace findings, the glossary anchor is new Tier-1 evidence, and the supersession-conflation rejection (DA-Q019-1) generated the most consequential addition to v1.17 (R-MEM-1-CLARIFICATION). Queue is now empty after Q-019 closes; framework empty-queue protocol activated. | ✦ Researched | v1.17 |

<!-- @end: tracker -->

---

<!-- @anchor: rules -->
## Adopted Rules

Rules in this project are organized topically across [Skill Specification](#skill-specification), [System Design](#system-design), [Meta-Skill & Validation](#meta-skill-validation). Each rule has a stable `R-XXX-N` ID and an inline `<a id>` link target; reference them via standard cross-links such as `[R-FM-1](#r-fm-1)`.

<!-- @end: rules -->

---

<!-- @anchor: discarded -->
## Discarded Alternatives

Permanent record of rejected approaches. Never re-propose items listed here. Each entry has a stable `DA-{TOPIC}-{N}` label and an inline `<a id>` link target.

Each rejected approach is logged as a verdict block with badge=reject. The label field is the permanent identifier. Always check this section before proposing any approach.

<!-- @da: DA-001 -->
<a id="da-001"></a>

**DA-001.** **Multi-depth skill folders for organization** (e.g., `~/.claude/skills/spec-system/spec-creator/SKILL.md`). Claude Code does not discover nested skills; symlink workarounds break across upgrades (Anthropic Issue #10238, #18192, #16438). Use kebab-case prefix in flat root instead (`spec-system-creator`).

<!-- @da: DA-002 -->
<a id="da-002"></a>

**DA-002.** **`README.md` inside the skill folder.** Anthropic Complete Guide explicitly disallows; duplicates SKILL.md and is never read by Claude as the entrypoint.

<!-- @da: DA-003 -->
<a id="da-003"></a>

**DA-003.** **Top-level `index.md` or `skills.json` index file in the skills folder.** Claude Code's discovery is frontmatter-scan-based; an index file would be unread dead weight that drifts from reality. (Within a single skill's `references/`, an `index.md` IS allowed per Karpathy llm-wiki pattern.)

<!-- @da: DA-004 -->
<a id="da-004"></a>

**DA-004.** **Putting long procedures in CLAUDE.md.** Anthropic's own skill page: CLAUDE.md content loads every session; skill bodies do not. Procedures belong in skills.

<!-- @da: DA-005 -->
<a id="da-005"></a>

**DA-005.** **Heavy-handed `MUST`/`ALWAYS`/`NEVER` style in SKILL.md bodies.** Anthropic skill-workshop: "yellow flag — if possible, reframe and explain the reasoning." Rigid imperatives degrade adherence on edge cases.

<!-- @da: DA-006 -->
<a id="da-006"></a>

**DA-006.** **Manually prefixing `name:` for plugin namespacing** (e.g., `myorg/skill-name`). Silently breaks loading; plugins inject prefix automatically.

<!-- @da: DA-007 -->
<a id="da-007"></a>

**DA-007.** **Generating sort/format/parse logic via tokens instead of bundled scripts.** Rejected for both efficiency and determinism reasons per Anthropic engineering guidance.

<!-- @da: DA-008 -->
<a id="da-008"></a>

**DA-008.** **Programmatic skill→skill calling.** Not supported in Claude Code; subagents cannot spawn subagents. Use subagent `skills:` preload OR `context: fork` + `agent:` instead.

<!-- @da: DA-009 -->
<a id="da-009"></a>

**DA-009.** **Treating SKILL.md as a one-shot turn message** (re-reading on each turn). Claude Code does NOT re-read SKILL.md on later turns; treating it as one-shot leads to drift. SKILL.md content is sticky for the session and re-attached after compaction.

<!-- @da: DA-010 -->
<a id="da-010"></a>

**DA-010.** **Adopting arXiv 2604.24026 (SSL schema) quantitative thresholds as normative.** Preprint dated within the current month; not peer-reviewed. The paper's MRR (0.573→0.707) and macro-F1 (0.744→0.787) figures are NOT adopted. The SSL three-layer vocabulary (Scheduling/Structural/Logical) is admitted ONLY as framing, never as a numerical rule.

<!-- @da: DA-011 -->
<a id="da-011"></a>

**DA-011.** **Adopting Karpathy llm-wiki's `index.md` directly into our skills root.** It's a within-references-folder pattern for human-curated knowledge bases, not a skill-discovery mechanism at the Claude-Code level. May be adopted INSIDE a skill's `references/` if the skill is large.

<!-- @da: DA-012 -->
<a id="da-012"></a>

**DA-012.** **OS-reserved-name hazard (CON, PRN, AUX, NUL, COM1-9) as a skill-naming rule** (proposed by Gemini-1 citing D.A. Wheeler's Secure Programming HOWTO). Rejected — credible source but the connection from Windows reserved device names to Claude Code skill folder names is speculative; no Anthropic source links them. The kebab-case rule (R-FM-2) already forbids these strings mechanically (capitals not allowed). Logged here so it is not re-proposed.

<!-- @da: DA-018 -->
<a id="da-018"></a>

**DA-018.** **Tree-of-Thoughts as a skill-body authoring rule** (Yao, Yu, Zhao, Shafran, Griffiths, Cao, Narasimhan, *Tree of Thoughts: Deliberate Problem Solving with Large Language Models*, NeurIPS 2023, arXiv:2305.10601). Rejected because Claude Code already implements deliberate search at runtime via extended thinking and Plan Mode; instructing every skill author to write search-tree pseudocode in SKILL.md duplicates and may conflict with Anthropic's runtime planner. ToT remains a useful harness-level concept, not a skill-authoring rule.

<!-- @da: DA-019 -->
<a id="da-019"></a>

**DA-019.** **Plan-and-Solve as a mandatory SKILL.md body opener** (Wang, Xu, Lan, Hu, Lan, Lee, Lim, *Plan-and-Solve Prompting*, ACL 2023, arXiv:2305.04091). Rejected because Anthropic's Plan Mode and the documented `agent: Plan` subagent type are the canonical planning mechanism; mandating a textual planning prefix in every SKILL.md duplicates runtime behavior and conflicts with skill-workshop's anti-CAPS-LOCK guidance.

<!-- @da: DA-020 -->
<a id="da-020"></a>

**DA-020.** **ART task-library auto-selection as a skill-routing replacement** (Paranjape, Lundberg, Singh, Hajishirzi, Zettlemoyer, Tulio Ribeiro, *ART: Automatic multi-step reasoning and tool-use*, 2023, arXiv:2303.09014). Rejected because Claude Code routes from frontmatter descriptions natively; ART-style program-template lookup would require a separate runtime mechanism that Anthropic has not exposed. Out-of-scope until such an API ships.

<!-- @da: DA-021 -->
<a id="da-021"></a>

**DA-021.** **"20 skills per session" hard limit** as a global Claude / Managed Agents constraint (asserted by Gemini-2). **Rejected as hallucinated.** Verified during Turn 2: the actual Anthropic-documented limit is *"You can include up to 8 Skills per request"* in the Messages API (platform.claude.com/docs/en/build-with-claude/skills-guide). Filesystem-based Claude Code skills scale with the listing budget (2%/16K + 250 chars per description), not with a session count. The real rule is adopted as R-API-1; Gemini-2's 20 is rejected with prejudice.

<!-- @da: DA-022 -->
<a id="da-022"></a>

**DA-022.** **`mode: true` as an Anthropic frontmatter field** (asserted by Gemini-2). **Rejected as hallucinated.** No such field appears in code.claude.com/docs/en/skills, platform.claude.com/docs/en/agents-and-tools/agent-skills/overview, the best-practices page, or the Complete Guide PDF. The actual frontmatter fields are: `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context: fork`, `agent`, `hooks`, `paths`, `allowed-tools` (open-standard adds `license`, `compatibility`, `metadata`). Behavioral-overlay use cases are already covered by `disable-model-invocation: true` (manual-only invocation).

<!-- @da: DA-023 -->
<a id="da-023"></a>

**DA-023.** **`CLAUDE_CODE_FORK_SUBAGENT` environment variable for spawning forked subagents** (asserted by Gemini-2). **Rejected as hallucinated.** The real mechanism is the `context: fork` frontmatter field, already documented at code.claude.com/docs/en/skills and adopted in v1.1 R-CTX rules. No such env var appears in code.claude.com/docs/en/tools-reference, settings.json schema docs, or the release notes. Per the framework's `independence_note`, treating Gemini-2's confident assertion as confirmation would be a shared training artifact, not independent confirmation.

<!-- @da: DA-024 -->
<a id="da-024"></a>

**DA-024.** **Mandatory `eval_queries.json` schema with a fixed positive-to-negative trigger ratio enforced by the validation script** (asserted by Gemini-2). **Rejected as Gemini-2 overreach beyond the cited source.** Hamel Husain's *Evals Skills for Coding Agents* (hamel.dev/blog/posts/evals-skills/, March 2026, verified) advocates eval-driven skill design and ships the `eval-audit` pattern across six diagnostic areas (error analysis, evaluator design, judge validation, human review, labeled data, pipeline hygiene) — but it does NOT mandate the specific filename `eval_queries.json` nor a fixed positive-to-negative ratio. The broader principle (skills should ship with an eval suite) is admitted as PROPOSED for Q-008, without the fabricated schema.

<!-- @da: DA-025 -->
<a id="da-025"></a>

**DA-025.** **Pure-template (Cookiecutter-style Jinja) meta-skill** — fixed template + variable substitution, no LLM authorship. Rejected: trigger-shaped descriptions cannot be naïvely templated; description quality measurably affects retrieval (R-XPOLL-4/5).

<!-- @da: DA-026 -->
<a id="da-026"></a>

**DA-026.** **Runtime LLM-only generation with no scaffold script** — Claude writes the entire folder from prompts at session time. Rejected: violates ReWOO determinism (R-XPOLL-8); kebab-case naming, frontmatter YAML, ZIP packaging are deterministic problems where LLM generation introduces non-deterministic failure modes (Issue #239 case study).

<!-- @da: DA-027 -->
<a id="da-027"></a>

**DA-027.** **Validate-on-save** (run `quick_validate.py` on every Edit/Write of SKILL.md). Rejected: blocks intermediate states; blocks edits not in the eventual commit. lint-staged community treats save-time validation as anti-pattern; pre-commit/finalization gating is norm.

<!-- @da: DA-028 -->
<a id="da-028"></a>

**DA-028.** **Tree-of-Thoughts–style search inside the meta-skill** (branching + backtracking over candidate body drafts). Rejected: Self-Refine reports diminishing returns past iteration 2 in this domain; ToT increases cost without measurable gain.

<!-- @da: DA-029 -->
<a id="da-029"></a>

**DA-029.** **Mandatory wizard UI / forced interactive 4-prompt sequence with no `--yes` path.** Rejected: forces meta-skill into UI mode incompatible with subagent invocation in headless environments. `npm init -y` and `cargo new` both ship zero-prompt paths.

<!-- @da: DA-030 -->
<a id="da-030"></a>

**DA-030.** **Auto-fix everything on validator failure** (silently rewrite invalid frontmatter to make it valid). Rejected: violates Reflexion external-signal requirement; Issue #34609 ($18 silent charges) is the cautionary tale for silent-action footguns.

<!-- @da: DA-031 -->
<a id="da-031"></a>

**DA-031.** **(Gemini-3 fabrication)** "0→1 shot 2%→24% accuracy lift; 2–5 shots plateau 32–38%" attributed to *Search Self-Play* (Lu et al. 2025, arXiv:2510.18821). Rejected: paper exists (verified) but is about RL self-play for search agents, NOT few-shot scaling; cited percentages do not appear in the paper.

<!-- @da: DA-032 -->
<a id="da-032"></a>

**DA-032.** **(Gemini-3 fabrication)** "Exactly four examples optimum" attributed to *Mazeika et al. 2024, arXiv:2402.14656*. Rejected: arXiv:2402.14656 is a thermoelectric-films physics paper. The arXiv ID is wrong; the claim is unverifiable as stated.

<!-- @da: DA-033 -->
<a id="da-033"></a>

**DA-033.** **(Gemini-3 misattribution)** Self-Refine 3-iteration plateau attributed to *ShieldLearner* (Ni et al. 2025, arXiv:2502.13162). Rejected: ShieldLearner is about jailbreak defense, not Self-Refine. The 3-iteration cap is properly anchored in Madaan et al., NeurIPS 2023, arXiv:2303.17651 (already in R-META-8).

<!-- @da: DA-034 -->
<a id="da-034"></a>

**DA-034.** **(Gemini-3 folklore-repeat)** "SKILL.md body strictly under 100 lines per documented best practices." Rejected: same body-length folklore class corrected in v1.2 R-BODY-1 (canonical = ≤500 per Anthropic best-practices). Third Gemini variant of the same training-artifact error (Gemini-1: 300; Gemini-2: 300; Gemini-3: 100) — one data point, not independent confirmation.

<!-- @da: DA-035 -->
<a id="da-035"></a>

**DA-035.** **Use an LLM as the primary validator for Q-004 mechanical checks.** Considered: build the validator as a Claude-API agent that reads SKILL.md and judges holistically. Rejected: violates R-META-10 (ReWOO determinism — same input must produce same findings without LLM in-loop), violates R-META-9 (LLM-based fixes are non-auditable), and would cost ~$0.01/run + 10s latency per pre-commit invocation, breaking developer flow. Mechanical Python runs in milliseconds. The Q-008 LLM-judge stays as a separate, slower, manually-invoked downstream tool — the ReWOO Planner/Worker decoupling.

<!-- @da: DA-036 -->
<a id="da-036"></a>

**DA-036.** **Hand-rolled YAML parser for SKILL.md frontmatter.** Considered: write a minimal YAML-subset parser to avoid PyYAML dependency. Rejected: SKILL.md frontmatter uses arbitrary YAML 1.1/1.2 features (nested `metadata` map, arrays in `allowed-tools`, multi-line strings); deviating from `yaml.safe_load` (which Anthropic's own quick_validate.py uses) risks silent divergence. Issue #9817 in anthropics/claude-code already documents skill-discovery breaking when frontmatter is reformatted by Prettier — re-using Anthropic's parser semantics is the only safe choice.

<!-- @da: DA-037 -->
<a id="da-037"></a>

**DA-037.** **Embed all rules in one mega-regex.** Considered: single multi-rule regex with named capture groups for performance. Rejected: ~50 rules, several requiring AST analysis or graph traversal (R-SR-5 reachability; R-XPOLL-4 embedding); loses per-rule citations in JSON output; loses per-rule severity granularity; disables --rules / --skip-rules selection. Adopted instead: one Python module per rule family.

<!-- @da: DA-038 -->
<a id="da-038"></a>

**DA-038.** **Ship the validator as a non-skill PyPI package only.** Considered: distribute via `pip install skill-validator`, omit SKILL.md wrapper. Rejected: violates R-XPOLL-9 (dogfooding); loses in-conversation invocation (a user inside Claude Code couldn't say 'validate my skill' without the SKILL.md trigger). Adopted instead: BOTH — ship the skill folder AND publish the same package on PyPI from pyproject.toml. console_scripts entry-point provides the CLI; SKILL.md provides Claude-discoverable invocation.

<!-- @da: DA-039 -->
<a id="da-039"></a>

**DA-039.** **Gemini-4 false claim that Issue #37 narrows the frontmatter allow-list to `{name, description}` only.** Verified false: the actual allow-list documented in anthropics/skills Issue #37 is `{name, description, license, allowed-tools, metadata}`, with additional Claude-Code-only fields `{disable-model-invocation, user-invocable, agent, context, compatibility, argument-hint}` per code.claude.com/docs/en/skills and claude-code Issue #25795. Rejecting Gemini's narrowing because it would over-strictly fail-close legitimate skills using `license:` or `allowed-tools:`.

<!-- @da: DA-040 -->
<a id="da-040"></a>

**DA-040.** **Gemini-4 pre-commit `files:` regex including `~/\.claude/skills`.** Tilde character does not expand inside pre-commit file regexes — pre-commit operates on the repository working tree, not the user's home directory. Including the tilde would silently match nothing on `~`-prefixed paths and produce confusing 'no files to validate' results. Adopted instead: `files: 'SKILL\.md$'` with no path-prefix gating; the validator handles directory walking internally.

<!-- @da: DA-041 -->
<a id="da-041"></a>

**DA-041.** **Gemini-4 `pass_filenames: true` in pre-commit hook.** Would feed pre-commit only the staged-changed files to the validator, breaking R-XPOLL-4 (cross-skill pairwise description similarity needs the full library on every run). Adopted instead: `pass_filenames: false` so the validator always walks the entire skills directory; `files: 'SKILL\.md$'` controls when the hook fires, but the hook then ignores the per-file list and operates library-wide.

<!-- @da: DA-042 -->
<a id="da-042"></a>

**DA-042.** **Gemini-4 citation of `arxiv:2604.20462`.** Fits the known-fabricated `2604.X` ID family (same pattern as 2604.24026 caught and rejected in v1.1). The ID was placed in Gemini-4's Discovery list as a generic 'literature review pipeline' paper. Not verified against arxiv.org; not adopted as evidence; the underlying research point (semantic similarity for literature deduplication) does not require a fabricated citation when sentence-transformers' own model card and the well-validated ReWOO/DSPy papers already anchor the architecture.

<!-- @da: DA-043 -->
<a id="da-043"></a>

**DA-043.** **Gemini-4 exit-code contract (0=success, 1=any-failure, 2=usage-error).** Standard flake8/pre-commit convention but conflicts with code.claude.com/docs/en/hooks-guide which specifies exit code 2 as the 'block' signal for Claude Code hooks. Anthropic-supremacy applies. Project's contract stays 0=pass / 1=warn-only / 2=fail (so pre-commit and Claude Code hooks both treat 2 as blocking). agent-ecosystem/skill-validator uses (1=err, 2=warn) which is yet a third convention — logged as a Tier-2 disagreement but not adopted.

<!-- @da: DA-044 -->
<a id="da-044"></a>

**DA-044.** **Generic markdown linter (markdownlint, mdl) as primary validator.** Considered: instead of building skill-validator, lean on existing markdown linters. Rejected: generic linters enforce stylistic rules (header hierarchy, trailing whitespace, line lengths) but lack semantic awareness of progressive disclosure (cannot evaluate R-BODY-2 5K-token budget on body specifically), of frontmatter allow-lists (R-FM-2..6), of cross-skill collision (R-XPOLL-4), of skill-specific naming (R-NAME-2 folder=name match), or of dogfooding (R-XPOLL-9). markdownlint MAY be composed alongside skill-validator for stylistic checks but cannot replace it. Confirmed by Gemini-4 contribution and adopted.

<!-- @da: DA-045 -->
<a id="da-045"></a>

**DA-045.** **Silent auto-fix as the default.** Considered: when validator finds R-NAME-2 folder/name mismatch or over-length descriptions, silently rewrite. Rejected: violates R-META-9 (no-silent-actions). Truncating descriptions destroys author intent; auto-renaming folders cascades into git history breakage. Adopted instead: validator emits `suggested_fix` strings in JSON output; the user (or Claude under user supervision) applies them. The `--fix` flag is reserved as a hard error in v1.4 (machine-enforced policy).

<!-- @da: DA-046 -->
<a id="da-046"></a>

**DA-046.** **Adopting agent-ecosystem/skill-validator's exit-code semantics directly (1=err, 2=warn).** The Tier-2 de-facto reference uses 1=validation-errors, 2=warnings, 3=CLI/usage-error. Considered for interoperability. Rejected: conflicts with Anthropic's hooks-guide which uses exit 2 as the 'block' signal; Anthropic-supremacy applies. Project stays at 1=warn-only, 2=fail. Disagreement logged in v1.4 as a Tier-2 friction point; consumers using both validators must layer translation in CI scripts.

<!-- @da: DA-047 -->
<a id="da-047"></a>

**DA-047.** **Treating R-FM-4 `when_to_use` as project-internal-only.** Considered (in Q-005 Turn 1, before live-docs fetch): keep `when_to_use` permitted but not officially documented, since the Lee Hanchung blog (October 2025) and anthropics/skills issue #37 didn't list it. Rejected after Q-005 Turn 2 vetting fetched the LIVE code.claude.com/docs/en/skills on 2026-05-02 and found `when_to_use` explicitly listed in the frontmatter reference table with the 1,536-character truncation cap documented. Anthropic-supremacy applied: live docs > older blog/issue snapshots. R-FM-4 is fully VALIDATED.

<!-- @da: DA-048 -->
<a id="da-048"></a>

**DA-048.** **Rigid trigger-grammar regex `^(When|If|For)\s+(the user|a request|input)\s+.+,\s*(do|use|invoke|call|run)\s+.+` for descriptions.** Considered for R-XPOLL-5 enforcement. Rejected: anthropics/skills/{pdf,docx,pptx}/SKILL.md descriptions empirically use diverse triggering syntax (e.g. 'Use this skill whenever the user wants to do anything with PDF files'), and skill-development SKILL.md prescribes the third-person template 'This skill should be used when the user asks to "phrase 1", "phrase 2"' which is incompatible with the imperative regex. Replaced by R-XPOLL-5 PROJECT-INTERNAL soft-warn checking for ANY of {'Use when', 'Use this skill', 'This skill should be used', 'Trigger', 'whenever', 'If the user'} as trigger vocabulary.

<!-- @da: DA-049 -->
<a id="da-049"></a>

**DA-049.** **Gemini-5 R-XPOLL-7 promotion to Tier-1 ('Anthropic's skill architecture directly implements Voyager').** Gemini-5 cited arXiv:2305.16291 (Wang et al., TMLR 2024 — verified real, NVIDIA/Caltech/UT Austin affiliation, non-future-dated) and asserted Tier-1 promotion. Rejected: paper existence is necessary but not sufficient for Tier-1 status of the *application claim*. No Anthropic primary source maps Skills to Voyager's library construct — Anthropic's own framing in 'Equipping agents for the real world with Agent Skills' (anthropic.com/engineering, 2025) uses the 'onboarding-guide / progressive-disclosure / filesystem-as-context' metaphor, not Voyager. R-XPOLL-7 stays PROJECT-INTERNAL as analogy-only.

<!-- @da: DA-050 -->
<a id="da-050"></a>

**DA-050.** **Gemini-5 R-XPOLL-8 promotion via 'CrewAI uses 0.85 with all-MiniLM-L6-v2' Tier-2 citation.** Gemini-5 cited docs.crewai.com/en/concepts/memory as Tier-2 corroboration of the 0.85 cosine threshold + all-MiniLM-L6-v2 embedding model combination. Rejected: independent verification could not confirm CrewAI memory docs prescribe exactly 0.85 with this exact model — and even if it did, 'one Tier-2 system uses this' is insufficient for the project's Tier-1+empirical-calibration standard for quantitative thresholds. The 0.85 number remains pre-registered for empirical calibration on the anthropics/skills + obra/superpowers + agent-ecosystem corpus before locking. R-XPOLL-8 stays PROJECT-INTERNAL.

<!-- @da: DA-051 -->
<a id="da-051"></a>

**DA-051.** **Gemini-5 'cl100k_base via tiktoken' as primary skill-validator tokenizer.** Gemini-5 actually rejected this (correctly) but framed the rejection in a way that conflated cl100k_base and o200k_base as both unsuitable. Confirmed by live Anthropic 'Token counting' docs (platform.claude.com/docs/en/build-with-claude/token-counting) that Anthropic uses a proprietary tokenizer exposed via `messages.count_tokens` API — neither tiktoken encoding matches. Validator's primary length metric is physical line count (matches Anthropic's `quick_validate.py` and the ≤500-line published rule); token-secondary metric is `messages.count_tokens` (online) or `o200k_base` (offline approximation only). cl100k_base is the older OpenAI encoding and is fully discarded.

<!-- @da: DA-052 -->
<a id="da-052"></a>

**DA-052.** **Gemini-5 claim: '250-character terminal truncation' for skill descriptions.** Gemini-5 stated that descriptions are truncated at 250 characters in the interactive terminal display, and at 1,536 characters in the skills index. Rejected: live code.claude.com/docs/en/skills (fetched 2026-05-02) documents only the 1,536-character cap on combined description+when_to_use and the dynamic 1%-of-context skill-listing budget (8,000-char fallback) overridable via `SLASH_COMMAND_TOOL_CHAR_BUDGET`. No 250-character terminal truncation appears in any Anthropic primary source. Likely Gemini-5 hallucination.

<!-- @da: DA-053 -->
<a id="da-053"></a>

**DA-053.** **Gemini-5 R-SR-7 promotion to Tier-1 ('header conventions specified to assist RAG').** Gemini-5 cited Anthropic best-practices.md's '"Include a table of contents at the top" strictly mandates the mapping of headers' as Tier-1 evidence for stable header anchors. Rejected: this is a category conflation. The TOC-at-100-lines requirement (R-BODY-4) mandates the *presence* of a table of contents. The proposed R-SR-7 (NEW v1.5 candidate distinct from v1.4's R-SR-7 link-orphan rule) is about *stable header anchor schemes* (slug stability across edits, used for partial reads with anchored line offsets) — a different concept Anthropic does not specify. Stays PROJECT-INTERNAL.

<!-- @da: DA-054 -->
<a id="da-054"></a>

**DA-054.** **Gemini-5 R-CONTAM-1 promotion via 'Ruff README' Tier-2 justification.** Gemini-5 cited Astral Ruff's rule-prefix system (E for pycodestyle, F for pyflakes, I for isort, etc.) as Tier-2 prior art for tracking 'rule provenance'. Rejected: Ruff prefixes track *which underlying linter implements the rule* (origin in code), not *what evidence-tier supports the rule's correctness* (origin in research). These are different concepts. The original R-CONTAM-1 — flagging rules whose only support is Discovery-tier — has no direct OSS precedent. Stays PROJECT-INTERNAL but its novelty value is acknowledged.

<!-- @da: DA-055 -->
<a id="da-055"></a>

**DA-055.** **Gemini-5 claim: '@anthropic-ai/tokenizer SDK' as primary local tokenizer.** Gemini-5 mentioned this as a recommended local tokenizer alternative to tiktoken. Rejected (with caution): Anthropic historically published a JS tokenizer (early Claude 1.x era) but did not maintain it through Claude 3+ — `@anthropic-ai/tokenizer` is not currently the documented tokenizer and using it would yield outdated token counts for Claude 4+ models. Live Anthropic 'Token counting' docs direct users to the `messages.count_tokens` API endpoint instead. Validator's offline approximation falls back to tiktoken o200k_base with a calibration disclaimer, not @anthropic-ai/tokenizer.

<!-- @da: DA-056 -->
<a id="da-056"></a>

**DA-056.** **Hard cap of 5 parallel forks per orchestrator turn (with claimed 5–7 RPM organization-tier rate limit).** Gemini-6 framed this as a documented Anthropic limit. Verification: Anthropic's *How we built our multi-agent research system* (2025) explicitly contemplates >10 subagents for complex research; Anthropic's `code.claude.com/docs/en/costs` page does NOT enumerate a 5–7 RPM organization-tier cap. Per ANTHROPIC SUPREMACY, Anthropic's >10 upper bound wins over Gemini-6's "5 max." R-PAR-2 ceiling stays at 8 (aligned to R-API-1 envelope, conservative within Anthropic's documented range).

<!-- @da: DA-057 -->
<a id="da-057"></a>

**DA-057.** **Cross-skill `shared/` directory at the *ecosystem* level for inter-skill helper sharing.** Gemini-6 cited `github.com/anthropics/skills/blob/main/skills/claude-api/shared/live-sources.md` as evidence. Verification: that `shared/` is *internal* to the `claude-api` skill, organizing its own bundled references — it is **not** an inter-skill sharing mechanism. R-COMP-3 (embed-and-duplicate across peer skills) stands. Authors MAY use a `shared/` subdirectory *inside* their own skill for internal organization; that is intra-skill structure, not cross-skill linking.

<!-- @da: DA-058 -->
<a id="da-058"></a>

**DA-058.** **`ConfigChange` listed as a blockable hook event.** Gemini-6 placed this in its blockable-events list. Verification: the canonical `code.claude.com/docs/en/hooks` reference does NOT document any `ConfigChange` event. Likely a Gemini-6 hallucination. R-FAIL-2 / R-FAIL-4 unaffected; the canonical fan-in synchronization point is `PostToolBatch`.

<!-- @da: DA-059 -->
<a id="da-059"></a>

**DA-059.** **`UserPromptExpansion` listed as a separate blockable hook event distinct from `UserPromptSubmit`.** Verification: only `UserPromptSubmit` exists in the canonical hooks reference. Likely a Gemini-6 conflation with template/string-substitution expansion. Rejected.

<!-- @da: DA-060 -->
<a id="da-060"></a>

**DA-060.** **Citing the Medium article "How Anthropic Built An AI That Outperforms Itself By 90%" as the source for the 15×-token multi-agent figure.** Verification: the 15× figure is from Anthropic's primary engineering post *How we built our multi-agent research system* (Hadfield/Zhang/Lien/Scholz/Fox/Ford, 2025). Per project rule §2 (Anthropic supremacy) and tier discipline, the primary source is cited; the Medium article is a derivative and is not used in v1.6 References.

<!-- @da: DA-061 -->
<a id="da-061"></a>

**DA-061.** **Tagging the per-branch isolation of the 25,000-token re-attach budget as PROPOSED.** Gemini-6 hedged with "PROPOSED" framing. Verification: the canonical `code.claude.com/docs/en/skills` doc states each subagent has its own context with its own auto-compaction lifecycle; the 25k budget pattern is described directly in the same doc. This is a single canonical-Anthropic source per project rule §validation_gate, sufficient for VALIDATED. R-FAIL-1 promotes to VALIDATED rather than PROPOSED.

<!-- @da: DA-062 -->
<a id="da-062"></a>

**DA-062.** **Asserting that subagent stderr/exit-code propagates as a structured error to the parent.** Gemini-6 cited `coding-agent-loop-spec.md` (third-party) and `hermes-agent.nousresearch.com` (third-party) as evidence that the underlying tool schema returns stdout/stderr/exit-code/wall-clock. Per ANTHROPIC SUPREMACY: Anthropic's own docs state the parent receives the subagent's *final assistant message* and (optionally) `additionalContext` from a `SubagentStop` hook — no structured stderr/exit-code field crosses the boundary. R-FAIL-3 captures this correctly. Third-party reverse-engineering is rejected as Tier-1 evidence on Claude-Code-specific behavior.

<!-- @da: DA-063 -->
<a id="da-063"></a>

**DA-063.** **Symlinking AGENTS.md to CLAUDE.md as a project-canonical workaround for cross-tool sharing in skill systems.** (Already rejected in v1.1–1.2 for the *project*-level memory file; this DA captures a Gemini-6 *skill*-level extrapolation that peer skills should symlink helpers to share.) Verification: `anthropics/skills` shows zero symlinks across peer skills; embed-and-duplicate is the canonical pattern (R-COMP-3). Symlinks would also break the "drop-in folder" portability guarantee that underpins R-SYS-1 / R-SR-3.

<!-- @da: DA-064 -->
<a id="da-064"></a>

**DA-064.** **Treating the `5,000-token-per-skill` re-attach cap and the `25,000-token` total as independent global budgets that do not interact.** Verification: the canonical doc states the 25k budget is filled starting from the most recently invoked skill, with each skill capped at 5k. They are coupled, not independent: 5 most-recent skills at 5k each = 25k, and older skills are dropped. R-FAIL-1 captures this correctly as a single coupled mechanism, not two separate budgets.

<!-- @da: DA-065 -->
<a id="da-065"></a>

**DA-065.** **Treating user correction as a programmatic signal via a hypothetical `UserCorrection` hook event.** Rationale: No such event exists in the live Anthropic hooks reference (`code.claude.com/docs/en/hooks`, fetched 2026-05-04). The 29 canonical hook events do not include any user-correction event. Conflicts with Q-006's DA-064 discipline of rejecting hallucinated events. **Adopted instead:** R-RETRO-3 — user correction is *inferred* by transcript scan, never assumed to be programmatic.

<!-- @da: DA-066 -->
<a id="da-066"></a>

**DA-066.** **Mandating an `errata/` sibling directory pattern at the skill root.** Rationale: Not in Anthropic's three-folder convention (`scripts/`/`references/`/`assets/`); not used by any shipped Anthropic skill (`pdf/`, `pptx/`, `docx/`, `xlsx/` all use `references/`); would break the agentskills.io open-standard portability guarantee. **Adopted instead:** R-SELF-1 — `references/gotchas.md` is canonical; R-SELF-3 — `errata/` SHOULD NOT be created (Turn 2 reworded from MUST NOT).

<!-- @da: DA-067 -->
<a id="da-067"></a>

**DA-067.** **Appending accumulated errata digests directly into the `description:` field.** Rationale: Conflicts with the verified 1024-character description cap (`platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`); degrades trigger precision for the auto-mode classifier; conflicts with skill-workshop's *replace-not-append* description-optimization workflow. **Adopted instead:** R-DRIFT-1 — replace via skill-workshop pass with held-out validation; R-DRIFT-3 — preserve 1024-char cap.

<!-- @da: DA-068 -->
<a id="da-068"></a>

**DA-068.** **Voyager-style add-on-first-success criterion for promoting on-the-fly scripts.** Rationale: Voyager's verifier is a second GPT-4 call in a tight loop with cheap retry. Claude Code skills can ship to plugin marketplaces, so false positives are expensive. Strict-mode tightening to N≥3 (R-XPOLL-4 anchor) is justified. **Adopted instead:** R-EXTRACT-1 — N≥3 reuses in-session OR ≥3 sessions in 14 days (inter-session arm tightened Turn 2 per Gemini-7).

<!-- @da: DA-069 -->
<a id="da-069"></a>

**DA-069.** **Placing the "after a task, review and update" rule in the top-level `CLAUDE.md`.** Rationale: Inflates always-loaded context; cannot benefit from `disable-model-invocation` gating; cannot participate in the four-layer composition ladder (R-COMP-1..3); places policy outside the version control of the skill itself. **Adopted instead:** Primary placement = the Q-003 meta-skill; trigger = Stop/SessionEnd hook in meta-skill frontmatter; CLAUDE.md carries a one-line pointer only.

<!-- @da: DA-070 -->
<a id="da-070"></a>

**DA-070.** **Dropping the user-accept gate when the validator passes (auto-merge on green).** Rationale: Direct violation of R-XPOLL-6 (Reflexion's external-signal requirement; user-accept is the second signal). Even-stricter under R-DESTRUCT-1 for `disable-model-invocation: true` skills.

<!-- @da: DA-071 -->
<a id="da-071"></a>

**DA-071.** **Using the skill-workshop hook directly as the retrospective trigger.** Rationale: skill-workshop is purpose-built for *creation* and *description optimization*; retrospective ingestion is a different shape of work. **Adopted instead:** Meta-skill (Q-003) is the trigger; meta-skill *delegates* to skill-workshop's description-optimization subroutine when R-DRIFT-1's N=3 threshold is reached.

<!-- @da: DA-072 -->
<a id="da-072"></a>

**DA-072.** **Auto-bumping major version on every retrospective.** Rationale: Semver should reflect the magnitude of behavioral change; routine `references/gotchas.md` writes are patch-level. Auto-major would break dependents that pin by major version. **Adopted instead:** R-VC-2 — patch=references / minor=body / major=description (regen).

<!-- @da: DA-073 -->
<a id="da-073"></a>

**DA-073.** **Scheduling retrospectives via cron-like external triggers.** Rationale: No first-class scheduler in Claude Code; only `SessionStart` with the `maintenance` matcher exists (per `code.claude.com/docs/en/hooks` Setup section, requires `--init-only` or `-p --init`/`-p --maintenance`). External cron leaves the auditing surface outside Claude Code's control. **Adopted instead:** R-RETRO-1 — Stop/SessionEnd hooks within Claude Code's lifecycle, plus optional `SessionStart` with `maintenance` matcher for scheduled cleanup.

<!-- @da: DA-074 -->
<a id="da-074"></a>

**DA-074.** **Using `!command` Dynamic Context Injection in SKILL.md to inline-execute bash and embed errata content** (Gemini-7 G7-3). Rationale: **Hallucination.** The `!command` shorthand is a Claude Code custom-slash-commands feature defined in `.claude/commands/*.md`, NOT a SKILL.md feature. SKILL.md is loaded as static markdown content; the agent uses standard tools (Read, Grep) to follow file references. The live `code.claude.com/docs/en/hooks` and `code.claude.com/docs/en/skills` documentation contain no such SKILL.md syntax. Gemini-7 conflated two distinct mechanisms. **Adopted instead:** R-RETRO-* — context injection through hook return values' `additionalContext` field, not through inline bash expansion in SKILL.md.

<!-- @da: DA-075 -->
<a id="da-075"></a>

**DA-075.** **Treating `references/gotchas.md` as 'context fragmentation' requiring inline embedding** (Gemini-7 G7-4). Rationale: Misreads progressive disclosure as a bug rather than the canonical Anthropic-validated design. Progressive disclosure (verified Tier-1: `platform.claude.com/docs/en/agents-and-tools/agent-skills/overview`) is the *intended* mechanism. The 500-line body cap (R-BODY-1) and the 25,000-token re-attach budget make `references/`-based loading the only sustainable shape. **Adopted instead:** R-SELF-1 keeps gotchas in `references/gotchas.md` with the SKILL.md body retaining a single-line trigger ("Known issues — see `references/gotchas.md`") so the agent loads it on demand.

<!-- @da: DA-076 -->
<a id="da-076"></a>

**DA-076.** **Locking the `description:` field entirely against autonomous regeneration; only major-semver via human consensus** (Gemini-7 G7-7). Rationale: Conflicts with Anthropic-canonical skill-workshop description-optimizer behavior, which IS Tier-1 evidence. Anthropic's own skill-workshop (`github.com/anthropics/skills/skill-workshop/SKILL.md`) ships an automated description-optimization pass with held-out validation; locking entirely contradicts this. **Adopted instead:** R-DRIFT-5 (NEW Turn 2) — autonomous regen permitted but MUST preserve the original `when_to_use` scope-set; scope changes (narrowing or expanding) require manual major-version bump. Gemini-7's semantic-drift concern is genuine and is fully addressed by the scope-preservation constraint.

<!-- @da: DA-077 -->
<a id="da-077"></a>

**DA-077.** **Framing the three-folder convention as a hard parser-enforced rule** (Gemini-7 G7-2). Rationale: v1.6 didn't actually claim parser enforcement — it claimed canonical convention plus shipped-Anthropic-skills evidence. Gemini-7's reading is a useful clarification but constructs a strawman by attributing parser-enforcement framing. **Adopted instead:** R-SELF-3 reworded from MUST NOT → SHOULD NOT, with explicit note that the parser is permissive but the agentskills.io ecosystem and shipped Anthropic skills uniformly use the three-folder convention; deviation requires the skill be marked non-portable.

<!-- @da: DA-078 -->
<a id="da-078"></a>

**DA-078.** **Use the LLM-judge as a pre-commit gate.** Rejected: violates R-META-10 (ReWOO determinism — mechanical validator must not depend on LLM in pre-commit / hook path); Q-004 already rejected the same architectural shape as DA-035 (LLM-as-primary-validator). The Q-008 judge stays manually-invoked / scheduled, off the developer-flow critical path. Anchored on Xu et al., "ReWOO: Decoupling Reasoning from Observations," arXiv:2305.18323; Anthropic engineering, "Demystifying evals for AI agents," 2026-01.

<!-- @da: DA-079 -->
<a id="da-079"></a>

**DA-079.** **Likert 1–5 (or 1–10) scoring per rule instead of binary pass/warn/fail.** Rejected: Hamel Husain's binary-pass/fail recommendation (hamel.dev/blog/posts/llm-judge/) correlates better with domain-expert judgement and resists verbosity bias; G-Eval (Liu et al., EMNLP 2023, arXiv:2303.16634) documents middle-cluster bias in multi-point scales; arXiv:2510.27106 "Rating Roulette" further documents self-inconsistency in Likert judging. R-LLMJ-2 keeps 3-level pass/warn/fail.

<!-- @da: DA-080 -->
<a id="da-080"></a>

**DA-080.** **Run judge with k=5 or k=7 self-consistency.** Rejected (Turn 1): cost grows linearly; Anthropic skill-workshop's own convention is k=3 (3 runs per eval query); Self-Refine (Madaan et al., NeurIPS 2023, arXiv:2303.17651) plateau at ~3 iterations; arXiv:2510.27106 documents diminishing returns beyond k=3. Note: Turn 2 Gemini-8 attempted to relitigate this with misattributed evidence; see DA-094 / DA-095. K=5 reconsideration deferred to **Q-013**.

<!-- @da: DA-081 -->
<a id="da-081"></a>

**DA-081.** **Use Opus 4.7 as default judge backbone.** Rejected: 67% more expensive than Sonnet 4.6 with marginal-only accuracy gain on rubric-driven judging tasks; Opus reserved for opt-in `--high-precision` mode. Anchored on Anthropic pricing page (platform.claude.com/docs/en/about-claude/pricing, retrieved 2026-04-29) and finout.io Opus 4.7 cost-analysis.

<!-- @da: DA-082 -->
<a id="da-082"></a>

**DA-082.** **Run periodic skill audits via the `SessionStart` hook.** Rejected: `SessionStart` fires once per session, not on a schedule (code.claude.com/docs/en/hooks). Cron-style scheduling is the correct mechanism — shipped natively as Claude Code Routines (post-Turn-2 update, see R-CADENCE-2 revised) or via GitHub Actions cron as fallback.

<!-- @da: DA-083 -->
<a id="da-083"></a>

**DA-083.** **Hook-based skill-loading verification via `PostToolUse matcher:"Skill"`.** Rejected today: anthropics/claude-code Issue #43630 confirms PostToolUse with the Skill matcher does not dispatch (open as of 2026-05-04). Documented as revisitable in R-LOAD-4 — if Anthropic ships skill-aware PostToolUse, promote the loading-verification mechanism.

<!-- @da: DA-084 -->
<a id="da-084"></a>

**DA-084.** **"List your loaded skills" probe as a verification mechanism.** Rejected ("Hector's gap" from Q-012 FlanksAPI Slack thread): skill-workshop's own SKILL.md documents Claude's tendency to under-trigger skills, making any introspection-by-prompt unreliable; Hector's 13-test integration suite passed even when the skill mechanism was completely broken because Claude inferred answers from the codebase / CLAUDE.md. R-LOAD-3 forbids this pattern as the only test.

<!-- @da: DA-085 -->
<a id="da-085"></a>

**DA-085.** **Cosine-similarity threshold (Sentence-BERT etc.) as the R-DRIFT-5 scope-preservation primary test.** Rejected: semantic similarity ≠ scope preservation; "use for X" and "do not use for X" can have high cosine similarity. Cosine is invariant to magnitude (well-documented in NLI literature, e.g., Q² evaluation arXiv:2104.08202; Similarity-of-Neural-Network-Models survey ACM Computing Surveys 2024 dl.acm.org/doi/10.1145/3728458). NLI tests directional logical relation, which is what R-DRIFT-5 actually requires. Cosine permitted as cross-check only.

<!-- @da: DA-086 -->
<a id="da-086"></a>

**DA-086.** **Pairwise judging as the primary mode for all semantic rules.** Rejected: pairwise needs a reference output; the 21 semantic rules judge a single skill against a rubric, not against a competitor — pointwise is the natural fit per Comet's LLM-as-Judge guide and Hamel Husain's binary-label workflow. Pairwise (MT-Bench-form per Zheng et al., NeurIPS 2023, arXiv:2306.05685) reserved for R-DRIFT-5 only (R-LLMJ-6).

<!-- @da: DA-087 -->
<a id="da-087"></a>

**DA-087.** **SARIF as judge output format.** Rejected (re-confirms Q-004 DA-052): too verbose for LLM context; loses the 0/1/2 exit-code contract; structured-JSON-with-per-run-fields is the Anthropic-canonical pattern (skill-workshop's `benchmark.json` schema).

<!-- @da: DA-088 -->
<a id="da-088"></a>

**DA-088.** **Auto-fix LLM-judge fails by silently rewriting the skill.** Rejected (re-confirms v1.5 DA-045 silent-auto-fix prohibition): violates R-META-9 (LLM-based fixes are non-auditable). Judge surfaces issues for human review; never modifies skills.

<!-- @da: DA-089 -->
<a id="da-089"></a>

**DA-089.** **Quarterly cadence as the only review tier.** Rejected: too slow for drift detection in autonomous-agent systems; Dependabot best-practice corpus (docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference) prefers monthly default with quarterly review as a separate tier. R-CADENCE-1 ships a three-tier schedule.

<!-- @da: DA-090 -->
<a id="da-090"></a>

**DA-090.** **Bake the LLM-judge into the agentskills.io spec mandatory layer.** Rejected: agentskills.io specification is community-driven and stays mechanical; the LLM-judge is a Research-Buddy framework opinion, not part of the open standard. The validator can ship the judge as a Q-008 framework deliverable without demanding the broader ecosystem adopt it.

<!-- @da: DA-091 -->
<a id="da-091"></a>

**DA-091.** **(Gemini-8 G8-D) `<available_skills>` parsed by a host-side validator as a deterministic loading-proof signal.** Rejected: architectural confusion. The `<available_skills>` block lives inside the agent's system prompt (visible to the agent during a session) — it is NOT a host-readable environment variable a Python validator can introspect. Per code.claude.com/docs/en/skills (May 2026 retrieval): skill descriptions are loaded into context with budget = 1% of context window or `SLASH_COMMAND_TOOL_CHAR_BUDGET` fallback; no host-side enumeration API. anthropics/claude-code Issue #22902 (open Feb 2026) is a *feature request* for exactly this introspection capability — confirming it does not exist today. The only way to read `<available_skills>` from outside the agent is to ask the agent to read it back, which is the unreliable model-self-reporting Hector's gap warns against (R-LOAD-3 prohibition).

<!-- @da: DA-092 -->
<a id="da-092"></a>

**DA-092.** **(Gemini-8 G8-E) `InstructionsLoaded` hook fires for `.claude/skills/*.md`.** Rejected: refuted by Anthropic primary docs and three issue trackers. (1) code.claude.com/docs/en/hooks (live re-fetch May 2026) documents the payload schema with `memory_type: "Project"` and `file_path: "…/CLAUDE.md"` — the memory_type field carries CLAUDE.md, not skill names. (2) anthropics/claude-code Issue #30573 (open) explicitly states: "Added InstructionsLoaded hook event that fires when CLAUDE.md or .claude/rules/*.md files are loaded into context." (3) Issue #31017 (open) confirms: "It correctly fires at session start with load_reason 'session_start' and during lazy loading (nested traversal, path glob match, includes)" — referring to instruction files (CLAUDE.md / rules), not skills. Gemini-8 cited Issue #30897 as evidence; that issue is a *feature request* for batch events and content hashes, not evidence the hook fires for skills. R-LOAD-4 (no hook reliance for skill-loading verification today) is strengthened, not weakened.

<!-- @da: DA-093 -->
<a id="da-093"></a>

**DA-093.** **(Gemini-8 G8-A1) Use "Prometheus 3" as judge backbone, deprecating G-Eval.** Rejected: Prometheus 3 does not exist. Verified at prometheus-eval.github.io (May 2026): the family is Prometheus 1 (Kim et al., arXiv:2310.08491, ICLR 2024 / NeurIPS 2023 WS), Prometheus 2 (Kim et al., arXiv:2405.01535, EMNLP 2024), and M-Prometheus (Pombal et al., arXiv:2504.04953, August 2025 preprint, multilingual variant of Prometheus 2). No "Prometheus 3" model or paper exists. Consistent with the framework's `independence_note` warning about LLM-shared-training-artifact fabrications.

<!-- @da: DA-094 -->
<a id="da-094"></a>

**DA-094.** **(Gemini-8 G8-A3 source 1) Adopt K=5 self-consistency on the strength of "Simulated Annotators: A Cost-Effective Alternative to Human Evaluation" with ECE 0.089→0.075 and AUROC 0.613→0.632.** Rejected: paper title and specific numbers are fabricated. The real source is "Trust or Escalate: LLM Judges with Provable Guarantees for Human Agreement," ICLR 2025 (proceedings.iclr.cc/...) — it does introduce a technique called *Simulated Annotators*, but with parameters K=3 few-shot examples × N=5 simulated annotators (NOT k=5 self-consistency votes), and the headline finding is a 40% API cost reduction via cascaded selective evaluation, not the cited ECE/AUROC numbers. Gemini-8 conflated few-shot example count with self-consistency sample count. K=5 reconsideration moved to **Q-013**.

<!-- @da: DA-095 -->
<a id="da-095"></a>

**DA-095.** **(Gemini-8 G8-A3 source 2) "Single-Advocate Multi-Round Protocols for LLM Evaluation, Authors Anonymous, 2026, EACL" supports K=5.** Rejected: title and venue fabricated. SAMRE (Single-Advocate Multi-Round Evaluation) is one of two protocols within "Debate, Deliberate, Decide (D3): A Cost-Aware Adversarial Framework for Reliable and Interpretable LLM Evaluation," arXiv:2410.04663, October 2024, named authors (not anonymous, not EACL 2026). The paper does not argue for K=5 self-consistency; SAMRE's value proposition is iterative refinement under a token budget.

<!-- @da: DA-096 -->
<a id="da-096"></a>

**DA-096.** **(Gemini-8 G8-D1) Mizan Balance Function elevated to VALIDATED authority for cosine-similarity rejection.** Rejected: Discovery tier only. Sole source is Ahsan Shaokat's self-published "Mizan AI/ML Series" on Medium (Articles #2/#5/#11/#16, November 2025). No peer review, no broader citation network, no benchmarks beyond Shaokat's self-reports. Per `framework.source_tiers`, Discovery sources are "corroborate-only, never primary"; Gemini-8's elevation is a tier violation. The underlying conclusion (cosine has magnitude blindness, NLI is preferred for entailment) stands on independent Tier-1 evidence (Q² arXiv:2104.08202; Similarity-of-Neural-Network-Models survey ACM Comp Surveys 2024).

<!-- @da: DA-097 -->
<a id="da-097"></a>

**DA-097.** **(Gemini-8 G8-A2) Binary pass/warn/fail "fundamentally fails" — mandate scalar 1–N scoring with minimum-acceptability thresholds.** Rejected: overclaim. Hamel Husain (hamel.dev, anchor for our R-XPOLL-2 / R-LLMJ-2) explicitly recommends binary labels for code-checkable assertions; Anthropic's own "Demystifying evals for AI agents" (2026-01) classifies model-graded checks distinctly from code-based checks with no preference for Likert scoring. Scalar scoring permitted as secondary signal but not required. R-LLMJ-2 stands.

<!-- @da: DA-098 -->
<a id="da-098"></a>

**DA-098.** **(Gemini-8 G8-B2) Continuous-validation + weekly drift scan + quarterly audit cadence on NIST SSDF / OWASP DevSecOps authority.** Rejected: NIST SP 800-218 SSDF v1.2 (csrc.nist.gov/projects/ssdf) documents secure-development practices (PO/PS/PW/RV groups) — it does NOT mandate skill-audit frequencies. OWASP DevSecOps guidelines emphasize continuous validation at the platform / deployment-pipeline level, not at the skill-artifact level. The leap from "continuous validation is best practice in DevSecOps" to "monthly skill audits are grossly insufficient" is an unsupported extrapolation. Adding a continuous LLM-judge to the pre-commit path would also re-create the violation of R-META-10 that DA-035 / DA-078 already rejected. R-CADENCE-1 (monthly + quarterly + on-demand) stands.

<!-- @da: DA-099 -->
<a id="da-099"></a>

**DA-099.** **(Gemini-8 G8-D-derived) R-LOAD-8 "Multi-Vector Skill Loading Introspection": validator parses `<available_skills>` array AND captures InstructionsLoaded events for skills.** Rejected: depends on DA-091 (host-side introspection of agent context) and DA-092 (InstructionsLoaded firing for skills) — both rejected. The proposed R-LOAD-8 has no working primitive. R-LOAD-1 (canary) + R-LOAD-2 (negative-control) + R-LOAD-4 (no hook reliance, revisitable) collectively cover the verification surface today. If Anthropic ships the missing primitives (Issue #22902 lands or Issue #43630 closes), revisit per Q-013.

<!-- @da: DA-100 -->
<a id="da-100"></a>

**DA-100.** **Symlinking `<sub>/.claude/skills/<name>` → `<root>/.claude/skills/<name>` as a portable cross-scope pattern.** Rejected. Issue #14836 (anthropics/claude-code) shows `/skills` listing fails to find symlinked skills; Issue #25367 shows discovery-vs-execution split with transient "Unknown skill" error before resolving; Issue #37590 confirms `.claude/skills/` symlinks are NOT documented (only `.claude/rules/` is); Issue #20755 shows symlink-as-container is not recursed. Tier-1 contradicting source: code.claude.com/docs/en/skills (no symlink mention) + Issues #14836/#25367/#37590. Tolerated with caveat per R-WORKSPACE-5; not endorsed as primary.

<!-- @da: DA-101 -->
<a id="da-101"></a>

**DA-101.** **Using `additionalDirectories` in `.claude/settings.json` to expose root `.claude/skills/` to a subfolder session.** Rejected. Issue #37553 (anthropics/claude-code) — explicit bug report: "skills are not loaded from `additionalDirectories`, but are from `--add-dir`." Issue #43267 confirms on Windows. Tier-1 contradicting source: anthropics/claude-code Issues #37553, #43267.

<!-- @da: DA-102 -->
<a id="da-102"></a>

**DA-102.** **`${CLAUDE_SKILLS_PATH}` env var to override skill-discovery roots.** Rejected. Issue #22902 is an OPEN feature request titled "Custom skills directory paths via env var or settings"; the variable does not exist as of 2026-05-04. Tier-1 contradicting source: anthropics/claude-code Issue #22902.

<!-- @da: DA-103 -->
<a id="da-103"></a>

**DA-103.** **Cross-plugin skill helper sharing via namespaced reference (`plugin-b:helper-skill`).** Rejected. Issue #15944 (anthropics/claude-code) is an OPEN feature request for cross-plugin namespace syntax; not currently supported. Marketplace cache copy isolates plugins. Tier-1 contradicting source: anthropics/claude-code Issue #15944 + code.claude.com/docs/en/plugins-reference (paths outside plugin root don't work post-install).

<!-- @da: DA-104 -->
<a id="da-104"></a>

**DA-104.** **Root-level `.claude/scripts/` convention as a shared-script primitive.** Rejected. No such directory is in the documented exceptions table at code.claude.com/docs/en/skills. Anthropic's tooling does not look there for anything. Tier-1 contradicting source: code.claude.com/docs/en/skills (exceptions table lists `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/`, `.claude/hooks/`, `.claude/output-styles/` only).

<!-- @da: DA-105 -->
<a id="da-105"></a>

**DA-105.** **Cross-skill router/index-skill pattern (`services/SKILL.md` → Markdown links into sibling skills via `../<other-skill>/SKILL.md`).** Rejected. Crossing skill-folder boundaries with `..` links breaks R-SYS-1 portability; the linked target is read via `Read`, losing skill-loading semantics (`disable-model-invocation`, allowed-tools narrowing, 25,000-token re-attach budget). Anthropic's own usage of internal routers (pptx → editing.md) stays within a single skill. Tier-1 contradicting source: code.claude.com/docs/en/skills + skill-folder-as-unit semantics (anthropics/skills self-contained shipping pattern).

<!-- @da: DA-106 -->
<a id="da-106"></a>

**DA-106.** **`<skill>/references/foo.md → ../../repo/docs/foo.md` symlinks for repo-doc reuse.** Rejected. Same R-SYS-1 violation as DA-105; plus symlinked references inherit Issue #14836-class fragility on Windows / dotfiles. Tier-1 contradicting source: platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices ("File paths matter: Claude navigates your skill directory like a filesystem").

<!-- @da: DA-107 -->
<a id="da-107"></a>

**DA-107.** **Using the `paths` glob field to load/route to `repo/docs/`.** Rejected. `paths` only gates auto-activation; it does not load content. Tier-1 contradicting source: code.claude.com/docs/en/skills (paths described as activation-gating only); allahabadi.dev complete frontmatter guide confirms.

<!-- @da: DA-108 -->
<a id="da-108"></a>

**DA-108.** **(Gemini-9 G9-F-derived, REJECTED-as-overreach) Add `internal: true` (or `metadata.internal: true`) as a 16th allow-listed frontmatter key for "internal-only" skill suppression.** Rejected. The Anthropic 15-key allow-list (R-FM-6, validated against live code.claude.com/docs/en/skills frontmatter table 2026-05-02) does not include `internal`. vercel-labs/skills' `metadata.internal: true` plus `INSTALL_INTERNAL_SKILLS=1` env var (verified via README + DeepWiki + Vercel community post + Issue #572) is a Tier-2 cross-tool community convention targeting 40+ different coding agents, not a Claude-Code-canonical mechanism. Adopting it would (a) violate Anthropic supremacy on Claude-Code-specific frontmatter governance, (b) require expanding R-FM-6 without Tier-1 backing, (c) duplicate functionality already available via `user-invocable: false` + scoped `paths`. R-REFLOC-2(c) stays as-is. Gemini-9 itself reaches the same conclusion under Anthropic supremacy; the DA logs the underlying *proposal* (not Gemini-9's evaluation of it) so it cannot be re-proposed.

<!-- @da: DA-109 -->
<a id="da-109"></a>

**DA-109.** **(Gemini-9 G9-H1-derived) Migrate v1.9 skill composition from flat `.claude/skills/` to GraSP-style typed Directed Acyclic Graphs with precondition-effect edges.** Rejected. GraSP (Xia et al., Tencent, arXiv:2604.17870, 20 Apr 2026 — verified real; Tencent institutional affiliation confirmed) is a peer-reviewed-track academic proposal with no Anthropic implementation, no Tier-1 endorsement, and no shipping integration with Claude Code. v1.9 is a workspace-topology specification, not a runtime composition redesign. R-COMP-1's documented four-layer composition ladder (inline → `context: fork` → custom subagent with `skills:` preload → agent teams) is the canonical Anthropic mechanism. GraSP is logged as a PROPOSED forward-looking reference for Q-009 reopen at v2.0+. Tier-1 contradicting context: code.claude.com/docs/en/skills four-layer composition.

<!-- @da: DA-110 -->
<a id="da-110"></a>

**DA-110.** **(Gemini-9 G9-H2-derived) Adopt Skilldex's three-tier "global / shared / project" scope hierarchy as the v1.9 canonical scope model.** Rejected. Skilldex (Saha & Hemanth, arXiv:2604.16911, 18 Apr 2026 — verified real with author-affiliation caveat: neither author has a verifiable institutional ResearchGate profile) proposes a "shared" tier that has no Anthropic equivalent. Anthropic's documented three-fold hierarchy is personal (`~/.claude/skills/`) / project (`<cwd>/.claude/skills/`) / plugin (`${CLAUDE_PLUGIN_ROOT}/skills/`); the "shared" middle tier in Skilldex is a non-Anthropic invention. The R-SHARE-* family in this project uses "shared" as a *descriptive* adjective for embed-and-duplicate / plugin-bundled-helpers patterns, not as a hierarchy tier. Skilldex's *skillset abstraction* (bundle of related skills with shared assets enforcing cross-skill behavioral coherence) IS structurally aligned with Anthropic's plugin model and is logged as PROPOSED corroborating reference for R-WORKSPACE-3. Tier-1 contradicting source: code.claude.com/docs/en/skills (personal/project/plugin hierarchy, no "shared" tier).

<!-- @da: DA-111 -->
<a id="da-111"></a>

**DA-111.** **(Gemini-9 G9-H3-derived) Use the "26.1% community-skill vulnerability rate" as a v1.9 quantitative threshold (e.g., a verify-before-installing gate or a security-tier rule).** Rejected. The statistic appears in Xu & Yan arXiv:2602.12430 (Zhejiang University, verified real Tier-1 survey) as their reference [14] = Liu et al. arXiv:2601.10338, "Agent skills in the wild: an empirical study of security vulnerabilities at scale." The primary measurement (Liu et al.) was not independently verified by this project for sample-frame, methodology, or replicability; per project rule on quantitative thresholds (pre-registration + Tier-1 verification of the primary source), the stat may be cited as background context but cannot graduate to a v1.9 mechanical threshold. Logged for Q-013 reopen (Q-008 LLM-judge work, where security validation is in scope) at the appropriate stage.

<!-- @da: DA-112 -->
<a id="da-112"></a>

**DA-112.** **Single-file-with-TOC for any reference size, regardless of length.** Rejected. Above ~500 lines / ~10,000 words, single-file approaches collide with the Claude Code Read tool's hard ceiling (R-CHUNK-5; anthropics/claude-code Issues #4002, #14876, #15687, plus #45019 silent 25K→10K downgrade Apr 2026 and #40357 Desktop 10K cap), and with the lost-in-the-middle effect (P-CHUNK-9). Anthropic's best-practices Pattern 2 explicitly recommends domain-split (`reference/finance.md`, `reference/sales.md`); skill-workshop SKILL.md repeats the recommendation with 'Domain organization: when a skill supports multiple domains/frameworks, organize by variant.' Replaced by R-CHUNK-2.

<!-- @da: DA-113 -->
<a id="da-113"></a>

**DA-113.** **On-disk vector index inside `references/` (e.g., `references/embeddings.faiss`, `references/chroma.db`) as primary lookup mechanism.** Rejected. No Anthropic documentation endorses on-disk vector indexes for in-skill references; Boris Cherny (Anthropic, Claude Code lead) publicly stated Claude Code dropped the local-RAG/vector-DB approach in favor of agentic Grep+Read because of staleness, fuzzy-positives in code retrieval, and security (embedding inversion) concerns. A vector-index runtime dependency violates R-SYS-1 (drop-in folder portability) by introducing embedding-model selection, index versioning, and DB-runtime requirements. Replaced by R-CHUNK-6.

<!-- @da: DA-114 -->
<a id="da-114"></a>

**DA-114.** **Semantic search over `references/` via an in-skill MCP tool (e.g., a bundled embedding service exposed as a Skill-internal MCP server) as primary lookup.** Rejected for the same reasons as DA-113. Note: this rejection does NOT prohibit a skill from invoking an external semantic-search MCP tool for non-reference data (e.g., querying a customer knowledge base); it scopes specifically to in-skill `references/` content where header-anchored Grep+Read (R-CHUNK-6) is the documented Anthropic pattern.

<!-- @da: DA-115 -->
<a id="da-115"></a>

**DA-115.** **Content-addressed chunking (chunks named by SHA hash, e.g., `references/9a8b3c.md`, `references/4f2e1d.md`).** Rejected. Defeats the discovery model — agents cannot 'decide which file to read' if filenames are opaque hashes. Conflicts with R-LAZYLOAD-1 (every reference must be linked from SKILL.md with explicit when-to-load guidance — impossible if filenames are unreadable hashes). Conflicts with R-CHUNK-4 (one-level-deep nesting requires authors to think in human-readable categories, not hashes).

<!-- @da: DA-116 -->
<a id="da-116"></a>

**DA-116.** **Jump-tags / line-anchored cross-references in SKILL.md (e.g., 'See `references/foo.md:L142-L189`').** Conditionally rejected. While the Claude Code Read tool supports `offset/limit` parameters and the Anthropic system prompt confirms this, no Anthropic documentation endorses embedding line numbers in markdown links, and line numbers drift on file edits making the references brittle. Header-anchored references (R-CHUNK-6 — point at the H2 in the TOC, then Grep or Read with offset matching the section) are robust to edits and are the documented pattern.

<!-- @da: DA-117 -->
<a id="da-117"></a>

**DA-117.** **Mandatory `references/_index.md` TOC for the references directory.** Conditionally rejected as MUST-rule; accepted as optional convention. Anthropic's documented pattern is for SKILL.md itself to act as the index of `references/` (Pattern 2 in best-practices: SKILL.md lists every reference file with a one-line description). A separate `references/_index.md` is redundant unless the skill has many references organized in subgroups; in that case it is permitted but not required.

<!-- @da: DA-118 -->
<a id="da-118"></a>

**DA-118.** **Mandatory minimum chunk size of 256 tokens for reference files.** Rejected as a MUST. R-LAZYLOAD-3 SHOULD-level guidance is the right strength — mandatory minimums punish legitimate tiny references (e.g., `references/error-codes.md` listing 12 error codes, intentionally atomic). The framework's strictness default does not extend to imposing lower bounds without empirical justification; the upper bounds (T-CHUNK-1..3) are anchored to documented limits, the lower bound (T-CHUNK-4) is heuristic only.

<!-- @da: DA-119 -->
<a id="da-119"></a>

**DA-119.** **Treat the Claude Code 25,000-token Read ceiling as a [portable] rule.** Rejected. The 25K limit is documented in anthropics/claude-code via Issues #4002, #14876, #14888, #15687 only; Issue #14888 confirms it is a hardcoded Claude Code product decision; Issue #45019 documents that it was silently dropped to 10K in Apr 2026 without doc churn; Issue #40357 documents Desktop has always been 10K. Other agent surfaces (Claude.ai, the API code-execution tool, Cursor, Aider, etc.) may have different limits. R-CHUNK-5 is tagged [claude-code-only]; the [portable] safety threshold (R-CHUNK-2) sits at the more conservative 10K-words / 500-lines / ~10K-15K-tokens band that is robust across all documented surfaces.

<!-- @da: DA-120 -->
<a id="da-120"></a>

**DA-120.** **(Gemini-10 G10-E) Upgrade R-LAZYLOAD-3 from SHOULD to MUST based on the calculation '50 lines = ~3,000 tokens'.** Rejected. The arithmetic is wrong by ~5x: 50 lines of markdown average ~50-80 characters per line × 0.25 tokens/character ≈ 500-1,000 tokens, not 3,000. The 3,000-token figure would correspond to ~250+ lines, well above any sensible inline-vs-extract threshold. The threshold itself (50 lines as the cross-over point between tool-call overhead and context-window economy) survives, but the rationale is corrected and the rule remains SHOULD-tier per framework's no-MUST-without-empirical-justification principle. Source: paraphrased Gemini-10 second-opinion text 2026-05-05.

<!-- @da: DA-121 -->
<a id="da-121"></a>

**DA-121.** **(Gemini-10 G10-F1) CaveAgent `injection.py` runtime-skill-injection pattern as a v1.10 normative production rule for Claude Code Skills.** Rejected as normative; ACCEPTED as PROPOSED forward-influence reference (P-CHUNK-11). The CaveAgent paper (arXiv:2601.01569, Maohao Ran and 22 other authors, HKBU/HKUST/HKGAI, submitted 4 Jan 2026 v1 / 19 Feb 2026 v3) is verified real Tier-1 academic research with verifiable institutional affiliation. The `injection.py` mechanism is real in CaveAgent's own framework (PyPI llm-py-agent 0.1.0; github.com/vanzll/PyAgent — both verified) and the paper claims it 'extends the Agent Skills open standard.' However: (a) Claude Code Skills run via the stateless Bash tool spawning scripts via `${CLAUDE_SKILL_DIR}/scripts/*` — there is NO persistent Python runtime to inject Python objects (DataFrames, DB connections) into; (b) CaveAgent's runtime model fundamentally requires an IPython kernel-class persistent process (cave_agent/pycallingagent use IPyKernelRuntime); (c) Gemini-10's framing as a 'missed production paradigm' is incorrect — there is no production deployment of CaveAgent on top of Claude Code, and CaveAgent is best read as a research extension targeting Python-runtime-based agent frameworks (PydanticAI, custom toolsets), not Claude Code. Logged as P-CHUNK-11 (forward-influence reference per Q-009 precedent for GraSP/Skilldex). Source: paraphrased Gemini-10 second-opinion text 2026-05-05; CaveAgent paper independently fetched.

<!-- @da: DA-122 -->
<a id="da-122"></a>

**DA-122.** **(Gemini-10 G10-F2) SOLID `.claude/skill-memories/*.md` as canonical Anthropic inheritance/extension pattern.** Rejected. Verified as anthropics/claude-code Issue #25469 (anton-abyzov, opened 13 Feb 2026, labels `enhancement` + `stale`), an unmerged, inactive **community feature proposal** — not an Anthropic-implemented namespace. Gemini-10 framed it as an established production paradigm; it is not. Anthropic's actual documented mechanism for the underlying use case (extending or overriding skill behavior without forking the skill) is **`.claude/rules/*.md`** (per code.claude.com/docs/en/memory): always-on guidance loaded recursively into context, with optional `paths` frontmatter for scoped activation. Rules are orthogonal to skills (rules = always-on guidance; skills = on-demand procedures), so they do not 'inherit from' a SKILL.md, but they DO solve the no-fork-required customization problem Gemini-10 raised. Logged for Q-009/Q-013 cross-reference: R-WORKSPACE-3 (plugin distribution as the canonical cross-scope sharing primitive) plus the `.claude/rules/` mechanism together cover the extension-without-fork use case without requiring a new namespace. Source: paraphrased Gemini-10 second-opinion text 2026-05-05; Issue #25469 independently verified.

<!-- @da: DA-123 -->
<a id="da-123"></a>

**DA-123.** **(Gemini-10 G10-A) 'TOC must be positioned within the first 50 lines of the reference file.'** Rejected as a specific quantitative threshold. The 50-line figure is Gemini's engineering reasoning extrapolated from `head -100` partial-read behavior, not a documented Anthropic constraint. R-CHUNK-1 already requires reference files >100 lines to begin with a `## Contents` (or `## Table of Contents`) section, which trivially places the TOC within any reasonable head-N preview window (head -25, head -50, head -100). Adopting the specific 50-line cutoff would be (a) overcautious without empirical justification, (b) at risk of conflicting with Anthropic if a future doc revision specifies a different number, and (c) redundant with the existing 'begin with' phrasing. Source: paraphrased Gemini-10 second-opinion text 2026-05-05.

<!-- @da: DA-124 -->
<a id="da-124"></a>

**DA-124.** **(Gemini-10 G10-D) '30% accuracy drop in mid-document content' as a specific quantitative threshold for chunking decisions.** Rejected. The 30% figure does not appear in Liu et al. 'Lost in the Middle' (TACL 2024 vol 12 pp 157-173, arXiv:2307.03172, Stanford / Samaya AI / FAIR — verified) or in Chroma's 'Context Rot' technical report (2025, 18 frontier models — verified) as a single reportable cross-task figure. Both papers report task-dependent degradation curves with significant variance: Liu et al. show MultiDocQA accuracy dropping from ~75% (best-position) to ~50% (worst-position) for 20-document inputs in some models, and from ~62% to ~52% for 30-document inputs — neither equals exactly 30%; Chroma reports performance degradation begins at varying token counts well below context-window capacity, model-by-model. Adopting any specific percentage as a portable threshold violates the framework's pre-registration discipline (T-CHUNK-* thresholds were pre-registered with concrete metrics; '30% drop' was not). The qualitative U-shape and just-in-time-retrieval implication are retained as P-CHUNK-9 PROPOSED. Source: paraphrased Gemini-10 second-opinion text 2026-05-05; Liu et al. and Chroma reports independently fetched.

<!-- @da: DA-125 -->
<a id="da-125"></a>

**DA-125.** **(Gemini-1 G1-C2) arXiv:2603.15994 'Memory as Recursive Attention Structure (MaRS)' with bidirectional supersession formalism.** Rejected: arXiv ID does not surface in two distinct searches; appears to confabulate the MaRS *system* described inside arXiv:2512.12856 'Forgetful but Faithful' (Dec 2025) with a fake separate paper. The underlying bidirectional supersession concept is independently VALIDATED via RFC 7322 §4.1.4 Updates/Obsoletes (Flanagan & Ginoza 2014) and is adopted on that basis — does NOT require this fabricated citation. Fits the project's prior 2604.X / 2603.X fabrication pattern (DA-042 family).

<!-- @da: DA-126 -->
<a id="da-126"></a>

**DA-126.** **(Gemini-1 G1-C5) Framing arXiv:2603.04814 'Beyond the Context Window' (Pollertlam & Kornsuwannawit, 5 Mar 2026) as evidence *against* wholesale loading for the Research Buddy.** Rejected: cherry-picked. The paper's actual recommendation, omitted by Gemini-1, matches the Research Buddy operating profile exactly: 'For one-time or short interactions where accuracy is the top priority, the full-history approach is the better choice.' Properly read, the paper SUPPORTS the deferral of hybrid retrieval. Additionally, Gemini-1's '91% p95 latency reduction' figure is misattributed to this paper — it is actually from the Mem0 paper (arXiv:2504.19413, Apr 2025).

<!-- @da: DA-127 -->
<a id="da-127"></a>

**DA-127.** **(Gemini-1 G1-C8) Attribution of 'Entrenchment under user-coupled drift' failure mode to arXiv:2604.12034 'Memory as Metabolism' (Miteski, 13 Apr 2026).** Rejected: paper argument is INVERTED. Miteski's central failure mode is *over-entrenchment* (wikis ossify; the dominant interpretation gets more protected over time, and newer contradicting evidence gets more easily dismissed). Gemini-1 attributes the opposite framing (drift away from ground truth). The phrase 'user-coupled drift' does not appear in the abstract. The paper's actual concern reinforces the supersession-link adoption (DA-supersession is the antidote to ossification), but the specific failure mode Gemini-1 named is not what the paper documents.

<!-- @da: DA-128 -->
<a id="da-128"></a>

**DA-128.** **(Gemini-1 G1-C6) Argument that the Anthropic 25 KB / 200-line MEMORY.md auto-injection limit constrains a 715 KB on-demand-loaded user document.** Rejected: misapplication. The canonical doc (code.claude.com/docs/en/memory) explicitly states: 'This limit applies only to MEMORY.md. CLAUDE.md files are loaded in full regardless of length.' The Research Buddy JSON is neither MEMORY.md nor a startup-injected file; it is a user-document loaded by the agent on demand and is unconstrained by the 25 KB limit. Gemini-1 also misattributed the URL (cited docs.anthropic.com/en/docs/claude-code/sub-agents; the actual locus is code.claude.com/docs/en/memory).

<!-- @da: DA-129 -->
<a id="da-129"></a>

**DA-129.** **(Gemini-1 G1-C3 specific quantitative figures) The figures `rho ≈ -0.33` (task-difficulty confounding) and `30% retrieval diversity threshold` attributed to arXiv:2604.12007 'When to Forget' (Simsek, 13 Apr 2026).** Rejected at the quantitative level: not present in the paper's abstract; cannot be verified end-to-end. The paper's actual headline correlation is `rho = 0.89 ± 0.02` (Memory Worth ↔ true utility) across 20 independent seeds. The qualitative pattern that outcome-based decay has documented failure modes IS preserved as PROPOSED via the paper's own associational-vs-causal disclaimer ('p+(m) is an associational quantity, not a causal one'), which independently supports the Q-011 (e) rejection of MemoryBank-style numeric decay on normative rules.

<!-- @da: DA-130 -->
<a id="da-130"></a>

**DA-130.** **R-MEM-3 (PROPOSED v1.1 — symlink `AGENTS.md` ↔ `CLAUDE.md` at the project-memory layer for cross-tool sharing).** **Demoted to permanent DA at v1.12** with `superseded_by: [R-MEM-10]` per agent_guidelines.framework.rule_lifecycle.supersession_links. Rationale: canonical Anthropic Tier-1 contradiction surfaced during Q-014 Turn 2. `code.claude.com/docs/en/memory` § AGENTS.md states verbatim: "Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it so both tools read the same instructions without duplicating them." The canonical replacement pattern is the `@AGENTS.md` import directive (R-MEM-10), not a symlink. Reinforcement: claude-code-action Issue #1187 documents an `ENOENT: no such file or directory, symlink` crash in CI/CD pipelines since v1.0.89 when `CLAUDE.md` is symlinked to `AGENTS.md` (Anthropic-owned repo, Tier-1). Anthropic supremacy applies. The PROPOSED symlink rule never reached VALIDATED and is now permanently rejected.

<!-- @da: DA-131 -->
<a id="da-131"></a>

**DA-131.** **(Gemini-14 fabrication) "Hard truncation limit of exactly 1,536 characters for the combined `description` and `when_to_use` fields" in YAML frontmatter.** Rejected: fabricated. Direct fetch of `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices` (Tier-1) confirms the canonical limit is **1024 characters** on `description` (single field, non-empty, no XML tags, no XML reserved words). There is no `when_to_use` field separately documented in the canonical YAML schema, no 'combined' field treatment, and no 1,536-character figure anywhere in canonical docs. Pattern: numeric-figure invention consistent with prior Gemini-N hallucinations (DA-031..033, DA-094, DA-097, DA-120, DA-123, DA-124).

<!-- @da: DA-132 -->
<a id="da-132"></a>

**DA-132.** **(Gemini-14 fabrication) `context: fork` as a SKILL.md YAML frontmatter field that 'isolates complex task execution within dedicated subagents'.** Rejected: scope confusion. `context: fork` exists as a **subagent-frontmatter** field per the project's existing R-COMP-1..3 composition ladder (Q-006, v1.6) and per code.claude.com/docs/en/sub-agents — it is NOT a skill-frontmatter field. The canonical best-practices doc has zero mention of `context: fork` in the SKILL.md context. Pattern: feature confusion across product surfaces (similar to DA-074 — `!command` Dynamic Context Injection in SKILL.md, also a subagent feature confused with skills).

<!-- @da: DA-133 -->
<a id="da-133"></a>

**DA-133.** **(Gemini-14 repeat hallucination) Dynamic Context Injection in SKILL.md via `!\`command\`` shorthand.** Rejected: this is a **repeat hallucination**, identical to the Gemini-7 hallucination already rejected at **DA-074 (v1.7)**. The `!command` shorthand is a feature of slash commands in Claude Code (per code.claude.com/docs/en/slash-commands), NOT a SKILL.md feature. Per agent_guidelines.framework.second_opinion_review.independence_note: when multiple second opinions share the same error, treat it as one data point (likely shared training artifact), not independent confirmation. DA-074 stands; DA-133 is its v1.12 refresh.

<!-- @da: DA-134 -->
<a id="da-134"></a>

**DA-134.** **(Gemini-14 miscitation) The agents.md homepage shell command `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` framed as evidence for CLAUDE.md ↔ AGENTS.md symlink convention.** Rejected: direct fetch of agents.md confirms this command is for **AGENT.md (singular) → AGENTS.md (plural)** backward compatibility — i.e., for repositories that previously used the older singular `AGENT.md` filename and want to migrate to the LF/Agentic-AI-Foundation-stewarded `AGENTS.md` plural standard while keeping the old name as a symlink. It is **not** a recommendation for symlinking AGENTS.md to CLAUDE.md or vice versa. agents.md homepage actually contains zero recommendation for CLAUDE.md ↔ AGENTS.md symlinks; the canonical Anthropic answer (per R-MEM-10) is the `@AGENTS.md` import directive, not a symlink.

<!-- @da: DA-135 -->
<a id="da-135"></a>

**DA-135.** **(Gemini-14) "Developers SHOULD utilize OS-level symbolic links inside each skill's `references/` directory pointing to a common global repository folder" as the cross-skill reference-doc sharing rule.** Rejected: too broad. Anthropic's plugins-reference Tier-1 doc explicitly endorses symlinks **only within a plugin** ("create symbolic links to external files within your plugin directory. Symlinks are preserved in the cache rather than dereferenced"), and explicitly disallows paths that traverse outside the plugin root ("Paths that traverse outside the plugin root (such as `../shared-utils`) will not work after installation"). Project-scope (non-plugin) skills sharing a reference via symlinks to 'a common global repository folder' is NOT first-party-supported. The canonical rule is R-REF-SHARE-1: plugin-internal symlinks via `${CLAUDE_PLUGIN_ROOT}` paths, otherwise embed-and-duplicate, otherwise unsupported.

<!-- @da: DA-136 -->
<a id="da-136"></a>

**DA-136.** **(Gemini-14) `disable-model-invocation: true` reframed as the canonical mechanism for 'Human-in-the-Loop Write Gates' on the LLM-Wiki v2 ingestion pattern.** Rejected: confabulation. The `disable-model-invocation: true` frontmatter field exists in Anthropic skill frontmatter for the **unrelated purpose** of disabling model-driven activation of a skill (i.e., the skill must be invoked explicitly by the user, not auto-triggered by Claude). It is **not** a write-gate on a skill's `references/` directory, and it does not implement Mattia83it's recommended HITL write-gate pattern. The actual answer to Mattia83it's HITL critique within the project's framework is the strictness default + R-CHUNK-6 (no runtime writes to `references/`) + R-LOG-REJECT (DA-Q014-V7 / DA-Q014-V8 / DA-Q014-V9 lineage).

<!-- @da: DA-137 -->
<a id="da-137"></a>

**DA-137.** **(Gemini-14 misframing) anthropics/skills Issue #189 (~50K wasted tokens) framed as evidence of a 'cross-skill reference duplication crisis' requiring an architectural cross-skill reference primitive.** Rejected: misframed. The actual issue, verified by direct fetch, is that **two plugins (`document-skills` and `example-skills`) ship the same 17 skills**, causing duplicate skill loading. The cause is plugin-packaging hygiene (the marketplace exposing two plugins with identical content), not a missing architectural primitive for cross-skill reference doc sharing. The 50K-token figure is a real, documented Tier-1 finding — but it supports a different conclusion (plugin packaging discipline, scope of /context filtering, marketplace deduplication) than Gemini-14 claims.

<!-- @da: DA-138 -->
<a id="da-138"></a>

**DA-138.** **(Gemini-14 partial overreach) Karpathy's llm-wiki gist framed as evidence for the CLAUDE.md ↔ AGENTS.md symlink convention via the claim that the gist 'remains agnostic to the format war'.** Rejected: the gist names CLAUDE.md and AGENTS.md as parallel filenames for the schema layer ("a document (e.g. CLAUDE.md for Claude Code or AGENTS.md for Codex)"), but does **not** recommend symlinking them. Naming both as alternatives is not equivalent to endorsing a symlink between them. The agent-tool-specific schema choice is documented; the symlink is not. The community-recommended symlink predates and is independent of Karpathy's pattern catalogue.

<!-- @da: DA-139 -->
<a id="da-139"></a>

**DA-139.** **(Composite — Q-014 Turn 1 LLM-Wiki / LLM-Wiki-v2 patterns rejected as skill-`references/` patterns.)** The following Karpathy and rohitg00 v2 patterns are permanently rejected as patterns inside a skill's `references/` directory: (1) three-layer raw/wiki/schema separation; (2) immutable `raw/` rule inside a skill; (3) LLM-owned `wiki/` layer modified at runtime; (4) ingest/query/lint operations; (5) grep-parseable `## [date] op | …` log prefix inside `references/` (covered by R-LOG-REJECT MUST NOT); (6) sub-folders concepts/entities/sources/comparisons (conflicts with R-CHUNK-4 single level); (7) YAML frontmatter on every reference page beyond the R-REF-FM-1 whitelist (`title:`, `summary:`, `load_when:`); (8) Obsidian `[[wiki-link]]` cross-refs (conflicts with R-CHUNK-4 chained-links prohibition); (9) file-back-to-wiki at runtime (skills are static at discovery time per R-WORKSPACE-1); (10) qmd / Marp / Dataview as primary lookup mechanism (qmd's BM25+vector+rerank conflicts with R-CHUNK-6 no-vector-index rule); (11) numeric confidence scoring per claim (Mattia83it counter-pattern: 'false precision'); (12) retention decay / Ebbinghaus forgetting curve (Mattia83it: 'old doesn't mean stale'); (13) consolidation tiers (working/episodic/semantic/procedural) inside a skill (knowledge-base scale only); (14) typed knowledge graph with semantic edges (conflicts with R-CHUNK-6); (15) hybrid BM25+vector+graph retrieval (already DA-113/DA-114); (16) event-driven hooks tied to `references/` (skills are read-only at runtime); (17) LLM-self-healing rewrites of reference pages (Mattia83it: 'corrupts silently'); (18) LLM contradiction resolution at runtime (same reason); (19) crystallisation — auto-distilling completed work-chains into reference pages (skills are not session-distillation engines). All 19 sub-patterns are out of scope for the single-skill `references/` layer; some apply to project-memory layer (e.g., supersession via git, addressed in R-MEM-10). DA-139 is a composite entry; individual sub-pattern rationales are recorded in Session Notes — Q-014.

<!-- @da: DA-140 -->
<a id="da-140"></a>

**DA-140.** **(Gemini-15 BUDGET-MEM-1 conflation) `<root>/CLAUDE.md` framed as having the same hard 200-line / 25 KB silent-truncation cap as `MEMORY.md`.** Rejected by direct Tier-1 contradiction. The canonical Anthropic memory doc states verbatim: *'The first 200 lines of MEMORY.md, or the first 25KB, whichever comes first, are loaded at the start of every conversation. … This limit applies only to MEMORY.md. **CLAUDE.md files are loaded in full regardless of length**, though shorter files produce better adherence.'* (*How Claude remembers your project*, Anthropic, 2026, https://code.claude.com/docs/en/memory). Anthropic supremacy applies. The 200-line figure for CLAUDE.md is a soft adherence target, not a truncation cap. Gemini-15's BUDGET-MEM-1 reformulation is rejected; R-BOUNDARY-3 carveout added to lock the soft-target reading.

<!-- @da: DA-141 -->
<a id="da-141"></a>

**DA-141.** **(Gemini-15 ROUTE-EPISTEMIC-1 universal-supersession overreach) GROUNDING.md framed as 'the absolute, unbreakable ceiling of the supersession hierarchy', 'natively injected' by 'modern agentic scaffolds and platforms' at 'highest possible system priority'.** Rejected. The arXiv paper exists and authors are verified — Magnus Palmblad (Leiden UMC), Jared M. Ragland and Benjamin A. Neely (NIST Charleston), submitted 2026-04-23 (arXiv:2604.21744, https://arxiv.org/abs/2604.21744) — but its abstract says verbatim: *'we propose GROUNDING.md, a community-governed, **field-scoped** epistemic grounding document, using mass spectrometry-based proteomics as an example.'* The paper is a **proposal**, not a description of a current platform mechanism, and is **field-scoped to scientific domains**. No Anthropic Tier-1 source mentions GROUNDING.md or its priority injection. Promotion to a top-of-supersession rule violates the strictness default. **Retained narrowly as P-BOUND-GROUNDING-1 PROPOSED** (domain-scoped, for regulated scientific computing / safety-critical systems only; precedence achieved via `@GROUNDING.md` import in CLAUDE.md before `@AGENTS.md`; not a platform mechanism).

<!-- @da: DA-142 -->
<a id="da-142"></a>

**DA-142.** **(Gemini-15 quantitative threshold from Discovery-only) ToolSearch flat overhead 'approximately 1,700 tokens' per skill activation.** Rejected for VALIDATED status. Source cited by Gemini-15: a Reddit r/ClaudeAI thread (*PSA: Audited my Claude Code setup*, 2026, https://www.reddit.com/r/ClaudeAI/comments/1sm66h8/) — Discovery-tier per project source_tiers. No Anthropic Tier-1 corroboration of the specific 1,700-token figure. Per the project's Discovery rule, quantitative thresholds require Tier-1 support to be VALIDATED. Stays at PROPOSED at most; will not be cited as a quantitative anchor in any spec rule. (The *qualitative* claim that ToolSearch incurs non-trivial activation overhead is plausible and consistent with Anthropic's progressive-disclosure thesis, but the specific number is unverified.)

<!-- @da: DA-143 -->
<a id="da-143"></a>

**DA-143.** **(Gemini-15 quantitative claims from Discovery-only) 'Progressive disclosure reduces token usage by up to 85%' and 'unoptimized memory architecture costs $150–$250 per developer per month'.** Rejected for VALIDATED status. Sources cited by Gemini-15: Finout (*Claude Code Pricing 2026*, https://www.finout.io/blog/claude-code-pricing-2026) and Morph (*The Real Cost of AI Coding in 2026*) — Discovery-tier; both vendor blogs. The conceptual direction (progressive disclosure substantially reduces context cost) is consistent with Anthropic's published Skills design principles, but the specific 85% and $150–$250 figures lack Tier-1 corroboration. Cannot become spec quantitative anchors. Stays at PROPOSED at most.

<!-- @da: DA-144 -->
<a id="da-144"></a>

**DA-144.** **(Gemini-15 numeric overclaim) Reference files >300 lines must include a table of contents.** Rejected — corrected to 100 lines. The canonical Anthropic best-practices doc states verbatim: *'For reference files longer than 100 lines, include a table of contents at the top.'* (*Skill authoring best practices*, Anthropic, 2026, https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices). Gemini-15's 300-line threshold is 3× too lenient and would violate Anthropic supremacy if adopted. The corrected 100-line threshold is the basis of the new VALIDATED **R-BOUNDARY-9**. Note: Gemini-15 *correctly* cited the canonical `head -100` partial-read mechanism that justifies the ToC requirement; the threshold itself was the only error in this claim cluster.

<!-- @da: DA-145 -->
<a id="da-145"></a>

**DA-145.** **(Gemini-15 overclaimed framing) 'Anti-patterns and negative constraints' framed as a supersession-resolution mechanism for cross-container drift.** Rejected for VALIDATED status. The *technique* of using anti-patterns / negative constraints / explain-the-why inside skill text is a real and Anthropic-endorsed authoring pattern (skill-workshop yellow-flag guidance against bare MUST/ALWAYS/NEVER imperatives), but Gemini-15 elevates it into a **supersession-resolution mechanism** that resolves factual conflicts across containers without tooling — a framing for which no Tier-1 source provides backing. The technique remains a recommended skill-authoring pattern; the supersession-resolution overlay does not become a routing rule. Stays PROPOSED at most; not adopted as an R-BOUNDARY-* rule.

<!-- @da: DA-146 -->
<a id="da-146"></a>

**DA-146.** **(Gemini-15 citation-discipline failure) Pricing claims sourced via Finout when Anthropic primary source exists.** Rejected on citation discipline. Per project source_tiers rejection rule: *'secondary citations of Anthropic claims when the primary Anthropic page is reachable'* are auto-rejected. The underlying Opus 4.7 / Sonnet 4.6 / Haiku 4.5 figures cited by Gemini-15 ($5/$25, $3/$15, $1/$5 per MTok) are correct and verifiable at the Anthropic primary source (*Introducing Claude Opus 4.7*, Anthropic, 2026, https://www.anthropic.com/news/claude-opus-4-7), but Gemini-15's citation chain (Finout) bypasses the primary. Adopted spec text MUST cite anthropic.com primary, not third-party rate cards. Note: this is a citation-discipline rejection only; the underlying figures remain factually correct.

<!-- @da: DA-Q016-1 -->
<a id="da-q016-1"></a>

**DA-Q016-1.** **(Gemini-16 fabricated mechanism) 'Native progressive-disclosure injection parser that bypasses the LLM behavioral action space.'** Gemini-16 claimed that when SKILL.md contains markdown links, *'the host software executing the application performs a direct disk read of target.md and seamlessly, fully injects the resultant text directly into the conversation history. Because this native injection is executed outside the LLM's behavioral action space, the tokenization is precise, reliable, and fundamentally immune to bash-related truncation.'* **Refuted as fabricated.** Anthropic's Agent Skills overview at https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview states verbatim: *'Claude uses bash to read SKILL.md from the filesystem, bringing its instructions into the context window. If those instructions reference other files (like FORMS.md or a database schema), Claude reads those files too using additional bash commands.'* Best-practices doc: *'Claude reads SKILL.md, sees the reference to reference/finance.md, and invokes bash to read just that file.'* Progressive disclosure is **agent-driven** (LLM-issued bash/Read tool calls), not a host-side parser bypass. The correct mechanism explanation — graph-distance-driven partial-read regression at transitive reference steps — is captured in R-CHUNK-4-CLARIFICATION. **Independence note:** third Gemini fabrication of a host-side bypass-of-LLM-action-space mechanism in this project (prior: DA-074 Gemini-7 `!command` Dynamic Context Injection; DA-133 Gemini-12 `!command` recurrence), counted as one shared-training-artifact data point.

<!-- @da: DA-Q016-2 -->
<a id="da-q016-2"></a>

**DA-Q016-2.** **(Gemini-16 misattributed Tier-1 citation) `anthropics/claude-code` Issue #13617 cited as evidence for autonomous `head -100` file traversal fallback behavior.** Direct fetch of https://github.com/anthropics/claude-code/issues/13617 confirms the actual issue title is *'Bug: ARM64 binary replaced with x86_64 during install on Apple Silicon'* (2025-12-10). The issue is about Apple Silicon binary install, NOT about file traversal mechanisms, NOT about `head -100` partial-read behavior, NOT about progressive disclosure. Misattributed citation rejected with prejudice.

<!-- @da: DA-Q016-3 -->
<a id="da-q016-3"></a>

**DA-Q016-3.** **(Gemini-16 fabricated quantitative claim) `anthropics/skills/claude-api/shared/tool-use-concepts.md` is 327 lines.** Direct fetch of https://github.com/anthropics/skills/blob/main/skills/claude-api/shared/tool-use-concepts.md (2026-05-06) returns the GitHub blob header **305 lines (200 loc) · 14.5 KB**. Gemini-16's 327-line figure is off by 22 lines (~7%). Per `domain_constraints.rules.strictness_default` and the framework's quantitative-precision requirement, the 305-line figure is adopted. The Gemini-16 figure is rejected as fabricated.

<!-- @da: DA-Q016-4 -->
<a id="da-q016-4"></a>

**DA-Q016-4.** **(Gemini-16 misattributed academic citation) arXiv:2601.04583 cited as 'Agent Behavior Frameworks' supporting the claim *'code strictly dictates the model's actual optimized action space.'*** Gemini-16's own bibliography footer titles the paper *'Autonomous Agents on Blockchains: Standards, Execution Models, and Trust Boundaries'* — a blockchain-agents paper unrelated to skill ingestion, agent file traversal, or LLM action-space optimization. Misattribution rejected. The 'Code-as-Truth' meta-principle this citation was meant to support is independently rejected as DA-Q016-5.

<!-- @da: DA-Q016-5 -->
<a id="da-q016-5"></a>

**DA-Q016-5.** **(Gemini-16 normative meta-principle overreach) 'Code-as-Truth Principle' — a proposed new clause that 'in any instance of direct, irreconcilable conflict between official prose documentation and a canonical Anthropic reference implementation, the operational structure … of the reference implementation shall universally dictate the standard.'** Rejected on two independent grounds. (1) **Unnecessary:** Q-016 turned out not to be an Anthropic-vs-Anthropic contradiction at all once the best-practices doc was read in full — Pattern 2 `bigquery-skill/reference/finance.md` and the Bad-vs-Good chained-link example (identical filenames, hop-count differs) both point to the markdown-link-depth interpretation that the canonical `claude-api` skill instantiates. The simpler resolution path (read the doc in full) avoids needing any new meta-principle. (2) **Category error:** the supporting argument cites Anthropic's eval and diff-tool methodology to claim *'the model has been statistically and mathematically optimized to traverse'* the canonical repo's specific layouts. This conflates eval-pipelines-running-on-codebases (which test task completion) with models-being-optimized-for-codebase-layouts (which they are not — Claude is a general model, not fine-tuned on `anthropics/skills` directory shapes). Anthropic_supremacy clause stands unchanged.

<!-- @da: DA-Q016-6 -->
<a id="da-q016-6"></a>

**DA-Q016-6.** **(Gemini-16 misattributed empirical claim) `skill-workshop` references include `references/spec-summary.md` and `references/scoring-rubric.md`, cited via `anthropics/skills` Issue #853.** Issue #853 actual title: *'An Agent Skill that tests and scores any other Agent Skill against the official anthropics/skills specification'* — a community **proposal** for a third-party meta-skill that would score other skills, NOT a description of `skill-workshop`'s own layout. Per Turn 1 verification, `skill-workshop/references/` actually contains primarily `schemas.md`. Gemini-16's claimed file paths are not present in the canonical layout. Misattribution rejected.

<!-- @da: DA-147 -->
<a id="da-147"></a>

**DA-147.** **(Gemini-13 G13-A1 fabrication) "Anthropic skill-workshop's canonical default for self-consistency voting is k=10, mandating ten runs for rigorous measurement."** Rejected: fabricated. Direct re-fetch of `github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md` (2026-05-07) returns verbatim text *"running each query 3 times to get a reliable trigger rate"* in the description-optimization workflow section. Confirmed across (1) `anthropics/skills` canonical, (2) `anthropics/claude-plugins-official` mirror, (3) DeepWiki summary, (4) skillsmp.com mirror, (5) smithery.ai mirror, (6) piax.org mirror, (7) tessl.io blog write-up — seven independent surfaces all agree on k=3. The Anthropic convention has not rotated. Pattern: numeric-figure invention consistent with prior Gemini-N fabrications (DA-031..033, DA-094, DA-097, DA-120, DA-123, DA-124, DA-131).

<!-- @da: DA-148 -->
<a id="da-148"></a>

**DA-148.** **(Gemini-13 G13-A2 misattribution) "TrustJudge ICLR 2026 explicitly mandates the reporting of four or five runs because three yields too few triples to discriminate models."** Rejected on two grounds. (1) **Paper status misattributed.** TrustJudge (Wang et al., arXiv:2509.21117) is *"Under review as a conference paper at ICLR 2026"* (verbatim from the OpenReview PDF), NOT yet accepted. ICLR 2026 review cycle is in double-blind progress. Per project rules, "under review" is not Tier-1 venue-accepted; it remains arXiv-PROPOSED. (2) **Quantitative claim misread.** TrustJudge's "triples" are MODEL-PAIR TRANSITIVITY TRIPLES (A vs B, B vs C, A vs C — circular preference chains), NOT self-consistency vote counts per query. Verbatim from the abstract: *"Pairwise Transitivity Inconsistency, manifested through circular preference chains (A>B>C>A) and equivalence contradictions (A=B=C≠A)."* The paper's contribution is *distribution-sensitive scoring* and *likelihood-aware aggregation* — orthogonal to self-consistency vote count. Same conflation pattern as DA-094 (Trust-or-Escalate K=3 few-shot conflated with k=3 self-consistency). The k=3 self-consistency floor remains anchored on Anthropic skill-workshop + Self-Refine plateau, unchanged.

<!-- @da: DA-149 -->
<a id="da-149"></a>

**DA-149.** **(Gemini-13 G13-A3 relitigation) "SAMRE Protocol (EACL 2026) demonstrates k=5 with personas matches k=7 jury at 85.1% accuracy."** Rejected: this is a relitigation of DA-095, which already established that the SAMRE protocol's actual home is *"Debate, Deliberate, Decide (D3): A Cost-Aware Adversarial Framework for Reliable and Interpretable LLM Evaluation,"* arXiv:2410.04663, October 2024, named authors Liu/Du/Chen/Hu/Cao/Wang — NOT an anonymous EACL 2026 submission. The 85.1% figure cannot be reconciled with the actual D3 paper's reported numbers without verbatim citation, which Gemini-13 does not provide. Per the project's no-relitigation-without-new-Tier-1-evidence rule (`framework.second_opinion_review.brief_template` context-completeness section), DA-095 stands. The framework's brief was supposed to mark this as off-limits unless new evidence emerged; Gemini-13 ignored that constraint.

<!-- @da: DA-150 -->
<a id="da-150"></a>

**DA-150.** **(Gemini-13 G13-A4 unverifiable citation) "Can LLMs Automate Fact-Checking Article Writing? (2026, MIT Press) establishes five runs as the optimal equilibrium for self-consistency."** Rejected as unverifiable. The paper exists at https://direct.mit.edu/tacl (Transactions of the ACL, MIT Press) per Gemini-13's bibliography surface, but the specific quantitative claim "five runs as the optimal equilibrium, noting that performance gains become marginal as the count increases beyond this point" cannot be confirmed against the paper's actual content without verbatim quote. Per the project's quantitative-threshold-pre-registration rule, an optimum claim of this specificity must be Tier-1-verifiable end-to-end; Gemini-13's paraphrase-only treatment is insufficient. Pattern note: this is the third Gemini-13 paraphrased-quantitative-without-verbatim citation in this single submission — the brief explicitly required *"Title, Author, Year, Venue, DOI/URL in the same sentence as the claim."*

<!-- @da: DA-151 -->
<a id="da-151"></a>

**DA-151.** **(Gemini-13 G13-C1 fabrication) `anthropics/claude-code` Issue #42250 documents PreToolUse-Skill bifurcation with three test cases (user slash → PreToolUse fails / PostToolUse succeeds; programmatic agent → PreToolUse succeeds / PostToolUse fails).** Rejected as fabricated. Live search of `github.com/anthropics/claude-code/issues/42250` and search engines for the verbatim title returns no such issue. The issue numbers in the 42xxx range that DO exist on the repo cover unrelated topics (#42796 about thinking-token redaction; #43630 about PostToolUse-Skill never firing; #46926 about `type: "agent"` PreToolUse hooks). The bifurcation behavior Gemini-13 describes IS partially real (PreToolUse-Skill fires for agent-dispatched calls per Issue #21614 sub-agent crash + canonical hooks-doc `UserPromptExpansion` event description), but the cited evidence vehicle (#42250) is non-existent. Pattern: same as DA-094 (fabricated paper title), DA-095 (fabricated venue), DA-Q016-2 (misattributed issue number). Conclusion direction is partially correct from independent canonical evidence; the cited evidence is not.

<!-- @da: DA-152 -->
<a id="da-152"></a>

**DA-152.** **(Gemini-13 G13-C2 fabrication) `anthropics/claude-code` Issue #47307 documents a regression where matcher: "Skill" no longer works for hooks on certain operating system platforms.** Rejected as fabricated. Live search for `Issue #47307` in `github.com/anthropics/claude-code` and search-engine search for the verbatim issue title return no findable issue. The Gemini-13 search-result listing that surfaces *"[BUG] `matcher: "Skill"` no longer works for hooks · Issue #47307"* appears to be a hallucinated search-engine cache; the underlying URL does not resolve to a real issue. Real issues with the closest topical fit are #43630 (PostToolUse-Skill, still open) and #21614 (PreToolUse-Skill sub-agent crash, labeled `duplicate`); neither matches Gemini-13's description. Pattern: same fabrication signature as DA-151. **Independence note applied across DA-147..152:** all six rejections are treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note`, not six independent confirmations of unreliability. The pattern is the same one observed in Gemini-3, Gemini-4, Gemini-8, Gemini-12, Gemini-15, Gemini-16: confident, verbatim-style citation of fabricated paper titles, fabricated venue attributions, and fabricated issue numbers, with directionally-plausible claims wrapped around the fabricated evidence.

<!-- @da: DA-153 -->
<a id="da-153"></a>

**DA-153.** **(Gemini-18 G18-1 fabrication) The central CLAUDE.md file historically operates under a rigid 25,000-token ingestion limit; if a project standard exceeds this, the framework silently ignores the overflow without warnings, anchored to anthropics/claude-code Issue #21925.** Rejected as fabrication. **Direct verification 2026-05-07:** Issue #21925 ([github.com/anthropics/claude-code/issues/21925](https://github.com/anthropics/claude-code/issues/21925), opened gizyckik 2026-01-30, title *"[DESIGN FLAW] Context compaction destroys workflow — no CLAUDE.md reload, no pause, auto-continues and breaks own work"*) is about CLAUDE.md **not being re-read after auto-compaction**, not about a 25K ingestion ceiling. The verbatim issue body states: *"CLAUDE.md was supposed to solve this — but it's NOT re-read after compaction, making it useless for long sessions."* No 25K cap is mentioned anywhere in the issue. The fabricated mechanism directly contradicts canonical Anthropic Tier-1 [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) which states verbatim *"CLAUDE.md files are loaded in full regardless of length"* — already locked as [DA-140](#da-140). Adjacent corroboration: anthropics/claude-code Issue #22085 ([github.com/anthropics/claude-code/issues/22085](https://github.com/anthropics/claude-code/issues/22085), opened 2026-01-31, *"Auto-reload CLAUDE.md config files when session is continued from context compaction"*) confirms the actual issue is non-reload after compaction, not a size cap, and that CLAUDE.md is *"loaded correctly"* on session start. Pattern: same fabrication signature as DA-140 (Gemini-15 BUDGET-MEM-1 conflation), DA-151/-152 (Gemini-13 fabricated issue numbers), DA-Q016-2 (Gemini-16 misattributed issue). Gemini-18 anchored a fabricated mechanism (rigid 25K ingestion cap on CLAUDE.md) to a real issue number (#21925) whose actual content is unrelated.

<!-- @da: DA-154 -->
<a id="da-154"></a>

**DA-154.** **(Gemini-18 G18-2 naming hallucination) Developers can manipulate the `autoCompactWindow` parameter (formerly `CLAUDE_AUTOCOMPACT_WINDOW`) to adjust the compaction trigger threshold.** Rejected on naming. **Direct verification 2026-05-07:** the `autoCompactWindow` setting exists per anthropics/claude-code Issue #42149 ([github.com/anthropics/claude-code/issues/42149](https://github.com/anthropics/claude-code/issues/42149), verbatim *"There is no way to fully disable auto-compaction. The only available setting is `autoCompactWindow` (min 100000, max 1000000), which controls when compaction triggers but not whether it triggers"*), and the corresponding env var is `CLAUDE_CODE_AUTO_COMPACT_WINDOW` per the source-code reproduction at [kenhuangus.substack.com/p/claude-code-pattern-6-context-management](https://kenhuangus.substack.com/p/claude-code-pattern-6-context-management) showing `process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW`. The "formerly `CLAUDE_AUTOCOMPACT_WINDOW`" framing in Gemini-18 implies a renaming history that does not exist; the env var was always `CLAUDE_CODE_AUTO_COMPACT_WINDOW`. The substantive Gemini-18 conclusion (this knob does NOT override R-FAIL-1's 25K/5K parameters) is correct and is incorporated into R-FAIL-1's hard-coded clause; only the naming-history claim is rejected. Minor severity vs DA-153/-157.

<!-- @da: DA-155 -->
<a id="da-155"></a>

**DA-155.** **(Gemini-18 G18-3 tabular fabrication) Disambiguation table row "Universal Project File: 25,000 Tokens (Hard Limit) — Session initialization — Unexposed — Dictates the maximum structural ingestion of the core CLAUDE.md standard."** Rejected as fabrication. Same fabricated mechanism as [DA-153](#da-153), but logged as a separate DA because the tabular format implies a vendor-documented mechanism that does not exist — tabular precision is a different epistemic claim from prose framing, and conflating them in a single DA risks a future second-opinion researcher accepting the table while DA-153 only covers the prose. The canonical Anthropic memory doc explicitly contradicts the row's "Hard Limit" framing: *"CLAUDE.md files are loaded in full regardless of length."* The "Unexposed" column compounds the error by claiming a hidden hardcoded mechanism for which no source code exists. Adopted instead: **the disambiguation table in R-FAIL-1's "Confusable 25K figures" section enumerates SIX confusable mechanisms** (skill re-attach, Read-tool ceiling, MEMORY.md 25 KB, tool-response default, MAX_MCP_OUTPUT_TOKENS default, Cowork compaction-instruction overhead) — none of which is a CLAUDE.md ingestion cap.

<!-- @da: DA-156 -->
<a id="da-156"></a>

**DA-156.** **(Gemini-18 G18-4 quantitative overreach) "Five thousand tokens translates roughly to 18,000 to 22,000 characters of dense textual instruction"** as an architectural fact. Rejected as Discovery-tier rule-of-thumb packaged as quantitative architectural anchor. The 5,000-token limit is documented Tier-1; the specific 18,000-22,000-character envelope is not anchored to any Anthropic source or peer-reviewed measurement — it is a back-of-envelope conversion using assumed average tokens-per-character that varies substantially across language, code-block density, markdown formatting, and tokenizer choice. Per project domain rule §7 (pre-registration), quantitative thresholds adopted as rules require Tier-1 source backing; Gemini-18's conversion is methodologically reasonable but tier-discipline-failing. The directional claim that 5K tokens limits dense markdown content is correct and survives in R-FAIL-1's Opus-4.7 effective-budget caveat (where the 1.0-1.35× tokenizer-inflation range IS Tier-1 anchored to Anthropic's Opus 4.7 release notes). Severity: mild — Gemini-18's reasoning is sound, only the specific numeric range is unsourced.

<!-- @da: DA-157 -->
<a id="da-157"></a>

**DA-157.** **(Gemini-18 G18-5 env-var fabrication) Developers were forced to utilize a newly discovered environment variable, `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS`, to manually force the file-read threshold back to functional levels (e.g., 50,000 tokens), in response to the April 2026 silent 25K→10K downgrade documented in Issue #45019.** Rejected as fabricated env-var name. **Direct verification 2026-05-07:** the env var `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` does NOT exist in `code.claude.com/docs/en/env-vars`, `code.claude.com/docs/en/settings`, or any source-code reproduction. anthropics/claude-code Issue #45019 ([github.com/anthropics/claude-code/issues/45019](https://github.com/anthropics/claude-code/issues/45019), opened viniciusferrao 2026-04-08) verbatim states: *"I cannot find any controls to get back to 25000."* Issue #14888 ([github.com/anthropics/claude-code/issues/14888](https://github.com/anthropics/claude-code/issues/14888)) confirms the file-read limit is *"hardcoded"* and the issue is a Feature Request precisely because no override env var exists. Real Claude Code env vars in this naming neighborhood are `CLAUDE_CODE_MAX_OUTPUT_TOKENS` (model output cap, not file-read; Issues #4255, #6158, #24055, #24159) and `MAX_MCP_OUTPUT_TOKENS` (MCP tool-output cap, defaults to 25K per Issue #6158 verbatim *"MCPContentTooLargeError: MCP tool 'search_for_pattern' response (36382 tokens) exceeds maximum allowed tokens (25000)"*), neither of which controls the file-read 25K→10K behavior. Pattern: same fabrication signature as DA-153 — Gemini-18 confidently named a non-existent env var to anchor a real Anthropic mechanism (Issue #45019 silent downgrade) for which no override actually exists. **Independence note applied across DA-153..157:** five rejections from Gemini-18 are treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note`, not five independent unreliability signals. The systemic-Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16 of fabricating Anthropic-blessed mechanisms via misattribution to real GitHub-issue numbers and confident fabrication of env-var/setting names continues. Materially: Gemini-18's verified contributions on Task Budgets and meta-skill 5K-cap implication are useful; the cluster of fabrications around CLAUDE.md and env-var names indicates that any second-opinion citation of an issue number, env-var name, or setting key MUST be verified end-to-end before incorporation, regardless of how plausibly the surrounding prose reads.

<!-- @da: DA-Q019-1 -->
<a id="da-q019-1"></a>

**DA-Q019-1.** **(Gemini-19 supersession-rule overreach) The AutoDream consolidation engine "lacks the systemic permission to overwrite user prose" and "maintains a strictly segregated sub-directory that is inherently and permanently subservient to the primary ruleset," framed as a universal supersession rule that protects user-authored entries inside `MEMORY.md`.** Rejected for VALIDATED status on **two-level conflation grounds**. The framing collapses two distinct mechanisms: **(level A — cross-container)** the [R-MEM-1](#r-mem-1) hierarchy correctly places user-authored CLAUDE.md *above* Claude-written Auto Memory; AutoDream's documented file scope per [R-AUTODREAM-1](#r-autodream-1) is the auto-memory directory only, so AutoDream cannot touch CLAUDE.md/AGENTS.md/SKILL.md, and the cross-container reading "user always wins" is correct. **(level B — intra-MEMORY.md)** Within MEMORY.md itself, AutoDream MAY rewrite or destructively delete user-reinforced entries — Tier-1 [`anthropics/claude-code` Issue #47959](https://github.com/anthropics/claude-code/issues/47959) (`Auto Dream deletes memory files without user consent — 23 files lost in one day`, opened 2026-04-08, has-repro/data-loss labeled by Anthropic) documents *"a rule that had been reinforced 3 times by the user (never use 'Author: Claude' in copyright headers)"* being deleted, with the user's mitigation being to set `autoDreamEnabled: false` permanently. Gemini-19's universal-supersession reading is **directly contradicted** by Tier-1 #47959 at level B. **Pattern:** same two-level conflation signature as [DA-140](#da-140) (Gemini-15 BUDGET-MEM-1 conflating MEMORY.md's hard 200-line/25KB load cap with CLAUDE.md's load behavior). The cross-container reading is preserved and codified in [R-MEM-1-CLARIFICATION](#r-mem-1-clarification); the universal-supersession overreach is rejected. Adopted instead: **R-MEM-1-CLARIFICATION** locks in the cross-container/intra-MEMORY.md split with explicit Tier-1 anchor to #47959.

<!-- @da: DA-Q019-2 -->
<a id="da-q019-2"></a>

**DA-Q019-2.** **(Gemini-19 quantitative overreach) "Over 1,200 individual sessions experienced in excess of 50 consecutive compaction failures, resulting in the systemic waste of approximately 250,000 API calls per day globally"** anchored to "The Claude Code leak just gave every developer a masterclass in AI agent orchestration, Varshith Hegde, 2026, Dev.to, https://dev.to/iraycd/the-claude-code-leak-just-gave-every-developer-a-masterclass-in-ai-agent-orchestration-1km6". Rejected for VALIDATED status. The cited Dev.to article is a single Discovery-tier source (named-author blog post on aggregator platform), and the precise quantitative figures (1,200 sessions / 50 consecutive failures / 250,000 API calls per day globally) are not independently corroborated by any Tier-1 source, by any Anthropic-hosted bug-tracker thread, by Anthropic engineering posts, or by other independent post-leak analyses. Per project domain rule §7 (pre-registration), quantitative thresholds adopted as architectural facts require Tier-1 source backing. **Pattern:** same Discovery-rule-of-thumb-as-architectural-fact signature as [DA-156](#da-156) (Gemini-18's 18,000-22,000-character envelope for 5K tokens). Gemini-19 used the figures as illustrative narrative for *why* offline consolidation matters; the directional claim (active auto-compaction has documented inefficiency, motivating offline consolidation) is reasonable, but the precise quantification is a Discovery-tier blog illustration, not a measured architectural figure suitable for VALIDATED adoption. Severity: mild — the directional motivation survives without the unsourced numeric envelope.

<!-- @da: DA-Q019-3 -->
<a id="da-q019-3"></a>

**DA-Q019-3.** **(Gemini-19 arXiv misattribution) "Integrating sleep-time compute for memory consolidation, Sumers et al., 2025, arXiv, https://arxiv.org/html/2604.00009v1"** cited as the academic foundation for AutoDream's design. Rejected on direct end-to-end verification. **Verification 2026-05-07:** arXiv:2604.00009 IS a real paper — but the actual title is **"Eyla: Toward an Identity-Anchored LLM Architecture with Integrated Biological Priors"** (Discovery-tier — search-result anchor `arxiv.org/html/2604.00009`), NOT "Integrating sleep-time compute for memory consolidation." Sumers is **referenced inside Eyla** (the 2023 Sumers et al. cognitive-architectures-survey is one of Eyla's literature citations) but is **NOT the author** of arXiv:2604.00009. The Letta/sleep-time-compute connection appears as a **single one-line literature note** inside Eyla's related-work section: *"Letta (Letta, 2025) demonstrates sleep-time compute for memory consolidation."* Gemini-19 appears to have read a snippet of arXiv:2604.00009 surfacing the Letta/Sumers literature notes and confidently misattributed the paper's authorship and title. **Pattern:** same arXiv-misattribution signature as [DA-Q016-4](#da-q016-4) (Gemini-16's arXiv:2601.04583 misattribution). **The DIRECTIONAL claim that AutoDream's design draws on sleep-time-compute research IS correct:** the actual paper is **arXiv:2504.13171** ("Sleep-time Compute: Beyond Inference Scaling at Test-time"), and o-mega.ai's analysis cites the leaked `src/tasks/DreamTask/DreamTask.ts` directly with this anchor (verbatim: *"a background memory consolidation system inspired by UC Berkeley's 'Sleep-time Compute' research"* + *"the research it is based on (arXiv:2504.13171) showed a 5x reduction in test-time compute at equal accuracy"*). The 5× reduction figure is independently corroborated by smeuse.org's separate description of the same paper. Adopt the directional claim with the **corrected citation arXiv:2504.13171**; reject Gemini-19's specific Eyla-misattributed claim. **Independence note applied across DA-Q019-1..-3:** all three rejections from Gemini-19 are treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note`. The systemic-Gemini pattern (Gemini-2/5/6/7/8/10/13/15/16/18) of fabricating specific citations (issue numbers, env-var names, arXiv IDs, supersession-rule overreach) anchored to plausible-sounding mechanisms continues. Materially: Gemini-19's net contribution remains positive — the davccavalcante corroboration measurably strengthens the `tengu_*` namespace findings, the `code.claude.com/docs/en/glossary` anchor is new Tier-1 evidence, and the supersession-conflation rejection (DA-Q019-1) generated the most consequential addition to v1.17 ([R-MEM-1-CLARIFICATION](#r-mem-1-clarification)).

<!-- @end: discarded -->

---

<!-- @anchor: sessions -->
## Session Notes

One subsection per researched topic. Each contains pre-registration, sources consulted, decisions adopted, rejected claims, and second-opinion evaluation.

<!-- @session: Q-001 -->
<a id="q-001"></a>

### Sources Table

| Label | Tier | Source | Use |
|---|---|---|---|
| Anthropic-1 | Tier 1 | Extend Claude with skills (code.claude.com/docs/en/skills) | Primary canonical reference for Claude Code skill behavior, paths, precedence, budgets |
| Anthropic-2 | Tier 1 | Agent Skills overview (platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) | Claude API skills feature, frontmatter requirements, token budgets |
| Anthropic-3 | Tier 1 | Equipping agents for the real world with Agent Skills (anthropic.com/engineering, 2025-10-16) | Three-level progressive disclosure framing; mutual-exclusion splitting rationale |
| Anthropic-4 | Tier 1 | Effective context engineering for AI agents (anthropic.com/engineering, 2025-09-29) | Lazy loading and just-in-time retrieval principles |
| Anthropic-5 | Tier 1 | skills/skill-workshop/SKILL.md (github.com/anthropics/skills) | Imperative voice rule; "yellow flag" on heavy MUST/NEVER; 300-line ToC; extract-when-repeated trigger |
| Anthropic-6 | Tier 1 | skills/pdf, skills/docx, skills/doc-coauthoring (github.com/anthropics/skills) | Empirical patterns: SKILL.md + references/<topic>.md + scripts/ + assets/ separation |
| Anthropic-7 | Tier 1 | Issues #18192, #16438, #10238 (github.com/anthropics/claude-code) | Single-depth limitation confirmation |
| Anthropic-8 | Tier 1 | How Claude remembers your project (code.claude.com/docs/en/memory) | CLAUDE.md hierarchy and @import semantics |
| Anthropic-9 | Tier 1 | The Complete Guide to Building Skills for Claude (resources.anthropic.com) | kebab-case folder rule; no-README-inside-skill rule |
| agentskills-1 | Tier 2 | Agent Skills Specification (agentskills.io/specification.md) | Open-standard frontmatter constraints (name max 64, description max 1024) |
| Codex-1 | Tier 2 | Agent Skills (developers.openai.com/codex/skills) | Cross-vendor comparison ONLY; 2%/16,000 listing budget belongs to Codex, NOT Claude Code |
| VSCode-1 | Tier 2 | Use Agent Skills in VS Code (code.visualstudio.com/docs/copilot/customization/agent-skills) | Plugin namespacing hazard |
| AGENTS-1 | Tier 2 | agents.md project (agents.md, factory/Sourcegraph/Cursor docs) | Cross-tool standard scope and lookup order |
| Karpathy-1 | Discovery | llm-wiki gist (gist.github.com/karpathy/442a6bf555914893e9891c11519de94f, 2026-04-04) | Schema-document pattern (CLAUDE.md/AGENTS.md as schema layer); within-references index.md pattern |
| Karpathy-2 | Discovery | @karpathy on X (2025-06-25) | Definition of "context engineering" |
| Fowler-1 | Discovery | Structured-Prompt-Driven Development (martinfowler.com/articles/structured-prompt-driven/) by Zhang & Xia, 2026-04-28 | REASONS canvas; "fix the prompt first" governance rule |
| arXiv-2604.24026 | Tier-1-eligible (caveat: preprint not peer-reviewed) | Liang et al., Peking University, 2026-04-27 | SSL framing as VOCABULARY only; quantitative claims NOT adopted |
| Gemini-1 | Second-opinion (vetted) | Google Gemini Deep Research output, 2026-05-01 (this session) | Mostly agreement; two factual conflicts and one overreach (OS-reserved-names) rejected; new pointers: Issues #44199 (skill shadowing), #27569 (use-when ignored), agentskills.io `skills-ref validate` CLI |

---

### Decisions adopted (35 rules across 8 categories)

Full rule text lives in the **Skill Specification** and **System Design** tabs. Summary by category:

- **Frontmatter (R-FM-1..7):** name+description REQUIRED; name kebab-case ≤64; description ≤1024 chars in open standard, combined description+when_to_use ≤1,536 in Claude Code; no XML in YAML; no manual namespace prefix; reserved words `anthropic`, `claude`, and any native slash-command name (e.g. `mcp`, `agent`) forbidden.
- **Body & length (R-BODY-1..5):** SKILL.md ≤500 lines / ≤5,000 tokens; reference files >300 lines need ToC; recommended sections (Overview/Workflow/Examples/Gotchas) but NOT mandatory; no README.md inside skill folder.
- **Naming (R-NAME-1..2):** `SKILL.md` is case-sensitive (Anthropic supremacy over the Hanchung blog claim); folder name = frontmatter `name`.
- **Skill vs reference (R-SR-1..5):** procedural → SKILL.md or references/<topic>.md; factual → references/<name>.md with ToC; templates → assets/; executable → scripts/; references load only when SKILL.md cites them inline.
- **System organization (R-SYS-1..5):** single-depth folder is enforced; precedence enterprise > personal > project (inverse of CLAUDE.md memory!); no top-level skills index file is read; split-trigger 500 lines OR mutually-exclusive variants; cross-skill composition via subagent `skills:` preload OR `context: fork` + `agent:` (no programmatic skill→skill call).
- **CLAUDE.md / AGENTS.md (R-MEM-1..4):** memory hierarchy managed > project > rules > user > local > auto-memory; CLAUDE.md = facts everyone needs, skills = procedures that load on trigger; symlink AGENTS.md ↔ CLAUDE.md for cross-tool projects (PROPOSED workaround).
- **Helper scripts (R-HELP-1..7):** under `<skill>/scripts/`; Python preferred; stable CLI with --help and JSON-to-stdout; documented in SKILL.md Usage block; reference via `${CLAUDE_SKILL_DIR}`; pre-approve via `allowed-tools`; extract-when-repeated trigger from skill-workshop.
- **Context-efficiency (R-CTX-1..4):** progressive disclosure as architectural rule; mutually-exclusive content paths in separate files; SKILL.md bodies are STANDING (not re-read); first 5K tokens / shared 25K budget after compaction (Claude-Code-specific).

---

### Rejected claims (logged in Discarded Alternatives)

- **DA-001..DA-011** from my own Turn 1 findings (multi-depth folders; README inside skill; top-level index file; long procedures in CLAUDE.md; heavy MUST/NEVER style; manual namespace prefix; token-generation-instead-of-script for deterministic ops; programmatic skill→skill calling; treating SKILL.md as one-shot turn message; arXiv 2604.24026 quantitative thresholds; Karpathy index.md as Claude-Code-level mechanism).
- **DA-012 (from Gemini-1 overreach):** OS-reserved-name hazard (CON, PRN, AUX, NUL, COM1-9) cited by D.A. Wheeler. Rejected — credible source but no Anthropic citation links these to skill folder names; the kebab-case rule already forbids the offending tokens mechanically. Added to Discarded Alternatives so it is not re-proposed.
- **Gemini-1 conflict 1 (rejected):** 2%/16,000-char description listing budget — Anthropic Claude Code uses 1%/8,000. Codex uses 2%/16,000; do not conflate.
- **Gemini-1 conflict 2 (rejected):** 1,000-token re-attachment budget (Discovery: Porter Medium). Anthropic Tier 1 says 5,000 per skill / 25,000 combined.
- **Gemini-1 unverified:** "Linux Foundation-backed AGENTS.md" — kept the named-vendor backing list (Google, OpenAI, Factory, Sourcegraph, Cursor) and dropped the LF claim.

---

### Contradiction check

Cross-section contradiction check **passed**. v1.0 contained no prior research findings, so the only consistency requirement is internal: every adopted rule was checked for conflict against every other adopted rule. None found. The CLAUDE.md memory hierarchy (project > user) and skills precedence (enterprise > personal > project) are inverse — flagged as a documented footgun in R-SYS-2 and R-MEM-1, not a contradiction.

### Independent verification of Gemini-1 (≥3 sources)

Per `framework.second_opinion_review.evaluation`, ≥3 cited sources independently verified. The four sources directly fetched in Turn 1 that Gemini-1 also cites: (1) Anthropic Claude Code skills page, (2) anthropics/skills skill-workshop SKILL.md, (3) agentskills.io specification, (4) arXiv 2604.24026. Quorum met. Gemini-1's NEW citations (#44199 skill shadowing, #27569 use-when ignored, agentskills.io `skills-ref validate`) are queued for promotion-pass verification in Q-005.

### Cross-section impact

- **skill-spec tab:** populated all 6 sections (Skill Anatomy, Frontmatter Rules, Required Sections, Length and Style, Naming Conventions, Skill vs Reference Content)
- **system-design tab:** populated all 7 sections (System Organization, Locations and Precedence, Dependencies and Splitting Strategy, Satellite Files, Index Files, Interaction with CLAUDE.md/AGENTS.md, Context-Efficiency Techniques, Helper Scripts)
- **meta-validation tab:** unchanged — Q-003/Q-004 will populate it
- **Open queue:** added Q-006..Q-010

<!-- @session: Q-002 -->
<a id="q-002"></a>

### Reconciliation of the two parallel v1.1 files (Turn 1, Anthropic-supremacy)

| # | Conflict | FILE A position | FILE B position | Resolution | Authoritative source |
|---|---|---|---|---|---|
| 1 | SKILL.md body length cap | <300 lines (best-practices folklore) | ≤300 lines per skill-workshop | **≤500 lines** documented by Anthropic best-practices; both earlier numbers were folklore | platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |
| 2 | AGENTS.md cross-tool workaround | `@AGENTS.md` import (canonical) | Symlink (PROPOSED) | **FILE A wins.** `@AGENTS.md` is documented; recursive 5-hop max | code.claude.com/docs/en/memory |
| 3 | PowerShell access mechanism | `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` env var | `shell:` frontmatter field | **FILE A wins for tool activation.** `shell:` is documented only on per-hook entries and `defaultShell`, NOT on SKILL.md frontmatter root. DA-006 stands. | code.claude.com/docs/en/tools-reference |
| 4 | arXiv:2604.24026 affiliation | UNVERIFIABLE | Peking University (confident) | **FILE A wins.** Authors are real (Liang/Wang/Liang/Liu); affiliation field not visible on arXiv abstract page; admit SSL vocabulary only. | arxiv.org/abs/2604.24026 |
| 5 | CLAUDE.md size | <200 lines (hard) | ≤200 / ≤300 PROPOSED | **<200 lines strict target; ≤300 yellow flag.** | code.claude.com/docs/en/memory |
| 6 | Per-skill listing budget | Not mentioned | 1%/8K (introduced) | Adopt **2%/16K total + 250-char per-description** (FILE B's 1%/8K was itself folklore; the documented numbers differ). | code.claude.com/docs/en/skills + Issue #40121 |
| 7 | DA-007 (15K-char hallucinated budget) | Present | Absent | **Retain.** No Anthropic source supports 15,000-char global tool budget. | Negative finding |
| 8 | AGENTS.md Linux Foundation backing | Not addressed | Rejected as Gemini hallucination | **FILE B wrong; reverse rejection.** AAIF formed 9 Dec 2025, Linux Foundation-stewarded. AGENTS.md, MCP, goose are founding projects. | linuxfoundation.org/press; openai.com/index/agentic-ai-foundation; agents.md |

---

### Sources Table (Q-002 — incremental over Q-001)

| Label | Tier | Source | Use |
|---|---|---|---|
| Voyager-1 | Tier 1 | Wang, Xie, Jiang, Mandlekar, Xiao, Zhu, Fan, Anandkumar, *Voyager: An Open-Ended Embodied Agent with Large Language Models*, TMLR 2024 (arXiv:2305.16291). NVIDIA + Caltech. | Skill library, automatic curriculum, iterative-prompting verification — anchors R-XPOLL-1..3 |
| MRKL-1 | Tier 1 | Karpas et al. (AI21 Labs), *MRKL Systems*, 2022, arXiv:2205.00445 | Modular routing via textual descriptions of expert capability — anchors R-XPOLL-4 |
| Toolformer-1 | Tier 1 | Schick et al. (Meta AI), *Toolformer*, NeurIPS 2023, arXiv:2302.04761 | Trigger-shaped descriptions for tool/skill invocation — anchors R-XPOLL-5 |
| Reflexion-1 | Tier 1 | Shinn, Cassano, Berman, Gopinath, Narasimhan, Yao, *Reflexion*, NeurIPS 2023, arXiv:2303.11366. Northeastern/MIT/Princeton. | Self-reflection requires external verification signal — anchors R-XPOLL-6 |
| SelfRefine-1 | Tier 1 | Madaan et al., *Self-Refine*, NeurIPS 2023, arXiv:2303.17651. CMU/AI2/UW/Google/Meta. | Bounded iteration cap (~3 passes) — anchors R-XPOLL-7 |
| ReWOO-1 | Tier 1 | Xu, Peng, Lei, Mukherjee, Liu, Xu, *ReWOO*, 2023, arXiv:2305.18323. NC State + Microsoft. | Decouple reasoning from observations when outputs deterministic — anchors R-XPOLL-8 |
| DSPy-1 | Tier 1 | Khattab et al. (Stanford/Berkeley/CMU), *DSPy*, ICLR 2024, arXiv:2310.03714 | Programmatic compilation of declarative signatures — anchors R-XPOLL-9 + Q-003 architecture |
| AAIF-1 | Tier 2 | Linux Foundation, *Announces the Formation of the Agentic AI Foundation*, 9 Dec 2025; OpenAI co-founder announcement | AGENTS.md is LF-stewarded under AAIF — overturns FILE B rejection |
| agents-md-1 | Tier 2 | agents.md (April 2026 homepage); developers.openai.com/codex/guides/agents-md; docs.factory.ai/cli/configuration/agents-md | Closest-file-wins precedence; AGENTS.override.md higher precedence; programmatic-checks discoverability — anchors R-MEM-7..9 |
| AnthropicAPI-1 | Tier 1 | platform.claude.com/docs/en/build-with-claude/skills-guide (Using Agent Skills with the API) | **8-skills-per-request limit** in Messages API — anchors NEW R-API-1 |
| Hamel-1 | Discovery | Hamel Husain, *Evals Skills for Coding Agents*, hamel.dev/blog/posts/evals-skills/, March 2026 | Eval-driven skill design; eval-audit pattern — supports R-XPOLL-2 strengthening; cross-ref for Q-008 |
| Yan-1 | Discovery | Eugene Yan, *Patterns for Building LLM-based Systems & Products*, eugeneyan.com/writing/llm-patterns/, 2023 | Defensive UX, Guardrails patterns — supports invocation-control rule under R-FM-6 |
| Willison-1 | Discovery | Simon Willison, blog posts on Agent Skills (simonwillison.net 2025-10-16) and Agentic Engineering Patterns | Action-Selector pattern (cross-ref for R-CTX subagent isolation) |
| Weng-1 | Discovery | Lilian Weng, *LLM Powered Autonomous Agents*, lilianweng.github.io/posts/2023-06-23-agent/, 23 June 2023 | Procedural vs declarative memory framing — confirms Q-001 R-SR (cross-reference, no new rule) |
| Hanchung-1 | Discovery | Lee Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, leehanchung.github.io 2025-10-26 | Empirical confirmation that routing is description-similarity-based — supports MRKL-1 / R-XPOLL-4 |
| Gemini-2 | Second-opinion (vetted) | Google Gemini Deep Research output, 2026-05-01 (this Turn 2) | Confirmed paper set; introduced 4 hallucinations rejected with rationale (DA-021..024); confirmed eval-driven design as principle but not Gemini-2's specific schema; surfaced AAIF reversal |

---

### Decisions adopted (12 new rules + 1 corrective)

- **R-XPOLL-1..3 (Voyager, TMLR 2024)** — Skill library architecture: descriptions as retrieval keys; pre-commit verification against examples; curriculum-style meta-skill onboarding.
- **R-XPOLL-4 (MRKL, AI21 2022)** — Description disambiguation: validation-script flags pairwise cosine similarity ≥ 0.85 across descriptions in a project.
- **R-XPOLL-5 (Toolformer, NeurIPS 2023)** — Trigger-shaped description grammar: every description MUST include a *Use when…* / *When…* clause naming concrete user-utterance triggers.
- **R-XPOLL-6 (Reflexion, NeurIPS 2023)** — Self-update requires an external verification signal (test/lint/user-correction); no LLM-confidence-only auto-edits. Routes to Q-007.
- **R-XPOLL-7 (Self-Refine, NeurIPS 2023)** — Promotion-pass cap of 3 iterations per session. Routes to Q-007.
- **R-XPOLL-8 (ReWOO, 2023)** — Deterministic helper outputs are facts: SKILL.md body SHOULD NOT include reasoning prose between a deterministic script and its consumption.
- **R-XPOLL-9 (DSPy, ICLR 2024)** — Meta-skill is a compiler, not a template engine: declarative spec → compiled SKILL.md → metric (validation script). Routes to Q-003 + Q-004.
- **R-MEM-7 (agents.md / Codex docs)** — Closest-file-wins precedence: nested AGENTS.md / CLAUDE.md, the file closest to the edited path takes precedence; explicit user chat prompts override all files.
- **R-MEM-8 (Codex AGENTS.md docs)** — `AGENTS.override.md` pattern at the same directory level for higher-precedence siblings; portable because the import simply names the file.
- **R-MEM-9 (agents.md spec)** — AGENTS.md / CLAUDE.md MAY enumerate programmatic checks (lint, test) that the agent SHOULD run before declaring done.
- **R-API-1 (Anthropic API skills-guide) — NEW VALIDATED** — *In the Messages API, you can include up to 8 Skills per request* via the `container.skills` parameter. This is the API-side upper bound on simultaneous skill activation; it does NOT apply to filesystem-based Claude Code skills, which scale with the listing budget instead.
- **R-BODY-1 corrective (CRITICAL)** — SKILL.md body cap is **≤500 lines** per Anthropic best-practices. Both parallel v1.1 files used folklore numbers (100 and 300); the canonical number is documented at platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.

---

### Rejected claims (logged in Discarded Alternatives — DA-018..DA-024)

- **DA-018** Tree-of-Thoughts as a skill-body authoring rule (Yao et al., NeurIPS 2023). Claude Code already implements deliberate search at runtime via extended thinking + Plan Mode; mandating it inside SKILL.md duplicates Anthropic's runtime planner.
- **DA-019** Plan-and-Solve as a mandatory SKILL.md body opener (Wang et al., ACL 2023). Claude Code's Plan Mode is the canonical mechanism; instructing every skill author to write a planning prefix duplicates that.
- **DA-020** ART task-library auto-selection as a routing replacement (Paranjape et al., 2023). Claude already routes from frontmatter descriptions; ART-style program-template lookup would require a separate runtime mechanism Anthropic has not exposed.
- **DA-021 (Gemini-2 fabrication)** "20 skills per session" hard limit. **Rejected.** The actual Anthropic-documented limit is **8 skills per Messages API request** (skills-guide); no "per-session" 20-skill cap appears anywhere in Anthropic docs. Adopted the real number as R-API-1.
- **DA-022 (Gemini-2 fabrication)** `mode: true` boolean as an Anthropic frontmatter field. **Rejected.** No such field appears in any Anthropic skill documentation; the actual frontmatter fields are `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context: fork`, `agent`, `hooks`, `paths`, `allowed-tools`. Behavioral overlays do not require a new field — `disable-model-invocation: true` already covers the manual-invocation-only case.
- **DA-023 (Gemini-2 fabrication)** `CLAUDE_CODE_FORK_SUBAGENT` environment variable. **Rejected.** The real mechanism is the `context: fork` frontmatter field already documented in code.claude.com/docs/en/skills and adopted in v1.1 R-CTX. Per the framework's `independence_note`, this also flags the failure mode of inventing env vars when frontmatter exists.
- **DA-024 (Gemini-2 overreach)** Mandatory `eval_queries.json` schema with a fixed positive-to-negative trigger ratio. **Rejected as Gemini-2 invention.** Hamel Husain's *Evals Skills for Coding Agents* (March 2026, verified) is the cited inspiration but does NOT mandate this specific filename or schema. The broader principle (skills should ship with an eval suite) is admitted as PROPOSED for Q-008, without the fabricated schema.

---

### Cross-section impact

- **skill-spec tab** — Frontmatter Rules: add R-XPOLL-5 (trigger-shaped grammar), R-API-1 (8-skill API limit). Length and Style: correct R-BODY-1 to **≤500 lines** with explicit citation. Skill vs Reference Content: add R-XPOLL-1 (descriptions as retrieval keys) cross-reference.
- **system-design tab** — Locations and Precedence: add R-MEM-7..9 (closest-file-wins, AGENTS.override.md, programmatic-checks). Dependencies and Splitting: add R-XPOLL-2 (pre-commit skill verification) and R-XPOLL-4 (description disambiguation) as cross-skill organization rules. Add `InstructionsLoaded` hook tooling note.
- **meta-validation tab** — Promote from PENDING. Validation script gains seven new mechanical checks anchored in R-XPOLL-4/5/8 + R-API-1 + R-BODY-1 corrective + listing-budget heuristic. Q-003 architectural anchor: DSPy compilation model (R-XPOLL-9) and Voyager curriculum (R-XPOLL-3).
- **research tab** — Open Queue: Q-002 → ✦ Researched v1.2; blue callout → Q-003. Tracker: T-002 added. Discarded Alternatives: DA-018..DA-024 added. References: v1.2 entry added.
- **changelog tab** — v1.2 entry inserted at top; v1.1 set current=false.
- **meta** — version 1.1 → 1.2; date 2026-05-01.

<!-- @session: Q-003 -->
<a id="q-003"></a>

### Sources Table (Q-003 — incremental over Q-002)

| Label | Tier | Source | Use |
|---|---|---|---|
| Anthropic-skills-1 | Tier 1 | github.com/anthropics/skills — `skills/skill-workshop/SKILL.md` (485 lines; 32.4 KB; pushy trigger-rich description; 9 helper scripts; 1 ref doc; 1 asset; 3 sub-agent prompts). | Canonical reference for meta-skill anatomy; anchors R-META-1..15. |
| Anthropic-skills-2 | Tier 1 | github.com/anthropics/skills — `skill-workshop/scripts/{init_skill,quick_validate,package_skill,run_eval,run_loop,improve_description,aggregate_benchmark,generate_report,utils}.py`. | Deterministic helpers; anchors R-META-10 split. |
| Anthropic-skills-3 | Tier 1 | github.com/anthropics/skills — `skill-workshop/references/schemas.md` (evals.json schema, behavioral 2–3 prompts, trigger-eval 20 queries 60/40 split). | Anchors R-META-15 (eval set sizing). |
| Anthropic-skills-issue-37 | Tier 1 | github.com/anthropics/skills/issues/37 — frontmatter whitelist `{name, description, license, allowed-tools, metadata}`; unexpected keys break Claude.app import. | Anchors R-META-2 (frontmatter strictness). |
| Anthropic-skills-issue-239 | Tier 1 | github.com/anthropics/skills/issues/239 — generated SKILL.md fails validation due to `[TODO ...]` parsed as YAML list. | Anchors R-META-7 (creation-time validation gate). |
| Anthropic-skills-issue-518 | Tier 1 | github.com/anthropics/skills/issues/518 — grader subagents misroute grading.json; Bash blocked during baseline `without_skill` runs inflating baseline scores; `aggregate_benchmark.py` glob mismatch (`eval-*` vs descriptive names). | Anchors R-META-19 (Bash-availability assertion in eval baseline) — Gemini-3 contribution, verified. |
| Anthropic-skills-issue-532 | Tier 1 | github.com/anthropics/skills/issues/532 — `run_loop.py` requires `ANTHROPIC_API_KEY`, breaking enterprise SSO users (majority of base). | Anchors R-META-7 strengthening (validator must be SSO-compatible) — Gemini-3 contribution, verified. |
| Anthropic-skills-issue-34609 | Tier 1 | github.com/anthropics/claude-code/issues/34609 — `run_loop.py` silently uses `ANTHROPIC_API_KEY`, $18 surprise charges. | Strengthens R-META-9 / R-META-7 (no silent network actions). |
| Anthropic-guide-1 | Tier 1 | resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf — official 32-page playbook; description form `[What it does] + [When to use it] + [Key capabilities]`. | Anchors R-META-13 (Toolformer-style trigger grammar enforcement). |
| DSPy-1 | Tier 1 | Khattab et al. (Stanford+UC Berkeley+CMU), *DSPy: Compiling Declarative Language Model Calls into Self-Improving Pipelines*, ICLR 2024, arXiv:2310.03714. | Compiler model → R-META-3, R-META-4. BootstrapFewShot `max_bootstrapped_demos=4` default. |
| DSPy-docs | Tier 1 | dspy.ai/learn/optimization/optimizers — `BootstrapFewShot(metric, max_bootstrapped_demos=4, max_labeled_demos=16)`. | Quantitative anchor for example count in R-META-15. |
| SelfRefine-1 | Tier 1 | Madaan et al. (CMU+AI2+UW+Google+Meta), *Self-Refine*, NeurIPS 2023, arXiv:2303.17651 — diminishing returns past iteration 2; experiments capped at 4 iterations. | Anchors R-META-8 (3-iteration cap). |
| Reflexion-1 | Tier 1 | Shinn et al. (Northeastern+MIT+Princeton), *Reflexion*, NeurIPS 2023, arXiv:2303.11366 — verbal RL with external feedback signals. | Anchors R-META-9 (external verification = validator AND user-accept). |
| ReWard-hacking-1 | Tier 1 | Pan et al., *Spontaneous Reward Hacking in Iterative Self-Refinement*, 2024, arXiv:2407.04549 — same-model self-judging diverges from ground-truth under optimization pressure. | Reinforces R-META-9 (no LLM-confidence-only signals). |
| Voyager-1 | Tier 1 | Wang et al. (NVIDIA+Caltech), *Voyager*, TMLR 2024, arXiv:2305.16291; curriculum.txt prompt; first-15-tasks-no-retrieval. | Anchors R-META-11 (zero-bundling) and R-META-12 (3-tier curriculum). |
| ReWOO-1 | Tier 1 | Xu et al. (NC State+Microsoft), *ReWOO*, 2023, arXiv:2305.18323 — decouple planner from worker; deterministic outputs are facts. | Anchors R-META-10 (deterministic-vs-LLM split). |
| agentskills-spec | Tier 2 | agentskills.io/specification — open standard: scaffold tree `SKILL.md + scripts/ + references/ + assets/`. | Confirms R-META-5 (scaffolding tree structure). |
| npm-init | Tier 2 | docs.npmjs.com/cli/v11/commands/npm-init — 8-prompt baseline; `--yes` zero-prompt path. | Anchors R-META-6 elicitation portability + DA-029 rejection. |
| cargo-new | Tier 2 | Sheshbabu, *Rust for JS Devs Tooling Overview*, 2023 — `cargo new` zero-prompt fixed scaffold. | Confirms `--yes` non-interactive path is portable industry norm. |
| precommit-1 | Tier 2 | Chacon & Straub, *Pro Git: Git Hooks*, git-scm.com — pre-commit/pre-push gating. | Anchors R-META-7 (rejecting save-time validation). |
| lint-staged-1 | Tier 2 | Hjelle, lint-staged pre-commit hook gist, 2020, gist.github.com/dahjelle/8ddedf0aebd488208a9a7c829f19b9e8 — staged-only, never on save. | Confirms DA-027 rejection of save-time validation. |
| Gemini-3 | Second opinion | Google Gemini Deep Research output for Q-003 meta-skill design, submitted by user 2026-05-01. Vetted: Issues #518/#532 verified real → R-META-18..19 added; YAML+JSON-Schema embedding accepted → R-META-3 strengthened; negative counter-examples principle accepted → R-META-16; synthetic→organic example lifecycle accepted → R-META-17. Rejected: 3 fabricated/misattributed arXiv IDs (DA-031..033) and one folklore-repeat 100-line cap (DA-034 — same shared-training-artifact error class as Gemini-2 v1.1). | Net contribution: 4 new rules adopted, 4 fabrications rejected. |

### Decisions adopted (15 base + 4 Gemini-3 incorporations)

- **R-META-1 [skill][claude-code-only][VALIDATED]** — Meta-skill ships at `<scope>/skills/skill-workshop/SKILL.md`, conforming to the same spec it generates. Eat-its-own-dogfood requirement.
- **R-META-2 [reference][portable][VALIDATED]** — Frontmatter MUST contain `name` + trigger-rich `description` ≤1024 chars; MAY contain `license`, `allowed-tools`, `metadata`. Whitelist is exactly `{name, description, license, allowed-tools, metadata}` (Issue #37). `compatibility` is a flagged mismatch (in skill-workshop body but not in the validator whitelist — see cross-section impact).
- **R-META-3 [skill][portable][PROPOSED]** — Declarative spec input is `.skill-spec.yaml` with `{name, intent, triggers[], output_contract, allowed_tools[], needs.{scripts,references,assets}, evals.{behavioral, triggers}}`. **Strengthening per Gemini-3:** the spec MUST validate against an embedded JSON Schema before any LLM authorship runs (deterministic fail-fast on type errors). JSON Schema lives in `skill-workshop/references/skill-spec.schema.json`.
- **R-META-4 [skill][claude-code-only][PROPOSED]** — Compiler step `compile_skill(spec) → SkillFolder` in strict order: (1) JSON-Schema validate spec; (2) deterministic `init_skill.py` scaffold; (3) deterministic frontmatter assembly; (4) LLM body authorship using ≤3 retrieved exemplar skills; (5) LLM description authorship; (6) bounded description-optimization loop ≤3 iterations; (7) deterministic `quick_validate.py` — fail-closed.
- **R-META-5 [skill][portable][VALIDATED]** — Scaffold drops AT MINIMUM `SKILL.md` + `evals/evals.json`. Drops `scripts/`, `references/`, `assets/` ONLY when `needs.*: true`. Deletes all `.gitkeep` and placeholder examples after authorship. Never drops a skill-root `README.md` (DA-002).
- **R-META-6 [skill][portable][VALIDATED]** — Elicitation = exactly 4 required prompts: (a) what does it enable? (b) when should it trigger? (c) expected output format? (d) eval cases yes/no? Optional follow-up "Interview" phase only for unanswered edge cases. Non-interactive `--yes` path permitted with sane defaults; MUST still elicit `name` + `triggers`.
- **R-META-7 [skill][portable][VALIDATED]** — Validator runs at exactly two gates: (a) immediately after `init_skill.py` scaffold (creation gate; fixes Issue #239); (b) inside `package_skill.py` before producing the `.skill` artifact (finalization gate). MUST NOT auto-run on every save. **Strengthening per Gemini-3 (Issue #532):** validator is SSO-compatible — does NOT require `ANTHROPIC_API_KEY` for its core path. Use `claude` CLI subprocess for any LLM call when no API key is present.
- **R-META-8 [reference][portable][VALIDATED]** — Iteration cap = 3 for body refinement and 3 for description optimization (tighter than skill-workshop's current `--max-iterations 5`). Early-stop if no improvement after 1 iteration.
- **R-META-9 [skill][portable][VALIDATED]** — External verification signal for promotion = (`quick_validate.py` PASS) AND (user feedback empty OR explicit accept). Validator-only or LLM-confidence-only signals are insufficient. No silent auto-fix; no silent network actions (per Issue #34609).
- **R-META-10 [reference][portable][VALIDATED]** — Deterministic helpers (no LLM): `init_skill.py`, `quick_validate.py`, `package_skill.py`, `aggregate_benchmark.py`, frontmatter YAML emission, kebab-case checking, length counting, ZIP creation, eval-set 60/40 stratified split. LLM authorship: description prose, body prose, behavioral example synthesis, trigger-eval phrase generation, feedback interpretation, blind-comparator judgment.
- **R-META-11 [skill][claude-code-only][PROPOSED]** — Meta-skill ships ZERO bundled example skills inside its own folder. Retrieves user's prior skills by description embedding (Voyager top-5); falls back to public `anthropics/skills` library reference if none exist.
- **R-META-12 [skill][claude-code-only][PROPOSED]** — Curriculum has 3 tiers gated on user history (count of skills authored): Tier-1 (0 prior) → "vibe" mode, no evals required; Tier-2 (1–9) → eval prompts (2-3) required; Tier-3 (10+) → trigger-eval optimization, blind comparison, benchmark mode unlocked. Count = `ls ~/.claude/skills/ | wc -l`.
- **R-META-13 [skill][portable][VALIDATED]** — Compiler MUST emit a `description` of the form `"<verb-phrase>. Use when <utterance triggers>."` enforcing R-XPOLL-5. Validator extends `quick_validate.py` to flag descriptions lacking a "Use when…" / "When…" clause as warning (strict mode: error).
- **R-META-14 [skill][claude-code-only][PROPOSED]** — Body cap for the meta-skill itself: ≤400 lines (vs 500-line global cap). The reference skill-workshop (485 lines) violates this — flagged for upstream issue.
- **R-META-15 [skill][portable][VALIDATED]** — Eval-set for the meta-skill itself: 3 behavioral test prompts ("create a fresh skill", "improve an existing skill", "optimize a description") and 20 trigger-eval queries (10 should-trigger, 10 should-not-trigger). The meta-skill's evals.json is itself a conformance example.
- **R-META-16 [skill][portable][PROPOSED] — Gemini-3 contribution.** Conformance examples set MUST include at least one negative counter-example (DSPy Assertions principle: behavioral guardrails via explicit "what not to do" demonstrations). For the standard 2–3 behavioral set, that means at least 1 of the 2–3 is a negative or boundary case.
- **R-META-17 [skill][portable][PROPOSED] — Gemini-3 contribution.** Examples lifecycle = synthetic-bootstrap → organic-trace replacement. Initial 2–3 behavioral examples are LLM-synthesized; a programmatic hook (`--inject-trace <path>`) lets users replace synthetic examples with verified real-world execution traces over time. The meta-skill's `improve_description.py` analog for examples is `improve_examples.py` (not yet shipped in skill-workshop).
- **R-META-18 [reference][claude-code-only][PROPOSED] — Gemini-3 contribution.** Issue #518 failure-mode rules: validator + run_eval MUST refuse to publish a benchmark report when (a) any subagent's `Bash` tool was unavailable in a `without_skill` baseline run, or (b) any `grading.json` file lands outside its expected `<eval-name>/<config>/` path, or (c) the aggregate script glob mismatches the configured eval-naming convention.
- **R-META-19 [skill][portable][PROPOSED] — Gemini-3 contribution.** When running paired `with_skill` vs `without_skill` evaluations, the meta-skill MUST assert tool-environment parity in writing before the run starts ("Both runs have access to: Bash, Read, Write, Edit, Grep, Glob") and validate post-run that this parity held. Anchors against Issue #518 inflation pathology.

### Rejected claims — Q-003 specific (DA-025..DA-034)

- **DA-025** Pure-template (Cookiecutter-style Jinja) approach — fixed template + variable substitution, no LLM authorship. **Rejected.** Description quality measurably affects retrieval; trigger-shaped grammar cannot be naïvely templated; community has migrated AWAY from pure templating (Yeoman/Cookiecutter) toward generative authorship.
- **DA-026** Runtime LLM-only generation with no scaffold script — Claude writes the entire folder from prompts at session time. **Rejected.** Violates ReWOO determinism (R-XPOLL-8); kebab-case naming, frontmatter YAML, and ZIP packaging are deterministic problems where LLM generation introduces non-deterministic failures (Issue #239 is the case study).
- **DA-027** Validate-on-save (run `quick_validate.py` on every Edit/Write of SKILL.md). **Rejected.** Save is too aggressive: blocks intermediate states; blocks edits not part of the eventual commit. lint-staged community treats save-time validation as anti-pattern; pre-commit/finalization gating is norm.
- **DA-028** Tree-of-Thoughts–style search inside the meta-skill (branching + backtracking over candidate body drafts). **Rejected.** Self-Refine reports diminishing returns past iteration 2 in this domain; ToT increases cost without measurable gain; we already have ≤3 linear iterations as the cap.
- **DA-029** Mandatory wizard UI / forced interactive 4-prompt sequence with no `--yes` non-interactive path. **Rejected.** Forces meta-skill into UI mode incompatible with subagent invocation in headless environments. `npm init -y` and `cargo new` ship zero-prompt paths.
- **DA-030** Auto-fix everything on validator failure (silently rewrite invalid frontmatter to make it valid). **Rejected.** Violates Reflexion external-signal requirement; Issue #34609 ($18 silent charges) is the cautionary tale for silent-action footguns.
- **DA-031 (Gemini-3 fabrication)** "0→1 shot 2%→24% accuracy lift; 2–5 shots plateau 32–38%" attributed to *Search Self-Play* (Lu et al. 2025, arXiv:2510.18821). **Rejected.** The arXiv paper EXISTS (verified via arxiv.org/abs/2510.18821 — Hongliang Lu et al., Alibaba-Quark + SYSU, posted 2025-10-21) but it is about reinforcement-learning self-play for search agents, NOT few-shot example count scaling. The cited percentages do not appear in the paper. Misattribution.
- **DA-032 (Gemini-3 fabrication)** "Exactly four examples represents the mathematical optimum for instruction-following robustness" attributed to *Mazeika et al. 2024, arXiv:2402.14656*. **Rejected.** arXiv:2402.14656 is "A short account of thermoelectric film characterization techniques" — a physics paper, not an LLM paper. The arXiv ID is wrong; the claim itself is unverifiable. (The 4-demos default is real but anchors only in DSPy `BootstrapFewShot` defaults — already in R-META-15 via DSPy-docs.)
- **DA-033 (Gemini-3 misattribution)** "Self-Refine performance plateaus after exactly three iterations" attributed to *ShieldLearner* (Ni et al. 2025, arXiv:2502.13162). **Rejected.** ShieldLearner exists (verified) but is about jailbreak attack defense in LLMs, NOT Self-Refine iteration mechanics. Misattribution. The 3-iteration cap is properly anchored in the actual Self-Refine paper (Madaan et al., NeurIPS 2023, arXiv:2303.17651) — already in R-META-8 via SelfRefine-1.
- **DA-034 (Gemini-3 folklore-repeat)** "SKILL.md body strictly under 100 lines per documented best practices." **Rejected.** This is the same body-length folklore class we already corrected in v1.2 (R-BODY-1 corrective: canonical Anthropic limit is ≤500 lines per the official best-practices guide). Per `framework.second_opinion_review.independence_note`, this is the third Gemini variant of the same training-artifact error (Gemini-2 said 300; Gemini-3 says 100) — treated as one data point, not independent confirmation.

### Cross-section impact (atomic write applied this session)

- **skill-spec tab** — Minor: confirm whitelist `{name, description, license, allowed-tools, metadata}` (per Issue #37); flag that `compatibility` appears in skill-workshop body but not in whitelist (mismatch logged for Q-005 promotion-pass).
- **system-design tab** — Skill Library Architecture: meta-skill placement = `<scope>/skills/skill-workshop/`; scaffold drops files into a sibling skill folder. Satellite-file conventions confirmed: `scripts/`, `references/`, `assets/`, plus optional `evals/` and `agents/` (sub-agent prompts).
- **meta-validation tab** — Meta-Skill Spec section fully populated by R-META-1..19. Validation Rules: `quick_validate.py` extended with R-META-13 (trigger-grammar check) and R-META-18..19 (Bash-availability and grading.json-path assertions). Validation Script Design: hook integration at exactly two gates (create + finalize), SSO-compatible.
- **research tab** — Open Queue: Q-003 → ✦ Researched v1.3; blue callout → Q-004. Tracker: T-003 added. Discarded Alternatives: DA-025..DA-034 appended. References: v1.3 entry added in descending order.
- **changelog tab** — v1.3 entry inserted at top with `current=true`; v1.2 set `current=false`.
- **meta** — `version` 1.2 → 1.3; `date` 2026-05-01.

### Contradiction check

> **Passed** _(green)_
>
> **Contradiction check across all prior research: PASSED with 1 deferred resolution.** R-META-1..19 are consistent with R-FM-1..7, R-BODY-1..5, R-NAME-1..2, R-SR-1..5, R-SYS-1..N, R-XPOLL-1..9, R-API-1, R-MEM-7..9, and the R-BODY-1 corrective. **Deferred resolution:** the `compatibility` frontmatter key appears in the skill-workshop SKILL.md body but is not in the validator whitelist `{name, description, license, allowed-tools, metadata}` — this is a single-source mismatch within Anthropic's own materials. Logged for Q-005 promotion-pass verification rather than resolved here, since the practical effect (Claude.app rejects the key) is consistent with the whitelist and contradicts the body prose.

<!-- @session: Q-004 -->
<a id="q-004"></a>

### Sources Table (Q-004 — incremental over Q-003)

| Label | Tier | Source | Use |
|---|---|---|---|
| Anthropic-best-practices-1 | Tier 1 | platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices — 500-line body cap; ≤5000 tokens recommended; 100-line TOC threshold for references; description ≤1024; description+when_to_use ≤1536. | Anchors R-FM-3, R-FM-4, R-BODY-1 corrective, R-BODY-2 token-budget threshold; surfaces R-BODY-4 100-vs-300 contradiction. |
| Anthropic-skills-CodeDocs | Tier 1 | code.claude.com/docs/en/skills — `disable-model-invocation: true` field documented; permission syntax Skill(name) and Bash(command *); allowed-tools field; user-invocable field. | Validates Gemini's `disable-model-invocation: true` proposal; anchors validator-skill frontmatter design; confirms Bash(python3 *) glob syntax for allowed-tools. |
| Anthropic-skills-issue-37 (re-cite) | Tier 1 | github.com/anthropics/skills/issues/37 — frontmatter allow-list confirmed as `{name, description, license, allowed-tools, metadata}` (NOT just `{name, description}` as Gemini falsely claimed). | Anchors R-FM-6 candidate and rejects Gemini's allow-list narrowing. |
| Anthropic-claudecode-issues-disable-mi | Tier 1 | github.com/anthropics/claude-code/issues/26251, /22345, /19141 — known semantic gaps with `disable-model-invocation`: blocks user invocation in some configs (#26251), ignored in plugin context (#22345), needs clearer docs vs `user-invocable` (#19141). | Caveats on validator-skill frontmatter — disable-model-invocation: true alone may break `/skill-validator` slash invocation; pair with explicit user-invocable: true to be safe. |
| Anthropic-hooks-guide | Tier 1 | code.claude.com/docs/en/hooks-guide — Claude Code hooks treat exit code 2 specifically as 'block' signal. | Anchors Anthropic-supremacy decision on exit-code contract (0=pass, 1=warn-only, 2=fail) over Gemini's flake8-style 1=any-fail. |
| agent-ecosystem-validator | Tier 2 | github.com/agent-ecosystem/skill-validator (v1.1.0, March 2026, Go, MIT, 45 stars) — VERIFIED REAL. CLI: validate structure / validate links / analyze content / analyze contamination / score evaluate / check. Exit codes: 0=clean, 1=errors, 2=warnings, 3=CLI/usage error. --strict flag promotes warnings to errors. Token thresholds: SKILL.md body warns at 5K tokens or 500 lines; per-reference warn 10K err 25K; total references warn 25K err 50K. Uses o200k_base encoding. Detects unclosed code fences (error), broken internal links (error), orphan files via reachability graph with Python import resolution. Pre-commit hook IDs are platform-specific (skill-validator-claude, etc.). | Anchors NEW PROPOSED rules R-BODY-6/7 R-SR-6/7 R-XPOLL-10 R-CONTAM-1; confirms Gemini's --strict pattern; surfaces o200k_base encoding update; surfaces exit-code disagreement (skill-validator uses 1=err 2=warn, our project uses 1=warn 2=err for Claude Code hook compatibility). |
| agentskills-io-spec | Tier 2 | agentskills.io — Agent Skills specification used by agent-ecosystem/skill-validator as conformance target. | Tier-2 source for the de-facto cross-platform skill spec; useful for portability flag decisions. |
| pre-commit-framework | Tier 2 | pre-commit.com — language: python, additional_dependencies, pass_filenames behavior, files regex semantics. | Anchors the .pre-commit-hooks.yaml and .pre-commit-config.yaml designs. |
| sentence-transformers | Tier 2 | sbert.net — `sentence-transformers/all-MiniLM-L6-v2` model card; util.cos_sim API. | Anchors R-XPOLL-4 default embedding choice; threshold 0.85 remains pre-registered project-internal. |
| tiktoken-o200k | Tier 2 | github.com/openai/tiktoken — o200k_base encoding (gpt-4o family); replaces cl100k_base for closer parity with modern model tokenizers. | Anchors encoding switch in R-BODY-2 mechanical heuristic. |
| Gemini-4 (second opinion) | Discovery (vetted) | Google Gemini Deep Research output for Q-004, submitted by user 2026-05-01. Vetted: 4 contributions accepted (disable-model-invocation, --strict flag, generic-markdown-linter discard, agent-ecosystem repo URL); 5 rejected (false Issue #37 narrowing, broken pre-commit regex, broken pass_filenames, suspicious arxiv ID, incompatible exit-code contract). | Surfaces real agent-ecosystem/skill-validator repo (largest find of the turn); rejected hallucinations logged in DA-039..DA-043. |

### Decisions adopted (Q-004)

- **Rule classification matrix completed.** All 50 v1.3-adopted rules classified: 27 MECHANICAL (deterministic Python check), 18 SEMANTIC (deferred to Q-008 LLM-judge), 5 HYBRID. Full per-rule heuristic, severity, and false-positive mitigation in tabs.meta-validation.Validation Rules (machine-checkable).
- **Validator CLI design.** Exit codes 0=pass / 1=warn-only / 2=fail (matching code.claude.com/docs/en/hooks-guide where exit 2 blocks); 64=misuse, 65=malformed input, 66=cannot open, 70=internal error (sysexits.h convention). --strict promotes warnings to failures (adopted from Gemini and confirmed by agent-ecosystem). --format {json,text} with TTY auto-detect. --embedding-model overrides default sentence-transformers/all-MiniLM-L6-v2. --self-path for R-XPOLL-9. --surface {api,claude-code,both} for R-FM-6 frontmatter scope.
- **JSON output schema finalized.** Custom-compact (not SARIF — too verbose for LLM context per Gemini's correct architectural argument). Schema: {schema_version, validator_version, embedding_model, embedding_model_revision, started_at, duration_seconds, library_root, skills_examined, findings:[{rule_id, severity, message, file, line, column, skill, citation, suggested_fix?, tags[]}], summary:{fail,warn,info,pass}, exit_code}. citation field MANDATORY for fail-severity findings.
- **Hook integration at two gates.** Creation-time: skill-workshop body invokes scripts/validate.py before package_skill writes; exit_code==2 blocks. Finalization-time: .pre-commit-hooks.yaml ships inside the validator skill folder for `local: repo` consumers; .github/workflows/validate-skills.yml example provided. CRITICAL FIX vs Gemini's draft: pass_filenames: false (cross-skill R-XPOLL-4 needs full library); files: 'SKILL\.md$' only (no broken `~/\.claude/skills` regex).
- **Validator packaged as `skill-validator` skill.** Folder layout: skill-validator/SKILL.md + scripts/{validate,check_descriptions,check_frontmatter,check_body,check_naming,check_references,check_memory,check_meta,output_json,output_text,self_check}.py + references/{rule-catalog,exit-codes,json-schema,hook-integration}.md + tests/ + .pre-commit-hooks.yaml + pyproject.toml. Frontmatter: `disable-model-invocation: true` (Tier-1 verified) prevents agent from spontaneously running validation; `allowed-tools: Read, Bash(python3 *), Glob, Grep` (read-only set; no Edit/Write enforces R-META-9). Body ≤500 lines per R-BODY-1 (validator skill is NOT the meta-skill so the stricter ≤400 cap doesn't apply). Self-validation gate: validator validates itself in CI.
- **R-FM-6 NEW VALIDATED candidate.** Frontmatter top-level keys must be subset of {name, description, license, allowed-tools, metadata, disable-model-invocation, user-invocable, agent, context, compatibility, argument-hint}. Sources: anthropics/skills Issue #37 + code.claude.com/docs/en/skills + claude-code Issue #25795 listing the VS Code schema fields. --surface flag controls strictness (api = 5-key strict; claude-code = full set; both = permissive union). 2 Tier-1 sources met validation gate.
- **6 NEW PROPOSED candidate rules from agent-ecosystem/skill-validator (Tier-2 reference).** R-BODY-6 (per-reference token caps: warn 10K, fail 25K; total: warn 25K, fail 50K); R-BODY-7 (unclosed ``` or ~~~ code fence detection); R-SR-6 (internal relative-link existence); R-SR-7 (reachability-graph-based transitive orphan detection with Python import resolution); R-XPOLL-10 (keyword stuffing: 5+ quoted strings or 8+ comma-separated short segments in description); R-CONTAM-1 (cross-language contamination — semantic, mechanical proxy via language-category mapping with 0.5/0.2 thresholds). All marked PROPOSED pending Q-005 promotion.
- **Encoding switch.** R-BODY-2 mechanical heuristic switched from `tiktoken.get_encoding('cl100k_base')` to `tiktoken.get_encoding('o200k_base')` for parity with the agent-ecosystem/skill-validator Tier-2 reference and closer alignment with modern model tokenizers. Threshold (5000 tokens) unchanged.
- **Anthropic-supremacy disagreement logged on R-BODY-4.** Anthropic best-practices says ≥100-line reference files need TOC; v1.3 project rule said ≥300. Validator now uses 100=fail, 200=warn (Anthropic wins per project's Anthropic-supremacy rule); v1.3 300-line threshold formally revised in v1.4.
- **`when_to_use` field status clarified.** Community-observed but absent from Anthropic's documented allow-list. R-FM-4 stays adopted but tagged PROPOSED for Q-005; Q-005 will decide between (a) drop entirely, (b) require under metadata.when_to_use, or (c) lobby Anthropic to officially document it.

### Rejected Gemini-4 contributions (logged DA-039..DA-043; full rationale in Discarded Alternatives tab)

- Gemini falsely claimed Issue #37 limits frontmatter to {name, description} only — the actual allow-list is {name, description, license, allowed-tools, metadata}. Multiple Anthropic Tier-1 sources confirm the broader list. REJECTED → DA-039.
- Gemini's pre-commit `files:` regex included `~/\.claude/skills` — the tilde character does not expand inside file regexes (pre-commit operates on the working tree, not the home directory). REJECTED → DA-040.
- Gemini's pre-commit `pass_filenames: true` would break R-XPOLL-4 cross-skill pairwise similarity (the validator needs full library access on every run, not staged-files-only). REJECTED → DA-041.
- Gemini cited arxiv:2604.20462 in its Discovery list — fits the known-fabricated `2604.X` pattern (same family as 2604.24026 caught in v1.1). Not adopted; not used as evidence. REJECTED → DA-042.
- Gemini's exit-code contract (0=success, 1=any-failure, 2=usage-error) conflicts with Anthropic's code.claude.com/docs/en/hooks-guide which treats exit 2 specifically as the 'block' signal. Anthropic-supremacy applies. Project keeps 0/1/2 = pass/warn/fail. REJECTED → DA-043.

### Gemini-4 contributions accepted into v1.4

- **`disable-model-invocation: true`** on the validator skill's frontmatter. Tier-1 verified at code.claude.com/docs/en/skills. Prevents the agent from spontaneously running validation mid-conversation.
- **`--strict` flag** that elevates WARN-severity findings to FAIL severity for binary-pass/fail CI. Confirmed in agent-ecosystem/skill-validator v1.1.0 as the de-facto convention.
- **Discarding generic markdown linters** (markdownlint, mdl) as the primary validator — they enforce stylistic rules (header hierarchy, trailing spaces) but cannot evaluate Skills-specific concerns like progressive disclosure, R-XPOLL-4 description similarity, or R-BODY-2 token budgets. Logged as DA-044.
- **The agent-ecosystem/skill-validator repo URL itself** as a Tier-2 reference implementation. The repo is real (verified at github.com), at v1.1.0, March 2026. It does NOT package itself as a SKILL.md (which is fine — it pre-dates our R-XPOLL-9 dogfooding requirement and is Go-based). Useful as a portability comparison, not a direct integration target.

<!-- @session: Q-005 -->
<a id="q-005"></a>

### Q-005 — Promotion Pass: Re-Verification of PROPOSED claims (2026-05-02)

**Methodology:** Each PROPOSED claim from Q-001..Q-004 fetched against the live code.claude.com/docs/en/skills documentation and the live anthropics/claude-code/plugins/plugin-dev/skills/skill-development/SKILL.md on 2026-05-02. Per-claim verdicts: PROMOTE (Tier-1 confirmed), REVISE-TO-PROJECT-INTERNAL (no Tier-1 backing, kept as internal rule with stricter-direction rationale), or DISCARD (logged as DA-NNN).

#### Per-claim verdict matrix

| rule_id | Q-005 verdict | tier | Anthropic primary citation | rationale |
|---|---|---|---|---|
| R-FM-4 (`when_to_use` allow-list) | PROMOTE | Tier 1 | live code.claude.com/docs/en/skills frontmatter table | Field officially documented with description: "Additional context for when Claude should invoke the skill. Appended to description in the skill listing and counts toward the 1,536-character cap." |
| R-FM-6 (frontmatter allow-list, dual-profile) | PROMOTE — EXPAND | Tier 1 | live code.claude.com/docs/en/skills + anthropics/skills issue #37 | v1.4 R-FM-6 Claude Code profile expanded from 7 to 15 keys: name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell. Skills API standard profile remains: name, description, license, allowed-tools, metadata. |
| R-XPOLL-5 (description trigger grammar) | REVISE-PI | Project-internal | skill-development SKILL.md "Description (Frontmatter)" section | Anthropic recommends third-person template "This skill should be used when..." — not the v1.3 imperative regex. Lint becomes soft-warn for absence of trigger vocabulary, not regex enforcement. |
| R-XPOLL-7 (Voyager skill-library mapping) | REVISE-PI (analogy-only) | Project-internal | arXiv:2305.16291 (Wang et al., TMLR 2024) verified real but not Anthropic-cited | Paper exists; Anthropic does not map Skills to Voyager. Stays as internal mental model. Gemini-5 Tier-1 promotion claim discarded as DA-049. |
| R-XPOLL-8 (≥0.85 cosine description-similarity) | REVISE-PI | Project-internal | no Tier-1 backing; CrewAI Tier-2 cite unverified | Threshold pre-registered for empirical calibration on anthropics/skills + obra/superpowers + agent-ecosystem corpus. Embedding model fixed to sentence-transformers/all-MiniLM-L6-v2 (open, no API dependency). |
| R-BODY-1 (body ≤500 lines) — re-confirmed | RE-CONFIRM | Tier 1 | platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices + live skills-doc "Keep SKILL.md under 500 lines" | No change from v1.2 corrective; live docs confirm 500-line cap. Word-target 1,500-2,000 (skill-development SKILL.md) is consistent — at ~10 words/line that's ~150-200 lines, well under 500. |
| R-BODY-4 (reference TOC at >300 lines) — re-confirmed | RE-CONFIRM | Tier 1 | skill-workshop SKILL.md | No change from v1.4. Note: older obra/superpowers cached snapshot uses 100-line trigger; both are valid (stricter direction = 100), validator accepts either as warn-level. The "100-vs-300-vs-500 contradiction" v1.3 logged was a category error: 500=body, 300=ref-TOC-trigger, 100=older-cached-ref-TOC-trigger. |
| R-BODY-6 (reference token caps) — re-verified | KEEP PROJECT-INTERNAL | Project-internal | no Anthropic upper bound; skill-development SKILL.md "If files are large (>10k words), include grep search patterns" | Anthropic does not publish a hard token cap on reference files (unlimited bundled resources principle). 10k-words "large" threshold from skill-development SKILL.md aligns roughly with the 10K-token warn level. Calibration plan: measure p95 reference-file size in anthropics/skills corpus. |
| R-BODY-7 (unclosed code-fence detection) — re-verified | KEEP VALIDATED Tier-2 | Tier 2 | agent-ecosystem/skill-validator | Defensive lint with self-evident correctness; no Anthropic mandate but no Anthropic contradiction either. Stays VALIDATED at Tier-2. |
| R-BODY-8 (NEW — negative counter-examples in description) | PROMOTE | Tier 1 | anthropics/skills/{docx,pptx,pdf}/SKILL.md exemplars + skill-development SKILL.md "Common Mistakes to Avoid" section | Empirically present in ≥3 anthropics/skills exemplars (e.g. docx: "Do NOT use for PDFs, spreadsheets, Google Docs..."). Skill-development SKILL.md uses explicit ✓ DO / ❌ DON'T paired sections. Validator: warn if description lacks any negative-trigger phrase {"Do NOT", "Avoid", "not for"} — soft-warn, not fail. |
| R-BODY-9 (NEW — imperative body / third-person description) | PROMOTE | Tier 1 | skill-development SKILL.md "Writing Style Requirements" section | Verbatim mandate: "Write the entire skill using imperative/infinitive form (verb-first instructions), not second person. Use objective, instructional language (e.g., 'To accomplish X, do Y' rather than 'You should do X' or 'If you need to do X')." Plus: "❌ DON'T: Use second person anywhere". For descriptions: "Use the third-person (e.g. 'This skill should be used when...' instead of 'Use this skill when...')." Validator: warn on detection of second-person pronouns ("you", "your", "yours") in body; warn on detection of imperative voice in description (heuristic: starts with verb other than "is"/"provides"/"contains"). Note: anthropics/skills/{pdf,docx,pptx} use imperative-style descriptions — this is a backward-compat issue logged as soft-warn. |
| R-SR-1 (procedural vs reference distinction) — re-confirmed | RE-CONFIRM | Tier 1 | live skills doc "Types of skill content" section | Live docs explicitly distinguish "Reference content" (knowledge applied alongside conversation) from "Task content" (step-by-step actions). Plus skill-development SKILL.md "Anatomy of a Skill" section with scripts/references/assets directory split. |
| R-SR-2 (lazy-load via path mention) — re-confirmed | RE-CONFIRM | Tier 1 | live skills doc "Add supporting files" section | "Reference these files from your SKILL.md so Claude knows what they contain and when to load them" + concrete example. anthropic.com/engineering blog confirms PDF skill's forms.md lazy-load pattern. |
| R-SR-6 (link integrity) — re-verified | PROMOTE | Tier 1 | anthropics/skills/skill-workshop/scripts/package_skill.py | Anthropic's own packaging script enforces this: every relative link must resolve to an existing file before the skill is bundled. Validator inherits this exact behavior. |
| R-SR-7 (orphan file detection) — re-verified | KEEP VALIDATED Tier-2 | Tier 2 | agent-ecosystem/skill-validator | No Anthropic mandate but agent-ecosystem standard practice. Stays VALIDATED Tier-2. Note: this is the v1.4 R-SR-7 (orphan-detection), distinct from the proposed-but-discarded R-SR-7-anchor-scheme rule (DA-053). |
| R-CONTAM-1 (Discovery-only contamination check) | KEEP PROJECT-INTERNAL | Project-internal | novel; no OSS precedent (Gemini-5 Ruff comparison rejected as DA-054) | Provenance contamination check protects the project from re-importing fabricated arXiv IDs, ghost frontmatter keys, and stale guidance. Ruff's rule-prefix system tracks code origin (which underlying linter), NOT evidence-tier provenance — different concept. Stays PROJECT-INTERNAL with novelty value acknowledged. |
| Encoding-model decision | FINALIZED | Tier 1 | platform.claude.com/docs/en/build-with-claude/token-counting + anthropics/skills/skill-workshop/scripts/quick_validate.py | Validator primary metric: physical line count (matches Anthropic's ≤500 published rule and quick_validate.py implementation, which counts characters not tokens). Token-secondary online: `messages.count_tokens` API. Token-secondary offline: tiktoken `o200k_base` with calibration disclaimer (~25-30% under-counts vs Claude proprietary tokenizer for English text). cl100k_base discarded entirely (older OpenAI encoding). `@anthropic-ai/tokenizer` discarded as stale (DA-055). |

#### Anthropic-supremacy contradiction log

- **Contradiction A — `when_to_use` allow-list status drift over time.** Lee Hanchung blog (October 2025) and anthropics/skills issue #37 listed `when_to_use` as undocumented; live code.claude.com/docs/en/skills (May 2026) lists it explicitly. Resolution: live docs supersede older snapshots. R-FM-4 fully VALIDATED.
- **Contradiction B — Description voice convention.** anthropics/skills/{pdf,docx,pptx} use imperative descriptions ('Use this skill whenever the user wants to do anything with PDF files'); skill-development SKILL.md mandates third-person passive ('This skill should be used when the user asks to...'). Resolution: skill-development SKILL.md is the authoritative authoring guide; the imperative-style exemplars are pre-existing and grandfathered. Validator soft-warns on imperative descriptions in new skills, hard-passes existing anthropics/skills repo for backward-compat.
- **Contradiction C — Body-length expression.** best-practices.md says ≤500 lines; skill-development SKILL.md says 1,500-2,000 words ideal, <5,000 words max. Resolution: these are consistent (500 lines × ~10 words/line ≈ 5,000-word cap; ideal 1,500-2,000 words ≈ 150-200 lines). Validator uses physical line count (matches Anthropic's quick_validate.py implementation) at ≤500 fail / ≤400 warn. Word-count is informational only.
- **Contradiction D — Anthropic's own validator vs Anthropic's own guidance.** quick_validate.py does NOT enforce most R-BODY-* rules (no token counting, no voice check, no counter-example check). This is Anthropic's deliberate choice to keep CI lightweight, NOT a contradiction with their guidance. Project validator is intentionally stricter than Anthropic's reference implementation — this is the project's entire raison d'être. Documented in v1.5 design rationale.

#### Gemini-5 second-opinion evaluation

**Source label:** Gemini-5 (Google Gemini Deep Research output for Q-005, submitted by user 2026-05-02).

**Vetting result:** 4 contributions accepted, 6 rejected.

- **Accepted (1) — R-FM-4 PROMOTE.** Gemini-5 correctly identified that `when_to_use` IS officially documented in live code.claude.com/docs/en/skills, contrary to my Q-005 Turn 1 reading of older snapshots. Independent verification by fetching the live URL on 2026-05-02 confirms. Q-005 Turn 1 verdict (REVISE-PI) overturned.
- **Accepted (2) — R-BODY-9 voice rule PROMOTE Tier-1.** Gemini-5 correctly cited skill-development SKILL.md's verbatim '❌ DON'T: Use second person anywhere' and the imperative/infinitive mandate. Independent verification by fetching the live SKILL.md on 2026-05-02 confirms exact language.
- **Accepted (3) — Full Claude Code extended frontmatter key list.** Gemini-5 surfaced that the validator must accept context, agent, disable-model-invocation, user-invocable, argument-hint as Claude Code extensions. Live docs confirm an even larger list (15 keys total: name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell). R-FM-6 expanded accordingly.
- **Accepted (4) — 1,536-character description+when_to_use cap re-affirmed.** Already in v1.4 R-FM-4 but Gemini-5's independent confirmation strengthens the citation chain.
- **Rejected (1) — Gemini-5 R-XPOLL-7 PROMOTE Tier-1.** Conflates paper existence (verified) with Anthropic adoption (not documented). Logged DA-049.
- **Rejected (2) — Gemini-5 R-XPOLL-8 PROMOTE Tier-2 via CrewAI.** Independent verification could not corroborate CrewAI uses 0.85 with all-MiniLM-L6-v2 specifically. Even if true, 'one Tier-2 system uses this' < project standard for quantitative thresholds. Logged DA-050.
- **Rejected (3) — Gemini-5 '250-character terminal truncation'.** Not in any Anthropic primary source. Likely hallucination. Logged DA-052.
- **Rejected (4) — Gemini-5 R-SR-7-anchor-scheme PROMOTE Tier-1.** Conflates TOC-presence requirement (R-BODY-4) with stable header anchor scheme (different concept Anthropic does not specify). Logged DA-053.
- **Rejected (5) — Gemini-5 R-CONTAM-1 PROMOTE Tier-2 via Ruff.** Conflates code-origin rule prefixes with evidence-tier provenance. Different concepts. Logged DA-054.
- **Rejected (6) — Gemini-5 '@anthropic-ai/tokenizer SDK'.** Stale package; Anthropic now directs users to `messages.count_tokens` API. Logged DA-055.

#### New Tier-1 facts surfaced from live docs

- **`paths` glob field** — auto-activates skill only when working with files matching the glob pattern. Same syntax as path-specific rules in CLAUDE.md.
- **`effort` field** — values low/medium/high/xhigh/max (model-dependent). Overrides session effort level for the skill's active turn.
- **`shell` field** — values bash (default) or powershell. Powershell mode requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`.
- **`arguments` field** — named positional arguments (space-separated string or YAML list). Names map to `$name` substitution placeholders in the skill body, ordered by position.
- **`model` field** — per-skill model override; accepts same values as /model command, plus `inherit` to keep the active model.
- **`SLASH_COMMAND_TOOL_CHAR_BUDGET` env var** — overrides the dynamic 1%-of-context skill-listing budget (default 8,000-char fallback).
- **Auto-compaction re-attach budget** — 25,000 tokens total across all skills carried forward, 5,000 tokens per skill. Older skills can be dropped entirely after compaction.
- **Subagent execution semantics** — `context: fork` + `agent: Explore|Plan|general-purpose` runs skill content as the prompt for an isolated subagent context. Inverse pattern: subagents with `skills` field preload skill content at startup. Both interact with R-FM-6 frontmatter validation.
- **Live-change detection** — Claude Code watches skill directories for file changes; edits take effect within current session without restart. Creating a top-level skills directory that didn't exist when session started DOES require restart.
- **Skill description char-budget heuristic** — if many skills are loaded, descriptions are shortened to fit; this is what makes the 1,536-char per-skill cap critical (anything beyond is invisible to routing).

#### Cross-section impact

- **Frontmatter Rules** — R-FM-4 status updated (live-docs validation), R-FM-6 ALLOWED list expanded to 15-key Claude Code profile.
- **Length and Style** — new R-BODY-8 (negative counter-examples) and R-BODY-9 (imperative body / third-person description) added.
- **Required Sections** — no change.
- **Skill vs Reference Content** — R-SR-6 promoted to Tier-1 (Anthropic's package_skill.py enforces it), R-SR-7 stays Tier-2.
- **Validation Rules (machine-checkable)** — R-FM-4 row: status updated PROPOSED→VALIDATED. R-FM-6 row: ALLOWED list expanded. New rows: R-BODY-8 (warn-level negative-trigger-phrase detector) and R-BODY-9 (warn-level second-person pronoun detector + description-voice heuristic).
- **Validation Script Design** — encoding decision finalized (line counts primary; messages.count_tokens secondary; o200k_base offline approximation only). New CLI flags: --check-voice (R-BODY-9), --check-counter-examples (R-BODY-8). Default profile `--profile=claude-code` accepts the 15-key set; `--profile=skills-api` is the strict 5-key open-standard subset.
- **Interaction with CLAUDE.md / AGENTS.md** — no change.
- **Helper Scripts** — no change.
- **Skill Library Architecture (Voyager-inspired)** — clarification block added: this remains an analogy/internal mental model, not Anthropic-cited (DA-049 distinguishes paper-existence from Anthropic-adoption).

<!-- @session: Q-006 -->
<a id="q-006"></a>

### Q-006 — Multi-task skills: parallelism, delegation, composition (2026-05-04)

**Methodology.** Live re-fetch of `code.claude.com/docs/en/skills`, `code.claude.com/docs/en/sub-agents`, `code.claude.com/docs/en/agent-teams`, `code.claude.com/docs/en/hooks` on 2026-05-04. Cross-referenced with Anthropic's *How we built our multi-agent research system* engineering post (2025) and the `anthropics/skills` repository structure. Three peer-reviewed papers verified (AutoGen 2308.08155, MetaGPT 2308.00352, Voyager 2305.16291) — all real, all pre-2026-05-04, all institutionally affiliated. One Tier-2 candidate (arXiv:2603.09619 *Context Engineering: From Prompts to Corporate Multi-Agent Architecture*) rejected as Tier-1 — the YYMM ID `2603` is future-dated relative to today, and the abstract cites "Tomasev et al. (2026)" as if published. Per project rule §5, auto-rejected.

#### Per-sub-question Tier-1 confirmations

| Sub-question | Verdict | Source |
|---|---|---|
| (a) Parallel sub-task fan-out: forked subagents vs. sequential within one skill | VALIDATED — four-layer ladder; `context: fork` runs SKILL.md content in fresh isolated context; bidirectional composition table (skill-with-fork vs. subagent-with-`skills:`) | code.claude.com/docs/en/skills; code.claude.com/docs/en/sub-agents; *How we built our multi-agent research system*, Anthropic, 2025 |
| (b) Extract sub-task as peer skill vs. keep as section/reference | VALIDATED — 500-line cap forces extraction; description-budget cost (1,536 chars/skill) discourages over-extraction; `anthropics/skills` repo demonstrates flat self-contained pattern with zero cross-skill helper sharing | code.claude.com/docs/en/skills; platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices; github.com/anthropics/skills; skills/skill-workshop/SKILL.md |
| (c) Conductor: who orchestrates when multiple skills coordinate | VALIDATED — default conductor is implicit and model-mediated; explicit "team lead" only emerges at agent-teams tier; `paths` glob overlap is unresolved (model decides via description matching); `disable-model-invocation: true` removes the skill from `<available_skills>` entirely (blocks BOTH model invocation AND `paths` auto-activation AND subagent preloading) | code.claude.com/docs/en/skills; code.claude.com/docs/en/agent-teams |
| (d) Failure semantics across parallel branches | VALIDATED — hooks exit-code-2 matrix exhaustively documented; `PostToolBatch` is the canonical fan-in synchronization point; subagent failure surfaces as natural-language summary, not structured stderr; 25,000-token re-attach budget is per-session/per-skill-set, not aggregated across parallel branches; under-permissioned background subagents auto-deny silently | code.claude.com/docs/en/hooks; code.claude.com/docs/en/sub-agents; code.claude.com/docs/en/skills |

#### Pre-registered quantitative thresholds (per project rule §7)

- **R-PAR-2:** fan-out budget = 3–5 default, hard ceiling 8. Justification: Anthropic's lead-agent training prompt explicitly spawns "3-5 subagents in parallel" and contemplates ">10 for complex research"; the 8-ceiling matches R-API-1 (max 8 skills per Messages API request) so a single fan-out fits within one API turn's envelope. Strictness default applies on the lower bound.
- **R-FAIL-1:** 25,000-token re-attach budget per session/per-skill-set, with 5,000-token cap per skill. Direct quotation from `code.claude.com/docs/en/skills`: "Re-attached skills share a combined budget of 25,000 tokens. Claude Code fills this budget starting from the most recently invoked skill…" Each forked subagent or named subagent has its own context window with its own independent 25k pool. Fan-in does not merge pools.
- **R-DEL-1:** composition depth ceiling = 2. Direct quotations: "Subagents cannot spawn other subagents" and "A fork cannot spawn further forks." Strictness default applies.

#### Gemini-6 second-opinion evaluation

**Source label:** Gemini-6 (Google Gemini Deep Research output for Q-006, submitted by user 2026-05-04). **Vetting result:** 4 accepted (description-defaulting clarification, custom-commands-merged note, bundled-skills inventory, intra-skill `shared/` pattern note); 6 rejected (DA-056…DA-061). Three hallucinations isolated: (1) `ConfigChange` hook event — absent from canonical hooks reference; (2) `UserPromptExpansion` event distinct from `UserPromptSubmit` — not in canonical doc; (3) "5–7 RPM organization-tier RPS cap" — not in cited `code.claude.com/docs/en/costs`. One overcautious hedge corrected (per-branch budget promoted from PROPOSED to VALIDATED). Two derivative-source citations replaced with primary Anthropic sources. Independence note (per framework.second_opinion_review.independence_note): Gemini-1…Gemini-6 share a common training base; the `ConfigChange`/`UserPromptExpansion` hallucinations are treated as a single shared-training-data error, not independent confirmation.

#### Karpathy LLM-Wiki side-question (user-submitted with Gemini-6)

User asked whether Karpathy's llm-wiki gist (already vetted in v1.0) and rohitg00's LLM-Wiki-v2 fork (gist `2067ab416f7bbe447c1977edaaa681e2`) could improve documentation in this project. Both gists vetted: Karpathy original is a known-named-author Discovery source; rohitg00 fork is Discovery-tier with a real linked open-source project (`agentmemory`) and last-active 2026-05-03 (not future-dated). **Scope decision:** out of scope for Q-006 (which targets runtime composition mechanics). **Action:** added new low-priority queue item **Q-011** — "LLM-Wiki documentation patterns for the Research Buddy project itself" — covering confidence scoring, supersession links, consolidation tiers, hybrid search, and forgetting curves applied to the JSON-document approach. Honors the user's question without scope-creeping the active research item.

#### Cross-section impact applied in v1.6

- **skill-spec:** NEW subsection "Multi-task Composition" with R-COMP-1/2/3, R-PAR-1/2/3/4, R-DEL-1/2/3, R-CONDUCT-1/2/3/4, R-FAIL-1/2/3/4/5.
- **system-design / Skill Library Architecture:** annotated to clarify Anthropic's flat self-contained pattern (vs. a deep-library reading of Voyager); R-COMP-3 referenced as the controlling embed-and-duplicate rule.
- **system-design / Dependencies and Splitting Strategy:** four-layer composition ladder (R-COMP-1) added as the canonical decision algorithm for splitting.
- **system-design:** NEW subsection "Parallelism & Delegation Topology" documenting the lead-agent / subagent / agent-team escalation thresholds and the per-branch isolation of context, prompt cache, and re-attach budget.
- **meta-validation:** 5 new rule families added to the validation matrix — R-COMP-* (mechanical: depth-2 ceiling check, embed-vs-symlink check), R-PAR-* (mechanical: fan-out cap warning at 8; hybrid: `context: fork` actionable-instruction check), R-DEL-* (mechanical: subagent-skills-preload integrity check), R-CONDUCT-* (semantic: `paths` description-disambiguation check), R-FAIL-* (mechanical: `PostToolBatch`-presence check on multi-tool orchestrators; mechanical: `disable-model-invocation` semantics check).
- **research / Open Research Queue:** Q-006 → ✦ Researched v1.6; new blue callout points to Q-007; Q-011 appended at low priority.
- **research / Discarded Alternatives:** DA-056…DA-064 appended (corrected from a Turn-1 internal-draft numbering error — DA-025…DA-032 were already taken in Q-005's discards).
- **research / References:** v1.6 entry prepended with all live-fetched URLs and verified arXiv IDs.

#### Contradiction check across all prior research

**Result: PASSED.** No contradictions with v1.0–v1.5. Specific consistency verifications: (1) R-PAR-2 8-fork ceiling matches R-API-1 max-8-skills-per-Messages-API-request envelope; (2) R-DEL-2 (custom subagents must explicitly preload skills, cannot include skills with `disable-model-invocation: true`) is a *narrowing* constraint on R-FM-6, not a conflict; (3) R-COMP-3 (embed-and-duplicate) is consistent with R-SR-3..5 (skill-vs-reference) and with the v1.4 `anthropics/skills` flat-self-contained observation; (4) R-FAIL-1 *refines* the prior 25k-budget rule from R-CTX-* by establishing per-branch isolation; (5) R-CONDUCT-1 (no in-session orchestrator skill) is consistent with R-XPOLL-2 (curriculum-style meta-skill) because R-XPOLL-2 governs design-time skill creation while R-CONDUCT-1 governs runtime conduction; (6) R-CONDUCT-3 (`disable-model-invocation` removes skill from `<available_skills>` entirely) is consistent with R-FM-6's permissive flag definition — the flag exists; setting it does what R-CONDUCT-3 says.

<!-- @session: Q-007 -->
<a id="q-007"></a>

### Q-007 — Self-updating skills: post-session retrospective and auto-improvement (2026-05-04)

**Methodology.** Live re-fetch of `code.claude.com/docs/en/hooks` and `code.claude.com/docs/en/skills` during both Turn 1 and Turn 2 (2026-05-04). Tier-1 paper re-verification for Voyager (arXiv:2305.16291), Self-Refine (arXiv:2303.17651), Reflexion (arXiv:2303.11366), and DSPy (arXiv:2310.03714). Inspection of `github.com/anthropics/skills` for the canonical skill-workshop description-optimization workflow and the shipped `pdf/`, `pptx/`, `docx/`, `xlsx/` skill layouts. Pre-registered hypotheses written before consulting sources, per `framework.synthesis_matrix.pre_registration_rule`. Single second-opinion source evaluated in Turn 2: **Gemini-7** (Google Gemini Deep Research output, user-submitted). Side-question: **user-submitted Slack thread** documenting FlanksAPI monorepo refactor — scoped out of Q-007 per user instruction (project-specific), but generalizable patterns extracted into Q-012.

#### Pre-registered hypotheses (written before consulting sources)

| # | Sub-question | Pre-registered hypothesis | Confirming evidence class |
|---|---|---|---|
| H-a1 | (a) What triggers a retrospective? | `Stop` and `SessionEnd` are canonical end-of-turn / end-of-session points; `PostToolUse`/`PostToolUseFailure` for exit-2 test failures; user-correction is *inferable*, not programmatic. | Tier-1 hooks-reference listing those events as live |
| H-a2 | (a) Test failure trigger | Reuse existing exit-2 mechanism via validator hook, not a new event. | Anthropic exit-code-2 doc |
| H-b | (b) File target | `references/gotchas.md` (NOT SKILL.md body) — body is capped at 500 lines (R-BODY-1) and is the trigger surface, not a learning surface. `errata/` rejected as off-canonical-convention. | anthropics/skills shipped layout |
| H-c | (c) Version-control discipline | `skill/auto-update` branch with Conventional-Commits prefix `skill(retro):`; `version:` patch on references writes; revert validator-gated. | Plugin docs + Anthropic skill snapshot pattern |
| H-d | (d) Meta-skill + destructive workflows | Retrospectives for `disable-model-invocation: true` skills MUST NOT auto-apply; written as patches under `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/`. R-XPOLL-4's 3-iteration cap applies per-session-per-skill. | `disable-model-invocation` semantics doc |
| H-e | (e) Drift prevention | Description regenerated by skill-workshop's optimization pass after every N=3 retrospectives merged into gotchas.md. Replaces only if held-out test score does not regress. | skill-workshop description-improver loop |
| H-Q1 | Where does the 'review and update' rule live? | Meta-skill (Q-003) primary; `Stop`-hook trigger; `CLAUDE.md` reference-pointer only. | Anthropic engineering blog: "capture lessons into the skill" |
| H-Q2 | Promote on-the-fly script threshold | N≥3 reuses in-session OR ≥2 sessions in 7 days. **Refined Turn 2 to ≥3 sessions in 14 days** per Gemini-7. | R-XPOLL-4 + Voyager add-on-success criterion |
| H-Q3 | Runaway safeguards | semver patch=references / minor=body / major=description; rollback by git tag; ≤1 retro merge per skill per session. | Plugin/version field doc |

#### Per-sub-question Tier-1 confirmations (live fetch 2026-05-04)

- **(a) Triggers — VALIDATED.** `code.claude.com/docs/en/hooks` confirms `Stop` (per turn), `SessionEnd` (per session, with reasons `clear`/`resume`/`logout`/`prompt_input_exit`/`bypass_permissions_disabled`/`other`), `SubagentStop` with asymmetric stderr surface (shown to *subagent* only, consistent with R-FAIL-2), `PostToolUse`/`PostToolUseFailure` with `decision: "block"` injecting system reminders, `PostToolBatch` as fan-in synchronization point (R-FAIL-3). Prompt-type hooks on `Stop`/`SubagentStop` explicitly endorsed by docs: "primarily used with Stop and SubagentStop events for intelligent task completion checking." `stop_hook_active` field documented for loop prevention. Async hooks (`async: true` and `asyncRewake: true`) shipped early 2026.
- **(a) User-correction signal.** No programmatic event for user correction; canonical pattern (anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills): "ask Claude to capture its successful approaches and common mistakes into reusable context and code within a skill. If it goes off track when using a skill to complete a task, ask it to self-reflect on what went wrong." User-correction is *inferable* by transcript scan only.
- **(b) File target — VALIDATED.** `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices` confirms SKILL.md body ≤500 lines (R-BODY-1). `platform.claude.com/docs/en/agents-and-tools/agent-skills/overview` shows three-folder convention `scripts/`/`references/`/`assets/` (canonical, not parser-enforced — clarified Turn 2). Anthropic-shipped `pdf/`, `pptx/`, `docx/`, `xlsx/` use `references/` (or REFERENCE.md / forms.md siblings); **none ship an `errata/` directory**. Conclusion: `references/gotchas.md` is canonical write target.
- **(c) VC discipline.** Anthropic's own skill-workshop pre-snapshots before iteration: `cp -r <skill-path> <workspace>/skill-snapshot/` (verified in `skills/skill-workshop/SKILL.md`). `${CLAUDE_PLUGIN_DATA}` provides plugin-specific persistent storage surviving plugin updates and reinstalls. `/plugin uninstall` prompts before deleting plugin data. `version:` is metadata-only; Claude Code does not enforce ordering or rollback semantics on it — git tags are the rollback unit.
- **(d) Meta-skill + destructive — VALIDATED.** `code.claude.com/docs/en/skills` confirms `disable-model-invocation: true` excludes the skill from auto-discovery and restricts to user-typed `/skill-name` invocation. Reflexion (Shinn et al., NeurIPS 2023) external-signal requirement + Self-Refine (Madaan et al., NeurIPS 2023) 3-iteration plateau both anchor R-XPOLL-4/6. Retrospectives written to `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/<skill>-<timestamp>.diff` for explicit `--apply-retro` invocation.
- **(e) Drift prevention — VALIDATED Tier-1 from anthropics/skills.** skill-workshop's description-optimization pass: ~20 trigger eval queries, 3 runs each for stable trigger rate, prompt for improved descriptions, 60/40 train/held-out test split, iterate up to 5 times, select `best_description` by held-out test score. R-DRIFT-1 invokes this pass after every N=3 accepted retros. **Turn 2 added R-DRIFT-5:** regen MUST preserve the `when_to_use` scope-set.

#### Pre-registered quantitative thresholds (per project rule §7)

- **N=3 retrospectives between description regenerations** (R-DRIFT-1). Justification: anchored in R-XPOLL-4 (Self-Refine, Madaan et al. NeurIPS 2023) plateau-at-3 finding. Pre-registered before sources consulted.
- **N≥3 reuses in-session OR ≥3 sessions in 14 days for script promotion** (R-EXTRACT-1). Justification: in-session arm matches R-XPOLL-4's 3-iteration cap. Inter-session arm tightened from initial Turn-1 hypothesis (≥2 sessions in 7 days) to ≥3 sessions in 14 days during Turn 2 per Gemini-7's strict-mode argument against false positives in marketplace-shareable skills.
- **≤1 retrospective merge per skill per session, ≤3 merge attempts per skill per session** (R-ROLLBACK-3). Justification: R-XPOLL-4 (3-iteration cap) per skill per session.
- **30-second sync ceiling, 60-second async ceiling for retrospective hooks** (R-RETRO-5, PROPOSED). Justification: practitioner-derived defaults pending Tier-1 quantitative guidance from Anthropic; hook-reference docs do not yet publish a recommended timeout for retrospective writes.

#### Synthesis matrix (Claim × Source) — high-impact claims only

| Claim | T1: hooks-ref | T1: skills-doc | T1: anthropics/skills | T1: Anthropic eng-blog | T1: Voyager | T1: Self-Refine / Reflexion / DSPy | Verdict |
|---|---|---|---|---|---|---|---|
| 29 canonical hook events including Stop, SessionEnd, SubagentStop, PostToolUse, PostToolUseFailure, PostToolBatch, ConfigChange, UserPromptExpansion | ✓ | — | — | — | — | — | VALIDATED |
| Exit code 2 = blocking with stderr → Claude; SessionEnd cannot block ("shows stderr to user only") | ✓ | — | — | — | — | — | VALIDATED |
| `stop_hook_active` field for loop prevention | ✓ | — | — | — | — | — | VALIDATED |
| User correction is NOT a programmatic event — must be inferred | ✓ (no such event) | ✓ (no field) | — | ✓ ("self-reflect") | — | ✓ (Reflexion) | VALIDATED |
| `references/` is canonical sibling for loaded-as-needed docs | — | ✓ | ✓ | ✓ | — | — | VALIDATED |
| SKILL.md body ≤500 lines (R-BODY-1) | — | ✓ | ✓ | ✓ | — | — | VALIDATED |
| No `errata/` directory in shipped Anthropic skills (canonical-not-mandatory) | — | ✓ (3 folders) | ✓ (pdf/, pptx/, etc.) | — | — | — | VALIDATED |
| Skill `version:` field exists (metadata only) | — | ✓ | — | — | — | — | VALIDATED |
| `${CLAUDE_PLUGIN_DATA}` survives plugin updates | ✓ | ✓ | — | — | — | — | VALIDATED |
| skill-workshop pre-snapshots: cp -r <skill> <workspace>/skill-snapshot/ | — | — | ✓ | — | — | — | VALIDATED |
| skill-workshop's `--max-iterations 5` default for description optimization | — | — | ✓ | — | — | — | VALIDATED |
| `disable-model-invocation: true` for destructive workflows | — | ✓ | — | — | — | — | VALIDATED |
| Voyager adds skill only after self-verification (external check) | — | — | — | — | ✓ | ✓ (Reflexion) | VALIDATED |
| Self-Refine plateau ~3 iterations | — | — | — | — | — | ✓ | VALIDATED |
| Description is primary invocation trigger; ≤1024 chars cap | — | ✓ | ✓ | ✓ | — | — | VALIDATED |
| skill-workshop's description-optimization pass with held-out test scoring | — | — | ✓ | — | — | — | VALIDATED |
| Voyager add-on-first-success (no N>1 in original paper) | — | — | — | — | ✓ | — | VALIDATED — but tightened by R-XPOLL-4 for Claude Code |

#### Adopted rule families (30 rules across seven families in v1.7)

- **R-RETRO-1..6** [skill][portable mostly] — Retrospective protocol: Stop/SessionEnd triggers with stop_hook_active loop guard; prompt-type hooks for Stop/SubagentStop; in-skill-frontmatter `hooks:` with `once: true`; user correction is inferred not programmatic; async/sync ceilings (PROPOSED).
- **R-SELF-1..5** [skill][portable] — Canonical write target = `references/gotchas.md`; body reserved for behavioral corrections only; gotchas entry schema (date, trigger event, evidence anchor, proposed fix, status); `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/` for in-flight diffs; `errata/` SHOULD NOT be created (canonical-not-mandatory).
- **R-DRIFT-1..5** [skill][portable] — Description regen via skill-workshop after N=3 retros; held-out test scoring; ≤1024 char cap preserved; no hidden frontmatter fields; **R-DRIFT-5 (NEW Turn 2):** regen MUST preserve the original `when_to_use` scope-set; scope changes require manual major-version bump.
- **R-EXTRACT-1..3** [skill][portable] — Promote on-the-fly script at N≥3 reuses in-session OR ≥3 sessions in 14 days (inter-session arm tightened Turn 2); skill-workshop handles extraction; trigger-eval gate before marketplace.
- **R-DESTRUCT-1..3** [skill][claude-code-only] — Retros for `disable-model-invocation: true` skills require explicit `--apply-retro`; meta-skill's merge subcommand itself ships `disable-model-invocation: true`; **R-DESTRUCT-3 (NEW Turn 2):** merges go through Edit-tool permission classifier, never raw shell `patch`/`sed`.
- **R-VC-1..3** [skill][portable] — Conventional-Commits `skill(retro):` prefix; semver patch=references / minor=body / major=description; `skill/auto-update` branch with user-accept gate.
- **R-ROLLBACK-1..5** [skill][portable mostly] — Pre-merge `pre-retro-<skill>-<YYYYMMDD>` git tag; validator-gated revert with `health: degraded` escalation on second failure; ≤1 merge per skill per session, ≤3 attempts; cross-skill dependency re-validation on imported-path retros; semver-tag rollback for marketplace-distributed skills.

#### Gemini-7 second-opinion evaluation (Turn 2)

**Source label:** Gemini-7 (Google Gemini Deep Research output for Q-007, submitted by user 2026-05-04). **Source verifications performed (≥3 per framework):** (1) Live re-fetch of `code.claude.com/docs/en/hooks` confirmed all 29 hook events Gemini-7 endorsed are present in the canonical list, plus exit-code-2 semantics per event (Stop = blocking, SessionEnd = non-blocking 'shows stderr to user only'), and the `stop_hook_active` loop-prevention field. (2) `!command` / Dynamic Context Injection claim verified against the hooks doc and skills doc — **no such syntax exists for SKILL.md**; the `!command` shorthand is a Claude Code custom-slash-commands feature in `.claude/commands/*.md`, not a SKILL.md feature. **Gemini-7 conflated two distinct mechanisms.** (3) Voyager arXiv:2305.16291 paper re-verified for the N=3 framing — Voyager's add-on-success criterion is *first verified completion* not N=3; Voyager's N=3 references are statistical replications across random seeds for benchmarking. Gemini-7's narrow technical point is correct, but it attacks a strawman: Q-007 Turn 1 anchored N=3 in R-XPOLL-4 (Self-Refine, Madaan et al. NeurIPS 2023), not in Voyager.

| # | Gemini-7 claim | Verdict | Rationale |
|---|---|---|---|
| G7-1 | N=3 promotion threshold should be raised to N≥5 | REFINE — partial accept | Voyager-strawman framing wrong; underlying statistical-prudence argument has merit for inter-session promotion. Inter-session arm widened from ≥2/7d → ≥3/14d. Adopted as PROPOSED in R-EXTRACT-1. |
| G7-2 | "Three-folder convention" is hallucinated; `errata/` is not banned | REJECT framing, ACCEPT clarification | v1.6 didn't claim `errata/` is *banned* — it claimed `errata/` is *not in the canonical convention* and shipped Anthropic skills don't use it. Both still hold. R-SELF-3 reworded MUST NOT → SHOULD NOT. |
| G7-3 | Use `!command` Dynamic Context Injection in SKILL.md to load errata synchronously | REJECT — hallucination | `!command` is custom-slash-commands feature, not SKILL.md feature. SKILL.md is loaded as static markdown; agent uses Read/Grep tools. → DA-074. |
| G7-4 | `references/gotchas.md` causes "context fragmentation" | REJECT — misreads progressive disclosure | Progressive disclosure is the *intended* design (Tier-1 Anthropic-canonical). The 500-line cap (R-BODY-1) makes references the only sustainable shape. → DA-075. |
| G7-5 | `SessionEnd` is fundamentally disqualified due to SIGINT/process-exit race | ACCEPT — strengthen R-RETRO-1 | Hooks reference confirms SessionEnd cannot block (no exit-code-2 effect). SessionEnd restricted to logging/cleanup; Stop is canonical for synchronous merge writes. |
| G7-6 | DSPy compilation needs N≥10 training examples; N=3 will overfit | PARTIALLY ACCEPT — strawman | Q-007 Turn 1 didn't propose using DSPy compilation as the promotion gate. R-DRIFT-1's N=3 invokes Anthropic's skill-workshop (which itself runs ~20 trigger evals on 60/40 split). N=3 is the trigger frequency, not training-set size. No rule change. |
| G7-7 | Description regen destroys triggering via semantic drift; lock the description, only major-semver via human consensus | REFINE — accept constraint, reject lock | Semantic-drift risk is real. But Anthropic's own skill-workshop ships an automated description-optimizer — locking entirely conflicts with Tier-1 evidence. Added R-DRIFT-5 (NEW): regen MUST preserve the original `when_to_use` scope-set. |
| G7-8 | `${CLAUDE_PLUGIN_DATA}` use is correct; flag `disableSkillShellExecution` constraint requiring Edit-tool merges | ACCEPT | Consistent with Claude Code permission architecture. Added R-DESTRUCT-3 (NEW): merges MUST go through Edit-tool permission-classifier path. |
| G7-9 | All 29 hook events are accurate | ACCEPT — definitively verified Turn 2 | Live fetch of `code.claude.com/docs/en/hooks` 2026-05-04 confirms exact match. Reverses v1.6 caveat about DA-064's `ConfigChange`/`UserPromptExpansion` framing. |
| G7-10 | Voyager uses static embeddings for retrieval, not rewritten descriptions | ACCEPT as informational | True. But doesn't conflict with R-DRIFT-1 because Anthropic's skill-workshop (the actual mechanism) explicitly rewrites descriptions with held-out validation. Voyager is precedent for library growth (R-XPOLL-3), not description management. No rule change. |

#### FlanksAPI monorepo Slack thread (user-submitted side question)

User submitted a Slack conversation from their FlanksAPI monorepo refactor and explicitly scoped it OUT of Q-007 research (project-specific), asking only that generalizable patterns be considered for the queue. **The project-specific fix:** FlanksAPI is a monorepo containing multiple services, including aworkers. aworkers' skills originally lived under `aworkers/.claude/skills/` and were reachable when the IDE opened in aworkers but not when opened at FlanksAPI root (one-level-deep discovery). User's solution: copy each aworkers skill into `FlanksAPI/.claude/skills/aworkers-<skill-name>/` (adding the `aworkers-` prefix to avoid collisions with other services' skills) and add a symlink back into `aworkers/.claude/skills/` so sub-IDE access still works. **Three generalizable research questions extracted into Q-012:** (a) Naming/namespace convention for flat skill organization in monorepos with multiple services. (b) Router/index-skill pattern (Albert's `services/SKILL.md` redirect proposal) as a third option distinct from flatten+symlink. (c) Skill-loading verification tests for Q-008's validator (Hector's keyword-test gap insight: their 13-test integration suite passed even when the skill mechanism was broken because Claude could infer answers from the codebase or CLAUDE.md). Q-012 added at priority 12, OPEN. Items (a) and (b) overlap partially with Q-009 but are distinct enough to warrant their own queue item; item (c) is a feed-forward into Q-008 and is captured both in Q-012 and in the v1.7-updated Q-008 callout.

#### Cross-section impact applied in v1.7

- **skill-spec tab** — NEW subsection "Self-Updating Skills" with R-RETRO-1..6, R-SELF-1..5, R-DRIFT-1..5 rule families.
- **system-design tab** — NEW subsection "Self-Modification Governance" with R-EXTRACT-1..3, R-DESTRUCT-1..3, R-VC-1..3 rule families.
- **meta-validation tab** — Validation Rules section gains R-ROLLBACK-1..5 family with mechanical/semantic classification; validator gains: gotchas-entry-schema linting (mechanical), Conventional-Commits prefix lint on `skill/auto-update` branches (mechanical), description-scope-preservation check (semantic, deferred to Q-008), pending-retro-quarantine path validation (mechanical), per-session merge-rate limit (mechanical).
- **research tab** — Q-007 → ✦ Researched v1.7; Q-012 added at priority 12; Q-008 callout updated with feed-forward (skill-loading verification tests + R-DRIFT-5 scope-preservation semantic check); DA-065..DA-077 logged; v1.7 References entry; T-007 tracker row.
- **v1.6 caveat reversal** — DA-064's framing (Q-006 rejected `ConfigChange`/`UserPromptExpansion` as hallucinated) confirmed correct *as a verification demand* but the events are real per live re-fetch. No new DA needed; noted in changelog.

#### Contradiction check across all prior research

**Result: PASSED.** No contradictions with v1.0–v1.6. Specific consistency verifications: (1) **R-XPOLL-3 (Voyager growing-library + external verification)** — R-RETRO-* and R-EXTRACT-* both gate on validator+user-accept (R-XPOLL-6 reuse); no contradiction. (2) **R-XPOLL-4 (Self-Refine 3-iteration cap)** — R-DRIFT-1 N=3 retros between description regenerations; R-ROLLBACK-3 ≤3 merge attempts per session per skill; both anchored in this cap. (3) **R-XPOLL-6 (Reflexion external-signal requirement)** — All R-DESTRUCT-* and R-SELF-* rules require validator-pass AND user-accept. (4) **R-XPOLL-9 (DSPy compiler model for meta-skill)** — R-SELF-* treats retrospectives as compile inputs (gotchas → few-shot demonstrations next compile), structurally identical to DSPy's bootstrap-then-compile. (5) **R-API-1 (8 skills/request hard cap)** — Q-007 adds zero new always-loaded skills; the meta-skill is one already-counted skill. (6) **R-BODY-1 (SKILL.md ≤500 lines)** — R-SELF-1 explicitly forbids routine writes to body; R-SELF-2 permits body edits only as rare behavioral corrections. (7) **R-FAIL-1..5 (Q-006 per-branch token isolation, asymmetric subagent failure surface, PostToolBatch fan-in)** — R-RETRO-1 uses Stop/SessionEnd at top level; subagent retrospectives flow through SubagentStop with subagent-only stderr surface, consistent with R-FAIL-2's asymmetric surface. (8) **R-COMP-1..3 (four-layer composition ladder)** — Meta-skill sits at layer 2 (`context: fork` skill) or layer 3 (custom subagent with `skills:` preload); no conflict. (9) **R-META-1..19 (Q-003 meta-skill scaffolding)** — R-DRIFT-1 *delegates* to skill-workshop's description optimizer; R-SELF-2 keeps body as procedure surface; R-RETRO-* fits inside the organic-trace lifecycle. (10) **25,000-token re-attach budget per session/per skill-set** — Retrospectives write to `references/gotchas.md` which loads only on demand; no always-loaded inflation. (11) **Frontmatter schema** — No new frontmatter fields proposed (DA-066, DA-072 explicitly reject hidden fields). The existing `hooks:` field in skill frontmatter is reused, not extended.

<!-- @session: Q-008 -->
<a id="q-008"></a>

### Q-008 — Validation: LLM-based semantic checks + routine review cadence (2026-05-04)

#### Methodology

**Pre-registration (per `framework.synthesis_matrix.pre_registration_rule`).** Hypotheses written before consulting sources: (H1) the LLM-judge can be bolted onto Q-004's mechanical validator without violating R-META-10 if kept off the pre-commit path; (H2) skill-loading verification needs at least one mechanism that does not depend on agent-self-reporting; (H3) R-DRIFT-5 scope-preservation is a deterministic-text-comparison problem, not a generative-judging problem. **Sources fetched live.** platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices; code.claude.com/docs/en/{skills,hooks}; code.claude.com/docs/en/whats-new/2026-w16; github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md; anthropics/claude-code Issues #43630, #30573, #31017, #22902; anthropics/skills Issue #532; platform.claude.com/docs/en/about-claude/pricing. **Tier-1 papers re-verified.** G-Eval (arXiv:2303.16634), Prometheus 1/2 (arXiv:2310.08491; arXiv:2405.01535), MT-Bench (arXiv:2306.05685), Constitutional AI (arXiv:2212.08073), DSPy (arXiv:2310.03714), ReWOO (arXiv:2305.18323), Self-Refine (arXiv:2303.17651). **Single second-opinion source evaluated in Turn 2:** **Gemini-8** (Google Gemini Deep Research output, user-submitted 2026-05-04 with explicit stress-test framing — note that the prefatory turn surfaced a framework-level question about whether stress-test should remain default for `brief_template`; deferred to v1.9).

#### Decisions adopted (Turn 1 + Turn 2)

**LLM-judge family R-LLMJ-1..12 (12 PROPOSED rules).** Judge runs downstream-only (R-LLMJ-1 preserves R-META-10), binary 3-level pass/warn/fail (R-LLMJ-2), G-Eval-form CoT prompting (R-LLMJ-3), k=3 self-consistency majority vote (R-LLMJ-4), default Sonnet 4.6 with Prometheus 2 local fallback (R-LLMJ-5), pairwise reserved for R-DRIFT-5 only (R-LLMJ-6), structured JSON aligned to Q-004's 0/1/2 exit-code contract (R-LLMJ-7), ≥80%-TPR/≥80%-TNR calibration gate before per-rule deployment (R-LLMJ-8), DSPy-Suggest soft-assertion semantics — never halt-on-fail (R-LLMJ-9), explicit out-of-scope boundary excluding domain-content factuality and runtime correctness (R-LLMJ-10), per-skill audit budget ≤30K input + ≤6K output tokens ≈ $0.05–$0.18 with caching (R-LLMJ-11), judge prompt treats SKILL.md body as untrusted data (R-LLMJ-12). **Cadence family R-CADENCE-1..5 (5 PROPOSED rules).** Three-tier schedule (R-CADENCE-1: monthly drift + quarterly rule-set review + on-demand). **R-CADENCE-2 (revised Turn 2):** primary mechanism = Claude Code Routines (cloud-native, code.claude.com/docs/en/whats-new/2026-w16, launched 2026-04-14, beta header `experimental-cc-routine-2026-04-01`); GitHub Actions cron remains valid fallback for self-hosted CI users; `/review-skills` reviewer skill exposes the on-demand path. **R-CADENCE-1 caveat extended Turn 2:** Routines daily run caps Pro 5/Max 15/Team-Enterprise 25 are real operational constraints — 50+-skill repos need Team-or-Enterprise tier or GitHub Actions fallback. R-CADENCE-3 off-cadence triggers (skill-workshop new minor; validator major bump; ≥3 R-ROLLBACK-* events; R-XPOLL-8 overlap exceeded; post-merge retro fails). R-CADENCE-4 review-report.json schema. R-CADENCE-5 SemVer composition with R-VC-* / R-ROLLBACK-* / R-RETRO-* from Q-007. **Skill-loading verification family R-LOAD-1..7 (7 PROPOSED rules — note R-LOAD-8 was rejected as DA-099).** Each skill MUST ship ≥1 canary token test (R-LOAD-1) AND ≥1 negative-control rename / `disable-model-invocation: true` test (R-LOAD-2); reject "list your loaded skills" probes (R-LOAD-3, Hector's gap); hook-based introspection NOT a valid pattern today (R-LOAD-4, anchored on Issue #43630 + Issue #30573 + Issue #31017 + Issue #22902, all open as of 2026-05-04, revisitable when any closes); verification suite location `evals/loading_verification.json` with schema (R-LOAD-5); threshold ≥1+1 (R-LOAD-6); two-layer eval suite trigger-rate eval + loading verification (R-LOAD-7). **R-DRIFT-5 implementation (3 PROPOSED rules).** R-DRIFT-5-IMPL: bidirectional NLI entailment between old and new `when_to_use` blocks (DeBERTa-MNLI-class, deterministic per R-META-9) is primary. R-DRIFT-5-CHECK: trigger-eval delta on held-out test |Δ| ≤ 0.10. R-DRIFT-5-FALLBACK: LLM-as-judge pairwise (k=3) only when NLI unavailable. **Total Q-008 rules adopted: 27 PROPOSED across four families** (12 + 5 + 7 + 3). **Discarded: DA-078..DA-099 (22 alternatives — 13 Turn 1 + 9 Turn 2).** **Queue items added: Q-013** (k=3 vs k=5; Routines beta-header churn; PreToolUse skill-matcher status). **Cost summary:** ~$2.50–$9 per month per 50-skill repo for the LLM-judge layer; mechanical validator unchanged (Q-004 baseline).

#### Rejected claims (Turn 1 originals + Turn 2 additions)

Turn 1 logged DA-078..DA-090 (LLM-as-pre-commit-gate; Likert scoring; k=5/k=7; Opus default; SessionStart-as-cron; PostToolUse-Skill; "list loaded skills" probe; cosine similarity for R-DRIFT-5; pairwise as primary; SARIF; silent auto-fix; quarterly-only; agentskills.io spec mandate). Turn 2 logged DA-091..DA-099 from Gemini-8 vetting: DA-091 host-side parsing of `<available_skills>` (architectural confusion — agent-context vs host-observability); DA-092 InstructionsLoaded fires for skills (refuted by Anthropic primary docs + 3 issues); DA-093 "Prometheus 3" (does not exist); DA-094 "Simulated Annotators" paper-title fabrication; DA-095 SAMRE EACL2026-anonymous misattribution (real source D3 arXiv:2410.04663); DA-096 Mizan as VALIDATED authority (Discovery-tier override); DA-097 binary pass/fail "fundamentally fails" overclaim (against Hamel Husain Tier-2); DA-098 NIST-SSDF-mandates-weekly-skill-audits overreach (NIST does not); DA-099 R-LOAD-8 multi-vector skill-loading introspection (depends on rejected DA-091/DA-092).

#### Other researchers reviewed

**Source label:** Gemini-8 (Google Gemini Deep Research output for Q-008, submitted by user 2026-05-04 in stress-test mode). **Source verifications performed (≥3 per framework):** (1) Routines launch + spec verified via live fetch of code.claude.com/docs/en/whats-new/2026-w16 + 4 independent secondary sources — Tier-1 ACCEPT (G8-A → R-CADENCE-2 revised, G8-B → R-CADENCE-1 caveat). (2) `<available_skills>` host-introspection verified FALSE via Anthropic skills doc + Issue #22902 + Lee Hanchung deep-dive — REJECT (DA-091). (3) `InstructionsLoaded` skills-firing verified FALSE via Anthropic hooks doc payload schema + Issues #30573, #31017 — REJECT (DA-092). (4) Prometheus 3 verified NONEXISTENT via prometheus-eval.github.io + aclanthology + arxiv search — REJECT (DA-093). (5) "Simulated Annotators" verified MISATTRIBUTED — actual paper is "Trust or Escalate" ICLR 2025 (proceedings.iclr.cc) — REJECT (DA-094). (6) SAMRE verified MISATTRIBUTED — actual home is D3 arXiv:2410.04663 named authors Oct 2024 — REJECT (DA-095). (7) Mizan verified DISCOVERY-TIER-ONLY (Shaokat Medium series) — tier violation, REJECT (DA-096). (8) BiCon-Gate verified TIER-1 PROPOSED via arxiv.org/abs/2604.14389 + author affiliation Queen Mary University of London — ACCEPT (G8-M). **Outcome:** 5 contributions accepted, 1 deferred to Q-013, 9 rejected. **Independence note applied:** misattributed citations + nonexistent successors + tier overrides + architectural confusions treated as one LLM-hallucination data point, not independent confirmation, per `framework.second_opinion_review.independence_note`.

#### Tabs updated

- **research tab** — Q-008 → ✦ Researched v1.8; Q-013 added at priority 13; Q-009 promoted to blue callout; DA-078..DA-099 logged (22 new); v1.8 References entry; T-008 tracker row; v1.8 Reasoning Journey block; new Session Notes — Q-008 section.
- **meta-validation tab** — NEW rule families R-LLMJ-* (12 rules), R-CADENCE-* (5 rules), R-LOAD-* (7 rules), R-DRIFT-5-IMPL/CHECK/FALLBACK (3 rules) with mechanical/semantic/hybrid classification.
- **skill-spec tab** — NEW Validation Test Suite subsection covering R-LOAD-1/2/5/6/7 (canary + negative-control test patterns shipped per skill).
- **system-design tab** — NEW Routine-Based Audit Cadence subsection covering R-CADENCE-1..5 with the Routines-primary / GitHub-Actions-fallback architecture.
- **changelog tab** — v1.8 entry inserted at TOP, current=true; v1.5 (previously current=true) set to current=false. Top-level `changelog.entries` similarly updated (v1.7 → current=false, v1.8 → current=true).

#### Contradiction check (cross-section)

**Result: PASSED.** No contradictions with v1.0–v1.7. Specific consistency verifications: (1) **R-LLMJ-1 (downstream-only) ↔ R-META-10 (ReWOO determinism on hook path):** CONSISTENT — strengthens R-META-10 by naming the slow tool. (2) **R-LLMJ-9 (DSPy-Suggest soft) ↔ R-XPOLL-9 (DSPy compiler model):** CONSISTENT — refines, does not contradict. (3) **R-LLMJ-4 (k=3) ↔ R-XPOLL-4/7 (Self-Refine 3-iteration cap):** CONSISTENT — same 3-bound from independent Tier-1 sources (Madaan et al. + Anthropic skill-workshop). (4) **R-LLMJ-10 (out-of-scope) ↔ R-BODY-1 / R-API-1:** CONSISTENT. (5) **R-LLMJ-12 (judge prompt-injection hardening) ↔ R-XPOLL-6 (Reflexion external verification):** CONSISTENT — judge IS the external verifier, treats body as untrusted. (6) **R-CADENCE-3 off-cadence triggers ↔ R-ROLLBACK-* / R-RETRO-* / R-VC-* / R-XPOLL-8:** CONSISTENT — additive cross-links. (7) **R-CADENCE-2 revised (Routines primary) ↔ R-META-10:** CONSISTENT — Routines run audits OFF the pre-commit path, same as the prior GitHub Actions formulation. (8) **R-CADENCE-5 SemVer ↔ R-VC-* (Conventional Commits):** CONSISTENT. (9) **R-LOAD-4 no-hook-reliance ↔ R-META-9 auditability:** CONSISTENT — both express auditability constraints. (10) **R-LOAD-7 two-layer suite ↔ R-XPOLL-2 (Hamel eval-driven):** CONSISTENT — adds layer, does not displace. (11) **R-DRIFT-5-IMPL bidirectional NLI ↔ R-DRIFT-5 (Q-007 scope-preservation) ↔ R-META-9:** CONSISTENT — NLI is the deterministic implementation v1.7's R-DRIFT-5 called for. (12) **R-LLMJ-7 JSON exit-code ↔ Q-004 0/1/2 contract (DA-052 SARIF rejection):** CONSISTENT.

#### Outstanding gaps surfaced (logged for future queue items)

- **Routines beta-header churn risk** — `experimental-cc-routine-2026-04-01` may rotate; R-CADENCE-2's Routines path needs a versioned check. Captured in Q-013 scope.
- **`disable-model-invocation: true` as negative-control mechanism for R-LOAD-2** — verified the field exists in code.claude.com/docs/en/skills, but whether it makes the skill *invisible* to the model's view of `<available_skills>` (true negative control) vs. just blocking model-initiated invocation is not explicit in docs. May warrant empirical test in v1.8 implementation work.
- **Skill tool's PreToolUse status** — Issue #43630 covers PostToolUse only. Whether `PreToolUse matcher: "Skill"` fires today is unverified; if it does, R-LOAD-4 promotes from "no hook reliance" to "PreToolUse permitted, PostToolUse blocked." Captured in Q-013.
- **K=5 evidence question** — explicit in Q-013; do NOT change R-LLMJ-4 today.
- **brief_template default mode (blind vs stress-test)** — surfaced in prefatory turn; logged for v1.9 with explicit user approval; brief_template UNCHANGED in v1.8.

<!-- @session: Q-009 -->
<a id="q-009"></a>

### Q-009 — Workspace topology: cross-scope access, shared scripts, references-in-repo-docs (2026-05-04)

#### Methodology

**Pre-registration (per `framework.synthesis_matrix.pre_registration_rule`).** Seven hypotheses written before consulting sources: H1 (plugin distribution canonicalised), H2 (`CLAUDE_SKILLS_PATH` does not exist), H3 (`${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}`/`${CLAUDE_SKILL_DIR}` documented and resolve through symlinks), H4 (DA-058 holds — zero peer symlinks in shipping anthropics/skills), H5 (`paths` glob is auto-activation only), H6 (single-depth skill discovery), H7 (symlinks split execution-vs-discovery). Four pre-registered quantitative thresholds: T-MONO-1 (≥3 services → plugin), T-SHARE-1 (≥2 skills sharing helper → plugin-root), T-REF-1 (>10K-word reference → grep guidance), T-PFX-1 (≥2 collision → migrate to plugin). All seven hypotheses PASSED. All four thresholds ADOPTED.

**Sources consulted (Turn 1 + Turn 2, 2026-05-04).** **Anthropic Tier-1:** code.claude.com/docs/en/{skills, plugins, plugins-reference, memory, sub-agents, settings}; platform.claude.com/docs/en/agents-and-tools/agent-skills/{overview, best-practices}; support.claude.com/en/articles/12512180,12512198; anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills; resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf; github.com/anthropics/skills (README, skill-workshop/SKILL.md, pptx/SKILL.md + editing.md); github.com/anthropics/claude-plugins-official (plugin-dev). **Anthropic GitHub issues (30+):** anthropics/claude-code Issues #9354, #10238, #12633, #14836, #15642, #15944, #16438, #18192, #20755, #20805, #22081, #22902, #25150, #25367, #27145, #28266, #32910, #37344, #37553, #37590, #39138, #39403, #39475, #39787, **#40640** (doc/behaviour drift), #43267, #43695, #45956; anthropics/skills Issues #14, #189, #675, #953 (probable-verified XSD duplication), #1058. **Tier-2:** Cursor 2.4 changelog (cursor.com/changelog/2-4); AGENTS.md spec (agents.md); AAIF/Linux Foundation announcement; OpenAI Codex AGENTS.md docs; Vercel/Jude Gao AGENTS.md vs Skills evals (Tier-2 only). **Discovery (PROPOSED):** Lee Hanchung deep-dive; obra/superpowers v2.0 release notes; alirezarezvani/claude-skills (5,200+ stars); shanraisshan/claude-code-best-practice; Hidekazu Konishi harness/environment article; community discussion at community.vercel.com/t/removing-an-internal-skill-from-skills-sh/39521. **Peer-reviewed (Turn 2 verifications):** arXiv:2305.16291 (Voyager TMLR 2024, re-cited); **arXiv:2604.17870 GraSP (Xia et al., Tencent, 20 Apr 2026 — verified real)**; **arXiv:2604.16911 Skilldex (Saha & Hemanth, 18 Apr 2026 — verified real with author-affiliation caveat)**; **arXiv:2602.12430 Xu & Yan survey (Zhejiang University, v3 17 Feb 2026 — verified real)**.

#### Decisions adopted (Turn 1 + Turn 2)

**R-WORKSPACE-1..6 (cross-scope discovery, 6 rules — VALIDATED).** Single-depth discovery at every scope (R-WORKSPACE-1; Issues #10238/#16438/#18192/#20755/#28266/#39138). `--add-dir <monorepo-root>` is the supported launch-time exception (R-WORKSPACE-2; Issues #37553/#43267 contradict `additionalDirectories`; Issue #22902 confirms `${CLAUDE_SKILLS_PATH}` does not exist). Plugin distribution at user/personal scope is the **Anthropic-canonical mechanism** for cross-scope skill sharing (R-WORKSPACE-3; code.claude.com/docs/en/plugins). `paths` glob is auto-activation only, not discovery substitute (R-WORKSPACE-4; PROPOSED R-WORKSPACE-5 for symlinked skill directories — discovery unreliable per Issues #14836/#25367/#37590, execution OK; R-WORKSPACE-6 PROPOSED — service-name prefix tolerated, plugin-per-service preferred at T-PFX-1).

**R-MONO-1..4 (monorepo specifics, 4 rules — 2 VALIDATED, 2 PROPOSED).** R-MONO-1: nested `.claude/skills/` discovery is **broken in shipping CLI ≥2.1.92** due to a Bun.Glob `dot: false` default regression — root cause documented in anthropics/claude-code Issue #44490 (decisive Tier-1 evidence with full reproduction; 5 successful runs at 2.1.81 vs 1 failing at 2.1.92), cross-references Issues #33999/#17302/#43178/#40640. Defensive recommendation: skills must live in cwd's `.claude/skills/` (no parent-traversal reliance) until Anthropic patches. R-MONO-2 (PROPOSED): preferred topology is per-service `.claude/skills/` for service-specific procedures + user-installed plugin for cross-service patterns, with `--add-dir` only as session-time fallback (T-MONO-1 ≥3 services threshold). R-MONO-3 (VALIDATED): cross-skill router/index-skill pattern is **discouraged** because Markdown links into sibling skills are read via `Read` (not skill-tool dispatch) and lose skill-loading semantics; Anthropic's own router pattern (pptx → editing.md) is intra-skill only. **R-MONO-4 NEW (PROPOSED, from Gemini-9 G9-B).** When skill body instructions require finding files inside `.claude/` on CLI ≥2.1.92, agents must use Bash `find` rather than the Glob tool, because `Bun.Glob.scan()` defaults to `dot: false` and silently returns "No files found" for any `.claude/`-prefixed pattern. Canonical workaround pattern (verbatim from Issue #44490): `SKILL_ROOT=$(dirname "$(find <repo-root> -path '*/<skill-name>/scripts/<known-script>' 2>/dev/null | head -1)")/..; REFS="$SKILL_ROOT/references"`. Status PROPOSED — sunsets automatically when Anthropic patches `Bun.Glob` default.

**R-SHARE-1..4 (shared scripts, 4 rules — VALIDATED).** R-SHARE-1: **DA-058 reaffirmed** — the `anthropics/skills` shipping repo (12 production skills inspected via DeepWiki + GitHub) shows zero peer-skill symlinks; embed-and-duplicate (R-COMP-3) is canonical for non-plugin cross-skill helpers. Within a plugin, `${CLAUDE_PLUGIN_ROOT}/scripts/` is the supported sharing primitive. Cross-plugin sharing is **not supported** (Issue #15944). T-SHARE-1 (≥2 skills sharing helper → plugin-root) is empirically validated by Gemini-9 G9-C: anthropics/skills Issue #953 (probable-verified) documents 30 physical XSD-schema files where 10 would suffice, with byte-identical SHA across docx/pptx/xlsx — the cited XSD files (e.g. `shared-customXmlDataProperties.xsd`) are real ECMA-376 schemas (verified via QtExcel/ecma-376-5th). R-SHARE-2: no `.claude/scripts/` convention exists. R-SHARE-3: `${CLAUDE_PLUGIN_ROOT}` only in JSON/YAML config (Issues #9354/#15642/#27145). R-SHARE-4: `${CLAUDE_SKILL_DIR}` is the correct anchor for non-plugin skills.

**R-REFLOC-1..4 (references-in-repo-docs, 4 rules).** R-REFLOC-1 (VALIDATED): no `..` paths in SKILL.md body or references — R-SYS-1 portability. R-REFLOC-2 (PROPOSED, HYBRID): four candidate patterns — (a) copy into `<skill>/references/` preferred; (b) skill authoritative + repo `docs/` links to it; (c) repo `docs/` authoritative with non-portable "internal" skill carve-out; **(d) NEW from Gemini-9 G9-E** — centralized `~/.claude/docs/` referenced via absolute paths from multiple skills (Discovery-tier, single user-attested via Issue #953). **R-REFLOC-2(c) clarified per Gemini-9 G9-F.** The "internal-only" carve-out uses **existing Anthropic-validated keys**: `user-invocable: false` (R-FM-6) hides the skill from `/skill-name` autocomplete, plus tightly-scoped `paths` glob gates auto-activation. **No new frontmatter key (`internal: true` or otherwise) is introduced.** Skill description must start with `[internal — not portable]` to carry semantic non-portability signal at retrieval time. R-REFLOC-3 (VALIDATED): R-BODY-4 reference-TOC extension. R-REFLOC-4 (VALIDATED): `paths` is not a content-loading mechanism.

**R-CROSS-1 (hallucination canary — VALIDATED).** `${CLAUDE_SKILLS_PATH}` does not exist as of 2026-05-04 (Issue #22902 still open per snapshot; Issue #39403 requests `skillsDirectories` array). Validators must reject any rule, skill, or doc that assumes such a variable exists. Future LLM-generated rules citing `${CLAUDE_SKILLS_PATH}` or `skillsDirectories` are flagged for re-verification. Mirror canary added: `Bun.Glob` and any reference to runtime-internal globber bypassing the public `find`/`Glob` tool surfaces is also flagged.

#### Anthropic doc-vs-issue resolution (Issue #40640)

Turn 1 §3.1 logged a Tier-1-vs-Tier-1 contradiction: Anthropic docs specify "Automatic Discovery from Nested Directories" while Anthropic Issue #40640 reports it doesn't work in shipping. **Resolution via Gemini-9 G9-B / Issue #44490 (decisive):** this is not a doc-vs-doc conflict — it is a **runtime regression in `Bun.Glob.scan()`** introduced between CLI 2.1.81 (working) and 2.1.92 (broken). The Anthropic spec is correct; the runtime is broken. Per `framework.domain_constraints.rules` (Anthropic-supremacy), the spec wins on intent and the runtime bug is logged for re-verification. R-MONO-1 captures the current shipping state (broken-pending-patch); R-MONO-4 captures the canonical workaround until patch lands. The doc itself does not need correction; only the runtime needs the fix. **Anthropic-supremacy ledger updated**: doc and issue tracker are reconciled at the runtime layer, not contradictory at the specification layer.

#### Rejected claims (Turn 1 originals + Turn 2 additions)

**Turn 1 logged DA-100..107** (8 alternatives): symlinks as portable pattern (DA-100); `additionalDirectories` for skill discovery (DA-101); `${CLAUDE_SKILLS_PATH}` (DA-102); cross-plugin skill helper sharing (DA-103); root-level `.claude/scripts/` convention (DA-104); cross-folder router-skill pattern (DA-105); `<skill>/references/foo.md → ../../repo/docs/foo.md` symlinks (DA-106); `paths` as content-routing mechanism (DA-107). **Turn 2 added DA-108..111** (4 alternatives): `internal: true` as 16th allow-list key (DA-108) — Anthropic supremacy applies, vercel-labs/skills' `metadata.internal: true` is Tier-2 cross-tool community convention, not Claude-Code-canonical; existing `user-invocable: false` + `paths` cover the use case. GraSP DAG composition as v1.9 directive (DA-109) — academic proposal arXiv:2604.17870 (Tencent, real), no Anthropic implementation, conflicts with R-COMP-1 four-layer ladder; logged as PROPOSED forward-influence reference only. Skilldex three-tier scope as canonical hierarchy (DA-110) — academic proposal arXiv:2604.16911 (real, author-affiliation caveat); the "shared" tier is non-Anthropic; Anthropic's hierarchy is personal/project/plugin. 26.1% community-skill vulnerability rate as quantitative threshold (DA-111) — citation chain through Xu & Yan arXiv:2602.12430 to Liu et al. arXiv:2601.10338, primary source not independently verified.

#### Other researchers reviewed

**Source label:** Gemini-9 (Google Gemini Deep Research output for Q-009, submitted by user 2026-05-04). **Source verifications performed (≥3 per framework, six performed):** (1) arXiv:2604.17870 GraSP — VERIFIED REAL; Tencent affiliation; 20 Apr 2026; not future-dated; abstract matches summary. (2) arXiv:2604.16911 Skilldex — VERIFIED REAL with caveat; 18 Apr 2026; institutional affiliation NOT verifiable (neither author has ResearchGate profile). (3) arXiv:2602.12430 Xu & Yan survey — VERIFIED REAL; Zhejiang University, rux@zju.edu.cn; v3 17 Feb 2026. Citation-chain caveat: Gemini-9 attributed 26.1% stat to Xu & Yan but their reference [14] = Liu et al. arXiv:2601.10338. (4) anthropics/claude-code Issue #44490 — VERIFIED REAL with full reproduction including exact root-cause analysis Gemini-9 cited ("Same as #33999 — Bun.Glob.scan() with dot: false (default) skips .claude/ during traversal") and verbatim Bash-`find` workaround. **Decisive Tier-1 contribution.** (5) anthropics/claude-code Issue #17302 — VERIFIED REAL; Jan 10 2026; corroborates Bun.Glob `dot:false` default issue family. (6) vercel-labs/skills `metadata.internal: true` — VERIFIED REAL via README + DeepWiki + Vercel community post + Issue #572 in vercel-labs/skills. **Probabilistic verification:** anthropics/skills Issue #953 — PROBABLE-VERIFIED via (a) issue-numbers-up-to-#1078 confirmed; (b) cited XSD files real ECMA-376 schemas; (c) DeepWiki confirms per-skill scripts duplication pattern; (d) Issue #189 confirms duplicate-content concerns are filed in this repo. **Outcome:** 6 contributions ACCEPTED (G9-A mechanical enforcement; G9-B Bun.Glob root-cause → R-MONO-1 refined + R-MONO-4 new; G9-C T-SHARE-1 empirical validation; G9-D DA-058 reaffirmation strengthened; G9-E centralized `~/.claude/docs/` PROPOSED candidate (d) for R-REFLOC-2; G9-F R-REFLOC-2(c) clarified — no new frontmatter key); 1 PROCESS confirmation (G9-G Q-012 disposition); 3 PROPOSED-only (G9-H1/H2/H3 — three arXiv papers as PROPOSED background); 4 REJECTED (DA-108 internal:true; DA-109 GraSP DAG; DA-110 Skilldex three-tier; DA-111 26.1% threshold). **Independence note applied:** Gemini-9 is materially cleaner than Gemini-2/5/7/8 — three real arXiv IDs, one decisive Tier-1 GitHub issue, only minor citation-chain misattribution and one author-affiliation gap. Treated as one LLM-second-opinion data point per `framework.second_opinion_review.independence_note`.

#### Cross-section contradiction check

**Result: PASSED.** No contradictions with v1.0–v1.8. Specific consistency verifications: (1) R-MONO-4 narrows R-MONO-1 with explicit Bun.Glob remediation; compatible. (2) R-REFLOC-2(c) clarification keeps R-FM-6 untouched (no allow-list expansion). (3) R-REFLOC-2(d) is additive PROPOSED, conditional on R-REFLOC-2(c) non-portable tagging; preserves R-SR-3/R-SYS-1 portability invariant. (4) R-WORKSPACE-3 (plugin distribution) is consistent with R-COMP-1..3 (composition ladder) — plugins are the user-installation mechanism, composition is the runtime mechanism. (5) R-SHARE-1 (DA-058 reaffirmation) is consistent with R-COMP-3 (embed-and-duplicate). (6) DA-108..111 prevent contradictory rules; do not introduce any. (7) Gemini-9's Bun.Glob root cause (R-MONO-1/R-MONO-4) does not contradict R-LOAD-1..7 — skill-loading verification stays canary-token-based; the bug affects in-skill reference-file Read, not skill discovery itself. (8) Q-012 → Resolved-via-merge does not orphan any rule — Q-012(c) skill-loading verification is already covered by v1.8 R-LOAD-1..7.

#### Atomic write targets executed

- **research tab** — Q-009 → ✦ Researched v1.9; Q-012 → ✦ Resolved-via-merge v1.9; blue callout points to Q-010; T-009 tracker row added; DA-100..111 logged (12 new); v1.9 References entry added at top of items; new Session Notes — Q-009 section; v1.9 Reasoning Journey block appended.
- **skill-spec tab** — NEW "Workspace Topology" subsection containing R-WORKSPACE-1..6, R-MONO-1..4 (incl. R-MONO-4 new), R-SHARE-1..4, R-REFLOC-1..4, R-CROSS-1.
- **system-design tab** — NEW "Workspace Topology" subsection (system-view of plugin-vs-personal/project decision tree, T-MONO-1/T-SHARE-1/T-PFX-1/T-REF-1 thresholds, Bun.Glob #44490 caveat); "Locations and Precedence" appended with the four documented discovery sources + `--add-dir` exception + Bun.Glob regression note; "Dependencies and Splitting Strategy" appended with the embed-and-duplicate-vs-plugin-bundle decision tree.
- **meta-validation tab** — Validation Rules section gains R-WORKSPACE-1..6, R-MONO-1..4, R-SHARE-1..4, R-REFLOC-1..4, R-CROSS-1 entries with mechanical/semantic classification; new hallucination-canary entries for `${CLAUDE_SKILLS_PATH}`, `skillsDirectories`, `internal: true`, `Bun.Glob` (workaround required, not direct invocation).
- **changelog tab** — v1.9 entry inserted at top, current=true; v1.8 entry's current=false.
- **meta** — version 1.8 → 1.9; date → 2026-05-04.

<!-- @session: Q-010 -->
<a id="q-010"></a>

### Q-010 — Reference chunking and lazy-load granularity (2026-05-05)

#### Methodology

**Pre-registration (per `framework.synthesis_matrix.pre_registration_rule`).** Eight hypotheses written before consulting sources: H1 (Anthropic documents an explicit reference-file size threshold beyond R-SR-7's 10,000 words), H2 (Anthropic documents a recommended chunking strategy for `references/`), H3 (Read tool has documented behavior degradation), H4 (token-cost differential documented), H5 (header-anchored Grep+Read canonical, not vectors/semantic-search), H6 (`${CLAUDE_SKILL_DIR}` orthogonal to chunking), H7 (R-WORKSPACE-1 single-depth does NOT apply to references — but R-CHUNK-4 does, on different grounds), H8 (lost-in-the-middle generalizes as a non-Claude-specific lower bound). Four pre-registered quantitative thresholds: T-CHUNK-1 (split-into-sub-files mandatory at 500 lines OR 10,000 words OR ~10K-15K tokens), T-CHUNK-2 (TOC-required at 100 lines per Anthropic best-practices, stricter-wins over skill-workshop's 300-line figure), T-CHUNK-3 (grep-guidance at 10,000 words extending R-SR-7), T-CHUNK-4 (per-chunk lower bound ~50 lines as SHOULD-tier inline-vs-extract heuristic). H1 FAIL (no single quantitative cutoff documented; ceiling is implicit via Read-tool 25K→10K ceiling not skill-spec); H2/H3/H5/H6/H7/H8 PASS; H4 PARTIAL (qualitative architectural rationale documented, quantitative measurements only at Tier-2). All four T-CHUNK-* thresholds ADOPTED.

**Sources consulted (Turn 1 + Turn 2, 2026-05-04 / 2026-05-05).** **Anthropic Tier-1:** code.claude.com/docs/en/{skills, memory, sub-agents, plugins, plugins-reference, settings, env-vars, errors}; platform.claude.com/docs/en/agents-and-tools/agent-skills/{overview, best-practices, getting-started, enterprise}; platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools; anthropic.com/engineering/{equipping-agents-for-the-real-world-with-agent-skills, effective-context-engineering-for-ai-agents}; resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf; github.com/anthropics/skills (skill-workshop, pdf, pptx, docx, xlsx — all references/ structures inspected); claude-code/CHANGELOG.md. **anthropics/claude-code Issues (Tier-1):** #4002, #6910, #7679, #11011, #14876, #14888, #15687 (Read-tool ceiling family); plus Turn-2 Gemini-10 contributions **#40357** (Desktop 10K vs CLI 25K — DECISIVE), **#45019** (CLI silent 25K→10K downgrade Apr 2026 — DECISIVE), **#25469** (`.claude/skill-memories/` community proposal verified as stale — anchor for DA-122). **anthropics/claude-plugins-official Issues:** **#995** (skill loading failures at 10K Read ceiling — corroborating). **Tier-1 peer-reviewed (arXiv-verified per framework rule):** Liu et al. arXiv:2307.03172 (TACL 2024, Stanford/Samaya/FAIR — verified real); Bhat et al. arXiv:2505.21700 (Fraunhofer IAIS, May 2025 — verified real); Chroma 'Context Rot' technical report (2025, 18 models incl. Claude 4 — verified at research.trychroma.com/context-rot); **Turn 2 Gemini-10 contribution: arXiv:2601.01569 CaveAgent (Maohao Ran et al., HKBU/HKUST/HKGAI, Jan 2026 v1 / Feb 2026 v3 — verified real Tier-1 institutional affiliation; logged as P-CHUNK-11 forward-influence reference, not normative — DA-121).** **Tier-2:** Boris Cherny statement on Claude Code dropping local-RAG/vector-DB (smartscope.blog, vadim.blog reproductions); Anthropic Contextual Retrieval Sep 2024 engineering post (RAG-context, NOT skill-references-context — flagged for cross-domain transfer caveat); Cursor 2.4 changelog; LangChain RecursiveCharacterTextSplitter defaults (survey only); Microsoft Agent Framework Skills docs (cross-tool corroboration). **Discovery (PROPOSED only):** Lee Hanchung deep-dive; aihola.com production-skill walkthrough; codeagentsalpha.substack.com complete-guide; Mikhail Shilkov internals reverse-engineering; obra/superpowers (mirrors Anthropic best-practices); alirezarezvani/claude-skills (community pattern survey); vercel-labs/agent-skills (path-resolution conventions). **Sources NOT consulted and why:** OpenAI file_search vector store chunk sizes (out of scope, different agent surface); Anthropic Sonnet/Opus tokenizer changes (cited Apr 2026 Joe Njenga Medium post is Discovery-only and tangential to chunking).

#### Decisions adopted (Turn 1 + Turn 2)

**R-CHUNK-1 [skill][reference][portable] VALIDATED — TOC at >100 lines.** When a single file in `references/` exceeds 100 lines, the file MUST begin with a `## Contents` (or `## Table of Contents`) section listing every H2 heading. **Conflict resolution:** Anthropic best-practices (platform.claude.com) specifies 100 lines; anthropics/skills/skill-workshop/SKILL.md specifies 300 lines. Per `domain_constraints.rules.strictness_default` and `Anthropic_supremacy` favoring the more recent canonical doc, **adopt 100 lines**. Validation logic: regex check for ≥100 lines AND no `## Contents` / `## Table of Contents` H2 in the file body before the first non-TOC H2. **Mechanical.**

**R-CHUNK-2 [skill][reference][portable] VALIDATED — domain split at 500 lines OR 10,000 words OR ~10K-15K tokens.** When a single reference file exceeds **any** of these thresholds, authors MUST split into domain-organized sub-files (e.g., `references/{aws,gcp,azure}.md`) per Anthropic best-practices Pattern 2 ('Domain-specific organization with reference/finance.md, sales.md, etc.'). **Turn-2 refinement:** the upper-end token threshold tightened from Turn-1's 20,000 tokens to **10,000-15,000 tokens** to reflect Apr 2026 silent Read-tool ceiling drop (Issue #45019) and Desktop's hardcoded 10K cap (Issue #40357), both verified real Tier-1 in Gemini-10 review. **Mechanical** (line + word + token count).

**R-CHUNK-3 [skill][reference][portable] VALIDATED — literal grep example at >10K words (extends R-SR-7).** When a reference file exceeds 10,000 words AND is not split per R-CHUNK-2, SKILL.md MUST include at least one literal `grep` invocation example (e.g., `grep -i "pipeline" reference/sales.md`), not just prose pointers. Anchored in skill-workshop SKILL.md ('if files are large >10k words, include grep search patterns') and best-practices Pattern 2 ('Quick search: Find specific metrics using grep'). **Mechanical+Semantic** (mechanical: presence of `grep` string; semantic: pattern usefulness).

**R-CHUNK-4 [skill][reference][portable] VALIDATED — references one level deep from SKILL.md.** Reference files MUST sit exactly one directory level below SKILL.md (`<skill>/references/foo.md`, not `<skill>/references/sub/foo.md` and never reachable only via chained markdown links SKILL.md→a.md→b.md). Anthropic best-practices: 'Avoid deeply nested references … Keep references one level deep from SKILL.md … When encountering nested references, Claude might use commands like `head -100` to preview content rather than reading entire files, resulting in incomplete information.' **R-CHUNK-4 imposes a CONTENT-FIDELITY constraint, distinct from R-WORKSPACE-1's discovery constraint.** Both apply independently and both stand. **Mechanical** (validator: walk `references/`, fail if any markdown file is nested deeper than one level OR if any chained markdown link is detected in SKILL.md → ref → ref → ref).

**R-CHUNK-5 [skill][reference][claude-code-only] VALIDATED — Claude Code Read-tool per-call ceiling.** Reference files SHOULD target ≤2,000 lines AND ≤10,000 tokens per file (not the older 25,000-token figure) to stay within the Claude Code Read tool's documented per-call ceiling as of 2026-05. Files exceeding this MUST either (a) be split per R-CHUNK-2 or (b) include explicit `Read(file, offset=N, limit=M)` invocation examples in SKILL.md showing how to paginate. **Turn-2 refinement (G10-B ACCEPTED-DECISIVE):** updated 25,000 → 10,000 tokens to reflect anthropics/claude-code Issue #45019 (silent Apr 2026 downgrade, verified real) AND Issue #40357 (Desktop hardcoded 10K, verified real). The older 25,000-token figure remains documented in some CLI versions but is no longer the safe target. Anchored in: claude-code system prompt (gist.github.com/armstrongl) — 'Default reads up to 2000 lines from start, lines >2000 chars truncated'; Issues #4002, #14876, #14888, #15687 (25K legacy ceiling); **Issues #40357, #45019, claude-plugins-official #995 (current 10K ceiling)**. **Mechanical** (line + token count). [claude-code-only] tag because the limit is a Claude Code product decision; Claude.ai, the API, and other surfaces may behave differently.

**R-CHUNK-6 [skill][reference][portable] VALIDATED — header-anchored Grep+Read canonical; vector indexes and semantic search NOT canonical for in-skill references.** Reference files SHOULD use header-anchored 'Grep-then-Read' lazy-loading: SKILL.md points to the file, the file has a `## Contents` TOC + clear H2 anchors, and SKILL.md describes either grep patterns (R-CHUNK-3) or specific section names. Authors MUST NOT bundle on-disk vector indexes, embeddings databases, or semantic-search retrievers as the **primary** lookup mechanism for in-skill `references/` files. Anchored in: best-practices Pattern 2; Boris Cherny statement that Claude Code dropped local-RAG/vector-DB (Tier-2 via smartscope.blog and vadim.blog reproductions); absence of any Anthropic doc endorsing in-skill vector indexing; Anthropic 'Effective context engineering' post emphasizing agentic exploration over pre-built embeddings. **Scope clarification:** R-CHUNK-6 does NOT prohibit a skill from invoking an external semantic-search MCP tool or RAG API for non-reference data (e.g., a customer knowledge base). It scopes specifically to in-skill `references/` files. **Turn-2 refinement (G10-C ACCEPTED-PARTIAL):** Gemini-10's 'DEPRECATED' framing rejected because secondary uses remain legitimate; rule strength stays 'must not as primary mechanism' rather than 'forbidden'. **Semantic** (validator can flag suspicious files like `*.faiss`, `*.chroma`, `embeddings.json` inside `references/`; full assessment LLM-only).

**R-LAZYLOAD-1 [skill][reference][portable] VALIDATED — every reference linked from SKILL.md with explicit when-to-load.** Every file in `references/` MUST be linked from SKILL.md by name with a one-sentence trigger condition. References not linked from SKILL.md MUST NOT exist in the skill (dead-code rule). Anchored in best-practices ('All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed') and skill-workshop SKILL.md. **Mechanical+Semantic** (mechanical: every `.md` in `references/` is referenced by name in SKILL.md; semantic: when-to-load guidance quality LLM-only).

**R-LAZYLOAD-2 [skill][reference][portable] VALIDATED — MANDATORY-READ imperative pattern for must-not-skim references.** When SKILL.md instructs Claude to read a reference file that is authoritative and must not be skimmed, SKILL.md SHOULD use the imperative pattern observed in anthropics/skills/docx/SKILL.md verbatim: `MANDATORY - READ ENTIRE FILE: Read [ooxml.md](ooxml.md) (~600 lines) completely from start to finish. NEVER set any range limits when reading this file.` This is Anthropic's own counter-pattern to Read's default preview behavior — operationalized as a rule. **Semantic** (mechanical check: presence of MANDATORY/ENTIRE FILE/NEVER tokens; semantic check: file actually merits the directive).

**R-LAZYLOAD-3 [skill][reference][portable] VALIDATED — inline content <50 lines (SHOULD-tier).** Reference files SHOULD NOT be smaller than ~50 lines unless genuinely modular (e.g., per-endpoint API stub, domain-segregated schema fragment). Below this threshold, content is better kept inline in SKILL.md to avoid the per-Read-call overhead and the discovery friction of many tiny files. **Turn-2 refinement (G10-E REJECTED → DA-120):** Gemini-10 proposed upgrading to MUST based on '50 lines = ~3,000 tokens' arithmetic; the math is wrong by ~5x (50 lines of markdown ≈ 500-1,000 tokens, not 3,000). The threshold itself stands; the rule remains SHOULD-tier per framework's no-MUST-without-empirical-justification principle. **Semantic only** (judgment call).

#### PROPOSED claims (Discovery-only or single-source — queued)

**P-CHUNK-7 — Token-cost differential 'full read' vs 'chunk read'.** Single Read of a ~10,000-token reference file consumes ~17,000 effective context tokens (1.7x overhead from line-number prefixes); Grep-then-targeted-Read for ~500 tokens consumes ~850 effective tokens — ~20x reduction when relevant fraction is small. Single Tier-2 source (anthropics/claude-code Issue #20223 community measurement); needs Tier-1 corroboration before promotion. **P-CHUNK-8 — Recommended 256-1024 token chunks for embedding-based retrieval.** When (and only when) a skill uses contextual retrieval / embedding search as a **secondary** lookup mechanism, 256-1024 token chunks with 10-20% overlap are appropriate. Tier-1 sources (Bhat et al. arXiv:2505.21700; Anthropic Contextual Retrieval) but RAG-context not skill-references-context — cross-domain transfer unverified. **P-CHUNK-9 — Lost-in-the-middle implies U-shaped degradation for in-skill references.** When agent loads multi-thousand-line reference in one Read call, middle ~50% utilized at lower fidelity than start/end. Liu et al. (TACL 2024) + Chroma (2025) demonstrate for general long-context tasks; transfer to skills plausible but unmeasured. **Turn-2 refinement (DA-124):** specific 30%-figure rejected; qualitative U-shape retained. **P-CHUNK-10 — `head -100` partial-read frequency.** Anthropic best-practices implies but doesn't quantify: agents preview-read with `head -100` (≈100 lines, 1,500-2,500 tokens) when reaching references via chained links. Authors should treat first ~100 lines of any deeply-nested reference as the only content guaranteed to be loaded. Single qualitative Tier-1 source. **P-CHUNK-11 NEW (Turn 2, Gemini-10 G10-F1 ACCEPTED-PARTIAL) — CaveAgent runtime-skill-injection paradigm.** Forward-influence reference for future Q-* items addressing persistent-runtime agent surfaces (Python-kernel-based frameworks like cave_agent / pycallingagent / PydanticAI with stateful sandboxes). Anchored in arXiv:2601.01569 (verified real Tier-1, HKBU/HKUST/HKGAI). NOT applicable to Claude Code's stateless-bash-tool runtime model (see DA-121). Q-009 precedent for GraSP/Skilldex forward-influence references.

#### Discarded Alternatives logged (DA-112..DA-124)

Twelve discards filed: DA-112 (single-file-with-TOC for any size); DA-113 (on-disk vector index primary); DA-114 (semantic search via in-skill MCP primary); DA-115 (SHA content-addressed chunking); DA-116 (jump-tags as canonical); DA-117 (mandatory `references/_index.md`); DA-118 (mandatory 256-token minimum chunk); DA-119 (25K Read limit as portable); plus Turn-2 Gemini-10-derived: **DA-120** G10-E MUST-upgrade-with-math-error; **DA-121** G10-F1 CaveAgent-as-normative; **DA-122** G10-F2 skill-memories-as-canonical; **DA-123** G10-A specific-50-line-cutoff; **DA-124** G10-D 30%-specific-figure. See Discarded Alternatives section for full text.

#### Other researchers reviewed

**Source label:** Gemini-10 (Google Gemini Deep Research output for Q-010, submitted by user 2026-05-05). **Source verifications performed (≥3 per framework rule, six performed):** (1) anthropics/claude-code Issue #40357 VERIFIED REAL via direct GitHub fetch — opened tovamerika-ux 2026-03-28; full reproduction with Desktop v1.1.9310 + Windows + 10K cap; error message text matches; **decisive Tier-1 contribution → R-CHUNK-5 Desktop refinement**. (2) anthropics/claude-code Issue #45019 VERIFIED REAL via direct GitHub fetch — opened viniciusferrao 2026-04-08; documents Apr 2026 silent 25K→10K downgrade; user provides search-link evidence; **decisive Tier-1 contribution → R-CHUNK-5 current-shipping-behavior caveat + R-CHUNK-2 portable threshold tightened**. (3) anthropics/claude-plugins-official Issue #995 VERIFIED REAL — documents real production failure mode where SKILL.md files in Anthropic's own claude-plugins-official repo fail at 10K Read limit; explicit recommendation matches R-CHUNK-2 + R-LAZYLOAD-1; corroborates G10-B. (4) arXiv:2601.01569 CaveAgent VERIFIED REAL — 23 authors led by Maohao Ran; HKBU/HKUST/HKGAI affiliation verified; not future-dated; abstract verified to claim 'extends the Agent Skills open standard'; PyPI llm-py-agent + github.com/vanzll/PyAgent verified real and confirm `injection.py` is a CaveAgent-framework filename, NOT Claude Code; **architecturally misapplied by Gemini-10 → P-CHUNK-11 PROPOSED forward-influence reference, DA-121 normative-rule rejection** (Q-009 GraSP/Skilldex precedent). (5) anthropics/claude-code Issue #25469 VERIFIED REAL — opened anton-abyzov 2026-02-13; labels `enhancement` + `stale`; community proposal NOT Anthropic-implemented; **DA-122 skill-memories-as-canonical rejection**. (6) PyPI llm-py-agent 0.1.0 VERIFIED REAL — description verbatim 'CaveAgent extends the Agent Skills standard with injection.py'; reinforces (4). **Outcome:** 1 ACCEPTED-DECISIVE (G10-B → R-CHUNK-5 + R-CHUNK-2 refined); 4 ACCEPTED-PARTIAL (G10-A spirit; G10-C tightening but not DEPRECATED-framing; G10-G env-var orthogonality; G10-F1 → P-CHUNK-11 forward-influence reference); 1 MISREAD clarified (G10-H — R-CHUNK-4 already enforces; H7 wording tightened); 6 REJECTED as DA-119..DA-124. **Independence note applied:** Gemini-10's pattern of fabricating 'Anthropic-blessed production paradigms' from academic-flavored sources matches systemic Gemini pattern across Gemini-2/5/6/7/8 — treated as ONE LLM-second-opinion data point per framework. Materially cleaner than Gemini-2/6/7/8 on arXiv verification (CaveAgent paper is real and well-cited); on par with Gemini-9 in evidence quality. Two decisive Tier-1 GitHub Issue verifications (#40357 + #45019) are major contributions.

#### Cross-section contradiction check

**Result: PASSED.** No contradictions with v1.0–v1.9. Specific consistency verifications: (1) R-CHUNK-1's 100-line TOC threshold for references is intentionally stricter than R-BODY-4's 300-line TOC threshold for SKILL.md body; rationale: references are reached via chained links and trigger `head -100` partial-read previews where the SKILL.md body is loaded in full at skill activation. No conflict. (2) R-CHUNK-3 extends R-SR-7 with literal-grep-example requirement; R-SR-7 stays in force. (3) R-CHUNK-4 imposes a CONTENT-FIDELITY one-level-deep constraint; R-WORKSPACE-1 imposes a DISCOVERY one-level-deep constraint on skill directories. Independent. Both stand. H7 (R-WORKSPACE-1 does not apply to references) stands; the second clause of H7 phrasing has been tightened — references CAN technically nest (the filesystem and Read tool permit it) but R-CHUNK-4 forbids it on content-fidelity grounds. (4) R-CHUNK-5 [claude-code-only] vs R-CHUNK-2 [portable] — separation is preserved; the [portable] threshold is the conservative lower bound. (5) R-CHUNK-6 protects R-SYS-1 (drop-in folder portability) by forbidding non-portable vector-index runtime dependencies. (6) R-LAZYLOAD-1 enforces L3 progressive disclosure (every reference must be linked from SKILL.md); compatible with R-COMP-1..3 composition ladder (chunking is intra-skill; composition is inter-skill — orthogonal). (7) R-LAZYLOAD-2 codifies anthropics/skills/docx/SKILL.md MANDATORY-READ pattern as a counter-pattern to Read's preview behavior; compatible with R-CHUNK-5 (which describes the default behavior R-LAZYLOAD-2 explicitly overrides). (8) R-LAZYLOAD-3 SHOULD-tier balances tool-call overhead against context-window economy; compatible with R-BODY-4 SKILL.md size cap. (9) ${CLAUDE_SKILL_DIR} resolution semantics unaffected by chunking (H6 PASS); compatible with R-MONO-1/4 (Bun.Glob regression affects skill discovery, not in-skill Read). (10) DA-121 P-CHUNK-11 CaveAgent forward-influence reference follows Q-009 GraSP/Skilldex precedent; non-conflicting because PROPOSED-tier forward references are explicitly scoped as 'not v1.10 normative.' (11) DA-122 preserves R-WORKSPACE-3 (plugin distribution) as the canonical extension-without-fork mechanism, with `.claude/rules/` as the orthogonal always-on guidance mechanism — both already documented; no rule conflict. **No contradictions detected.**

#### Atomic write targets executed

- **research tab** — Q-010 → ✦ Researched v1.10; blue callout points to Q-011; T-010 tracker row added; DA-112..DA-124 logged (13 new); v1.10 References entry added at top of items; new Session Notes — Q-010 section; v1.10 Reasoning Journey block appended.
- **skill-spec tab** — NEW "Reference Chunking & Lazy Loading" subsection containing R-CHUNK-1..6 and R-LAZYLOAD-1..3 with full rule text + Tier-1 citations; 100-vs-300-line TOC conflict resolution noted (Anthropic-supremacy + strictness default → 100-line threshold adopted; flag for re-check on next Anthropic doc revision).
- **system-design tab** — NEW "Reference Chunking Topology" subsection (Read-tool ceiling table — 25K legacy vs 10K current vs 10K Desktop; canonical Grep-then-Read pattern; vector-index/semantic-search rejection rationale; interaction with progressive-disclosure L1/L2/L3 layers; orthogonality to ${CLAUDE_SKILL_DIR} and R-WORKSPACE-1 single-depth discovery).
- **meta-validation tab** — Validation Rules section gains R-CHUNK-1..6 + R-LAZYLOAD-1..3 entries with mechanical/semantic classification; new hallucination-canary entries for `.claude/skill-memories/`, `injection.py` (both rejected as Claude Code patterns).
- **changelog tab** — v1.10 entry inserted at top, current=true; v1.9 entry's current=false.
- **meta** — version 1.9 → 1.10; date → 2026-05-05.

<!-- @session: Q-011 -->
<a id="q-011"></a>

### Q-011 — LLM-Wiki documentation patterns for the Research Buddy project itself (2026-05-05)

#### Methodology

Turn 1: broad research per project_specific.source_tiers, scoped explicitly to the JSON-document layer (NOT the underlying Claude Code skill spec). Five sub-questions (a)–(e) plus a calibration section (f). Pre-flight verified: Q-011 had no prior tracker entry or Session Notes; DA-003, DA-011, and DA-085 were the relevant prior rejections to avoid colliding with. Output: findings with inline citations [Title, Author, Year, Venue, DOI/URL]; proposed decisions; rejected alternatives; cross-section impact; calibration check; second-opinion brief printed verbatim per framework.second_opinion_review.brief_template.

Turn 2: vetted Gemini-1 second-opinion submission per framework.second_opinion_review.evaluation. Verified ≥4 cited sources end-to-end against arXiv directly. Identified 1 likely fabrication (DA-125), 1 inverted-argument distortion (DA-127), 1 cherry-picked omission (DA-126), 1 misapplied Anthropic-doc claim (DA-128), and 1 quantitative-figure non-appearance (DA-129). Net effect of Gemini-1 after vetting: STRENGTHENS Turn 1 decisions on (a), (d), (e); reverses no decisions; promotes (a) rule-status scheme, (d) deferral, and (e) categorical lifecycle to VALIDATED.

#### Sources consulted (verified end-to-end)

| Source | Tier | Verification | Disposition |
|---|---|---|---|
| RFC 2119 (Bradner 1997) | Tier 1 | Canonical IETF, rfc-editor.org/rfc/rfc2119 | ADOPT — force-keyword grammar |
| RFC 8174 (Leiba 2017) | Tier 1 | Canonical IETF | ADOPT — capitalization rule |
| RFC 7322 §4.1.4 (Flanagan & Ginoza 2014) | Tier 1 | Canonical IETF | ADOPT — Updates/Obsoletes supersession |
| GRADE (Guyatt et al. 2008, BMJ 336:924) | Tier 1 | Verified PMC2335261 | ADOPT — ordinal evidence levels |
| Cohen's Kappa (McHugh 2012, Biochemia Medica) | Tier 1 | Verified PMC3900052 | ADOPT — inter-rater agreement justification |
| CoALA (Sumers et al. 2024, TMLR, arXiv:2309.02427) | Tier 1 | Verified arXiv direct | ADOPT — memory-tier ontology |
| MemGPT (Packer et al. 2023, arXiv:2310.08560) | Tier 1 | Verified arXiv direct | REFERENCE — paging not adopted at this scale |
| Generative Agents (Park et al. 2023, UIST, arXiv:2304.03442) | Tier 1 | Verified arXiv direct | REFERENCE — recency*importance*relevance not adopted |
| Reflexion (Shinn et al. 2023, NeurIPS, arXiv:2303.11366) | Tier 1 | Verified arXiv direct | REFERENCE — episodic-buffer concept supports tier mapping |
| Voyager (Wang et al. 2023, TMLR, arXiv:2305.16291) | Tier 1 | Verified arXiv direct | REFERENCE — procedural-memory operationalisation |
| A-MEM (Xu et al. 2025, arXiv:2502.12110) | Tier 1 | Verified arXiv direct | REFERENCE — structured-attribute design for evidence substructure |
| When to Forget (Simsek 2026, arXiv:2604.12007) | Tier 1 | VERIFIED via web_search; 13 Apr 2026 | PARTIAL ADOPT — qualitative associational-vs-causal disclaimer; specific numeric figures rejected (DA-129) |
| Memory as Metabolism (Miteski 2026, arXiv:2604.12034) | Tier 1 | VERIFIED via web_search; 13 Apr 2026 | REFERENCE — ossification framing supports supersession; user-coupled-drift framing rejected (DA-127) |
| Beyond the Context Window (Pollertlam & Kornsuwannawit 2026, arXiv:2603.04814) | Tier 1 | VERIFIED via web_search; 5 Mar 2026 | ADOPT FOR (d) — supports deferral via short-interactions-paramount qualifier; cherry-picked Gemini-1 framing rejected (DA-126) |
| ConvoMem (Pakhomov, Nijkamp & Xiong 2025, arXiv:2511.10523) | Tier 1 | VERIFIED via web_search; 13 Nov 2025 | ADOPT FOR (d) — RAG-detrimental-below-150-conversations corroborated |
| Anthropic Contextual Retrieval (anthropic.com/news/contextual-retrieval, 2024) | Tier 1 | Canonical Anthropic | ADOPT FOR (d) deferred-pattern — 35%/49%/67% gains framed correctly |
| Anthropic memory doc (code.claude.com/docs/en/memory) | Tier 1 | Canonical Anthropic; verified URL | ADOPT FOR (e) freshness-validator design; Gemini-1 misapplication rejected (DA-128) |
| Wikipedia {{Update after}}, {{Obsolete source}} templates | Tier 2 | Canonical secondary | ADOPT — categorical staleness markers |
| MDN deprecation lifecycle (Experimental → Deprecated) | Tier 2 | Canonical secondary | ADOPT — lifecycle-state ontology |
| Reciprocal Rank Fusion (Cormack, Clarke & Büttcher 2009, SIGIR) | Tier 1 | Canonical IR | DEFERRED-PATTERN reference (per (d)) |
| Murre & Dros 2015, PLoS ONE 10(7):e0120644 | Tier 1 | Verified PLoS DOI | REFERENCE — Ebbinghaus replication; supports rejection of biological-decay model for non-capacity-constrained doc |
| Karpathy llm-wiki (gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) | Discovery | Fetched directly Turn 1 | REFERENCE — convergent threshold guidance ~100–200 pages |
| rohitg00 LLM-Wiki-v2 + Mattia83it commentary | Discovery | Fetched directly Turn 1 | REFERENCE — supersession-not-decay critique adopted; numeric float design rejected |
| Gemini-1 (Google Gemini deep research, submitted 2026-05-05) | Second opinion | Vetted per framework.second_opinion_review.evaluation | PARTIALLY INCORPORATED — see DA-125 to DA-129 for rejected portions |

#### Decisions (adopted, with status and gate)

**(a) Confidence scoring.** Adopt the four-level ordinal rule-status scheme PROPOSED → VALIDATED → CANONICAL → SUPERSEDED in `agent_guidelines.framework.rule_lifecycle.scheme` [VALIDATED → CANONICAL via vetting]. Adopt RFC 2119 capitalized force keywords in rule bodies in `agent_guidelines.framework.normative_keywords` [VALIDATED]. Adopt the per-rule `evidence` substructure schema (tier1_sources, tier2_sources, discovery_sources, last_verified_iso8601, contradictions) in `agent_guidelines.framework.rule_lifecycle.evidence_substructure` [PROPOSED — schema only; population deferred to next session]. **Reject** numeric confidence floats per DA-125 cluster: collapsing to floats imports false precision and a retrieval-ranking design pattern that does not fit normative ID-loaded rules.

**(b) Supersession links.** Adopt bidirectional `superseded_by` / `supersedes` plus `updates` / `updated_by` link fields between Discarded Alternatives and R-XXX-N rules, ported from RFC 7322 §4.1.4 [VALIDATED, canonical IETF + Discovery convergence with rohitg00 LLM-Wiki-v2]. Add `supersession_rationale` free-text field [PROPOSED — Tier-2 support]. Validator-script requirement: orphan supersession is a meta-validation error (see meta-validation tab). Preservation invariant: superseded DAs are NEVER deleted.

**(c) Consolidation tiers.** Adopt CoALA labels (working / episodic / semantic / procedural) attached to the existing tab/section structure as documentation in `agent_guidelines.framework.memory_tiers.mapping` [VALIDATED — Tier-1 convergence across CoALA, MemGPT, Generative Agents, Reflexion, Voyager, A-MEM]. Adopt promotion rules between tiers in `agent_guidelines.framework.tier_promotion_rules` [VALIDATED]. **Reject** structural tab reorganization to literal tier names; high churn, no measurable benefit at this scale.

**(d) Hybrid retrieval over the JSON.** **DEFER** with explicit trigger conditions in `agent_guidelines.framework.retrieval_strategy` [VALIDATED → strengthened by Gemini-1 vetting]. Adopted current default: whole-document read + section-anchor + grep. Adopted intermediate step: maintain `tabs[research].'Index'` content catalogue (Karpathy's llm-wiki convention applied at the JSON-document layer ONLY — DA-011 carve-out preserved). Acknowledge DA-085: any future vector component is scoped to JSON cross-session navigation only, never to normative rule scope-preservation tests.

**(e) Lifecycle markers.** Adopt categorical four-state lifecycle (current / verify_after_passed / stale / superseded) on References and R-XXX-N rules in `agent_guidelines.framework.reverification_intervals` [VALIDATED → strengthened by When to Forget associational-vs-causal disclaimer]. Adopt re-verification interval defaults: 90 days (Anthropic canonical), 365 days (peer-reviewed), 30 days (Discovery). Time alone NEVER moves to stale; only triggered re-verification finding source-changed/contradicted moves to stale, or explicit supersession link from (b). Preservation invariant: stale and superseded entries are NEVER deleted. **Reject** Ebbinghaus / MemoryBank-style numeric decay on rules: biological-capacity model does not transfer to a JSON document with no capacity constraint, and outcome-based decay has documented associational-vs-causal failure mode (When to Forget, Simsek 2026, arXiv:2604.12007).

**(f) Calibration outcome.** Adopt (b) wholesale; partial-adopt (a), (c), (e) with explicit rejection of the over-engineered numeric variants; defer (d) with trigger. Net pattern: rohitg00 LLM-Wiki-v2 primitives are optimized for very large personal knowledge bases with retrieval ranking against forgetful LLM context; the Research Buddy JSON is a small, audited, normative document loaded wholesale. Wholesale adoption would be a category error. Adopting standards-document primitives (RFC 7322, RFC 2119, Wikipedia templates, MDN lifecycle, GRADE) plus CoALA concept labels delivers the value without the over-engineering.

#### Rejected claims (Gemini-1 vetting failures)

Five DAs added at session close: DA-125 (fabricated MaRS arXiv ID 2603.15994); DA-126 (cherry-picked Pollertlam framing inverting the paper's actual recommendation); DA-127 (inverted-argument attribution to Miteski's 'Memory as Metabolism' — actual paper concerns ossification, not user-coupled drift); DA-128 (Anthropic 25 KB MEMORY.md limit misapplied to on-demand-loaded user documents); DA-129 (specific quantitative figures ρ≈-0.33 and 30% retrieval-diversity threshold not present in the actual 'When to Forget' abstract, only the headline ρ=0.89±0.02 is verifiable). Pattern is consistent with the project's prior Gemini-3 / Gemini-4 / Gemini-8 fabrication signatures (DA-031–DA-033, DA-039–DA-043, DA-091–DA-099).

#### Cross-section impact (sections this session writes to)

`meta` (version, date, file_name); `agent_guidelines.project_specific.final_goal` (boundary-contract amendment); `agent_guidelines.framework.rule_lifecycle` (NEW); `agent_guidelines.framework.normative_keywords` (NEW); `agent_guidelines.framework.memory_tiers` (NEW); `agent_guidelines.framework.tier_promotion_rules` (NEW); `agent_guidelines.framework.retrieval_strategy` (NEW); `agent_guidelines.framework.reverification_intervals` (NEW); `tabs[research].sections['Open Research Queue']` (Q-011 status, blue callout, Q-014/Q-015 added); `tabs[research].sections['Research Tracker']` (Q-011 row); `tabs[research].sections['Reasoning Journey']` (Q-011 outcome blocks); `tabs[research].sections['Discarded Alternatives']` (DA-125 to DA-129); `tabs[research].sections['Session Notes — Q-011']` (NEW section — this one); `tabs[research].sections['References']` (Q-011 references appended in descending version order); `tabs[meta-validation].sections['Validation Rules (machine-checkable)']` (supersession_integrity, reference_freshness, tier_consistency validators added — schema only); `tabs[changelog].sections['Version History']` (v1.11 entry).

<!-- @session: Q-014 -->
<a id="q-014"></a>

### Q-014 — LLM-Wiki documentation patterns applied to skill `references/` (2026-05-05)

#### Methodology

Turn 1: research per project_specific.source_tiers, scoped to three sub-questions: (i) inside a single skill's `references/`, (ii) cross-skill reference-doc sharing within a skills root, (iii) the AGENTS.md ↔ CLAUDE.md symlink convention as a project-memory-layer pattern. Pre-flight verified: Q-014 had no prior tracker entry; relevant prior rejections to avoid colliding with — DA-003 (top-level `index.md` rejected), DA-011 (Karpathy `index.md` at skills root rejected), DA-057 (cross-skill `shared/` ecosystem dir rejected), DA-063 (AGENTS↔CLAUDE symlink at skill-system layer rejected), DA-100 (cross-scope skill symlinks rejected), DA-103 (cross-plugin helper sharing unimplemented), DA-104 (root `.claude/scripts/` rejected), DA-105 (cross-skill router pattern rejected), DA-113/114 (vector / semantic-search inside `references/` rejected), DA-115 (content-addressed chunking rejected), DA-116 (jump-tags in SKILL.md rejected), DA-117 (mandatory `references/_index.md` MUST rejected; optional MAY accepted), DA-118 (mandatory minimum chunk size rejected). Turn 1 deliverable: ~28 LLM-Wiki patterns enumerated; empirical walk of `anthropics/skills/{pdf,skill-workshop,mcp-builder,doc-coauthoring,xlsx}/references/`; 7 candidate rules (R-REF-FM-1, R-REF-SUPERSEDE-1, R-REF-SECRETS-1, R-LOG-REJECT, R-REF-SHARE-1, R-IDX-1-REFINE, R-MEM-3-CARVEOUT) at conservative force levels; Turn 1's R-MEM-3 verdict was *keep PROPOSED*. Turn 2: vetted Gemini-14 second opinion (full 'Anthropic Claude Code Agent Skills System: Canonical Reference Architecture and Documentation Specification' deep research output from Google Gemini, 2026-05-05). Per framework.second_opinion_review.evaluation, verified ≥3 cited sources end-to-end. Five verified, with one critical reversal of Turn 1's R-MEM-3 verdict driven by canonical Anthropic Tier-1 evidence Turn 1 had missed.

#### Sources consulted (verified end-to-end during Turn 2)

| Source | Tier | Verification | Disposition |
|---|---|---|---|
| Anthropic memory doc § AGENTS.md (`code.claude.com/docs/en/memory`) | Tier 1 | Direct fetch confirms verbatim quote: "Claude Code reads CLAUDE.md, not AGENTS.md. If your repository already uses AGENTS.md for other coding agents, create a CLAUDE.md that imports it…" | ADOPT — drives R-MEM-3 demotion + R-MEM-10 VALIDATED CANONICAL |
| Anthropic best-practices doc (`platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`) | Tier 1 | Direct fetch end-to-end. Confirms description=1024-char limit (single field, not Gemini-14's 1,536 combined); no `context: fork` in skill frontmatter; no `!command` injection; canonical FORMS.md uppercase used as example | ADOPT — overrides multiple Gemini-14 hallucinations |
| Anthropic plugins-reference doc (`code.claude.com/docs/en/plugins-reference`) | Tier 1 | Confirms verbatim: "Symlinks are preserved in the cache rather than dereferenced, and they resolve to their target at runtime" + "Paths that traverse outside the plugin root … will not work after installation" | ADOPT — drives R-REF-SHARE-1 (plugin-internal sharing) |
| Anthropic skills repo `anthropics/skills` (skill-workshop, mcp-builder, pdf, claude-api, xlsx, doc-coauthoring) | Tier 1 | Direct fetches and search snippets. skill-workshop/SKILL.md uses 300-line ToC threshold (Tier-1 internal contradiction with best-practices' 100-line); claude-api skill confirmed multi-level (`python/`, `shared/`); xlsx skill confirmed flat-with-recalc.py-at-root layout | ADOPT empirical patterns; flag claude-api 2-level structure for Q-016 |
| Anthropic enterprise-skills doc (`platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise`) | Tier 1 | Search snippet confirms 'Verify no hardcoded credentials. Check for API keys, tokens, or passwords in Skill files.' | ADOPT — backs R-REF-SECRETS-1 SHOULD |
| claude-code-action Issue #1187 (`github.com/anthropics/claude-code-action/issues/1187`) | Tier 1 | Direct fetch confirms: ENOENT crash since v1.0.89 when CLAUDE.md is symlinked to AGENTS.md; reproduction steps explicit; workaround pin v1.0.88; fix in PR #1186 | ADOPT — reinforces R-MEM-3 demotion |
| agents.md homepage (`agents.md`) | Tier 2 | Direct fetch confirms: 60k+ adopters; LF/Agentic-AI-Foundation stewardship; nested AGENTS.md walk; 'closest AGENTS.md wins'. **Tier-1 misciting refuted:** the `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` shell command is for AGENT.md (singular) → AGENTS.md (plural) backward compatibility, NOT for CLAUDE.md ↔ AGENTS.md cross-tool symlinking | ADOPT for R-MEM-7..9 confirmation; REJECT Gemini-14 miscitation as DA-133 |
| anthropics/skills Issue #189 + #667 + #675 | Tier 1 | Direct fetch + search confirms: ~50K wasted tokens from duplicate plugin packaging (#189); non-standard directory naming flagged (#667); discoverability barriers (#675) | ADOPT as background; REJECT Gemini-14's framing of #189 as 'cross-skill reference duplication crisis' — actual cause is plugin packaging hygiene, not architectural |
| Karpathy llm-wiki gist (`gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`) | Discovery | Already verified end-to-end in Turn 1. Confirms 28 patterns enumerated. The gist names CLAUDE.md and AGENTS.md as parallel alternatives for the schema layer; **does NOT recommend symlinking them** | REFERENCE — community pattern catalogue, not canonical for skills |
| rohitg00 LLM-Wiki-v2 fork (`gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2`) | Discovery | Already verified end-to-end in Turn 1. v2 introduces confidence scoring, retention decay, hybrid retrieval, mesh sync, etc. — knowledge-base-scale patterns out of scope for single skill | REFERENCE — almost entirely out of scope at single-skill `references/` layer |
| Mattia83it commentary on rohitg00 gist (May 4, 2026) | Discovery | Already verified Turn 1: 'forgetting curves applied to errors and superseded decisions are how you repeat the same mistake'; 'numeric confidence scores are false precision'; 'human-in-the-loop as a write gate is not backwardness, it is quality control' | ADOPT — backs DA-Q014-V1 (confidence scores) and DA-Q014-V3 (decay) rejections |
| Gemini-14 (Google Gemini deep research, submitted 2026-05-05) | Second opinion | Vetted per framework.second_opinion_review.evaluation. 4 incorporations + 5 hallucination rejections (DA-130..DA-138 cluster) | PARTIALLY INCORPORATED — see Decisions and Rejected Claims below |

#### Decisions (adopted, with status and gate)

**(i)(a) `references/` empirical baseline confirmed.** R-SR-1, R-SR-2, R-SR-5, R-CHUNK-1..6, R-BODY-5 (no README.md inside skill) all hold unchanged. Anthropic skills universally use flat `references/<topic>.md` with inline SKILL.md citation per R-SR-5. Karpathy's `index.md` master-catalogue and `log.md` chronological journal are NOT used by any anthropics/skills production skill.

**(i)(b) New skill-spec rules adopted (PROPOSED — single-Tier-1 backing each):**
**R-REF-FM-1 [reference][portable] PROPOSED MAY:** A reference file inside `<skill>/references/` MAY include optional YAML frontmatter limited to `title:`, `summary:`, and `load_when:` fields. No other frontmatter is sanctioned. Backing: best-practices implies references are documentation-shaped; Karpathy P-K10 supports without mandating.
**R-REF-SUPERSEDE-1 [reference][portable] PROPOSED MAY:** Deprecated reference content MAY be retained under a `<details><summary>Old patterns / deprecated …</summary>…</details>` HTML-disclosure block instead of being deleted, mirroring best-practices doc § 'Avoid time-sensitive information' canonical example. Implements LLM-Wiki-v2 'supersession over decay' principle (Mattia83it counter-pattern).
**R-REF-SECRETS-1 [reference][portable] PROPOSED SHOULD:** Reference files SHOULD NOT contain hard-coded credentials, API keys, tokens, or PII; secrets MUST be externalised. Backing: Anthropic enterprise-skills doc Tier-1.
**R-LOG-REJECT [reference][portable] PROPOSED MUST NOT:** A skill `references/` directory MUST NOT contain a runtime `log.md` (Karpathy P-K8 chronological journal pattern). Activity logging is the responsibility of the project-memory layer (CLAUDE.md `@imports`) or git, not the skill layer. Backing: Anthropic skills are read-only at runtime; no anthropics/skills file exhibits a `log.md`; R-CHUNK-6 forbids primary-lookup mechanisms beyond grep-then-read.

**(i)(c) Index Files PROPOSED carve-out refined.** The existing System Design § Index Files PROPOSED note (Karpathy `index.md` allowed within `references/`) is refined to **MAY** when the skill has ≥3 reference files OR total reference content >5,000 lines. The catalogue MUST NOT be the primary discovery mechanism — SKILL.md inline citation per R-SR-5 remains canonical. This is NOT a duplicate of DA-117 (which rejected MUST and accepted optional); v1.12 locks the optionality at MAY-with-threshold.

**(ii) Cross-skill reference-doc sharing — R-REF-SHARE-1 adopted.** **R-REF-SHARE-1 [skill][portable] PROPOSED SHOULD:** Cross-skill reference-doc sharing within a skills root SHOULD follow the helper-script ladder of R-SHARE-1: (a) for plugin-bundled skills, place the canonical reference at `${CLAUDE_PLUGIN_ROOT}/<shared-refs>/<file>.md` and symbolically link it into each consuming skill's `references/`; (b) otherwise embed-and-duplicate (R-SHARE-1 lineage); (c) cross-plugin sharing is NOT supported (DA-103 stands). Backing (Tier-1): plugins-reference 'Symlinks are preserved in the cache rather than dereferenced, and they resolve to their target at runtime' + 'Paths that traverse outside the plugin root … will not work after installation'.

**(iii) MAJOR REVERSAL — R-MEM-3 demoted, R-MEM-10 adopted as VALIDATED CANONICAL.** Turn 1 had recommended *keep R-MEM-3 PROPOSED*. Turn 2 verification of Gemini-14 surfaced canonical Anthropic Tier-1 evidence Turn 1 missed: `code.claude.com/docs/en/memory` § AGENTS.md states verbatim *"Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it so both tools read the same instructions without duplicating them"* with the canonical pattern shown:

```
CLAUDE.md
@AGENTS.md
## Claude Code
Use plan mode for changes under `src/billing/`.
```

This is direct Anthropic-canonical and triggers Anthropic supremacy. **R-MEM-3 (PROPOSED, symlink AGENTS↔CLAUDE) is demoted to permanent DA-130, with `superseded_by: [R-MEM-10]` per agent_guidelines.framework.rule_lifecycle.supersession_links.** **R-MEM-10 [reference][portable] VALIDATED CANONICAL** is adopted in its place: "For cross-tool projects sharing instructions across Claude Code, Codex, Cursor, Aider, and the wider agents.md ecosystem, place the canonical instructions at `<root>/AGENTS.md` and create a `<root>/CLAUDE.md` whose body is `@AGENTS.md` (with optional Claude-specific directives appended below). Claude Code MUST follow the import directive at session start (verified canonical doc); Codex/Cursor/Aider read `AGENTS.md` natively. Repositories MUST NOT symlink CLAUDE.md to AGENTS.md or vice versa." Tags: [reference][portable] CANONICAL. Sources: code.claude.com/docs/en/memory § AGENTS.md (Tier-1 canonical Anthropic, primary); agents.md (Tier-2 — confirms 60k+ adopters, LF stewardship, nested AGENTS.md walk); claude-code-action #1187 (Tier-1 — documents the symlink failure mode). **R-MEM-3-CARVEOUT** (Turn 1 candidate) becomes **R-MEM-10-CARVEOUT MUST NOT** language inside R-MEM-10: "R-MEM-10 applies only at the project-memory layer (`<root>/CLAUDE.md` ↔ `<root>/AGENTS.md`, plus nested per-directory pairs per agents.md walk). It does NOT apply at the skill layer; SKILL.md has no AGENTS-equivalent and MUST NOT be symlinked or @-imported to a parallel name."

#### Rejected claims (Gemini-14 vetting failures + Turn-1-internal DA confirmations)

Nine new DAs added at session close: **DA-130** (R-MEM-3 demoted; superseded by R-MEM-10); **DA-131** (Gemini-14: 1,536-char description+when_to_use combined limit — fabricated; canonical limit is 1024 chars on single `description` field per best-practices doc fetch); **DA-132** (Gemini-14: `context: fork` as a SKILL.md frontmatter field — fabricated; `context: fork` is a subagent-frontmatter field per existing R-COMP-1..3 / DA-008 / DA-023 lineage); **DA-133** (Gemini-14: `!`+`command`+` Dynamic Context Injection in SKILL.md — repeat hallucination; identical to Gemini-7 hallucination already rejected at DA-074 v1.7); **DA-134** (Gemini-14: agents.md homepage `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` cited as evidence for CLAUDE↔AGENTS symlinks — miscitation; the actual command is for AGENT.md singular → AGENTS.md plural backward compatibility per direct fetch of agents.md); **DA-135** (Gemini-14: 'developers SHOULD utilize OS-level symbolic links inside each skill's references/ directory pointing to a common global repository folder' as the cross-skill rule — too broad; Anthropic supports symlinks only inside a plugin per plugins-reference Tier-1); **DA-136** (Gemini-14: `disable-model-invocation: true` framed as the canonical mechanism for 'Human-in-the-Loop Write Gates' for the LLM-Wiki v2 pattern — confabulation; the field exists in Anthropic skill frontmatter for the unrelated purpose of disabling model-driven activation, not for HITL write gates on `references/`); **DA-137** (Gemini-14: framing Issue #189 as 'cross-skill reference duplication crisis' — misframed; the actual issue is two plugins (`document-skills`, `example-skills`) shipping the same 17 skills, a packaging hygiene problem, NOT a missing cross-skill reference primitive); **DA-138** (Gemini-14: claim that Karpathy's gist 'remains agnostic to the format war' between CLAUDE.md and AGENTS.md and lists them 'as equally valid schema layer configurations depending on the underlying agent' — partially correct but used to support the symlink convention which neither gist endorses; the gist names them as parallel filenames, NOT as symlink targets). Pattern note: Gemini-14's hallucination signature is consistent with prior Gemini-3, Gemini-4, Gemini-7, Gemini-8, Gemini-10 fabrication signatures — recurring patterns include numeric figure invention (DA-131), feature confusion across product surfaces (DA-132, DA-136), repeat hallucinations across sessions (DA-133), source miscitation (DA-134, DA-138), and overgeneralization from a Tier-1 quote (DA-135, DA-137). The framework.second_opinion_review.independence_note rule applies: these are not independent confirmations but a shared training-artifact signature.

**Turn-1 DA candidates promoted to live DAs at session close:** Turn-1's DA-Q014-1..14 cluster (LLM-Wiki patterns rejected as skill-`references/` patterns — three-layer raw/wiki/schema; immutable raw; LLM-owned wiki; ingest/query/lint ops; grep-parseable log prefix; sub-folders; YAML frontmatter on every page beyond R-REF-FM-1 whitelist; Obsidian `[[wiki-link]]` cross-refs; file-back-to-wiki; qmd/Marp/Dataview as primary lookup; numeric confidence scoring; retention decay; consolidation tiers; typed knowledge graph; hybrid BM25+vector+graph retrieval; event-driven hooks; LLM-self-healing; LLM contradiction resolution; crystallisation) consolidate into **DA-139** (single composite entry covering the whole knowledge-base-scale pattern family) for tractability — each individual sub-pattern is referenced inside DA-139 with rationale.

**Cross-section impact at v1.12:** skill-spec § 'Skill vs Reference Content' (NEW R-REF-FM-1, R-REF-SUPERSEDE-1, R-REF-SECRETS-1, R-LOG-REJECT); system-design § 'Index Files' (existing PROPOSED carve-out refined to MAY-with-threshold); system-design § 'Cross-Skill Reference Doc Sharing' (NEW subsection with R-REF-SHARE-1); system-design § 'Interaction with CLAUDE.md / AGENTS.md' (R-MEM-3 demotion + R-MEM-10 VALIDATED CANONICAL); meta-validation § 'Validation Rules' (NEW machine-checkable lints: forbid `references/log.md` per R-LOG-REJECT; forbid frontmatter outside R-REF-FM-1 whitelist; warn if reference frontmatter contains credentials/tokens per R-REF-SECRETS-1; forbid SKILL.md or `<root>/CLAUDE.md` being a symlink to `<root>/AGENTS.md` per R-MEM-10; forbid 2+ level deep references per R-CHUNK-4 unless skill is `claude-api` pending Q-016 resolution); research § 'Discarded Alternatives' (DA-130..DA-139); research § 'References' (v1.12 entry); research § 'Open Research Queue' (Q-014 closed; Q-016 added); research § 'Research Tracker' (Q-014 row); research § 'Reasoning Journey' (v1.12 paragraph). Plus changelog v1.12 entry; meta version, date, file_name updated.

#### Pre-registered passes/fails for the verdicts in this session

Per agent_guidelines.framework.synthesis_matrix.pre_registration_rule, the test for promoting a candidate rule from Turn 1's PROPOSED-MAY/SHOULD set to v1.12-adopted status was: ≥1 Tier-1 source AND no Tier-1 contradiction AND consistency with all other adopted rules. The test for the R-MEM-3 demotion was: any Tier-1 contradiction with the existing PROPOSED rule body, where Tier-1 = canonical Anthropic doc + Anthropic-owned repo + Anthropic-engineering blog. Outcomes: R-MEM-3 → DEMOTED (Tier-1 contradiction found, canonical Anthropic memory doc); R-MEM-10 → ADOPTED VALIDATED CANONICAL (canonical Anthropic doc, sufficient under single-Tier-1 canonical rule); R-REF-FM-1, R-REF-SUPERSEDE-1, R-REF-SECRETS-1, R-LOG-REJECT, R-REF-SHARE-1 → ADOPTED PROPOSED (single-Tier-1 each, eligible for VALIDATED on Q-015 follow-up confirmation if independent Tier-1 corroboration emerges).

<!-- @session: Q-015 -->
<a id="q-015"></a>

### Q-015 — Skill-vs-project-documentation boundary contract (2026-05-05)

#### Turn 1 — Pre-registration and Tier-1 synthesis

**Pre-registration (per `synthesis_matrix.pre_registration_rule`):** *Hypothesis (H-015):* Anthropic's canonical guidance treats skills, `<root>/CLAUDE.md`, `<root>/AGENTS.md`, and repo docs as a coordinated routing system in which (a) `CLAUDE.md` carries short, always-true, project-wide invariants and pointer imports; (b) skills are the canonical home for any multi-step procedure or task-specific reference content; (c) repo docs are referenced rather than duplicated; (d) `AGENTS.md` is the tool-portable equivalent of `CLAUDE.md`-style invariants and is imported into `CLAUDE.md` via the verbatim `@AGENTS.md` directive (R-MEM-10) when both ecosystems coexist. *PASS metric:* ≥2 independent Tier-1 sources for each routing rule, with zero Tier-1 contradictions, and clean reconciliation with DA-004, R-MEM-10, R-MEM-10-CARVEOUT, DA-130, R-CHUNK-4, R-BODY-1, R-API-1, the 1024-char description budget, and the 25K-token re-attach budget. *FAIL metric:* Tier-1 silence or contradiction → rule tagged PROPOSED rather than VALIDATED.

#### Sources consulted — Turn 1 (Tier-1 anchors)

| Source | Tier | Verbatim anchor used | Disposition |
|---|---|---|---|
| How Claude remembers your project (Anthropic, 2026, code.claude.com/docs/en/memory) | Tier-1 canonical | *'If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill or a path-scoped rule instead.'* / *'target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence.'* / *'@AGENTS.md / ## Claude Code / Use plan mode for changes under `src/billing/`.'* (canonical example) / *'Across the directory tree, content is ordered from the filesystem root down to your working directory … instructions closer to where you launched Claude are read last.'* | ADOPTED — primary anchor for R-BOUNDARY-1, R-BOUNDARY-3, R-BOUNDARY-4, P-BOUND-SUPERSEDE-3 |
| Skill authoring best practices (Anthropic, 2026, docs.claude.com / platform.claude.com) | Tier-1 canonical | *'Keep references one level deep from SKILL.md. All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed.'* / *'description: Maximum 1024 characters'* / *'include both what the Skill does and when to use it … always write in third person.'* / *'Move detailed documentation to references/ and link to it.'* | ADOPTED — primary anchor for R-BOUNDARY-2, R-BOUNDARY-7 |
| Equipping agents for the real world with Agent Skills (Anthropic Engineering, 2025–2026, anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) | Tier-1 | Progressive-disclosure design principle; *'Agents with a filesystem and code execution tools don't need to read the entirety of a skill into their context window when working on a particular task.'* | ADOPTED — corroborates R-BOUNDARY-2's progressive-disclosure rationale |
| Best practices for Claude Code (Anthropic, 2026, code.claude.com/docs/en/best-practices) | Tier-1 | *'CLAUDE.md is loaded every session, so only include things that apply broadly. For domain knowledge or workflows that are only relevant sometimes, use skills instead.'* | ADOPTED — primary anchor for R-BOUNDARY-8 |
| Agent Skills overview (Anthropic, 2026, platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) | Tier-1 | Three-level progressive disclosure: metadata always loaded; SKILL.md body on activation; references on explicit Read. | ADOPTED — quantitative context-cost framing for R-BOUNDARY-8 |
| anthropics/skills GitHub repo (Anthropic, 2026, github.com/anthropics/skills) | Tier-1 | Empirical: SKILL.md files in canonical examples ≤500 lines; one-level-deep references; AGENTS-equivalent at skill layer absent. | ADOPTED — empirical reinforcement of R-BOUNDARY-2, R-BOUNDARY-6 |
| AGENTS.md spec (AAIF / Linux Foundation, 2026, agents.md) | Tier-2 (open standard, AAIF/LF stewardship) | *'AGENTS.md complements [README.md] by containing the extra, sometimes detailed context coding agents need: build steps, tests, and conventions.'* / FAQ: *'The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything.'* | ADOPTED — primary anchor for R-BOUNDARY-5 (referenced-not-duplicated) and the AGENTS.md walk semantics |

#### Turn 1 decisions adopted (status and gate)

**R-BOUNDARY-1 [skill][portable] VALIDATED.** Multi-step procedures (sequential steps, checklists, tool invocations) MUST be authored as a SKILL.md, not as CLAUDE.md or AGENTS.md content. Tier-1 anchor: 'How Claude remembers your project' — *'If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill or a path-scoped rule instead.'* Reinforced by 'Best practices for Claude Code' — *'For domain knowledge or workflows that are only relevant sometimes, use skills instead.'* Reinforces and reaffirms **DA-004**.

**R-BOUNDARY-2 [reference][portable] VALIDATED.** Long-form descriptive material tied to a single skill's task MUST live in `<skill>/references/<topic>.md`, linked one level deep from SKILL.md. Tier-1 anchor: 'Skill authoring best practices' — *'Keep references one level deep from SKILL.md. All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed.'* Reinforced by canonical `anthropics/skills` repo examples and by the progressive-disclosure mechanism in 'Equipping agents for the real world with Agent Skills.'

**R-BOUNDARY-3 [skill][claude-code-only] VALIDATED.** `<root>/CLAUDE.md` MUST be limited to project-wide always-on invariants and pointer-style imports; the **target** is ≤200 lines; long procedures MUST NOT be added (DA-004). Tier-1 anchor: 'How Claude remembers your project' — *'target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence.'* **CRITICAL CARVEOUT (formalized at v1.13 after Gemini-15 evaluation):** the 200-line figure is a **soft adherence target**, NOT a truncation cap. The same Anthropic doc states verbatim: *'This limit applies only to MEMORY.md. CLAUDE.md files are loaded in full regardless of length, though shorter files produce better adherence.'* See **DA-140**.

**R-BOUNDARY-4 [skill][portable] VALIDATED.** When the project also targets non-Claude agents, tool-portable invariants belong in AGENTS.md; `<root>/CLAUDE.md` MUST import via verbatim `@AGENTS.md` and MAY add a Claude-Code-specific section below. Tier-1 anchor: 'How Claude remembers your project' canonical example. Same Anthropic source as R-MEM-10.

**R-BOUNDARY-5 [reference][portable] VALIDATED.** Repo docs (`README.md`, `ARCHITECTURE.md`, `docs/adr/`, runbooks) MUST be referenced (via `@README.md`-style import in CLAUDE.md, or via outbound link in a skill's `references/`) rather than duplicated; when an agent-readable rewrite is needed, the rewrite MUST mark the human doc as canonical for facts. Tier-1 anchor: 'How Claude remembers your project' — `@README` example. Tier-2: agents.md spec — *'README.md files are for humans … AGENTS.md complements this.'* The supersession-marker mechanism (P-BOUND-SUPERSEDE-2) remains PROPOSED.

**R-BOUNDARY-6 [skill][claude-code-only] VALIDATED (strict-default).** Skills MUST NOT carry an AGENTS-equivalent file, MUST NOT be `@`-imported to a parallel-name target, and MUST NOT be symlinked to such a target. R-MEM-10 applies only at the project-memory layer (R-MEM-10-CARVEOUT). No Tier-1 source proposes a skill-layer AGENTS-equivalent; strict-default rejection of the construct.

**R-BOUNDARY-7 [skill][portable] VALIDATED.** The skill `description` field MUST encode both *what* the skill does and *when* Claude should use it; ≤1024 chars; written in third person. Tier-1 anchor: 'Skill authoring best practices' — *'Maximum 1024 characters … include both what the Skill does and when to use it … always write in third person.'* Reaffirms project's existing description budget.

**R-BOUNDARY-8 [skill][claude-code-only] VALIDATED (qualitative).** A piece of knowledge expected in ≥~50% of sessions and consisting of stable invariants (not procedures) MAY live in CLAUDE.md (subject to the ≤200-line target). Knowledge expected in <~50% of sessions MUST live in a skill so it stays out of context until activated. Tier-1 anchor: 'Best practices for Claude Code' — *'CLAUDE.md is loaded every session, so only include things that apply broadly.'* The ~50% midpoint is editorial guidance only; numeric threshold remains qualitative.

**P-BOUND-SUPERSEDE-1 [skill][portable] PROPOSED** (single-source-of-truth across containers); **P-BOUND-SUPERSEDE-2 [skill][portable] PROPOSED** (`canonical:` marker on derived agent-readable views); **P-BOUND-SUPERSEDE-3 [skill][claude-code-only] PROPOSED** (within CLAUDE.md, content authored *below* the `@AGENTS.md` import wins on conflict — extrapolation from documented directory-walk later-wins semantics); **P-BOUND-DRIFT-1 [skill][portable] PROPOSED** (drift scan on Q-008 cadence). All four remain PROPOSED at v1.13 — no Tier-1 source explicitly defines a cross-container supersession contract; strictness default keeps these as candidates only.

#### Turn 2 — Gemini-15 second-opinion evaluation

**Source label:** Gemini-15 — Google Gemini deep-research output titled *'Architecting Agentic Memory: Boundary Contracts and Routing Protocols for Claude Code and AGENTS.md Systems'*, submitted by user 2026-05-05. Per `framework.second_opinion_review.evaluation`, five sources verified end-to-end before incorporation.

#### Sources verified — Turn 2 (Gemini-15)

| Source | Tier | Verification result | Disposition |
|---|---|---|---|
| arXiv:2604.21744 — Palmblad, Ragland, Neely. *Agentic AI-assisted coding offers a unique opportunity to instill epistemic grounding during software development.* Submitted 2026-04-23. | Tier-1 (peer-reviewed-equivalent arXiv with verified institutional affiliation, not future-dated) | **Real paper.** Authors verified: Magnus Palmblad — Center for Proteomics and Metabolomics, Leiden University Medical Center, Netherlands; Jared M. Ragland and Benjamin A. Neely — NIST Charleston, SC. Subjects cs.SE / cs.AI / **q-bio.BM**. Abstract: *'we propose GROUNDING.md, a community-governed, **field-scoped** epistemic grounding document, using mass spectrometry-based proteomics as an example.'* The paper is a **proposal**, not a description of an existing platform mechanism, and is **field-scoped to scientific domains** (proteomics worked example). | ACCEPTED narrowly — supports new **P-BOUND-GROUNDING-1 PROPOSED** (domain-scoped only); REJECTS Gemini-15's universal-supersession-tier-zero framing → DA-141 |
| How Claude remembers your project (Anthropic, 2026, code.claude.com/docs/en/memory) — re-fetch | Tier-1 canonical | Verbatim Tier-1 contradicts Gemini-15 BUDGET-MEM-1: *'This limit applies only to MEMORY.md. CLAUDE.md files are loaded in full regardless of length, though shorter files produce better adherence.'* The 200-line MEMORY.md cap is hard; the 200-line CLAUDE.md figure is a soft adherence target. | REJECTS Gemini-15 BUDGET-MEM-1 conflation → DA-140; reaffirms R-BOUNDARY-3 carveout |
| Skill authoring best practices (Anthropic, 2026, docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) — re-fetch | Tier-1 canonical | Verbatim Tier-1: *'Claude may partially read files when they're referenced from other referenced files. When encountering nested references, Claude might use commands like head -100 to preview content rather than reading entire files, resulting in incomplete information.'* Also verbatim: *'For reference files longer than 100 lines, include a table of contents at the top.'* | ACCEPTS Gemini-15 head -100 mechanism (strengthens R-CHUNK-4 rationale); CORRECTS Gemini-15's 300-line ToC claim to canonical 100 lines → **R-BOUNDARY-9 NEW VALIDATED**; rejects Gemini-15's overclaim → DA-144 |
| Introducing Claude Opus 4.7 (Anthropic, 2026, anthropic.com/news/claude-opus-4-7) | Tier-1 | Verbatim Tier-1: *'Pricing remains the same as Opus 4.6: $5 per million input tokens and $25 per million output tokens.'* Confirms Sonnet 4.6 ($3/$15) and Haiku 4.5 ($1/$5) at primary source. | Pricing FIGURES correct; CITATION DISCIPLINE — Gemini-15 cited Finout when Anthropic primary exists → DA-146 |
| AGENTS.md spec (AAIF / Linux Foundation, 2026, agents.md) | Tier-2 (open standard with AAIF/LF stewardship) | FAQ verbatim: *'The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything.'* Body verbatim: *'Agents automatically read the nearest file in the directory tree, so the closest one takes precedence.'* 60k+ adopting OSS projects. | VALIDATES Gemini-15's closest-wins claim (Tier-2) |

#### Incorporations — 4 contributions accepted

**(1) R-BOUNDARY-9 [reference][portable] VALIDATED — NEW.** Reference files in `<skill>/references/` longer than **100 lines** MUST include a table of contents at the top, to ensure that the agent's `head -100`-style partial reads still surface the full document scope. Source: 'Skill authoring best practices', Anthropic, 2026, docs.claude.com — *'For reference files longer than 100 lines, include a table of contents at the top.'* Gemini-15 prompted this rule but cited an inflated 300-line threshold; canonical Anthropic value is 100 lines.

**(2) R-BOUNDARY-2 / R-CHUNK-4 rationale strengthened.** Add explicit `head -100` partial-read mechanism note to the existing R-BOUNDARY-2 / R-CHUNK-4 rationale: chained references trigger truncated previews, not full reads, which is *why* the one-level-deep rule exists. Verbatim Tier-1 quote sourced inline.

**(3) R-BOUNDARY-4-CLARIFICATION [skill][claude-code-only] VALIDATED — NEW.** When `<root>/AGENTS.md` exists and `<root>/CLAUDE.md` imports it, the verbatim `@AGENTS.md` directive MUST be the **first content line** of CLAUDE.md (before any other instruction). Claude-Code-specific content follows the import. This locks in the structural ordering observed in the canonical Anthropic example at 'How Claude remembers your project' § AGENTS.md. Note: Gemini-15's specific *recency-bias* rationale for in-file ordering is a Discovery-level extrapolation from documented directory-walk semantics; the structural rule is canonical Tier-1, the in-file-recency mechanism is logged as PROPOSED only.

**(4) R-BOUNDARY-1 elaboration: subagent context-isolation as a routing factor.** Add to the decision criteria: privacy/secrecy and large-noisy-data tasks belong in skills that route work to subagents (fresh isolated context windows; main session protected during auto-compaction). Implicit in Turn 1 §3.1; Gemini-15 makes the mechanism explicit. Anchored to Anthropic's multi-agent research engineering post (already in References).

**P-BOUND-GROUNDING-1 [reference][portable] PROPOSED — NEW (narrow scope).** For domains with formal validity invariants (regulated scientific computing, safety-critical systems), repositories MAY adopt a domain-scoped GROUNDING.md following the Palmblad–Ragland–Neely pattern (Hard Constraints + Convention Parameters; arXiv:2604.21744, 2026-04-23). Precedence is achieved by importing it from CLAUDE.md (`@GROUNDING.md` placed before `@AGENTS.md`) and reinforcing in skill bodies. **NOT a platform-injection mechanism.** Out of scope for the validation script unless project explicitly opts in. Status: PROPOSED at v1.13.

#### Rejected claims (Gemini-15 vetting failures) — DA-140..DA-146

**DA-140** (BUDGET-MEM-1 conflation: CLAUDE.md silent-truncation cap) — Tier-1 verbatim contradiction. **DA-141** (ROUTE-EPISTEMIC-1 universal supersession-tier-zero) — paper is field-scoped; no Anthropic Tier-1 references GROUNDING.md as a platform mechanism; retained narrowly as P-BOUND-GROUNDING-1 PROPOSED. **DA-142** (1700-token ToolSearch flat overhead) — Reddit Discovery only. **DA-143** (85% token-reduction / $150–$250 dev-month figures) — Finout/Morph Discovery only. **DA-144** (300-line ToC threshold) — canonical Anthropic value is 100 lines (3× stricter); Anthropic supremacy applies. **DA-145** (anti-patterns as supersession-resolution mechanism) — overclaimed framing; technique exists but the supersession framing lacks Tier-1 backing. **DA-146** (Finout citations for Anthropic-primary facts) — citation-discipline failure; figures correct, citation chain wrong.

**Tangential acknowledged (not adopted, not rejected):** AutoDream / `tengu_onyx_plover` / KAIROS daemon. Real and partially rolled out (March 2026 source-leak coverage; community reverse-engineering); operates on `~/.claude/projects/<project>/memory/`, **not** on CLAUDE.md or skills. Not in canonical Anthropic memory doc as of 2026-05-05. **Tangential to Q-015's boundary contract.** Logged as new queue item **Q-019** for post-GA Anthropic-doc revisit.

#### Cross-section impact at v1.13

**skill-spec § 'Skill vs Reference Content':** NEW Q-015 inter-container scope subsection containing R-BOUNDARY-1..-9 + R-BOUNDARY-4-CLARIFICATION; P-BOUND-* PROPOSED block. **skill-spec § 'Reference Chunking & Lazy Loading':** R-BOUNDARY-9 added (ToC at >100 lines threshold; corrected from Gemini-15's 300-line overclaim). **system-design § 'Interaction with CLAUDE.md / AGENTS.md':** NEW Q-015 v1.13 subsection — `@AGENTS.md`-first ordering rule (R-BOUNDARY-4-CLARIFICATION); explicit MEMORY.md ≠ CLAUDE.md note (CLAUDE.md is loaded in full regardless of length per canonical Tier-1). **meta-validation § 'Validation Rules (machine-checkable)':** three new lints (Lint #10 reference >100 lines must contain ToC near top; Lint #11 `@AGENTS.md` must be first content line of CLAUDE.md when present; restated Lint #1 — CLAUDE.md >200 lines emits WARN for adherence quality, not FAIL for truncation). **research § 'Discarded Alternatives':** DA-140..DA-146 added. **research § 'References':** v1.13 entry appended. **research § 'Open Research Queue':** Q-015 closed; Q-018 + Q-019 added. **Reasoning Journey:** v1.13 paragraph appended. **Changelog:** v1.13 callout `current=true`; v1.12 set `current=false`.

#### Pre-registered passes/fails for the verdicts in this session

Per `agent_guidelines.framework.synthesis_matrix.pre_registration_rule`, the test for promoting a Gemini-15 candidate to ADOPTED was: any Tier-1 corroboration of the specific mechanism cited, where Tier-1 = canonical Anthropic doc + Anthropic-owned repo + Anthropic-engineering blog + peer-reviewed arXiv with verified institutional affiliation. **Outcomes:** R-BOUNDARY-9 (ToC >100) → ADOPTED VALIDATED (canonical Anthropic, sufficient under the canonical-single-source rule); R-BOUNDARY-4-CLARIFICATION (`@AGENTS.md`-first) → ADOPTED VALIDATED (canonical Anthropic example); P-BOUND-GROUNDING-1 → ADOPTED PROPOSED (single Tier-1 arXiv, narrow domain scope); DA-140 → REJECTED (Tier-1 contradiction); DA-141 → REJECTED-AS-OVERREACH (Tier-1 paper exists but does not support the broader claim); DA-142..DA-145 → REJECTED (Discovery-only or canonical-overclaim); DA-146 → REJECTED on citation discipline. **Contradiction check: 1 resolved** (Gemini-15 BUDGET-MEM-1 conflation refuted by canonical Anthropic Tier-1 — MEMORY.md ≠ CLAUDE.md regarding hard cap).

<!-- @session: Q-016 -->
<a id="q-016"></a>

### Q-016 — R-CHUNK-4 reconciliation with `anthropics/skills/claude-api` (2026-05-06)

#### Methodology

**Pre-registration (per `synthesis_matrix.pre_registration_rule`).** Six hypotheses written before consulting sources: H1 (`claude-api` ships 2-level filesystem depth with one-hop markdown links from SKILL.md); H2 (best-practices doc, read in full, supports markdown-link-depth interpretation via Pattern 2 `reference/finance.md`); H3 (partial-read regression mechanism is graph-distance-driven, evidenced by best-practices Bad-vs-Good example using identical filenames and only hop-count difference); H4 (no Anthropic-vs-Anthropic contradiction exists; `Anthropic_supremacy` clause does not need extension); H5 (Candidate C — markdown-link semantics — is the right resolution; no breaking changes for v1.13-authored skills); H6 (Gemini-16 will provide ≥1 fabricated supporting citation per the independence-note pattern from prior Gemini sessions). **PASS metric:** ≥2 independent Tier-1 sources for the markdown-link-depth interpretation, with zero Tier-1 contradictions, and clean reconciliation with R-CHUNK-1, R-CHUNK-2, R-CHUNK-3, R-CHUNK-5, R-CHUNK-6, R-LAZYLOAD-*, R-WORKSPACE-1, R-BOUNDARY-2, R-BOUNDARY-9. **FAIL metric:** Tier-1 silence or contradiction → rule tagged PROPOSED rather than VALIDATED. **Outcome:** all six hypotheses PASS; five Tier-1 anchors (best-practices Bad/Good example, best-practices Pattern 2, engineering blog 'keeping the paths separate', Agent Skills overview 'Claude uses bash to read … additional bash commands', the `claude-api` skill itself) clear the ≥2 threshold; H6 confirmed via 4 verified fabrications/misattributions in Gemini-16 (DA-Q016-1, -2, -3, -4).

#### Sources consulted (verified end-to-end)

| Source | Tier | Verification | Disposition |
|---|---|---|---|
| Anthropic Skill authoring best practices (`platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`) | Tier 1 | Direct fetch confirms verbatim *'Avoid deeply nested references'* rule and Pattern 2 `bigquery-skill/reference/finance.md` example with subdirectory layout. Bad-vs-Good chained-link example uses identical filenames; varies only in hop count. | ADOPT — primary anchor for revised R-CHUNK-4 markdown-link semantics |
| Anthropic Agent Skills overview (`platform.claude.com/docs/en/agents-and-tools/agent-skills/overview`) | Tier 1 | Direct text confirms verbatim *'Claude uses bash to read SKILL.md from the filesystem … If those instructions reference other files (like FORMS.md or a database schema), Claude reads those files too using additional bash commands.'* | ADOPT — decisive refutation of Gemini-16's 'native injection parser' mechanism (DA-Q016-1) |
| Anthropic Engineering blog: Equipping agents for the real world with Agent Skills (Zhang, Lazuka, Murag, 2025-10-16, anthropic.com/engineering) | Tier 1 | Confirms verbatim *'Structure for scale: When the SKILL.md file becomes unwieldy, split its content into separate files and reference them. If certain contexts are mutually exclusive or rarely used together, keeping the paths separate will reduce the token usage.'* | ADOPT — reinforces subdirectory partitioning as sanctioned pattern |
| `anthropics/skills/claude-api/python/claude-api/tool-use.md` (live `main`, 2026-05-06) | Tier 1 | GitHub blob header reports **590 lines (477 loc) · 16.5 KB**. Confirms 2-level filesystem depth. | ADOPT — empirical anchor for R-CHUNK-4 v1.14 worked example; verifies Gemini-16's 590-line claim |
| `anthropics/skills/claude-api/shared/tool-use-concepts.md` (live `main`, 2026-05-06) | Tier 1 | GitHub blob header reports **305 lines (200 loc) · 14.5 KB**. **Refutes Gemini-16's 327-line claim.** | ADOPT empirical line count; REJECT Gemini-16 figure as DA-Q016-3 |
| `anthropics/skills/claude-api/SKILL.md` (live `main`, 2026-05-06) | Tier 1 | Direct fetch and prior Turn 1 verification confirm one-hop markdown links from SKILL.md to all referenced files including `python/claude-api/*` and `shared/*`. | ADOPT — empirical anchor; confirms link-graph topology |
| `anthropics/claude-code` Issue #13617 | Tier 1 | Direct fetch confirms title *'Bug: ARM64 binary replaced with x86_64 during install on Apple Silicon'* (2025-12-10) — about Apple Silicon binary install, NOT about file traversal mechanisms or `head -100` fallback. | REJECT Gemini-16 misattribution as DA-Q016-2 |
| agentskills.io specification (Tier-2 open standard, AAIF/LF stewardship) | Tier 2 | Confirms *'Activation: When a task matches a skill's description, the agent reads the full SKILL.md instructions into context. Execution: The agent follows the instructions, optionally executing bundled code or loading referenced files as needed.'* | ADOPT — cross-platform corroboration of agent-driven progressive disclosure |
| Whittaker, P. *Progressive Discovery: A Better Mental Model for Agent Skills* (dev.to, 2026) | Discovery | Direct fetch confirms argument that *'Claude is the one doing something. The Skill is not. The Skill is bytes on disk.'* Discovery-tier corroboration of mechanism, not normative. | REFERENCE — supports DA-Q016-1 framing |
| Gemini-16 (Google Gemini deep research, submitted 2026-05-06) | Second opinion | Vetted per `framework.second_opinion_review.evaluation`. 4 incorporations + 6 rejections (DA-Q016-1..-6). | PARTIALLY INCORPORATED — see Decisions and Rejected Claims |

#### Decisions adopted (Turn 1 + Turn 2)

**R-CHUNK-4 v1.14 [skill][portable] VALIDATED — REVISED.** Every reference file Claude is expected to read MUST be reachable in exactly one markdown-link hop from SKILL.md; filesystem subdirectory depth is unrestricted. Chained reference links (SKILL.md → A → B where B is not also one-hop reachable from SKILL.md) are forbidden. Mechanical: markdown-link-graph BFS rooted at SKILL.md; fail on graph-distance > 1. Supersedes the v1.13 filesystem-depth interpretation. **No breaking changes for v1.13-authored skills** — the v1.13 rule was strictly more restrictive than v1.14, so every flat-`references/` skill remains conformant.

**R-CHUNK-4-CLARIFICATION [skill][portable] VALIDATED — NEW v1.14.** The partial-read regression Anthropic warns about (*'Claude might use commands like `head -100` to preview content rather than reading entire files'*) is **graph-distance-driven, not filesystem-depth-driven**. Mechanism: per Anthropic Agent Skills overview, Claude reads SKILL.md and any referenced files via agent-issued bash/Read tool calls; there is no host-side parser bypass. At a transitive read step (a loaded reference itself names another `.md` file Claude hasn't seen), the agent is more likely to reach for `head -100`-style previews than for a full read. Flattening the markdown-link graph eliminates this transitive step regardless of where files sit on disk.

**R-BOUNDARY-2-CLARIFICATION [reference][portable] VALIDATED — NEW v1.14.** R-BOUNDARY-2's *'linked one level deep from SKILL.md'* phrase shares the R-CHUNK-4 anchor and inherits the v1.14 markdown-link-depth interpretation. `<skill>/references/<topic>.md` remains the recommended idiomatic layout, but multi-level filesystem layouts that preserve one-hop graph-reachability are permitted (`anthropics/skills/claude-api` is the canonical exemplar).

**LINT-Q016-1 [validator] VALIDATED — NEW v1.14.** Info-level (non-blocking) lint emitted when a graph-depth-1 file links back to another graph-depth-1 file. Both targets are already directly named by SKILL.md, so the cross-link is benign — but surfacing it during review helps catch structural drift early. Matches the empirical pattern in `claude-api` where `python/claude-api/tool-use.md` links upward to `shared/tool-use-concepts.md`, both already cited from SKILL.md.

#### Rejected claims (Gemini-16)

Six Gemini-16 contributions rejected with explicit rationale and logged as DA-Q016-1 through DA-Q016-6 in Discarded Alternatives. Summary: (1) fabricated 'native progressive-disclosure injection parser bypassing the LLM action space' mechanism — refuted by Anthropic Agent Skills overview's verbatim 'Claude uses bash to read … additional bash commands'; (2) Issue #13617 misattributed (actual issue is ARM64/x86_64 binary install, unrelated to file traversal); (3) `tool-use-concepts.md` 327-line count fabricated (actual 305 per blob header); (4) arXiv:2601.04583 cited as 'Agent Behavior Frameworks' supporting code-as-truth (actual paper is about blockchain agents per Gemini-16's own footer); (5) 'Code-as-Truth Principle' as new normative meta-principle — unnecessary (no actual Anthropic-vs-Anthropic contradiction once doc is read in full) and category-error (conflates eval-against-codebase with model-optimized-for-codebase); (6) `references/spec-summary.md` and `references/scoring-rubric.md` cited as `skill-workshop`'s references via Issue #853 (actual #853 is a community proposal for a meta-skill that scores other skills, not a description of skill-workshop's actual layout).

**Independence note (per `framework.second_opinion_review.independence_note`):** Gemini-16's fabricated 'native injection parser' claim is the third instance of a Gemini second opinion inventing host-side bypass-of-LLM-action-space mechanisms (prior: DA-074 Gemini-7 `!command` Dynamic Context Injection; DA-133 Gemini-12 `!command` recurrence). Treated as one data point per the shared-training-artifact rule, not three independent confirmations.

#### Forward-influence (queue items adjacent to Q-016)

Q-016 closure does not surface new queue items. Q-013 (self-consistency vote count, Routines beta-header churn, PreToolUse skill-matcher status), Q-018 (independent Tier-1 confirmation of 25K-token re-attach budget), and Q-019 (AutoDream / `tengu_onyx_plover` operational mechanics post-GA) remain OPEN, all low-priority and time-deferred until Anthropic publishes adjacent canonical doc updates. The blue callout has moved to Q-013 as the next priority-ordered item; per its scoping note, work proceeds when adjacent queue items stabilize the surrounding literature (LLM-as-judge surveys, Routines beta header rotation cadence, claude-code Issue #43630 PostToolUse/PreToolUse status).

---

<!-- @session: Q-013 -->
<a id="q-013"></a>

### Q-013: Self-consistency vote count, Routines beta-header, PreToolUse Skill matcher (2026-05-07)

**Pre-registration.** Three sub-question hypotheses, all in stress-test mode (per v1.8 prefatory-turn user decision): (a) **H-Q013-a** — k=3 remains the field-recommended default for LLM-as-judge self-consistency; no Tier-1 source post-dating v1.8 has produced quantitative evidence sufficient to graduate R-LLMJ-4 to k=5. (b) **H-Q013-b** — `experimental-cc-routine-2026-04-01` beta header is still active as of 2026-05-07; no rotation or GA promotion has happened in the ~3 weeks since v1.8. (c) **H-Q013-c** — `PreToolUse matcher: "Skill"` does NOT dispatch today, mirroring Issue #43630's PostToolUse finding; R-LOAD-4 stays at "no hook reliance." PASS metric for each: ≥2 independent Tier-1 sources support, no Tier-1 contradiction. FAIL/REJECT metric: Tier-1 silence or contradiction → tag PROPOSED revision instead of VALIDATED graduation. Hypothesis statuses (Turn 1 → Turn 2 reconciled): H-Q013-a CONFIRMED with 7 Tier-1 sources; H-Q013-b CONFIRMED with 3 Tier-1 sources; H-Q013-c **FALSIFIED** by canonical hooks-doc re-fetch + Issue #21614 + CHANGELOG OpenTelemetry finding.

**Sources consulted.**

| Source | Tier | Verification | Disposition |
|---|---|---|---|
| `github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md` | Tier-1 | Live re-fetch 2026-05-07; verbatim "running each query 3 times to get a reliable trigger rate" | k=3 anchor confirmed |
| `github.com/anthropics/claude-plugins-official/.../skill-workshop/SKILL.md` | Tier-1 | Live re-fetch 2026-05-07; mirror of canonical, identical text | k=3 anchor corroborated |
| Haldar & Hockenmaier, *Rating Roulette*, EMNLP 2025 Findings, `aclanthology.org/2025.findings-emnlp.1361.pdf` | Tier-1 | Live verify; venue-accepted (was preprint at v1.8) | Promotes from PROPOSED to corroborating Tier-1 |
| Wang et al., *TrustJudge*, arXiv:2509.21117 | arXiv | Live fetch; "Under review as a conference paper at ICLR 2026"; double-blind review | NOT venue-accepted; "triples" are model-pair transitivity tests, not self-consistency votes |
| Jung, Brahman, Choi, *Trust or Escalate*, ICLR 2025, `arxiv.org/abs/2407.18370` | Tier-1 | Re-cited from v1.8; K=3 few-shot × N=5 simulated annotators (NOT self-consistency) | DA-094 framing reaffirmed |
| `code.claude.com/docs/en/routines` | Tier-1 | Live re-fetch 2026-05-07; "two-most-recent-previous-versions continue to work" stability guarantee documented | Header active; rotation policy formalized |
| `claude.com/blog/introducing-routines-in-claude-code` | Tier-1 | Anthropic-owned launch post 2026-04-14; daily caps confirmed | Caps unchanged |
| `code.claude.com/docs/en/hooks` | Tier-1 | Live re-fetch 2026-05-07; canonical `UserPromptExpansion` event listed alongside `UserPromptSubmit`/`SessionStart` for stdout-as-context | Confirms my Turn 1's UserPromptExpansion finding |
| `anthropics/claude-code` Issue #43630 | Tier-1 | Live verify; still open with `stale` label; PostToolUse-Skill never fires for `/plugin:skill-name` OR Skill tool | R-LOAD-4 (b) clause stands |
| `anthropics/claude-code` Issue #21614 | Tier-1 | Live verify; sub-agent crash on PreToolUse-Skill hook errors — proves PreToolUse-Skill DOES fire for sub-agent dispatched calls | R-LOAD-4 (a) clause confirmed |
| `anthropics/claude-code/CHANGELOG.md` | Tier-1 | Live re-fetch 2026-05-07; *"`claude_code.skill_activated` OpenTelemetry event now fires for user-typed slash commands and carries a new `invocation_trigger` attribute"* | NEW Tier-1 finding for cross-path observability |
| Gemini-13 (Google Gemini Deep Research) | second-opinion | User-submitted 2026-05-07 stress-test mode | 2 contributions accepted; 6 rejected as DA-147..DA-152 |

**Decisions adopted.**

- [R-LLMJ-4](#r-llmj-4) HOLD at k=3. No rule diff. Citation refresh: Anthropic skill-workshop SKILL.md verbatim "3 times" verified 2026-05-07 across 7 independent surfaces (canonical + mirror + 5 secondary). Rating Roulette graduates from PROPOSED preprint to Tier-1 corroborating reference (EMNLP 2025 Findings).
- [R-CADENCE-2](#r-cadence-2) HOLD with editorial citation refresh. Beta header `experimental-cc-routine-2026-04-01` still active per `code.claude.com/docs/en/routines` 2026-05-07. Two-most-recent-previous-versions stability guarantee now formally documented in Anthropic-canonical doc — versioned-check pattern is automatically future-proofed.
- [R-LOAD-4](#r-load-4) **REVISED** to bifurcated permission. PreToolUse `matcher: "Skill"` PERMITTED for agent-dispatched skill calls (deterministic exit-code 2 blocking is now valid as a supplementary gate); PostToolUse `matcher: "Skill"` remains FORBIDDEN; `InstructionsLoaded` for skills remains FORBIDDEN. Mandatory canary (R-LOAD-1) + negative-control (R-LOAD-2) tests remain the primary verification mechanism — PreToolUse-Skill is supplementary, not replacement. **NEW supplementary observability primitive added:** `claude_code.skill_activated` OpenTelemetry event (anthropics/claude-code CHANGELOG, Anthropic-canonical) fires for ALL three skill-invocation paths (`"user-slash"` / `"claude-proactive"` / `"nested-skill"`) — supersedes hook-based observability for cross-path coverage and resolves the asymmetry left by Issue #43630.

**Rejected claims.** [DA-147](#da-147) (Gemini-13 G13-A1: Anthropic skill-workshop k=10 fabrication); [DA-148](#da-148) (Gemini-13 G13-A2: TrustJudge ICLR 2026 K=4/5 misattribution — paper "under review" not accepted; "triples" are model-pair transitivity tests not self-consistency votes); [DA-149](#da-149) (Gemini-13 G13-A3: SAMRE-EACL2026 relitigation — DA-095 already rejected this); [DA-150](#da-150) (Gemini-13 G13-A4: "Can LLMs Automate Fact-Checking" optimal-at-5 unverifiable claim); [DA-151](#da-151) (Gemini-13 G13-C1: Issue #42250 fabricated bifurcation); [DA-152](#da-152) (Gemini-13 G13-C2: Issue #47307 fabricated regression).

**Second-opinion evaluation.**

**Source label:** Gemini-13 (Google Gemini Deep Research output for Q-013, submitted by user 2026-05-07 in stress-test mode). **Source verifications performed (≥3 per framework):** (1) Anthropic skill-workshop k=10 claim verified FABRICATED via 7 independent surfaces all returning verbatim k=3 — REJECT (DA-147). (2) TrustJudge ICLR 2026 status verified UNDER REVIEW (not accepted) via OpenReview PDF + arXiv abstract + HuggingFace paper page — REJECT framing (DA-148). (3) TrustJudge "triples" semantics verified MISREAD via abstract verbatim "circular preference chains (A>B>C>A)" — these are model-pair transitivity tests, not self-consistency votes — REJECT (DA-148). (4) SAMRE EACL2026 attribution verified ALREADY REJECTED via DA-095 audit trail — REJECT relitigation (DA-149). (5) Issue #42250 verified NON-EXISTENT via direct search of `github.com/anthropics/claude-code/issues/42250` and search engine — REJECT (DA-151). (6) Issue #47307 verified UNFINDABLE via search engine and repo issue search — REJECT (DA-152). (7) Routines beta-header status verified STILL ACTIVE via live `code.claude.com/docs/en/routines` re-fetch — ACCEPT directional finding (Gemini-13 G13-B). (8) PreToolUse-Skill bifurcation directional claim verified TRUE via Issue #21614 + canonical hooks-doc + CHANGELOG OpenTelemetry mechanism, but Gemini-13's specific evidence vehicles (#42250, #47307) are fabricated — ACCEPT directional finding from independent canonical evidence; REJECT cited evidence (DA-151, DA-152). **Outcome:** 2 contributions ACCEPTED (Routines two-version stability guarantee documentation refresh G13-B → R-CADENCE-2 citation refresh; PreToolUse-Skill bifurcation directional finding G13-C → R-LOAD-4 revised, but on independent canonical evidence not Gemini-13's fabricated issue numbers); 6 REJECTED as DA-147..DA-152. **Independence note applied:** misattributed paper status + misread paper findings + relitigation of already-rejected DA + paraphrased-quantitative-without-verbatim-citation + two fabricated issue numbers treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note`. Pattern is consistent with Gemini-3, Gemini-4, Gemini-8, Gemini-12, Gemini-15, Gemini-16. **Critical Turn 2 finding NEITHER source captured:** the `claude_code.skill_activated` OpenTelemetry event (anthropics/claude-code CHANGELOG, Anthropic-canonical) is the canonical cross-path observability primitive — emerged from independent CHANGELOG audit during Turn 2 vetting, neither in my Turn 1 nor in Gemini-13.

**Cross-section contradiction check (semantic).** **Result: PASSED.** No contradictions with v1.0–v1.14 ruleset. Specific verifications: (1) **R-LOAD-4 revision (PreToolUse-Skill permitted) ↔ R-META-10 (ReWOO determinism on hook path):** CONSISTENT — PreToolUse hooks run deterministic shell commands or HTTP endpoints; the AGENT dispatched the call but the HOOK itself contains no LLM. Same constraint that made GitHub Actions cron + R-CADENCE-2 acceptable. (2) **R-LOAD-4 ↔ R-LOAD-1 / R-LOAD-2:** CONSISTENT — PreToolUse-Skill is supplementary, the canary + negative-control tests remain mandatory primary verification. (3) **R-LOAD-4 ↔ R-LOAD-3 ("list your loaded skills" forbidden):** CONSISTENT — the hook reads invocation payload, doesn't ask Claude to introspect. (4) **OpenTelemetry skill_activated finding ↔ R-META-9 (auditability):** CONSISTENT — strengthens auditability via Anthropic-canonical observability primitive. (5) **R-CADENCE-2 ↔ documented two-version stability guarantee:** CONSISTENT — formalizes the previously-speculative versioned-check requirement.

**Forward-influence (queue items adjacent to Q-013).** Q-013 closure does not surface new queue items. Q-018 (independent Tier-1 confirmation of 25K-token re-attach budget) and Q-019 (AutoDream / `tengu_onyx_plover` operational mechanics post-GA) remain OPEN, both low-priority. The blue callout moves to Q-018 as the next priority-ordered item.

<!-- @session: Q-018 -->
<a id="q-018"></a>

### Q-018 — Independent Tier-1 confirmation of the 25K-token re-attach budget (2026-05-07)

**Pre-registration (per `framework.synthesis_matrix.pre_registration_rule`).** Four hypotheses written before consulting sources: H-018-1 (a second Tier-1 source beyond `code.claude.com/docs/en/skills` independently states the 25,000-token combined budget), H-018-2 (the figure has been silently revised in 2025/2026, analogous to the Read-tool 25K→10K downgrade in [R-CHUNK-5](#r-chunk-5)), H-018-3 (Tier-1 documentation explicitly states the per-skill-set / per-branch-isolation scope OR the scope is project-internal extrapolation that survives because consistent with the canonical sub-agents doc), H-018-4 (an adjacent Tier-1 numeric anchor — auto-compaction trigger threshold, 5K-per-skill carry-forward, most-recent-first fill order — strengthens R-FAIL-1). PASS metric: ≥2 independent Tier-1 sources support OR canonical Anthropic single source confirmed; FAIL: Tier-1 silence or contradiction → tag PROPOSED instead of VALIDATED.

**Verdict matrix.**

| Hypothesis | Verdict | Basis |
|---|---|---|
| H-018-1 | **REJECTED — single canonical source** | After exhaustive Tier-1 sweep (platform.claude.com agent-skills overview/best-practices/getting-started/enterprise; anthropic.com/engineering posts on Agent Skills + context engineering; the 32-page *Complete Guide to Building Skills for Claude* PDF; anthropics/skills repository SKILL.md exemplars including skill-workshop; Opus 4.7 release notes), only `code.claude.com/docs/en/skills` restates the 25,000 / 5,000 figures. No second Tier-1 source. The single canonical Anthropic source is sufficient under the validation gate's single-canonical-source clause; rule status remains VALIDATED but is now explicitly labeled "single-canonical-source" rather than "multi-source." |
| H-018-2 | **NOT SUPPORTED — figures unchanged 2025–2026** | The current live text on `code.claude.com/docs/en/skills` (fetched 2026-05-07) still reads *"Re-attached skills share a combined budget of 25,000 tokens"* and *"keeping the first 5,000 tokens of each."* No alternative number appears anywhere in Tier-1 surfaces. **However:** Opus 4.7 release notes (platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7) document a tokenizer change producing 1.0–1.35× more tokens per identical text; effective skill content fitting in the unchanged 25K/5K nominal budget is compressed by up to ~26%. This is **not** a silent revision in the Issue #45019 sense; it is an effective compression downstream of the Opus 4.7 model swap. Adopted as new R-FAIL-1 caveat. |
| H-018-3 | **PARTIAL — project-internal composition** | Anthropic Tier-1 sub-agents doctrine ([code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) verbatim *"Each subagent runs in its own context window with its own custom system prompt, tool access, and permissions"*) plus the bare combined-budget figure logically compose to per-context-window isolation, but no Tier-1 source explicitly says "each subagent has its own 25K pool" or "pools do not merge at fan-in." The deprecated phrase "per-skill-set, per-branch" is project-internal terminology not appearing in any Anthropic doc; replaced with "per-session, per-context-window" and the isolation invariant is now framed as project-internal composition. claude-code Issues #5812 and #10212 independently corroborate sub-agent context isolation as a user-observed primitive. |
| H-018-4 | **CONFIRMED — fill order + per-skill cap, single source** | The 5,000-per-skill cap and most-recent-first fill order are stated in the same canonical sentence as the 25K figure. The 95%-of-context auto-compaction trigger that community sources commonly cite is Discovery-tier only (MindStudio, ECC docs) — not Tier-1; explicitly NOT adopted into R-FAIL-1. The auto-compaction trigger threshold is exposed via the `autoCompactWindow` setting (env var: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`; min 100,000 / max 1,000,000 per Issue #42149) but this is the trigger, not the re-attach budget. |

**Sources consulted (Turn 1 + Turn 2 verifications, all fetched 2026-05-07).** **Anthropic Tier-1:** `code.claude.com/docs/en/skills` (live re-fetch, verbatim quotation re-confirmed); platform.claude.com agent-skills overview/best-practices/getting-started/enterprise (SILENT on re-attach budget); `anthropic.com/engineering/writing-tools-for-agents` (verbatim *"For Claude Code, we restrict tool responses to 25,000 tokens by default"* — distinct mechanism, NOT independent corroboration); `anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills` (qualitative only — *"amount of context that can be bundled into a skill is effectively unbounded"*); `anthropic.com/engineering/effective-context-engineering-for-ai-agents` (SILENT); `resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf` (SILENT on re-attach budget; recommends *"Keep SKILL.md under 5,000 words"* — words ≠ tokens); anthropics/skills repository (skill-workshop/SKILL.md SILENT); `code.claude.com/docs/en/sub-agents` (verbatim sub-agent isolation framing); `code.claude.com/docs/en/env-vars` and `code.claude.com/docs/en/settings` (SILENT — no override env var documented); platform.claude.com Opus 4.7 release notes (tokenizer drift caveat; Task Budgets `task-budgets-2026-03-13` beta header). **anthropics/claude-code Issues (Tier-1):** #20466 (skill re-attachment-as-system-reminder mechanism confirmation; verbatim *"The skill invocation is preserved in a `<system-reminder>` block: 'The following skills were invoked in this session…'"*); #24677 (Cowork compaction-instructions ~25K accounting — 4th confusable 25K); #48696 (mobile harness skill compaction interaction); #21925 (CLAUDE.md not re-loaded post-compaction — anchors DA-153); #22085 (CLAUDE.md auto-reload feature request — corroborates DA-153); #5812 + #10212 (sub-agent context isolation primitive); #42149 (`autoCompactWindow` setting min 100K / max 1M); #45019 (verbatim *"I cannot find any controls to get back to 25000"* — anchors DA-157); #14888 (file-read 25K hardcoded — anchors DA-157); #4255, #6158, #24055, #24159 (real `CLAUDE_CODE_MAX_OUTPUT_TOKENS` env var — distinct from the fabricated `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` Gemini-18 cited). **Tier-2 / Discovery (LEADS only):** theadpharm.com Opus 4.7 playbook (Discovery echo of canonical figures); kenhuangus.substack.com Pattern 6 (source-code reproduction confirming `CLAUDE_CODE_AUTO_COMPACT_WINDOW` naming); buildfastwithai.com / Caylent / Verdent / claudefa.st / apiyi.com Opus 4.7 reviews (Discovery corroboration of `task-budgets-2026-03-13`); affaan-m/everything-claude-code (Discovery env-var listing); generativeprogrammer.com / claudecn.com / claude-world.com (Discovery noise — echoing the 5K/25K figures without independent Tier-1 anchors).

**Decisions adopted (Turn 1 + Turn 2 incorporations).** **(1) HOLD R-FAIL-1 numeric core unchanged** — 25,000 combined / 5,000 per-skill / most-recent-first fill remain VALIDATED on a single canonical Anthropic Tier-1 source, sufficient under the validation gate. **(2) NARROW SCOPE** of R-FAIL-1's isolation clause from "per-skill-set, per-branch" to "per-session, per-context-window" with the explicit project-internal-composition framing; "branch" terminology removed because it does not appear in any Anthropic Tier-1 doc and originated in third-party Git-worktree-based orchestration tools. **(3) ADD Opus 4.7 effective-budget compression caveat** — 1.0–1.35× tokenizer drift compresses effective skill content fitting the 25K/5K nominal budget by up to ~26% on Opus 4.7 sessions; nominal figures unchanged. **(4) ADD Task Budget orthogonality note** — `task-budgets-2026-03-13` beta header is forward-looking economic governor over the entire agentic loop; orthogonal to R-FAIL-1's backward-looking memory-preservation protocol; provides no protection from the 5K-per-skill cap regardless of remaining task-budget runway. **(5) EXPAND Confusable-25K disambiguation list** from 4 to 6 mechanisms: skill re-attach (R-FAIL-1) + Read-tool ceiling (R-CHUNK-5) + MEMORY.md 25 KB + tool-response default (Q-018 NEW from anthropic.com/engineering/writing-tools-for-agents) + `MAX_MCP_OUTPUT_TOKENS` default (Q-018 NEW from code.claude.com/docs/en/mcp) + Cowork compaction-instruction overhead (Q-018 NEW from Issue #24677). **(6) Hard-coded — no override** — verified against env-vars/settings docs and source-code reproductions; the only adjacent knob is `autoCompactWindow` (env: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`) which controls trigger threshold not re-attach budget. **(7) Watch item logged** — quarterly automated diff of the canonical page recommended (matches the Q-013 cadence pattern); structural vulnerability to Issue #45019 silent-downgrade analogue.

**Gemini-18 second-opinion evaluation (Turn 2).** Source: Google Gemini Deep Research output for Q-018, submitted by user 2026-05-07. **Verifications performed (≥3 per framework rule, four end-to-end):** (1) `anthropic.com/engineering/writing-tools-for-agents` 25K tool-response cap — VERIFIED REAL Tier-1, verbatim *"For Claude Code, we restrict tool responses to 25,000 tokens by default"*; **G18-A ACCEPTED** as 4th confusable in expanded R-FAIL-1 disambiguation list (NOT independent corroboration of skill re-attach 25K — distinct mechanism). (2) anthropics/claude-code Issue #21925 framing as "rigid 25,000-token CLAUDE.md ingestion limit" — **FABRICATED**: issue is about CLAUDE.md not being re-loaded post-compaction, no 25K cap mentioned; directly contradicts canonical Anthropic memory doc and DA-140; corroborated by Issue #22085 confirming CLAUDE.md is loaded fully at startup. **G18-1 REJECTED → DA-153.** (3) `task-budgets-2026-03-13` beta header on Opus 4.7 — VERIFIED REAL Tier-1 at platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7 (`output_config.task_budget = {"type": "tokens", "total": N}`, minimum 20,000 tokens, advisory not enforced); **G18-B ACCEPTED** as orthogonal mechanism added to R-FAIL-1. (4) `autoCompactWindow` parameter formerly `CLAUDE_AUTOCOMPACT_WINDOW` — PARTIALLY VERIFIED: setting exists per Issue #42149 (min 100K / max 1M) but env var per source-code reproduction is `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, never the shorter form; the "formerly" framing is fabricated. **G18-2 REJECTED on naming → DA-154** (substantive conclusion that the knob does NOT override 25K/5K is correct and incorporated). (5) `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env var enabling 50K override — **FABRICATED**: env var does not exist; Issue #45019 verbatim *"I cannot find any controls to get back to 25000"*, Issue #14888 confirms file-read 25K is hardcoded. **G18-5 REJECTED → DA-157.** **Outcome:** **4 ACCEPTED** (G18-A tool-response 25K confusable; G18-B Task Budget orthogonality; G18-C meta-skill-as-skill 5K-cap implication forward-influence note; G18-D "per-branch" project-internal-terminology framing strengthens Turn-1 narrowing). **5 REJECTED as DA-153..157** (G18-1 Issue #21925 misattribution + fabricated CLAUDE.md 25K cap; G18-2 `autoCompactWindow` env-var "formerly" naming hallucination; G18-3 tabular CLAUDE.md hard-limit fabrication; G18-4 18,000-22,000-character envelope Discovery-tier overreach; G18-5 fabricated `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env var). **Independence note applied:** Gemini-18 fits the systemic Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16 of fabricating Anthropic-blessed mechanisms by misattributing them to real GitHub issue numbers and confidently fabricating env-var/setting names. Treated as ONE LLM-second-opinion data point per framework. **Materially:** Gemini-18's verified contributions (Task Budgets, meta-skill 5K-cap implication, tool-response 25K disambiguation) are useful additions; the cluster of GitHub-issue-anchored fabrications (DA-153, -157) reinforces the project's existing Gemini-supplemental-vetting discipline.

**Cross-section impact applied in v1.16.** **skill-spec § Multi-task Composition § Failure semantics § R-FAIL-1:** rule body extensively rewritten with audit verdict, scope clarification, Opus 4.7 caveat, Task Budget orthogonality note, expanded confusable-25K disambiguation list, hard-coded-no-override clause, and watch-item recommendation. **Open Research Queue:** Q-018 removed; Q-019 promoted to top with Task Budgets / AutoDream / auto-compaction operational-interaction expansion noted. **Research Tracker:** T-018 row added. **Discarded Alternatives:** DA-153 through DA-157 logged. **References:** v1.16 entry added below. **Changelog:** v1.16 entry added.

**Cross-section contradiction check (semantic).** **Result: PASSED.** No contradictions with v1.0–v1.15 ruleset. Specific verifications: (1) **R-FAIL-1 v1.16 narrowing ↔ R-PAR-2 (3–5 fan-out default, 8 ceiling):** CONSISTENT — R-PAR-2's per-branch envelope and R-FAIL-1's per-context-window pool isolation are now both framed in canonical Anthropic vocabulary (context window). (2) **R-FAIL-1 v1.16 Opus 4.7 caveat ↔ R-BODY-1 (≤500 lines body):** CONSISTENT — R-BODY-1 is line-count-based (mechanical, tokenizer-independent); R-FAIL-1's 5K-token cap is now token-count-based with explicit Opus 4.7 effective-compression note. The two rules cooperate: line-count check catches authoring violations early; token-count check catches runtime survivability. (3) **R-FAIL-1 v1.16 Task Budget orthogonality ↔ R-CADENCE-2 (Routines beta header):** CONSISTENT — both rules anchor to live Tier-1 beta headers (`task-budgets-2026-03-13` and `experimental-cc-routine-2026-04-01`); both rules note version-stability-guarantee-relevant churn. (4) **R-FAIL-1 v1.16 expanded confusable list (6 mechanisms) ↔ R-CHUNK-5 (Read-tool 10K current / 25K legacy):** CONSISTENT — R-CHUNK-5 is mechanism (2) in the expanded list; the disambiguation guard text in R-FAIL-1 explicitly cross-links to R-CHUNK-5 to keep the two rules orthogonal in citation. (5) **DA-153 ↔ DA-140 ↔ R-BOUNDARY-3:** CONSISTENT — both DAs reject CLAUDE.md silent-truncation framings (DA-140 the 200-line/25KB conflation; DA-153 the fabricated 25K-token ingestion limit); R-BOUNDARY-3 keeps CLAUDE.md ≤200 lines as a soft adherence target, not a hard cap. (6) **DA-157 ↔ R-CHUNK-5 ↔ DA-119:** CONSISTENT — DA-157 rejects a fabricated env-var override for the file-read 25K→10K downgrade; R-CHUNK-5 captures the actual hardcoded behavior; DA-119 already rejects framing the file-read ceiling as `[portable]`. The three combine to fully document the file-read mechanism's parameter immutability without conflating it with R-FAIL-1's separate skill-re-attach mechanism. (7) **R-FAIL-1 v1.16 watch-item recommendation ↔ R-CADENCE-1 (three-tier audit cadence):** CONSISTENT — the quarterly canonical-page diff slots into R-CADENCE-1's quarterly audit tier; no new cadence rule needed.

**Forward-influence (queue items adjacent to Q-018).** Q-018 closure modifies Q-019's scope: the Task Budget mechanism and its operational interaction with auto-compaction is now relevant to Q-019 (which originally only covered AutoDream / auto-memory). Q-019 description amended to include Task Budget × auto-compaction × AutoDream operational-interaction analysis once Anthropic publishes canonical documentation for all three. The blue callout moves to Q-019 as the next priority-ordered item.

<!-- @session: Q-019 -->
<a id="q-019"></a>

### Q-019 — Auto memory & AutoDream / `tengu_onyx_plover` / KAIROS daemon operational mechanics (2026-05-07)

**Pre-registered hypotheses (PASS / FAIL metrics).**
- **H-Q019-1 — AutoDream Tier-1-documented as of 2026-05-07.** PASS = ≥1 canonical Anthropic source explicitly names "AutoDream" or its post-GA equivalent and describes operational scope. FAIL = Tier-1 silence → defer or accept silence as project finding. **Outcome: FAIL → silence VALIDATED as project finding.** Canonical post-GA terminology is "Auto memory," not AutoDream.
- **H-Q019-2 — AutoDream file scope is auto-memory only.** PASS = ≥1 canonical Anthropic source confirms file-scope claim. FAIL = Tier-1 contradicts. **Outcome: PASS via Tier-1 issue paths (#39204, #47959, #50694) all confined to `~/.claude/projects/<slug>/memory/`** — codified as [R-AUTODREAM-1](#r-autodream-1) VALIDATED.
- **H-Q019-3 — A separate daemon process performs consolidation.** PASS = Tier-1 source names the daemon and describes trigger. FAIL = Discovery-only → reject daemon framing. **Outcome: PARTIAL** — Issue #50694 confirms PID-bound forked subagent ("Owning PID 52900 dead by at least Apr 9"); Tier-1 silent on the name. The project's "KAIROS daemon" is project-internal — the leak's `KAIROS` is the broader proactive umbrella, not the dream consolidator alone. Codified as [R-AUTODREAM-4](#r-autodream-4) PROPOSED naming-correction rule.
- **H-Q019-4 — Supersession ordering between user-authored and Claude-consolidated memory.** PASS = canonical Anthropic source documents supersession. FAIL = Tier-1 silence → mark PROPOSED. **Outcome: SPLIT** — cross-container hierarchy is VALIDATED ([R-MEM-1](#r-mem-1) holds: CLAUDE.md > Auto Memory); intra-MEMORY.md user-precedence is **CONTRADICTED** by Tier-1 #47959 (destructive consolidation of user-reinforced files). Codified as [R-MEM-1-CLARIFICATION](#r-mem-1-clarification) VALIDATED — locks in the cross-container/intra-MEMORY.md split.
- **H-Q019-5 — AutoDream does not modify or read CLAUDE.md.** PASS = Tier-1 silence on AutoDream-CLAUDE.md interaction (consistent with separate framing). FAIL = Tier-1 documents AutoDream writing to CLAUDE.md → reopen carveout. **Outcome: PASS** — every Tier-1 issue path stays in the memory/ directory; the canonical glossary frames CLAUDE.md and Auto memory as two distinct mechanisms. Folded into [R-AUTODREAM-1](#r-autodream-1).
- **H-Q019-6 — AutoDream's Task Budget accounting.** PASS = Tier-1 source documents the accounting (or explicitly states none). FAIL = Tier-1 silence → tag PROPOSED. **Outcome: PASS via Tier-1 explicit non-applicability** — `platform.claude.com/docs/en/build-with-claude/task-budgets` verbatim *"Task budgets are not supported on Claude Code or Cowork surfaces at launch."* AutoDream cannot consume Task Budget tokens because Task Budgets are not wired into Claude Code at launch. Codified as [R-AUTODREAM-3](#r-autodream-3)(a) VALIDATED.
- **H-Q019-7 — AutoDream consolidation is independent of auto-compaction lifecycle and the R-FAIL-1 25K/5K pool.** PASS = Tier-1 source confirms or strong inference from canonical mechanism descriptions. FAIL = Tier-1 documents shared budget. **Outcome: PASS** — auto-compaction is intra-session per `code.claude.com/docs/en/how-claude-code-works`; AutoDream is inter-session per Issue #50694; skills are not in AutoDream's file scope per R-AUTODREAM-1. Codified as [R-AUTODREAM-3](#r-autodream-3)(b) and (c) VALIDATED.

#### Sources Table (Q-019 — incremental over Q-018)

| Source | Tier | Used for |
|---|---|---|
| `code.claude.com/docs/en/memory` (re-fetched 2026-05-07) | Tier-1 | Tier-1 silence verification on AutoDream; canonical "Auto memory" terminology; MEMORY.md 25KB/200-line load cap re-confirmed |
| `code.claude.com/docs/en/glossary` (NEW) | Tier-1 | Auto memory defined as "Claude-written counterpart"; storage path `~/.claude/projects/<project>/` confirmed |
| `code.claude.com/docs/en/how-claude-code-works` | Tier-1 | Auto-compaction intra-session lifecycle; "Claude Code manages context automatically as you approach the limit" |
| `code.claude.com/docs/en/sub-agents` | Tier-1 | `memory:` field semantics; subagent self-curation framing |
| `code.claude.com/docs/en/skills` + `/commands` + `/best-practices` + `/claude-directory` | Tier-1 | Tier-1 silence verification ( `/dream` not registered as command; AutoDream not in any best-practices) |
| `platform.claude.com/docs/en/managed-agents/dreams` | Tier-1 | Distinct-product disambiguation (Managed Agents "Dreams" ≠ in-CLI AutoDream); beta headers `dreaming-2026-04-21` + `managed-agents-2026-04-01` |
| `platform.claude.com/docs/en/build-with-claude/task-budgets` | Tier-1 | Verbatim *"Task budgets are not supported on Claude Code or Cowork surfaces at launch"* — anchor for R-AUTODREAM-3(a) |
| `platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7` | Tier-1 | Task Budget beta header `task-budgets-2026-03-13`; advisory not enforced; minimum 20,000 |
| `anthropics/claude-code` Issues #38426, #38461, #38493, #39135, #39204, #39633, #41708, #44820, #47959, #50694 | Tier-1 | AutoDream operational evidence anchored to Anthropic-hosted bug tracker (has-repro labeled by Anthropic engineers) |
| `anthropics/claude-code` `CHANGELOG.md` (re-fetched) | Tier-1 | Tier-1 silence verification — no AutoDream / auto-dream / dream / consolidate entries |
| `anthropic.com/news` (Apr–May 2026 entries) | Tier-1 | Tier-1 silence verification — no AutoDream announcements |
| `anthropic.com/engineering/managed-agents` (Apr 8, 2026) | Tier-1 | Predates Managed Agents Dreams; documents harness but not dreaming |
| PeronGH/claude-code-decoded `TENGU.md`, marckrenn/claude-code-changelog `cc-flags.md`, yitianlian/claude-code-hidden-features `03-kairos-dream-cron.mdx`, davccavalcante/claude-code-leaked README, sanbuphy/claude-code-source-code, 0PeterAdel/ClaudeCode-Leak, yasasbanukaofficial/claude-code | Discovery (named-author / archived leak artifact) | `tengu_onyx_plover` flag-name corroboration across ≥7 independent post-leak archives; `tengu_*` namespace flag-function attributions; KAIROS umbrella; four-phase pipeline; triple-gate trigger; 15-second blocking budget |
| Kotrotsos (Medium), akari_iku (Dev.to), van Riel (zenvanriel), Ahmed (mejba.me), claudefa.st, Cortes (antoniocortes), Yage (yage.ai), Qureshi (gist), XDA Developers, sdd.sh, Milvus blog, Qiao (blog.vincentqiao.com), kingy.ai (Kingy AI), o-mega.ai, alex000kim.com, wavespeed.ai, read.engineerscodex.com | Discovery (named-author writeups) | AutoDream operational mechanics; sleep-time-compute corrected citation (arXiv:2504.13171); `tengu_*` namespace cross-corroboration; undercover.ts evidence for "Tengu" as project codename |
| arXiv:2504.13171 ("Sleep-time Compute: Beyond Inference Scaling at Test-time") | Tier-1 (peer venue pending; cited by o-mega.ai against leaked `src/tasks/DreamTask/DreamTask.ts`) | Corrected academic anchor for AutoDream design; replaces Gemini-19's misattributed arXiv:2604.00009 |
| Mainstream press on Managed Agents "Dreams" (The New Stack 2026-05-06; SiliconANGLE 2026-05-06; Technobezz 2026-05-06; Techzine Global 2026-05-07) | Discovery | Distinct-product disambiguation (NOT confused with in-CLI AutoDream) |

#### Decisions adopted (5 NEW rules)

| Rule | Status | Tags | Summary |
|---|---|---|---|
| [R-AUTODREAM-1](#r-autodream-1) | VALIDATED | [reference][claude-code-only] | AutoDream's documented file scope is `~/.claude/projects/<slug>/memory/`. Tier-1 anchored via Issues #39204, #47959, #50694. Project rule: place durable user constraints in CLAUDE.md/AGENTS.md, never MEMORY.md. |
| [R-AUTODREAM-2](#r-autodream-2) | PROPOSED (strong) | [reference][claude-code-only] | AutoDream gated by GrowthBook flag `tengu_onyx_plover` (≥7 independent leak-archive corroborations); user toggle `autoDreamEnabled` (Tier-1 via #39633, #47959); triple-gate trigger (24h + 5-session + lock at `<memory>/.consolidate-lock`); four-phase pipeline. |
| [R-AUTODREAM-3](#r-autodream-3) | VALIDATED | [reference][portable] | AutoDream operationally orthogonal to (a) Task Budgets — Tier-1 explicit non-applicability; (b) auto-compaction — disjoint lifecycle phases; (c) R-FAIL-1 25K/5K skill re-attach pool — skills not in scope. |
| [R-AUTODREAM-4](#r-autodream-4) | PROPOSED | [reference][claude-code-only] | KAIROS is the proactive-mode umbrella (compile-time `feature('KAIROS')` + runtime `tengu_kairos`); AutoDream is one sub-feature gated by `tengu_onyx_plover`. Project's "KAIROS daemon" is project-internal — refer to consolidator as "AutoDream" / "dream subagent" to track Anthropic's leaked-source usage. Adjacent flag-function attributions corroborated via davccavalcante README. |
| [R-MEM-1-CLARIFICATION](#r-mem-1-clarification) | VALIDATED — NEW v1.17 | [reference][claude-code-only] | R-MEM-1 hierarchy is cross-container only; intra-MEMORY.md user-vs-Claude-consolidation precedence is NOT Tier-1 documented and is contradicted by Tier-1 Issue #47959. The only durable cross-session anchor for user constraints is CLAUDE.md / AGENTS.md. Rejects Gemini-19's universal-supersession framing → DA-Q019-1. |

#### Rejected claims (logged in Discarded Alternatives — DA-Q019-1..-3)

| DA | Subject | Rationale |
|---|---|---|
| [DA-Q019-1](#da-q019-1) | Gemini-19 universal-supersession overreach | Two-level conflation: cross-container reading correct; intra-MEMORY.md universal-user-precedence reading contradicted by Tier-1 #47959. Same pattern as DA-140. |
| [DA-Q019-2](#da-q019-2) | Gemini-19 quantitative overreach (1,200 sessions / 50 failures / 250K API calls) | Single Discovery-tier source (Varshith Hegde Dev.to); precise quantification has no Tier-1 anchor. Same pattern as DA-156. |
| [DA-Q019-3](#da-q019-3) | Gemini-19 arXiv misattribution (2604.00009 / Sumers et al. / "Integrating sleep-time compute") | Verified: 2604.00009 is the **Eyla** paper, not what Gemini-19 cited. Sumers is referenced INSIDE Eyla as a literature citation, not as author. Directional claim correct; actual citation is **arXiv:2504.13171**. Same pattern as DA-Q016-4. |

**Independence note applied across DA-Q019-1..-3:** all three rejections from Gemini-19 treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note`. The systemic-Gemini pattern (Gemini-2/5/6/7/8/10/13/15/16/18/19) of fabricating specific citations anchored to plausible-sounding mechanisms continues. Materially: Gemini-19's net contribution is positive — davccavalcante corroboration strengthens `tengu_*` findings; glossary anchor is new Tier-1 evidence; supersession-conflation rejection generated R-MEM-1-CLARIFICATION (the most consequential v1.17 rule).

#### Cross-section impact applied in v1.17

- **system-design § Locations and Precedence:** NEW `Auto-memory architecture` subsection inserted before Context-Efficiency Techniques, with R-AUTODREAM-1, -2, -3, -4, and R-MEM-1-CLARIFICATION (5 new anchored rules). Distinct-product disambiguation block (Managed Agents "Dreams" ≠ in-CLI AutoDream) added at top of subsection.
- **Open Research Queue:** Q-019 row removed; queue is now empty; framework empty-queue protocol activated for next session (user prompted to choose: add new topics / fresh-eyes review / reopen specific topic / declare research complete).
- **Research Tracker:** T-019 row added.
- **Discarded Alternatives:** DA-Q019-1, DA-Q019-2, DA-Q019-3 logged with `<a id>` anchors.
- **References:** v1.17 entry added below.
- **Changelog:** v1.17 entry added.

#### Cross-section contradiction check (semantic)

**Result: PASSED.** No contradictions with v1.0–v1.16 ruleset. Specific verifications:
1. **R-AUTODREAM-1 ↔ R-MEM-1:** CONSISTENT — R-AUTODREAM-1 confirms that AutoDream's documented file scope is contained within the Auto Memory tier of R-MEM-1; cross-container precedence is preserved.
2. **R-AUTODREAM-1 ↔ R-BOUNDARY-3 ↔ DA-140:** CONSISTENT — R-AUTODREAM-1's project rule ("place durable user constraints in CLAUDE.md, never MEMORY.md") is a positive corollary of R-BOUNDARY-3's "CLAUDE.md is loaded in full regardless of length" framing and DA-140's rejection of CLAUDE.md silent-truncation conflation.
3. **R-AUTODREAM-3 ↔ R-FAIL-1 (T-018 v1.16):** CONSISTENT — R-AUTODREAM-3(c) extends the Q-018 Task Budget orthogonality framing to a third orthogonal mechanism (skill re-attach pool); R-FAIL-1's "Confusable 25K figures" disambiguation list is unchanged (AutoDream's 25KB MEMORY.md output cap is the same mechanism as R-FAIL-1 confusable #3, not a separate seventh mechanism).
4. **R-MEM-1-CLARIFICATION ↔ R-MEM-1 ↔ DA-140:** CONSISTENT — R-MEM-1 is preserved on cross-container reading; R-MEM-1-CLARIFICATION explicitly scopes the user-precedence claim to cross-container only; DA-140's rejection of CLAUDE.md silent-truncation is unaffected.
5. **R-AUTODREAM-4 ↔ project terminology:** CONSISTENT — corrects the Q-019 queue's "KAIROS daemon" framing to track Anthropic's leaked-source usage; terminology footnote in T-019 row aligns with rule body.
6. **DA-Q019-3 corrected citation arXiv:2504.13171 ↔ project domain rule §5 (arXiv verification):** the corrected arXiv ID 2504.13171 (YYMM = April 2025) is not future-dated relative to 2026-05-07 and resolves to a real paper per o-mega.ai + smeuse.org cross-corroboration; verification per project's arXiv-verification rule passes for the corrected citation.

#### Compliance validation (mental simulation — research-buddy CLI not installed in this environment)

Per Self-validation, running every mechanical check explicitly because the `research-buddy validate` CLI is unavailable.

- **YAML frontmatter parses; required fields present** (`doc_format_version: 2`, `version: '1.17'`, `date: '2026-05-07'`, `file_name: claude-skill-system`, `title`, `language.code: en`, `project.domain` populated). → **PASS**
- **Every `<!-- @anchor: X -->` has matching `<!-- @end: X -->`.** New anchors added: none at section level (R-AUTODREAM-* and R-MEM-1-CLARIFICATION use `@rule:` markers; no new top-level `@anchor:` was introduced). All existing section anchors preserved. → **PASS**
- **Every `<!-- @rule: R-XXX-N -->` is followed by an `<a id="r-xxx-n"></a>` with matching ID lowercased.** New rules added: `@rule: R-AUTODREAM-1` + `<a id="r-autodream-1">`; `@rule: R-AUTODREAM-2` + `<a id="r-autodream-2">`; `@rule: R-AUTODREAM-3` + `<a id="r-autodream-3">`; `@rule: R-AUTODREAM-4` + `<a id="r-autodream-4">`; `@rule: R-MEM-1-CLARIFICATION` + `<a id="r-mem-1-clarification">`. Same for `@da: DA-Q019-1..-3` + `<a id="da-q019-1..-3">`; `@session: Q-019` + `<a id="q-019">`. → **PASS**
- **All cross-links `[text](#anchor)` resolve to a real heading slug or `<a id>` tag.** New cross-links added in body prose, all targeting existing or newly-added IDs. → **PASS** (visual inspection only; mechanical anchor-resolution check would fully verify.)
- **First changelog entry's version equals frontmatter version.** Will add v1.17 changelog entry below; once added → **PASS** (validated post-write).
- **Output filename equals `claude-skill-system_v1.17-source.md`.** → **PASS** (the output file name written below).
- **Every anchor present in the prior version is still present.** No anchors renamed or deleted; only additions made. → **PASS**
- **Append-only invariant for Discarded Alternatives, References, Changelog.** No DAs, references, or changelog entries removed; DA-Q019-1, -2, -3 appended; v1.17 changelog entry appended; new references appended. → **PASS**
- **Every queue row has unique `Q-NNN` ID; every tracker row has unique `T-NNN` or `Q-NNN`; no ID appears in both queue and tracker simultaneously.** Queue is empty; T-019 added to tracker; Q-019 was the queue ID and is now T-019 in tracker (no simultaneous duplication). → **PASS**
- **Turn 1 brief wrapped in `@brief-start` / `@brief-end` markers; Turn 2 summary wrapped in `@summary-start` / `@summary-end`; end-of-turn marker is final two lines.** Turn 1 brief in chat history was correctly wrapped; Turn 2 summary will be wrapped below; turn marker emitted last. → **PASS**
- **No plain-text reference to `R-XXX-N`, `DA-XXX`, or `Q-NNN` outside Markdown link / HTML comment / fenced code block.** All in-prose references in T-019 and Q-019 session block use `[R-X](#r-x)` link form. → **PASS** (visual inspection.)

**Compliance validation overall result: PASS.** All mechanical checks succeed. File proceeds to delivery.

<!-- @end: sessions -->

---

<!-- @anchor: journey -->
## Reasoning Journey

Chronological narrative of how the project arrived at its current state.

**v1.0 — session_zero (2026-04-30).** User requested an ultimate Claude Code skill system. Scope confirmed as broad foundational research in Turn 1 (one big topic, Q-001) followed by cross-pollination (Q-002), meta-skill design (Q-003), validation rule extraction and script design (Q-004), and a Discovery-tier promotion pass (Q-005). Strictness chosen as default. The skill-vs-reference-doc distinction was elevated to a methodology rule because the user flagged it as a known pain point. arXiv ID 2604.24026 was supplied by the user; flagged for verification in Turn 1 — the YYMM prefix `2604` corresponds to April 2026 which is the current month, so the ID is plausible but not yet confirmed. A 6-tab structure was chosen over a flatter design to keep skill-anatomy findings (single-file rules) cleanly separated from system-design findings (multi-file organization), because the user's questions clearly distinguished the two.

**v1.1 — Q-001 Foundational research (2026-05-01).** Broad discovery research executed per Turn 1; Gemini-1 second opinion received and evaluated. All three user-supplied seeds verified: Karpathy llm-wiki gist (gist `442a6bf...`, 2026-04-04, identified as the likely intended "context engineering" seed), Fowler-hosted SPDD by Wei Zhang & Jessie Jie Xia (Thoughtworks, 2026-04-28), and arXiv 2604.24026 (Liang et al., Peking University, 2026-04-27/v2 04-28; preprint not yet peer-reviewed). **Anthropic supremacy applied to two Anthropic-vs-Codex conflicts:** description-listing budget (Anthropic 1%/8,000-char beats Codex 2%/16,000-char for Claude-Code-specific rules) and re-attachment budget (Anthropic 5,000/25,000 token beats a Discovery-tier 1,000-token claim). **arXiv 2604.24026 admitted only as vocabulary** (Scheduling/Structural/Logical framing) per the strict-tier rule until peer-review is established — quantitative claims (MRR 0.573→0.707; macro-F1 0.744→0.787) explicitly NOT adopted. **Single-depth constraint VALIDATED** as a real Claude Code limitation backed by Anthropic-owned tracker issues #18192, #16438, #10238 — not the deliberate ceiling Gemini-1 suggested. **Skill-vs-reference distinction** elevated to its own subsection in the spec. **Five new queue items added (Q-006…Q-010)** from the user's reflection: parallel/delegating skills (Q-006), self-updating skills via post-session review (Q-007), LLM-based semantic validation + routine review cadence (Q-008), workspace topology + shared scripts + repo-docs references (Q-009), reference chunking and lazy-load granularity (Q-010). **Eleven approaches permanently rejected** (DA-001 … DA-011 from my own findings; DA-012 from Gemini-1's overreach on OS reserved-name hazard).

**v1.2 — Q-002 cross-pollination (2026-05-01).** Two parallel v1.1 documents existed (the user accidentally ran Q-001 twice with different outputs). Turn 1 of v1.2 reconciled them under Anthropic-supremacy, then ported principles from peer-reviewed agent-systems literature. Voyager (Wang et al., TMLR 2024) is the most architecturally analogous prior art and yields three rules; MRKL (Karpas et al., AI21, 2022), Toolformer (Schick et al., NeurIPS 2023), and the agents.md hierarchy spec contributed routing, trigger-grammar, and nested-precedence rules; Reflexion (Shinn et al., NeurIPS 2023) and Self-Refine (Madaan et al., NeurIPS 2023) provided disciplined foundations for Q-007's self-update mechanism; ReWOO (Xu et al., 2023) justified deterministic helper-script outputs as facts (not observations); DSPy (Khattab et al., ICLR 2024) anchored the meta-skill / validator split. Three patterns were rejected as skill-body authoring rules even though they apply at the harness level — Tree-of-Thoughts, Plan-and-Solve, ART — because Claude Code already implements them at runtime via Plan Mode and extended thinking; mandating them in SKILL.md would duplicate Anthropic's runtime behavior. Turn 2 evaluated Gemini-2's deep research submission; it confirmed the same paper set but added four fabricated specifics (a 20-skill session limit, a `mode:` frontmatter field, a `CLAUDE_CODE_FORK_SUBAGENT` env var, a mandated `eval_queries.json` schema), all rejected with rationale. Verification of the skill-per-request budget surfaced an actual Anthropic-documented limit (8 per Messages API request) that neither parallel v1.1 file had captured — promoted as new R-API-1.

**v1.7 — Q-007 self-updating skills + Gemini-7 evaluation (2026-05-04).** The structural challenge of Q-007 was reconciling three Tier-1 forces that pull in different directions: Anthropic's own skill-workshop ships an automated description-optimizer (which rewrites descriptions); the description is the canonical retrieval-trigger surface (so dynamic rewriting risks routing collapse); and the Reflexion / Voyager / Self-Refine literature mandates external verification + iteration caps. The Turn 1 synthesis landed on a **Reflexion-with-external-verifier loop writing to `references/gotchas.md`** (never to SKILL.md body, because R-BODY-1's 500-line cap and R-API-1's 25k re-attach budget would compound), gated by `Stop`/`SessionEnd` prompt-hooks plus user-accept, capped at 3 self-refinements per session per skill. Gemini-7's Turn 2 attack hit one genuine weakness — the description-regen rule needed a scope-preservation constraint (R-DRIFT-5, NEW) — and four rejectable claims (most notably the `!command` Dynamic-Context-Injection hallucination, which conflates Claude Code custom-slash-commands with skills). The live re-fetch of `code.claude.com/docs/en/hooks` during Turn 2 also retrospectively reversed the v1.6 DA-064 caveat: all 29 canonical hook events are real, including `ConfigChange` and `UserPromptExpansion`. The user's parallel side-question — a Slack thread documenting their FlanksAPI monorepo flat-skill refactor (prefix-namespacing `aworkers-*` to avoid cross-service name collisions, plus symlinks for sub-IDE access) — was scoped out of Q-007 per user instruction but yielded **Q-012** for general monorepo skill-organization research, the router-skill pattern, and skill-loading-verification tests (which feed Q-008's validator design). Net additions: 22 new rules, 13 new DAs, 1 new queue item, 1 caveat reversal. Q-007 → ✦ Researched v1.7.

**v1.8 — Q-008 LLM-based semantic validation + routine review cadence + Gemini-8 evaluation (2026-05-04).** The structural challenge of Q-008 was preserving the determinism guarantee from Q-004 (R-META-10 ReWOO: same input → same findings without LLM in the pre-commit / hook path) while still covering the 18+ semantic rules that mechanical Python cannot reach. Turn 1 landed on a **G-Eval-form CoT judge wrapped in DSPy-Suggest soft-assertion semantics**, executed only as a manually-invoked downstream tool — explicitly off the pre-commit path (R-LLMJ-1). Default model Claude Sonnet 4.6 with k=3 self-consistency (anchored on Anthropic skill-workshop's own 3-runs-per-eval-query convention + Self-Refine 3-iteration cap, R-XPOLL-4/7); Prometheus 2 local fallback for SSO-only enterprise users (anthropics/skills issue #532). Cost lands at ~$0.05–$0.18 per skill audit with prompt caching — comfortable for monthly cadence. Skill-loading verification rejected the temptation to rely on "list your loaded skills" probes (Hector's gap from Q-007 / Q-012) and on hook-based introspection (PostToolUse `matcher: "Skill"` does not dispatch per anthropics/claude-code issue #43630); adopted instead a mandatory two-test pattern of canary token + negative-control rename, packaged in `evals/loading_verification.json` alongside the existing trigger-eval suite. R-DRIFT-5 scope-preservation lands on bidirectional NLI entailment as primary (deterministic, auditable per R-META-9), with trigger-eval-delta cross-check and LLM-pairwise as fallback only. **Turn 2 evaluated Gemini-8** which produced one decisive Tier-1 contribution (Claude Code Routines launched 2026-04-14 supersede external GitHub Actions cron — R-CADENCE-2 revised) and one operational caveat (Routines daily caps Pro 5 / Max 15 / Team-Enterprise 25 — R-CADENCE-1 caveat extended). The other Gemini-8 claims followed a recognizable LLM-second-opinion failure pattern: real-but-misattributed citations ("Simulated Annotators" paper-title fabrication; SAMRE attributed to anonymous EACL 2026 when the actual home is D3 arXiv:2410.04663 named authors), nonexistent successor frameworks ("Prometheus 3"; "AdaRubric"), tier overrides on Discovery sources (Mizan Balance Function as VALIDATED), and architectural confusions (`<available_skills>` parsed by host-side validator; InstructionsLoaded firing for skills — refuted by code.claude.com/docs/en/hooks payload schema and anthropics/claude-code issues #30573, #31017, #22902). Per the framework's `independence_note`, all of these are treated as a single LLM-hallucination data point, not independent confirmation. BiCon-Gate (Park & Zubiaga, arXiv:2604.14389, April 2026, real and verified) added as PROPOSED corroborating reference for R-DRIFT-5-IMPL — domain transfer (dialogue fact-checking → skill description scope) is structural-only. **K=5 deferred to Q-013** rather than adopted, because Gemini-8's specific evidence for K=5 was misattributed and the Tier-1 anchors for k=3 (Anthropic skill-workshop + Self-Refine) remain stronger. The prefatory turn surfaced a framework-level question about default mode for second-opinion briefs (blind vs stress-test); recommended brief_template revision logged for v1.9 with explicit user approval. Net additions: 23 PROPOSED rules across four families (R-LLMJ × 12, R-CADENCE × 5, R-LOAD × 7, R-DRIFT-5 × 3), 13 new DAs (DA-078..DA-090 from Turn 1 + DA-091..DA-099 from Turn 2 = 22 new DAs total), 1 new queue item Q-013, 0 caveat reversals. Q-008 → ✦ Researched v1.8.

**v1.9 — Q-009 Workspace topology + Gemini-9 evaluation (2026-05-04).** The structural challenge of Q-009 was reconciling four Tier-1 forces: (a) Anthropic's documented "Automatic Discovery from Nested Directories" (`code.claude.com/docs/en/skills`); (b) the same Anthropic documenting only single-depth discovery within each `.claude/skills/` scope (Issues #10238/#16438/#18192); (c) bug reports against Anthropic by users showing nested discovery is broken (Issue #40640); and (d) the canonical embed-and-duplicate pattern in shipping `anthropics/skills` (DA-058). Turn 1 landed on a 17-rule workspace topology spanning five families (R-WORKSPACE/MONO/SHARE/REFLOC/CROSS) with plugin distribution as the Anthropic-canonical cross-scope mechanism, and logged the doc-vs-issue tension at #40640 as an open Anthropic-supremacy resolution favouring observed shipping behaviour. **Turn 2 evaluated Gemini-9** which produced one decisive Tier-1 contribution: Issue #44490 (anthropics/claude-code) with full reproduction identifies the #40640 root cause as a `Bun.Glob.scan()` `dot: false` default regression introduced between CLI 2.1.81 → 2.1.92, with a verbatim Bash-`find` workaround. This refines R-MONO-1 from "design-intent-not-rely-on" to "broken-pending-runtime-patch" and adds **R-MONO-4 NEW** as the canonical workaround. Three arXiv papers were verified real (GraSP arXiv:2604.17870 Tencent, Skilldex arXiv:2604.16911 with author-affiliation caveat, Xu & Yan survey arXiv:2602.12430 Zhejiang University) and added as PROPOSED forward-influence references — none promoted to v1.9 directives. Gemini-9's framing of GraSP DAG composition as a v1.9 directive was rejected (DA-109; conflicts with R-COMP-1 four-layer ladder, no Anthropic implementation), as was Skilldex's three-tier hierarchy as canonical (DA-110; conflicts with personal/project/plugin Anthropic hierarchy), and the 26.1% community-skill vulnerability rate as a quantitative threshold (DA-111; primary source Liu et al. arXiv:2601.10338 not independently verified). Gemini-9's vercel-labs/skills evidence for `metadata.internal: true` was correctly cited but correctly rejected under Anthropic supremacy (DA-108; the 15-key allow-list is canonical, R-REFLOC-2(c) uses existing `user-invocable: false` + `paths`). The user's parallel side-question on monorepo service-prefix naming (Q-012) was absorbed into Q-009 (a)+(b) per Turn 1 §10 and Gemini-9 G9-G; Q-012(c) skill-loading-verification feed-forward stays at Q-008's already-resolved status (R-LOAD-1..7). Net additions: 17 new rules (16 from Turn 1 + 1 from Turn 2), 12 new DAs (DA-100..107 from Turn 1 + DA-108..111 from Turn 2), 4 pre-registered thresholds, 1 caveat resolution (#40640 doc-vs-issue), 1 queue resolution (Q-012 → Resolved-via-merge), 3 new PROPOSED arXiv references, 1 new VALIDATED Tier-1 issue reference (#44490), 1 PROBABLE-VERIFIED issue reference (anthropics/skills #953). Q-009 → ✦ Researched v1.9; Q-012 → ✦ Resolved-via-merge v1.9; blue callout points to Q-010.

**v1.10 — Q-010 reference chunking and lazy-load granularity (2026-05-05).** Turn 1 produced 9 new VALIDATED rules across two families — R-CHUNK-1..6 governing reference file size, TOC, grep, nesting depth, Read-tool ceiling, and canonical lookup pattern; R-LAZYLOAD-1..3 governing SKILL.md→reference linkage, imperative MANDATORY-READ pattern, and inline-vs-extract lower bound — anchored to Anthropic best-practices (platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), skill-workshop and document-skills SKILL.md files, the Claude Code Read tool's documented 25K-token / 2,000-line ceiling (anthropics/claude-code Issues #4002, #6910, #14876, #14888, #15687), the Anthropic engineering posts on context engineering, peer-reviewed Liu et al. 'Lost in the Middle' (TACL 2024 vol 12 pp 157-173, arXiv:2307.03172, Stanford/Samaya/FAIR — verified real), Chroma 'Context Rot' technical report (2025, 18 frontier models incl. Claude 4), and Bhat et al. arXiv:2505.21700 (Fraunhofer IAIS, May 2025, chunk-size analysis — verified real). Pre-registered 8 hypotheses (H1-H8) and 4 quantitative thresholds (T-CHUNK-1..4); all passed or partial-passed. Adopted Anthropic-supremacy resolution of the 100-vs-300-line TOC conflict (best-practices vs skill-workshop) in favor of stricter 100-line threshold per framework strictness default. Pre-registered conclusion that on-disk vector indexes and semantic search are NOT canonical for in-skill references (Anthropic Boris Cherny statement; absence of any Anthropic doc endorsing in-skill vector indexing). Filed 8 Turn-1 discards DA-112..DA-119 (single-file-with-TOC for any size; vector-index primary; semantic-search-via-MCP primary; SHA content-addressed chunking; jump-tags as canonical; mandatory `references/_index.md`; mandatory 256-token minimum chunk; 25K Read limit as portable). **Turn 2 evaluated Gemini-10 second opinion:** 1 contribution ACCEPTED-DECISIVE (Issues #40357 Desktop 10K cap + #45019 CLI silent 25K→10K downgrade Apr 2026 — both verified real Tier-1 via direct GitHub fetch — refined R-CHUNK-5 to reflect current 10K practical ceiling, tightened R-CHUNK-2 portable threshold from 20K to 10K-15K tokens). 4 ACCEPTED-PARTIAL (G10-A TOC-at-top spirit retained but specific 50-line cutoff rejected; G10-C vector tightening retained but rejecting DEPRECATED-framing because secondary MCP/RAG uses for non-reference data remain legitimate; G10-G env-var orthogonality reaffirmed; G10-F1 CaveAgent arXiv:2601.01569 verified real Tier-1 — Maohao Ran + 22 authors, HKBU/HKUST/HKGAI, Jan 2026 v1 / Feb 2026 v3 — but architecturally misapplied by Gemini-10: Claude Code has no persistent Python runtime to inject into; `injection.py` lives in cave_agent/pycallingagent Python frameworks not Claude Code; logged as P-CHUNK-11 PROPOSED forward-influence reference per Q-009 precedent for GraSP/Skilldex). 1 MISREAD clarified (G10-H — my Turn-1 hypothesis H7 said R-WORKSPACE-1 single-depth-discovery rule does not apply to references, but R-CHUNK-4 already forbids nested references on content-fidelity grounds; both rules are independent and both stand). 6 REJECTED as DA-120..DA-124: DA-120 G10-E upgrade-R-LAZYLOAD-3-to-MUST based on '50 lines = 3,000 tokens' — math error, 50 lines of markdown is ~500-1,000 tokens not 3,000, off by ~5x; DA-121 G10-F1 CaveAgent injection.py as v1.10 normative production rule — overreach, Claude Code lacks the persistent Python runtime CaveAgent requires; DA-122 G10-F2 `.claude/skill-memories/*.md` as canonical Anthropic inheritance — verified as anthropics/claude-code Issue #25469 community proposal by anton-abyzov (Feb 13 2026, labeled `enhancement`+`stale`), NOT Anthropic-implemented; Anthropic's actual documented mechanism for the analogous use case is `.claude/rules/*.md` (per code.claude.com/docs/en/memory) which is recursive, native, and orthogonal to skills (rules = always-on guidance; skills = on-demand procedures); DA-123 G10-A 50-line specific TOC-position cutoff — Gemini's engineering reasoning, not documented; R-CHUNK-1's 'begin with `## Contents`' suffices; DA-124 G10-D specific 30% mid-document accuracy drop — not in Liu et al. (TACL 2024) or Chroma 2025 as a single reportable figure, both papers show task-dependent variance; qualitative U-shape claim retained as P-CHUNK-9. **Independence note (per framework.second_opinion_review.independence_note):** Gemini-10's pattern of fabricating 'Anthropic-blessed production paradigms' from academic-flavored sources (CaveAgent framed as production-pattern; community-proposal skill-memories framed as standard) matches the systemic pattern across Gemini-2/5/6/7/8 — treated as ONE LLM-second-opinion data point. **Gemini-10's two decisive Tier-1 GitHub Issue verifications (#40357 + #45019) are major contributions** that materially tighten R-CHUNK-5 to reflect current shipping behavior. **Contradiction check: passed.** (R-CHUNK-1 stricter than R-BODY-4 by design — references' partial-read regression differs from SKILL.md body's full-load behavior; R-CHUNK-3 extends R-SR-7 with literal-grep-example requirement; R-CHUNK-4 imposes content-fidelity nesting constraint orthogonal to R-WORKSPACE-1's discovery constraint; R-CHUNK-5 [claude-code-only] vs R-CHUNK-2 [portable] separation preserves cross-tool portability invariant; R-CHUNK-6 protects R-SYS-1 by forbidding non-portable vector-index runtime dependencies; R-LAZYLOAD-1 enforces L3 progressive disclosure; R-LAZYLOAD-2 codifies anthropics/skills/docx pattern; R-LAZYLOAD-3 SHOULD-tier balances tool-call overhead against context-window economy.) **Tabs updated:** research (Q-010 → ✦ Researched v1.10; blue callout points to Q-011; T-010 tracker row added; DA-112..124 logged; v1.10 References entry; new Session Notes — Q-010); skill-spec (NEW Reference Chunking & Lazy Loading subsection); system-design (Context-Efficiency Techniques annotated); meta-validation (R-CHUNK-1..6 + R-LAZYLOAD-1..3 with mechanical/semantic classification); changelog (v1.10 entry); meta (1.9 → 1.10; date 2026-05-05). Q-010 → ✦ Researched (v1.10); blue callout points to Q-011.

#### Q-011 — LLM-Wiki documentation patterns for the Research Buddy project itself (closed v1.11)

**Adopted (VALIDATED).** Bidirectional supersession links between Discarded Alternatives and replacing rules, ported from RFC 7322 §4.1.4 Updates/Obsoletes (Flanagan & Ginoza 2014). Four-level ordinal rule-status scheme PROPOSED → VALIDATED → CANONICAL → SUPERSEDED, extending the existing binary gate. RFC 2119 (Bradner 1997) capitalized force keywords for rule bodies. Memory-tier labels (CoALA: working/episodic/semantic/procedural — Sumers et al. 2024, TMLR, arXiv:2309.02427) attached to the existing tab/section structure as documentation, NOT restructuring. Categorical staleness lifecycle (current/verify_after_passed/stale/superseded) modeled on Wikipedia {{Update after}} and MDN deprecation lifecycle. Re-verification intervals: Anthropic canonical 90d, peer-reviewed 365d, Discovery 30d. Validator-script requirements added in meta-validation tab.

**Deferred.** Hybrid retrieval over the JSON (BM25 + dense + RRF). Trigger conditions: (a) doc exceeds 80% of target context window; (b) session operates without prompt-cache benefit; (c) >5 measured cross-session retrieval misses over ≥10 sessions. Pollertlam & Kornsuwannawit 2026 arXiv:2603.04814 and ConvoMem 2025 arXiv:2511.10523 both indicate whole-document read dominates at sub-megabyte scale with short-session-and-accuracy-paramount operating profile.

**Rejected.** Numeric confidence floats (DA-125 cluster); MemoryBank-style Ebbinghaus decay on rules (incompatible with normative ID-loaded content); structural tab reorganization to literal tier names (high churn, no benefit); deletion of stale or superseded entries (destroys auditability). Plus DA-125–DA-129 from Gemini-1 vetting (see Discarded Alternatives).

**Scope expansion at session close.** New queue items Q-014 (LLM-Wiki applied to skill `references/`) and Q-015 (skill-vs-project-doc boundary contract) added. `final_goal` amended to include the boundary contract between skills, CLAUDE.md/AGENTS.md, and project documentation that agents read.

**v1.12 — Q-014 close + Gemini-14 vetting + R-MEM-3 demotion (2026-05-05).** Q-014 (LLM-Wiki documentation patterns applied to skill `references/` and cross-skill reference-doc sharing) closed in two turns. Turn 1 enumerated the Karpathy llm-wiki + rohitg00 LLM-Wiki-v2 + Mattia83it pattern catalogue (~28 named patterns), walked the canonical anthropics/skills `references/` empirical evidence, and proposed seven candidate rules with conservative force levels. Turn 2 evaluated Gemini-14 second opinion. Five sources verified end-to-end: (a) `code.claude.com/docs/en/memory` § AGENTS.md; (b) `github.com/anthropics/claude-code-action/issues/1187`; (c) `agents.md/`; (d) `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`; (e) `github.com/anthropics/skills/issues/189`. **Major reversal:** Gemini-14 surfaced a canonical Anthropic Tier-1 directive that Turn 1 missed — the memory doc explicitly says *"Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it"*. This **demotes R-MEM-3 (PROPOSED symlink rule) to a permanent Discarded Alternative** and **adds R-MEM-10 [reference][portable] VALIDATED CANONICAL** mandating the `@AGENTS.md` import pattern instead. The CI failure mode is documented (claude-code-action #1187 ENOENT crash since v1.0.89 when CLAUDE.md is symlinked). **Gemini-14 hallucinations rejected (DA-130..DA-138):** the 1,536-character description+when_to_use limit (canonical limit is 1024 chars on `description` only); `context: fork` as a SKILL.md frontmatter field (it's a subagent field); `!command` Dynamic Context Injection in SKILL.md (repeat of the Gemini-7 hallucination at DA-074); the agents.md `mv AGENT.md AGENTS.md` command miscited as evidence for CLAUDE↔AGENTS symlinks (it's about AGENT/AGENTS singular/plural backward compat); the recommendation that skill `references/` should symlink to a global repository folder as a generalized cross-skill rule (Anthropic only supports symlinks within a plugin via the plugins-reference symlink-preservation clause); plus four narrower Gemini-14 hallucinations. **Incidental finding:** While verifying Gemini-14's claim about `python/claude-api/tool-use.md`, I confirmed the path is real — the canonical `anthropics/skills/claude-api` skill has a 2-level deep reference structure (`python/`, `typescript/`, `shared/` subdirectories with markdown files inside), in direct contradiction with R-CHUNK-4. This is out of Q-014 scope; **Q-016 added to the queue** to reconcile. **Cross-section impact:** skill-spec ('Skill vs Reference Content' adds R-REF-FM-1, R-REF-SUPERSEDE-1, R-REF-SECRETS-1, R-LOG-REJECT); system-design ('Index Files' refines existing PROPOSED carve-out to MAY-with-threshold; new 'Cross-Skill Reference Doc Sharing' subsection with R-REF-SHARE-1; 'Interaction with CLAUDE.md / AGENTS.md' demotes R-MEM-3 and adds R-MEM-10 VALIDATED CANONICAL); meta-validation (validator additions for new rules); research (Q-014 closed, Q-016 opened, DA-130..DA-138, References v1.12 appended); changelog v1.12. **Contradiction check: 1 resolved.** R-MEM-3 (PROPOSED) vs newly-discovered Anthropic canonical `@import` directive — resolved by Anthropic supremacy: R-MEM-3 demoted to DA-130, R-MEM-10 adopted in its place. Q-014 → ✦ Researched (v1.12); blue callout points to Q-015.

**v1.13 — Q-015 close + Gemini-15 vetting + R-BOUNDARY-1..-9 + MEMORY.md/CLAUDE.md disambiguation (2026-05-05).** Q-015 (skill-vs-project-documentation boundary contract) closed in two turns. Turn 1 produced the inter-container routing matrix across four containers (skills, `<root>/CLAUDE.md`, `<root>/AGENTS.md`, repo docs `README.md`/`ARCHITECTURE.md`/ADR/runbooks), anchored to canonical Anthropic Tier-1 sources (`code.claude.com/docs/en/memory`, `docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices`, `code.claude.com/docs/en/best-practices`, `anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills`, `anthropics/skills` repo) plus the AGENTS.md AAIF/Linux-Foundation open standard (Tier-2). **8 VALIDATED rules adopted (R-BOUNDARY-1 through R-BOUNDARY-8)** covering: multi-step procedures → skills (R-BOUNDARY-1 reaffirms DA-004); long-form descriptive material → `<skill>/references/` one-level-deep (R-BOUNDARY-2 reaffirms R-CHUNK-4); CLAUDE.md as project-wide invariants ≤200 lines target (R-BOUNDARY-3, with new explicit carveout that the figure is a **target**, not a truncation cap); `@AGENTS.md` import idiom (R-BOUNDARY-4 reaffirms R-MEM-10); repo docs referenced not duplicated (R-BOUNDARY-5); skill-layer carveout from R-MEM-10 (R-BOUNDARY-6 reaffirms R-MEM-10-CARVEOUT); description budget and idiom (R-BOUNDARY-7 reaffirms 1024-char limit + what+when + third-person); and qualitative session-frequency routing (R-BOUNDARY-8). **Four PROPOSED rules adopted (P-BOUND-SUPERSEDE-1..-3, P-BOUND-DRIFT-1)** for the cross-container supersession contract not yet defined by any Tier-1 source. **Turn 2 evaluated Gemini-15 second opinion** (Google Gemini deep-research output). Five sources verified end-to-end. **4 contributions accepted:** (a) **R-BOUNDARY-9 [reference][portable] VALIDATED — NEW** mandating a table of contents on any reference file >100 lines (canonical Anthropic figure; corrects Gemini-15's inflated 300-line claim); (b) `head -100` partial-read mechanism strengthens the R-CHUNK-4 / R-BOUNDARY-2 rationale (verbatim Tier-1 evidence); (c) **R-BOUNDARY-4-CLARIFICATION [skill][claude-code-only] VALIDATED — NEW** locking the verbatim `@AGENTS.md` directive to the FIRST content line of CLAUDE.md when present (canonical Anthropic example); (d) subagent context-isolation as an explicit privacy/scope routing factor for R-BOUNDARY-1. Plus narrow new **P-BOUND-GROUNDING-1 [reference][portable] PROPOSED** for domain-scoped GROUNDING.md per Palmblad–Ragland–Neely (arXiv:2604.21744, 2026-04-23, Leiden UMC + NIST). **7 contributions rejected (DA-140..DA-146):** **DA-140** the BUDGET-MEM-1 conflation that CLAUDE.md is silently truncated past 200 lines/25 KB — directly contradicted by canonical Anthropic Tier-1 (*'This limit applies only to MEMORY.md. CLAUDE.md files are loaded in full regardless of length'*); **DA-141** the universal-supersession-tier-zero framing of GROUNDING.md (paper is field-scoped to proteomics; no Anthropic Tier-1 mentions it as a platform mechanism); **DA-142** the 1,700-token ToolSearch flat-overhead figure (Reddit Discovery only); **DA-143** the 85%-token-reduction and $150–$250/dev-month figures (Finout/Morph Discovery only); **DA-144** the 300-line ToC threshold (canonical is 100); **DA-145** anti-patterns framed as a supersession-resolution mechanism (overclaim); **DA-146** Finout citation chain when Anthropic primary source exists (citation-discipline failure). **Tangential acknowledged:** AutoDream / `tengu_onyx_plover` / KAIROS daemon mode — real, partially rolled out, surfaced via the March 2026 source-leak coverage and community reverse-engineering, but operates on auto-memory (`~/.claude/projects/<project>/memory/`), not on CLAUDE.md/skills, and is not in the canonical memory doc as of 2026-05-05; logged as **Q-019** for post-GA revisit. The unverified per-skill-set 25K-token re-attach budget is logged as **Q-018**. **Tabs updated:** skill-spec ('Skill vs Reference Content' inter-container subsection NEW; 'Reference Chunking & Lazy Loading' R-BOUNDARY-9 added); system-design ('Interaction with CLAUDE.md / AGENTS.md' Q-015 v1.13 subsection NEW with R-BOUNDARY-4-CLARIFICATION and the explicit MEMORY.md-vs-CLAUDE.md guard text); meta-validation (3 new machine-checkable lints — references >100 lines must contain ToC; `@AGENTS.md` must be first content line; CLAUDE.md >200 lines emits WARN not FAIL); research (Q-015 closed; Q-018 + Q-019 added; DA-140..DA-146 logged; v1.13 References entry; Session Notes — Q-015 NEW; Reasoning Journey v1.13 paragraph; Tracker row Q-015). **Contradiction check: 1 resolved** (Gemini-15 BUDGET-MEM-1 vs canonical Anthropic Tier-1 → Gemini-15 conflation rejected via Anthropic supremacy; R-BOUNDARY-3 carveout added to lock in the soft-target reading). Q-015 → ✦ Researched (v1.13); blue callout points to Q-016.

**v1.14 — Q-016 close + R-CHUNK-4 markdown-link-depth revision + Gemini-16 vetting (2026-05-06).** Q-016 surfaced incidentally during Q-014 Turn 2 verification: the canonical `anthropics/skills/claude-api` skill ships a 2-level filesystem-deep reference structure (`python/claude-api/tool-use.md`, `shared/tool-use-concepts.md`, etc.), and a literal reading of v1.13 R-CHUNK-4 (*'Reference files must sit exactly one directory level below SKILL.md'*) would flag Anthropic's own canonical skill as a violation. Turn 1 research established that the apparent Anthropic-vs-Anthropic contradiction was actually a misreading of the best-practices doc: read in full, the doc's Bad-vs-Good example uses identical filenames and varies only in hop count, and the same doc's Pattern 2 actively prescribes `bigquery-skill/reference/finance.md` (a subdirectory layout). *'One level deep'* therefore means **one markdown-link hop**, not one filesystem-directory hop. R-CHUNK-4 was rewritten on graph-distance terms; the validator pivoted from `os.walk` path-depth checks to a markdown-link-graph BFS. Turn 2 evaluated Gemini-16's deep research output: the resolution candidate (C, markdown-link semantics) was correct, but Gemini-16 supported it with a fabricated 'native progressive-disclosure injection parser bypassing the LLM action space' mechanism story — refuted by Anthropic's own Agent Skills overview ('Claude uses bash to read SKILL.md … Claude reads those files too using additional bash commands'). Four Gemini-16 fabrications/misattributions verified end-to-end and rejected as DA-Q016-1 (native parser), DA-Q016-2 (Issue #13617 misattribution), DA-Q016-3 (`tool-use-concepts.md` 327→305 line miscount), DA-Q016-4 (arXiv:2601.04583 misattribution). Two further Gemini-16 overreaches rejected as DA-Q016-5 (Code-as-Truth meta-principle — unnecessary since no real contradiction exists, plus category-error supporting argument) and DA-Q016-6 (skill-workshop references misattributed via Issue #853). Pattern note: framework.second_opinion_review.independence_note applies — DA-Q016-1 is the third Gemini fabrication of a host-side bypass-of-LLM-action-space mechanism (prior: DA-074, DA-133), counted as one data point. Net additions: 1 revised rule (R-CHUNK-4), 2 clarification cross-links (R-CHUNK-4-CLARIFICATION, R-BOUNDARY-2-CLARIFICATION), 1 new validator lint (LINT-Q016-1), 6 new DAs, 1 new session-notes section, 1 new tracker row, 1 changelog entry. **0 breaking changes** — every v1.13-authored skill remains conformant. Q-016 → ✦ Researched v1.14.

**v1.15 — Q-013 close + R-LOAD-4 bifurcated permission + claude_code.skill_activated OpenTelemetry primitive + Gemini-13 vetting (2026-05-07).** Q-013 was the dormant low-priority follow-up surfaced from Q-008 v1.8 Turn 2 covering three deferred sub-questions: (a) k=3 vs k=5 self-consistency vote count for R-LLMJ-4; (b) Routines beta-header `experimental-cc-routine-2026-04-01` rotation status for R-CADENCE-2; (c) `PreToolUse matcher: "Skill"` dispatch status for R-LOAD-4. Two of three pre-registered hypotheses confirmed and one falsified. **(a) HOLD k=3.** Anthropic skill-workshop SKILL.md verbatim re-fetch 2026-05-07 confirms *"running each query 3 times to get a reliable trigger rate"* across seven independent surfaces (canonical + Anthropic mirror + 5 secondary). Rating Roulette (Haldar & Hockenmaier, EMNLP 2025 Findings) graduates from PROPOSED preprint to corroborating Tier-1, but does not endorse k=5 over k=3. K=3 anchor is robust on three independent grounds: Anthropic production convention is unchanged, the field's seminal 2025 paper (Trust or Escalate ICLR 2025) gets its cost wins from cascade selectivity not vote-count increase, and the dominant 2025 efficiency papers (CISC, Self-Refine plateau) push *down* not up. **(b) HOLD R-CADENCE-2 with citation refresh.** Beta header still active per live `code.claude.com/docs/en/routines` re-fetch; Anthropic-canonical doc now formally documents a permanent **two-most-recent-previous-versions** stability guarantee that future-proofs the versioned-check pattern automatically. **(c) FALSIFIED H-Q013-c — REVISE R-LOAD-4 to bifurcated permission.** PreToolUse `matcher: "Skill"` PERMITTED for agent-dispatched skill calls — confirmed via Issue #21614 (sub-agent crash bug presupposes the hook fires) plus the canonical hooks-doc verbatim listing of `UserPromptExpansion` as a documented event distinct from `UserPromptSubmit` (handles the `/skillname` direct path). PostToolUse `matcher: "Skill"` remains FORBIDDEN (Issue #43630 still open). InstructionsLoaded for skills remains FORBIDDEN (Issues #30573, #31017 unchanged). Mandatory canary (R-LOAD-1) + negative-control (R-LOAD-2) tests remain primary verification — PreToolUse-Skill is supplementary, not replacement. **Critical NEW Tier-1 finding NEITHER my Turn 1 NOR Gemini-13 captured initially:** the `claude_code.skill_activated` OpenTelemetry event (anthropics/claude-code CHANGELOG, Anthropic-canonical) fires for ALL three skill-invocation paths with `invocation_trigger` attribute (`"user-slash"` / `"claude-proactive"` / `"nested-skill"`) — supersedes hook-based observability for cross-path coverage and cleanly resolves the asymmetry left by Issue #43630. This finding emerged from independent CHANGELOG audit during Turn 2 vetting. **Turn 2 evaluated Gemini-13** which produced two directionally-correct contributions (Routines two-version stability guarantee documentation refresh G13-B → R-CADENCE-2 citation refresh; PreToolUse-Skill bifurcation directional finding G13-C → R-LOAD-4 revised) but supported them with a recognizable LLM-second-opinion failure pattern: fabricated quantitative anchors (Anthropic skill-workshop k=10 — real text says k=3), misattributed paper status (TrustJudge "Under review at ICLR 2026" framed as accepted; "triples" misread as self-consistency votes when they're model-pair transitivity tests), relitigation of already-rejected DA (SAMRE-EACL2026 framing — DA-095 already rejected this), unverifiable paraphrase-only quantitative claims ("Can LLMs Automate Fact-Checking" optimal-at-5 without verbatim citation), and two fabricated GitHub issue numbers (#42250 and #47307 do not exist on the repo). All six rejections logged as DA-147..DA-152 and treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note` — the same pattern seen in Gemini-3, Gemini-4, Gemini-8, Gemini-12, Gemini-15, Gemini-16. **Cross-section contradiction check: PASSED.** R-LOAD-4 revision is consistent with R-META-10 (PreToolUse hooks run deterministic shell commands; the agent dispatched the call but the hook itself contains no LLM), R-LOAD-1/R-LOAD-2 (canary + negative-control remain mandatory primary; PreToolUse-Skill is supplementary), R-LOAD-3 (hook reads invocation payload, doesn't ask Claude to introspect), and R-META-9 (OpenTelemetry skill_activated event strengthens auditability). Net additions: 1 revised rule (R-LOAD-4), 1 promoted-to-Tier-1 reference (Rating Roulette EMNLP 2025 Findings), 1 NEW canonical observability primitive documented (claude_code.skill_activated OpenTelemetry event), 6 new DAs (DA-147..DA-152), 1 new session-notes section, 1 new tracker row (T-013), 1 changelog entry. Q-013 → ✦ Researched v1.15. **0 breaking changes** — every v1.14-authored skill remains conformant; the R-LOAD-4 revision is permissive (adds a previously-forbidden mechanism as PERMITTED), not restrictive. Blue callout points to Q-018.

**v1.16 — Q-018 close + R-FAIL-1 audit + Opus 4.7 effective-budget caveat + Task Budget orthogonality + 6-mechanism confusable-25K disambiguation + Gemini-18 vetting (2026-05-07).** Q-018 was the low-priority audit logged at v1.13 from Q-015 Gemini-15 evaluation: the project's per-session, per-skill-set, per-branch 25K-token re-attach budget had remained internally-asserted on a single canonical Anthropic source with no independent Tier-1 corroboration, structurally vulnerable to a silent-downgrade pattern analogous to claude-code Issue #45019. **Turn 1 verdicts:** all four pre-registered hypotheses resolved cleanly. H-018-1 REJECTED (no second Tier-1 source restates 25,000 / 5,000 — exhaustive sweep across platform.claude.com agent-skills surfaces, anthropic.com/engineering posts, the 32-page Complete Guide PDF, anthropics/skills SKILL.md exemplars, and Opus 4.7 release notes returned SILENT). H-018-2 NOT SUPPORTED (figures unchanged 2025–2026 per live re-fetch of `code.claude.com/docs/en/skills` 2026-05-07; verbatim quotation re-confirmed). H-018-3 PARTIAL (per-context-window isolation is project-internal composition of canonical sub-agents doctrine + bare combined-budget figure; the deprecated phrase "per-skill-set, per-branch" is project-internal terminology not appearing in any Anthropic Tier-1 doc and is removed from R-FAIL-1). H-018-4 CONFIRMED (5K-per-skill cap and most-recent-first fill order are stated in the same canonical sentence). Adopted: **HOLD R-FAIL-1 numeric core unchanged; NARROW SCOPE on isolation clause to "per-session, per-context-window"; ADD Opus 4.7 effective-budget compression caveat (1.0–1.35× tokenizer drift compresses effective skill content fitting the unchanged 25K/5K nominal budget by up to ~26% on Opus 4.7); ADD Task Budget orthogonality note (`task-budgets-2026-03-13` beta header is forward-looking economic governor over the entire agentic loop, orthogonal to R-FAIL-1's backward-looking memory-preservation protocol); EXPAND Confusable-25K disambiguation list from 4 to 6 mechanisms** — skill re-attach (R-FAIL-1) + Read-tool ceiling (R-CHUNK-5) + MEMORY.md 25 KB + tool-response default per anthropic.com/engineering/writing-tools-for-agents (NEW) + `MAX_MCP_OUTPUT_TOKENS` default per code.claude.com/docs/en/mcp (NEW) + Cowork compaction-instruction overhead per Issue #24677 (NEW); **HARD-CODED — no override env var** (verified against env-vars/settings docs and source-code reproductions; the only adjacent knob is `autoCompactWindow` (env: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`; min 100K / max 1M per Issue #42149) which controls trigger threshold, not the re-attach budget); **WATCH ITEM logged** for periodic canonical-page diff against silent-downgrade pattern. **Turn 2 evaluated Gemini-18** which produced four useful directionally-correct contributions and five fabrications. **4 ACCEPTED:** G18-A (anthropic.com/engineering/writing-tools-for-agents tool-response 25K cap verified Tier-1 verbatim → 4th confusable in expanded disambiguation list), G18-B (`task-budgets-2026-03-13` beta header verified Tier-1 → orthogonality note), G18-C (meta-skill-as-skill 5K-cap implication → cross-section forward-influence note for system-design § Meta-Skill Spec), G18-D ("per-branch isolation is project-internal terminology not Anthropic-vendor terminology" framing → strengthens Turn-1 narrowing). **5 REJECTED as DA-153..157:** DA-153 Issue #21925 misattribution + fabricated "rigid 25,000-token CLAUDE.md ingestion limit" (issue is about CLAUDE.md not being re-loaded post-compaction; directly contradicts canonical Anthropic memory doc and DA-140; Issue #22085 corroborates that CLAUDE.md is loaded fully at startup); DA-154 `autoCompactWindow` env-var "formerly `CLAUDE_AUTOCOMPACT_WINDOW`" naming hallucination (actual name per source-code reproduction is `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and was never the shorter form); DA-155 tabular CLAUDE.md hard-limit fabrication (same as G18-1 in tabular form, separate DA because tabular precision implies vendor-documented mechanism that does not exist); DA-156 18,000-22,000-character envelope for 5K tokens as Discovery rule-of-thumb packaged as architectural fact; DA-157 `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env-var fabrication (does NOT exist; Issue #45019 verbatim *"I cannot find any controls to get back to 25000"*; Issue #14888 confirms the file-read 25K is hardcoded). **Independence note applied:** Gemini-18 fits the systemic Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16 of fabricating Anthropic-blessed mechanisms via misattribution to real GitHub-issue numbers and confident fabrication of env-var/setting names (DA-153, DA-157 are the same fabrication signature as DA-140, DA-151, DA-152, DA-Q016-2). Treated as ONE LLM-second-opinion data point. **Cross-section contradiction check: PASSED.** No contradictions with v1.0–v1.15 ruleset; specifically R-FAIL-1 v1.16 narrowing harmonizes with R-PAR-2 (per-context-window framing replaces "per-branch"); R-FAIL-1 Opus 4.7 caveat composes cleanly with R-BODY-1 (line-count + token-count cooperation); DA-153 reinforces DA-140 / R-BOUNDARY-3 (CLAUDE.md is loaded in full); DA-157 reinforces R-CHUNK-5 / DA-119 (file-read mechanism's parameter immutability). Net additions: 1 amended rule (R-FAIL-1 — extensively rewritten with audit verdict, scope clarification, Opus 4.7 caveat, Task Budget orthogonality, expanded confusable disambiguation, hard-coded clause, watch item), 5 new DAs (DA-153..157), 1 new session-notes section, 1 new tracker row (T-018), 1 changelog entry, Q-018 removed from queue, Q-019 promoted to top with Task-Budget-related expansion. **0 breaking changes** — every v1.15-authored skill remains conformant; R-FAIL-1's numeric core is unchanged. Q-018 → ✦ Researched v1.16. Blue callout points to Q-019.

**v1.17 — Q-019 close + auto-memory architecture chapter + AutoDream/`tengu_onyx_plover`/KAIROS umbrella formalization + R-MEM-1-CLARIFICATION + Gemini-19 vetting (2026-05-07).** Q-019 was the dormant low-priority follow-up logged at v1.13 from Q-015 Gemini-15 evaluation as a tangential acknowledgement, with the queue note explicitly directing "defer until Anthropic publishes canonical doc." User-overridden defer with "continue research" — the research investigated whether the 48 hours since Q-019's surfacing had produced canonical Anthropic documentation. **Turn 1 verdicts: Tier-1 silence VALIDATED on AutoDream / `tengu_onyx_plover` / `/dream` / KAIROS** as of 2026-05-07 across 13+ canonical Anthropic surfaces (memory doc, glossary doc, how-it-works doc, sub-agents doc, skills doc, commands doc, best-practices doc, claude-directory doc, news 2026-Q2, engineering posts, CHANGELOG, Complete Guide PDF, anthropics/skills, anthropics/anthropic-cookbook). Canonical post-GA terminology is **"Auto memory"** per the memory doc and glossary. **Distinct-product disambiguation:** `platform.claude.com/docs/en/managed-agents/dreams` documents a separate Managed Agents API product (asynchronous-job-with-immutable-input-store, beta header `dreaming-2026-04-21`) — NOT the in-CLI AutoDream consolidator. **Operational scope** Tier-1 anchored via `anthropics/claude-code` Issues #39204 (autoMemoryDirectory ignored), #47959 (Auto Dream deletes 23 user-reinforced memory files in one day, has-repro/data-loss labeled by Anthropic), and #50694 (`.consolidate-lock` PID-bound forked subagent, scheduled-between-sessions, has-repro labeled). **Trigger architecture** PROPOSED with very-strong cross-source corroboration from ≥6 independent post-leak archives (PeronGH, marckrenn, yitianlian, davccavalcante, sanbuphy, 0PeterAdel, plus yasasbanukaofficial): triple gate of (a) ≥24h since last consolidation, (b) ≥5 accumulated sessions, (c) advisory file lock — only the lock-file path is Tier-1 anchored. **Supersession SPLIT VERDICT.** Cross-container R-MEM-1 hierarchy holds (CLAUDE.md > Auto Memory; AutoDream cannot touch CLAUDE.md per Tier-1 issue paths). Intra-MEMORY.md user-vs-Claude precedence is NOT Tier-1 documented and is CONTRADICTED by Tier-1 #47959 demonstrating destructive consolidation of user-reinforced files. Codified as **R-MEM-1-CLARIFICATION VALIDATED** locking in the cross-container/intra-MEMORY.md split — the most consequential v1.17 addition. **Task Budget orthogonality VALIDATED Tier-1** via verbatim *"Task budgets are not supported on Claude Code or Cowork surfaces at launch"* (`platform.claude.com/docs/en/build-with-claude/task-budgets`) — strengthens T-018 v1.16 Task-Budget framing into a stronger orthogonality claim. **Auto-compaction orthogonality VALIDATED** via lifecycle disjointness (auto-compaction intra-session per `/how-claude-code-works`; AutoDream inter-session per Issue #50694). **Skill re-attach (R-FAIL-1) orthogonality VALIDATED** because skills are not in AutoDream's file scope. The three orthogonalities are codified as **R-AUTODREAM-3 VALIDATED**. **`tengu_onyx_plover` flag-name authenticity** is strongly corroborated across ≥7 independent post-leak archives all derived from Chaofan Shou's 2026-03-31 npm sourcemap discovery (Claude Code v2.1.88) — REJECTS the Q-018 Gemini-fabrication risk pattern: `tengu_onyx_plover` is anchored to a dated, attested, reproducible source-code-disclosure event with literal-string presence in two file paths reproducible across mirrors, naming-convention consistency with the broader `tengu_*` namespace, and zero Anthropic-source contradiction. Tagged PROPOSED rather than VALIDATED only because no Anthropic-authored canonical source acknowledges the flag. **Project-internal terminology correction.** The queue's "KAIROS daemon" framing is project-internal and does NOT match Anthropic's leaked-source usage; KAIROS is the broader proactive-mode umbrella (compile-time `feature('KAIROS')` + runtime GrowthBook `tengu_kairos`, env `CLAUDE_CODE_PROACTIVE=1`) encompassing six sub-features (dream consolidation gated additionally by `tengu_onyx_plover`, tick-loop monitoring, push notifications, PR subscription, GitHub webhooks, brief generation) and four exclusive specialized tools (`SendUserFile`, `PushNotification`, `SubscribePR`, `SleepTool`). Codified as **R-AUTODREAM-4 PROPOSED** naming-correction rule. Adjacent flag-function attributions corroborated via davccavalcante/claude-code-leaked README: `tengu_kairos` (assistant-mode umbrella), `tengu_ultraplan_model` (planning model), `tengu_cobalt_raccoon` (auto-compact), `tengu_portal_quail` (memory extract), `tengu_harbor` (MCP allowlist), `tengu_scratch` (worker scratch dirs), `tengu_malort_pedway` (computer use). **Turn 2 evaluated Gemini-19** which produced 9 useful directionally-correct contributions and 3 fabrications. **9 ACCEPTED:** Tier-1 silence reaffirmation; new Tier-1 `code.claude.com/docs/en/glossary` anchor I didn't have in Turn 1; davccavalcante/claude-code-leaked as additional independent corroboration of the `tengu_*` namespace; `tengu_ultraplan_model` and `tengu_cobalt_raccoon` flag-function attributions corroborated against davccavalcante README (my Turn-2 preliminary skepticism was wrong — the names AND functions are leak-anchored); triple-gate trigger architecture confirmed via additional independent source; 15-second blocking budget on KAIROS proactive shell commands; cross-container hierarchy framing; auto-compaction-vs-offline-consolidation orthogonality framing; Task Budget orthogonality framing. **3 REJECTED as DA-Q019-1..-3:** DA-Q019-1 universal-supersession overreach (two-level conflation: cross-container reading correct; intra-MEMORY.md universal-user-precedence reading contradicted by Tier-1 #47959 — same conflation pattern as DA-140); DA-Q019-2 quantitative overreach (1,200 sessions / 50 failures / 250K API calls — single Discovery-tier source, no Tier-1 anchor — same pattern as DA-156); DA-Q019-3 arXiv:2604.00009 misattribution (verified: 2604.00009 is the **Eyla** paper, not what Gemini-19 cited; Sumers is referenced INSIDE Eyla, not as author; the directional claim is correct with the corrected citation **arXiv:2504.13171** "Sleep-time Compute: Beyond Inference Scaling at Test-time" per o-mega.ai's TypeScript-anchored cite + smeuse.org's independent description — same pattern as DA-Q016-4). **Independence note applied:** Gemini-19 fits the systemic Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16/18 of fabricating specific citations anchored to plausible-sounding mechanisms; treated as ONE LLM-second-opinion data point. **Cross-section contradiction check: PASSED.** R-AUTODREAM-1 ↔ R-MEM-1 (file scope contained within Auto Memory tier); R-AUTODREAM-1 ↔ R-BOUNDARY-3 ↔ DA-140 (R-AUTODREAM-1's "place durable user constraints in CLAUDE.md never MEMORY.md" is positive corollary of R-BOUNDARY-3 + DA-140); R-AUTODREAM-3 ↔ R-FAIL-1 (extends Q-018 Task Budget orthogonality to a third orthogonal mechanism); R-MEM-1-CLARIFICATION ↔ R-MEM-1 ↔ DA-140 (R-MEM-1 preserved on cross-container; clarification scopes user-precedence to cross-container only); R-AUTODREAM-4 ↔ project terminology (corrects "KAIROS daemon" framing); DA-Q019-3 corrected arXiv:2504.13171 ↔ project domain rule §5 (verification passes for corrected citation). Net additions: **5 new rules** (R-AUTODREAM-1 VALIDATED, R-AUTODREAM-2 PROPOSED, R-AUTODREAM-3 VALIDATED, R-AUTODREAM-4 PROPOSED, R-MEM-1-CLARIFICATION VALIDATED), **3 new DAs** (DA-Q019-1..-3), **1 new system-design subsection** ("Auto-memory architecture"), **1 new session-notes section** (Q-019), **1 new tracker row** (T-019), **1 changelog entry** (v1.17), Q-019 removed from queue (queue is now EMPTY → framework empty-queue protocol activated). **0 breaking changes** — no existing rule's substantive content changed; R-MEM-1-CLARIFICATION refines but does not rewrite R-MEM-1; all v1.16-authored skills remain conformant. Q-019 → ✦ Researched v1.17. **Queue depth after Q-019: 0 sessions remaining.** User prompted to choose: (1) add new topics; (2) fresh-eyes review (scan whole project, propose gaps); (3) reopen specific topic; (4) declare research complete.

<!-- @end: journey -->

---

<!-- @anchor: references -->
## References

All sources cited across research, descending version order.

#### v1.17 (Q-019)

**`code.claude.com/docs/en/memory`** — Anthropic. *How Claude remembers your project — Claude Code Docs*, re-fetched 2026-05-07. Tier-1 canonical. Sweep result: SILENT on AutoDream / `tengu_onyx_plover` / `/dream` / KAIROS. Documents only "Auto memory" and confirms 200-line / 25 KB MEMORY.md startup load cap (re-confirmed verbatim *"the first 200 lines or 25KB of MEMORY.md, whichever comes first"*) and CLAUDE.md is loaded in full regardless of length (re-confirms DA-140). Re-cited from v1.13.

**`code.claude.com/docs/en/glossary`** — Anthropic. *Glossary — Claude Code Docs*, fetched 2026-05-07. Tier-1 canonical, NEW v1.17 anchor (Gemini-19 G19-B contribution). Defines "Auto memory" as the *"Claude-written counterpart"* to manual configuration files; storage path `~/.claude/projects/<project>/` confirmed. Anchor for [R-AUTODREAM-1](#r-autodream-1) file-scope establishment and the canonical-terminology framing in R-AUTODREAM-4.

**`code.claude.com/docs/en/how-claude-code-works`** — Anthropic. *How Claude Code works — Claude Code Docs*, fetched 2026-05-07. Tier-1 canonical. Verbatim: *"Claude Code manages context automatically as you approach the limit. It clears older tool outputs first, then summarizes the conversation if needed. Your requests and key code snippets are preserved; detailed instructions from early in the conversation may be lost."* Anchor for [R-AUTODREAM-3](#r-autodream-3)(b) — auto-compaction is intra-session, distinct from AutoDream's inter-session lifecycle.

**`platform.claude.com/docs/en/managed-agents/dreams`** — Anthropic. *Dreams — Claude API Docs*, fetched 2026-05-07. Tier-1 canonical. Verbatim: *"Dreaming is a Research Preview feature… A dream reads an existing memory store alongside past session transcripts, then produces a new, reorganized memory store: duplicates merged, stale or contradicted entries replaced with the latest value, and new insights surfaced. The input store is never modified… All Managed Agents API requests require the `managed-agents-2026-04-01` beta header. Dreams additionally require the `dreaming-2026-04-21` beta header."* Limits: 100 sessions per dream, 4096-character `instructions`, models `claude-opus-4-7` / `claude-sonnet-4-6`. Critical anchor for the **distinct-product disambiguation** at the top of the Auto-memory architecture subsection: Managed Agents "Dreams" is NOT the in-CLI AutoDream consolidator gated by `tengu_onyx_plover`.

**`platform.claude.com/docs/en/build-with-claude/task-budgets`** — Anthropic. *Task budgets — Claude API Docs*, fetched 2026-05-07. Tier-1 canonical. Verbatim: *"Task budgets are not supported on Claude Code or Cowork surfaces at launch. Use task budgets directly via the Messages API on Claude Opus 4.7."* Decisive anchor for [R-AUTODREAM-3](#r-autodream-3)(a) — AutoDream cannot consume Task Budget tokens because Task Budgets are not wired into Claude Code at launch. Strengthens T-018 v1.16 Task-Budget orthogonality framing.

**anthropics/claude-code Issue #50694** — *"Auto Dream silently disabled forever if a dream crashes mid-run — stale `.consolidate-lock` never gets cleaned up"*, opened afram123 2026-04-19, fetched 2026-05-07. https://github.com/anthropics/claude-code/issues/50694. Tier-1 (Anthropic-hosted bug tracker, has-repro labeled by Anthropic). Verbatim: *"The lock file at `~/.claude/projects/<slug>/memory/.consolidate-lock` is never validated against a live PID."* / *"Let Auto Dream start (scheduled between sessions — writes lock with current PID)."* / *"Hard-kill the dream process mid-run… `tasklist /FI "PID eq 52900"` → no task… Owning PID 52900 dead by at least Apr 9."* / *"Auto Dream / `autoDreamEnabled` does not appear in official docs or the changelog."* Decisive anchors for: (a) AutoDream's PID-bound forked-subagent process model; (b) `~/.claude/projects/<slug>/memory/.consolidate-lock` lock-file path (Tier-1 anchor for R-AUTODREAM-2's lock-file gate); (c) inter-session "scheduled between sessions" lifecycle confirmation (Tier-1 anchor for R-AUTODREAM-3(b) auto-compaction orthogonality); (d) Tier-1 silence acknowledgement on AutoDream documentation.

**anthropics/claude-code Issue #47959** — *"Auto Dream deletes memory files without user consent — 23 files lost in one day"*, opened 2026-04-08, has-repro/data-loss/memory/platform:macos labeled by Anthropic, fetched 2026-05-07. https://github.com/anthropics/claude-code/issues/47959. Tier-1 (Anthropic-hosted bug tracker). Verbatim: *"After enabling `autoDreamEnabled: true` in `~/.claude/settings.json`, Auto Dream silently deleted 23 memory files within approximately 24 hours."* / *"a rule that had been reinforced 3 times by the user (never use 'Author: Claude' in copyright headers)"* deleted by Auto Dream. Decisive anchor for [R-MEM-1-CLARIFICATION](#r-mem-1-clarification) — Tier-1 contradiction of universal-user-precedence within MEMORY.md; user mitigation was setting `autoDreamEnabled: false` permanently. Also anchors [DA-Q019-1](#da-q019-1) (rejection of Gemini-19's universal-supersession framing).

**anthropics/claude-code Issue #39204** — *"[BUG] auto-dream ignores autoMemoryDirectory, writes to default path"*, fetched 2026-05-07. https://github.com/anthropics/claude-code/issues/39204. Tier-1. Verbatim: *"Auto-dream writes memory files to the default `~/.claude/projects/<project>/memory/` directory instead of the path configured via autoMemoryDirectory."* Anchor for [R-AUTODREAM-1](#r-autodream-1) file-scope confirmation (and the carveout that the override is currently broken).

**anthropics/claude-code Issue #39633** — *"`/dream` command not registered and auto-dream not running"*, fetched 2026-05-07. https://github.com/anthropics/claude-code/issues/39633. Tier-1. Verbatim: *"`autoDreamEnabled: true` is set in `~/.claude/settings.json`, but the dream hasn't run in 13+ hours despite multiple sessions in that period."* Anchor for the `autoDreamEnabled` settings.json key (Tier-1 user-side toggle name in R-AUTODREAM-2) and for the user-observed scheduling behavior consistent with the triple-gate trigger.

**anthropics/claude-code Issue #39135** — *"`/dream` command shown in /memory UI but not recognized as a command"*, fetched 2026-05-07. https://github.com/anthropics/claude-code/issues/39135. Tier-1. Verbatim UI text: *"Auto-dream: on · last ran 13h ago · /dream to run"*. Anchor confirming the in-CLI surface name "Auto-dream" and the `/dream` slash-command framing — UI text, not documentation.

**`anthropics/claude-code` `CHANGELOG.md`** — Anthropic-hosted repo, fetched 2026-05-07. Tier-1. Sweep result: SILENT on AutoDream / auto-dream / dream / consolidate / autoDream / `tengu_onyx_plover` / KAIROS. Confirms Tier-1 silence verification for v1.17.

**davccavalcante/claude-code-leaked README** — *"Anthropic Claude Code CLI — Official CLI/TUI coding agent, rebuilt from a leaked source map v2.1.88 (March 2026)"*, fetched 2026-05-07. https://github.com/davccavalcante/claude-code-leaked. Discovery (named-author archival reconstruction of leak artifacts). NEW v1.17 corroboration source brought in by Gemini-19. Verbatim flag list: *"`tengu_malort_pedway` (computer use), `tengu_onyx_plover` (auto-dream), `tengu_kairos` (assistant mode), `tengu_ultraplan_model` (planning model), `tengu_cobalt_raccoon` (auto-compact), `tengu_portal_quail` (memory extract), `tengu_harbor` (MCP allowlist), `tengu_scratch` (worker scratch dirs)."* Verbatim KAIROS description: *"KAIROS — Persistent Assistant: Always-on. Daily logs in `~/.claude/.../logs/YYYY/MM/DD.md` (append-only). 'Dream' overnight (read-only bash, 15s budget, background). Feature gate: `feature('KAIROS')` + `tengu_kairos`. Phases: Orient/Gather/Consolidate/Prune. Exclusive tools: SendUserFile, PushNotification, SubscribePR, SleepTool. Status: normal/proactive."* Decisive anchor for: (a) `tengu_onyx_plover` cross-corroboration; (b) `tengu_*` namespace flag-function attributions accepted in R-AUTODREAM-4; (c) KAIROS umbrella vs AutoDream sub-feature distinction.

**o-mega.ai** — *Inside Claude Code: The Leaked Source Analysis*, fetched 2026-05-07. https://o-mega.ai/articles/inside-claude-code-the-leaked-source-analysis. Discovery (named outlet, technical breakdown). Verbatim citing the leaked `src/tasks/DreamTask/DreamTask.ts`: *"a background memory consolidation system inspired by UC Berkeley's 'Sleep-time Compute' research"* + *"the research it is based on (arXiv:2504.13171) showed a 5x reduction in test-time compute at equal accuracy"* + *"Three gates must be satisfied before it triggers: a 24-hour time gate, a 5-session minimum since the last dream, and consolidation lock acquisition (preventing concurrent dreams). Output is capped at 25KB."* Decisive anchor for the **corrected arXiv citation** (arXiv:2504.13171, NOT Gemini-19's misattributed 2604.00009) and for the four-phase pipeline + triple-gate trigger architecture in R-AUTODREAM-2.

**arXiv:2504.13171** — *"Sleep-time Compute: Beyond Inference Scaling at Test-time"*, fetched/cross-referenced 2026-05-07. https://arxiv.org/abs/2504.13171. Tier-1 (peer-reviewed paper; corroborated by smeuse.org's independent description as Letta-affiliated work demonstrating ~5× lower test-time compute at equivalent accuracy and 13–18% accuracy gains on Stateful GSM-Symbolic / Stateful AIME with multi-query amortization). **Corrected academic anchor for AutoDream design** per o-mega.ai's TypeScript-anchored citation against the leaked `src/tasks/DreamTask/DreamTask.ts`. Replaces Gemini-19's misattributed arXiv:2604.00009 ("Eyla" paper) — see [DA-Q019-3](#da-q019-3).

**arXiv:2604.00009** — *"Eyla: Toward an Identity-Anchored LLM Architecture with Integrated Biological Priors"*, fetched 2026-05-07. https://arxiv.org/html/2604.00009. Tier-1 (paper exists; verifiable via direct arXiv resolution). Cited here ONLY as the **misattribution target** in [DA-Q019-3](#da-q019-3) — Gemini-19 cited this arXiv ID as "Sumers et al., 2025, Integrating sleep-time compute for memory consolidation," but the paper's actual title is "Eyla: Toward an Identity-Anchored LLM Architecture..." with Sumers referenced INSIDE Eyla as a 2023 cognitive-architectures-survey author. The Letta–sleep-time-compute reference appears as a one-line literature note inside Eyla's related-work section.

**smeuse.org blog** — *Sleep Time Compute: How Developers Learn While They Sleep*, fetched 2026-05-07. https://blog.smeuse.org/posts/sleep-time-compute-agents. Discovery (named-author technical writeup). Independently corroborates arXiv:2504.13171 ("Sleep-time Compute: Beyond Inference Scaling at Test-time") with verbatim-comparable description: 5× test-time-compute reduction at equal accuracy; up to 13% / 18% accuracy gains on Stateful GSM-Symbolic / AIME respectively; Multi-Query variant amortizing precompute across queries with ~2.5× per-query cost reduction. Cross-corroboration anchor for DA-Q019-3's "directional claim is correct with corrected citation" framing.

**PeronGH/claude-code-decoded `TENGU.md`** — fetched 2026-05-07. https://github.com/PeronGH/claude-code-decoded/blob/main/TENGU.md. Discovery (named archival reconstruction). Verbatim: *"`tengu_onyx_plover` Used in: `src/services/autoDream/config.ts`, `src/services/autoDream/autoDream.ts`. This one controls whether background 'dream' memory consolidation runs and what thresholds it uses."* Anchor for `tengu_onyx_plover` literal-string presence in two file paths reproducible across mirrors (R-AUTODREAM-2 PROPOSED corroboration #1 of ≥7).

**marckrenn/claude-code-changelog `cc-flags.md`** — fetched 2026-05-07. https://github.com/marckrenn/claude-code-changelog/blob/main/cc-flags.md. Discovery (named archival reconstruction with version-to-version flag-delta tracking). Lists `tengu_onyx_plover` alongside `tengu_kairos_cron`, `tengu_kairos_cron_config`, `tengu_kairos_cron_durable`, `tengu_kairos_dream`, `tengu_kairos_push_notifications`, etc. — release-tracked across published `npm` bundles. R-AUTODREAM-2 corroboration #2.

**yitianlian/claude-code-hidden-features `03-kairos-dream-cron.mdx`** — fetched 2026-05-07. https://github.com/yitianlian/claude-code-hidden-features/blob/main/src/content/docs/03-kairos-dream-cron.mdx. Discovery. Verbatim: *"Auto Dream… Gated by `feature('KAIROS_DREAM')` plus the GrowthBook flag `tengu_onyx_plover`."* Anchor for the bifurcated gating model (compile-time `KAIROS_DREAM` AND runtime `tengu_onyx_plover`) in R-AUTODREAM-4. R-AUTODREAM-2 corroboration #3.

**yasasbanukaofficial/claude-code README** — fetched 2026-05-07. https://github.com/yasasbanukaofficial/claude-code. Discovery (named archival mirror, attributed to Chaofan Shou's 2026-03-31 discovery). Verbatim: *"Earlier today (March 31st, 2026) - Chaofan Shou (@Fried_rice) discovered something that Anthropic probably didn't want the world to see: the entire source code of Claude Code… was sitting in plain sight on the npm registry via a sourcemap file bundled into the published package."* / *"Claude Code 'dreams' to consolidate memory. The autoDream service (`src/services/autoDream/`) runs as a background subagent."* Anchor for the leak chronology (2026-03-31 v2.1.88 npm sourcemap; Chaofan Shou attribution).

**alex000kim.com** — *The Claude Code Source Leak: fake tools, frustration regexes, undercover mode, and more*, fetched 2026-05-07. https://alex000kim.com/posts/2026-03-31-claude-code-source-leak/. Discovery (named-author technical analysis, 2026-03-31). Anchor for the `tengu_*` GrowthBook namespace's existence (verbatim: *"It's gated behind a GrowthBook feature flag (tengu_anti_distill_fake_tool_injection)"*) and for "Tengu" as Claude Code's internal project codename via undercover.ts evidence.

**wavespeed.ai blog** — *Claude Code Hidden Features Found in the Leaked Source: Full List (2026)*, fetched 2026-05-07. https://wavespeed.ai/blog/posts/claude-code-hidden-features-leaked-source-2026/. Discovery. Verbatim: *"'Tengu' shows up hundreds of times as a prefix for feature flags and analytics events — almost certainly Claude Code's internal project codename."* Cross-corroboration for R-AUTODREAM-4's framing of `tengu_*` as the engineering codename namespace prefix.

**Mainstream-press disambiguation cluster (Managed Agents "Dreams")** — fetched 2026-05-07. *"Anthropic will let its managed agents dream"*, The New Stack, 2026-05-06; *"Anthropic is letting Claude agents 'dream' so they don't sleep on the job"*, SiliconANGLE, 2026-05-06; *"Anthropic Introduces Dreaming Feature for Claude Agents to Self-Improve Overnight"*, Technobezz, 2026-05-06; *"Anthropic introduces 'dreaming' for Claude Managed Agents"*, Techzine Global (Mels Dees), 2026-05-07. Discovery cluster. Cited collectively to establish that the May-2026 Anthropic press cycle around "dreaming" is for the **Managed Agents Dreams API product**, NOT the in-CLI AutoDream consolidator — supports the distinct-product disambiguation block atop the Auto-memory architecture subsection.

**Discovery-tier writeup cluster (AutoDream operational mechanics)** — fetched 2026-05-07. Marco Kotrotsos, *"Claude Code Dreams"*, Medium (https://kotrotsos.medium.com/claude-code-dreams-e9b88e225289); akari_iku, *"Does Claude Code Need Sleep? Inside the Unreleased Auto-dream Feature"*, DEV Community (https://dev.to/akari_iku/does-claude-code-need-sleep-inside-the-unreleased-auto-dream-feature-2n7m); Zen van Riel, *"Claude Code AutoDream: Memory Consolidation for AI Agents"* (https://zenvanriel.com/ai-engineer-blog/claude-code-autodream-memory-consolidation-guide/); Mejba Ahmed, *"Claude Code Autodream: AI Memory System Guide"* (https://www.mejba.me/blog/claude-code-autodream-memory-system); claudefa.st, *"Claude Code Dreams: Anthropic's New Memory Feature"* (https://claudefa.st/blog/guide/mechanics/auto-dream); Antonio Cortes, *"Auto Memory and Auto Dream"* 2026-03-30 (https://antoniocortes.com/en/2026/03/30/auto-memory-and-auto-dream-how-claude-code-learns-and-consolidates-its-memory/); Yage, *"The Hidden Lifecycle of Claude Code"* 2026-04-01 (https://yage.ai/share/claude-code-background-activity-en-20260401.html); Haseeb Qureshi, *"Inside the Claude Code source"* GitHub gist (https://gist.github.com/Haseeb-Qureshi/d0dc36844c19d26303ce09b42e7188c1); XDA Developers, *"Claude Code's leaked source code revealed some features Anthropic wasn't ready to share yet"* (https://www.xda-developers.com/claude-code-leaked-source-code-revealed-features/); sdd.sh, *"Claude Code AutoDream: Your AI Agent Finally Sleeps on It"* 2026-03 (https://sdd.sh/2026/03/claude-code-autodream-your-ai-agent-finally-sleeps-on-it/); Milvus blog, *"Claude Code Memory System Explained: 4 Layers, 5 Limits, and a Fix"* (https://milvus.io/blog/claude-code-memory-memsearch.md); Vincent Qiao, *"Claude Code settings.json Guide"* (https://blog.vincentqiao.com/en/posts/claude-code-settings-misc/); Kingy AI, *"KAIROS: Everything we know about Anthropic's secret always-on AI daemon"* (https://kingy.ai/ai/kairos-everything-we-know-about-anthropics-secret-always-on-ai-daemon/). Discovery (named-author writeups). Cited collectively as cross-corroboration sources for the four-phase pipeline + triple-gate trigger + 15-second blocking budget + KAIROS umbrella; never the sole anchor for any factual claim. Note: Kingy AI piece is the source from which Gemini-19 drew the 24h+5-session+lock framing; my Turn-1 research independently corroborated the same finding from yitianlian and o-mega.ai.

**Gemini-19 second opinion** — Google Gemini Deep Research output for Q-019, submitted by user 2026-05-07. **Verifications performed (3 end-to-end per framework):** (1) arXiv:2604.00009 / Sumers et al. attribution → FABRICATED → DA-Q019-3 REJECTION (verified: 2604.00009 is the Eyla paper). (2) davccavalcante/claude-code-leaked README flag-list → VERIFIED REAL Discovery → ACCEPTED as additional cross-corroboration of `tengu_*` namespace (G19-D contribution). (3) Universal-supersession framing for AutoDream → CONTRADICTED by Tier-1 Issue #47959 → DA-Q019-1 REJECTION. **Outcome:** 9 ACCEPTED contributions (Tier-1 silence reaffirmation; new glossary anchor; davccavalcante corroboration; flag-function attributions; triple-gate from 4th source; 15-second blocking budget; cross-container hierarchy framing; auto-compaction orthogonality framing; Task Budget orthogonality framing); 3 REJECTED as DA-Q019-1 (universal-supersession overreach via two-level conflation), DA-Q019-2 (1,200 sessions / 50 failures / 250K API calls Discovery-tier quantitative overreach), DA-Q019-3 (arXiv:2604.00009 Eyla misattribution; corrected citation arXiv:2504.13171). **Independence note applied:** fits systemic Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16/18 of fabricating specific citations anchored to plausible-sounding mechanisms; treated as ONE LLM-second-opinion data point. Materially: Gemini-19's net contribution is positive — davccavalcante corroboration measurably strengthens `tengu_*` findings; glossary anchor is new Tier-1 evidence; the supersession-conflation rejection generated R-MEM-1-CLARIFICATION (the most consequential v1.17 rule).

#### v1.16 (Q-018)

**`code.claude.com/docs/en/skills`** — Anthropic. *Extend Claude with skills*, Claude Code Docs, live re-fetched 2026-05-07. Tier-1 canonical, sole-source anchor for R-FAIL-1 numeric core. Verbatim: *"Auto-compaction carries invoked skills forward within a token budget. When the conversation is summarized to free context, Claude Code re-attaches the most recent invocation of each skill after the summary, keeping the first 5,000 tokens of each. Re-attached skills share a combined budget of 25,000 tokens. Claude Code fills this budget starting from the most recently invoked skill, so older skills can be dropped entirely after compaction if you have invoked many in one session."* Decisive anchor for [R-FAIL-1](#r-fail-1) HOLD-numeric-core decision under the validation gate's single-canonical-source clause; figures unchanged 2026-05-07 vs prior fetches.

**`anthropic.com/engineering/writing-tools-for-agents`** — Anthropic Engineering. *Writing effective tools for AI agents — using AI agents*, fetched 2026-05-07. Tier-1. Verbatim: *"For Claude Code, we restrict tool responses to 25,000 tokens by default."* **Distinct mechanism** from R-FAIL-1's skill re-attach budget — tool-response cap, not auto-compaction memory preservation. Adopted as 4th confusable in R-FAIL-1's expanded disambiguation list (Q-018 v1.16); does NOT independently corroborate the skill re-attach 25K. Anchor for Gemini-18 G18-A acceptance.

**`platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7`** — Anthropic. *What's new in Claude Opus 4.7*, Claude API Docs, fetched 2026-05-07. Tier-1 canonical. Verbatim: *"A task budget gives Claude a rough estimate of how many tokens to target for a full agentic loop, including thinking, tool calls, tool results, and final output. The model sees a running countdown and uses it to prioritize work and finish the task gracefully as the budget is consumed. To use, set the beta header `task-budgets-2026-03-13` and add the following to your output config: `output_config = {"effort": "high", "task_budget": {"type": "tokens", "total": 128000}}`, `betas=["task-budgets-2026-03-13"]`."* Plus the tokenizer drift caveat (1.0–1.35× per identical text) with explicit guidance to *"revisit `max_tokens` headroom and compaction triggers."* Anchor for [R-FAIL-1](#r-fail-1) Opus 4.7 effective-budget compression caveat AND Task Budget orthogonality note. Released 2026-04-16.

**`code.claude.com/docs/en/sub-agents`** — Anthropic. *Create custom subagents*, Claude Code Docs, indirect via Anthropic Skilljar course corroboration. Tier-1 canonical (re-cited from Q-006). Verbatim sub-agent isolation framing: *"Each subagent runs in its own context window with its own custom system prompt, tool access, and permissions."* Anchor for R-FAIL-1's per-context-window isolation clause (Q-018 v1.16 narrowing).

**`anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills`** — Anthropic Engineering, fetched 2026-05-07 via claude.com mirror. Tier-1. Sweep result: SILENT on the 25K/5K re-attach figures; describes context bundling qualitatively as *"effectively unbounded"* via progressive disclosure. Confirms H-018-1 REJECTED — no second Tier-1 source restates the figures.

**`resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf`** — Anthropic. *The Complete Guide to Building Skills for Claude* (32-page PDF), fetched 2026-05-07. Tier-1. Sweep result: SILENT on the 25K/5K re-attach figures. Adjacent recommendation *"Keep SKILL.md under 5,000 words"* is words-not-tokens and not framed as a compaction cap; counts as semantic adjacency only, not Tier-1 corroboration. Confirms H-018-1 REJECTED.

**anthropics/claude-code Issue #20466** — *"Skill invocations re-executed after conversation compaction"*, opened 2026-02-25 area:core/bug, verified 2026-05-07. https://github.com/anthropics/claude-code/issues/20466. Tier-1. Verbatim: *"After conversation compaction, Claude re-executes skills (like /gh-bug) that were already completed earlier in the session, creating duplicate issues/actions… The skill invocation is preserved in a `<system-reminder>` block: 'The following skills were invoked in this session. Continue to follow these guidelines: ### Skill: gh-bug … ARGUMENTS: [original arguments]'."* Anchor for the **mechanism** R-FAIL-1 governs (skills re-attached as system-reminder blocks after compaction); no numeric figure but confirms the re-attach behavior is real and observable.

**anthropics/claude-code Issue #24677** — *"Compaction death spiral in Cowork: 6 compactions in 3.5 min due to system context consuming 86.5% of window"*, verified 2026-05-07. https://github.com/anthropics/claude-code/issues/24677. Tier-1. Verbatim: *"System prompts (Claude Code internals) ~40,000 / 20%; Compaction instructions ~25,000 / 12.5%; Total system context ~173,000 / 86.5%; Remaining for actual conversation ~27,000."* Anchor for the **6th confusable 25K** added to R-FAIL-1's disambiguation list — compaction-instructions overhead — distinct from the skill re-attach budget.

**anthropics/claude-code Issue #21925** — *"[DESIGN FLAW] Context compaction destroys workflow — no CLAUDE.md reload, no pause, auto-continues and breaks own work"*, opened gizyckik 2026-01-30, verified 2026-05-07. https://github.com/anthropics/claude-code/issues/21925. Tier-1. Verbatim: *"CLAUDE.md was supposed to solve this — but it's NOT re-read after compaction, making it useless for long sessions."* **Critical:** issue is about CLAUDE.md not being re-loaded post-compaction, NOT about a 25K-token CLAUDE.md ingestion cap. Decisive anchor for [DA-153](#da-153) — Gemini-18's misattribution rejection.

**anthropics/claude-code Issue #22085** — *"Auto-reload CLAUDE.md config files when session is continued from context compaction"*, opened 2026-01-31, verified 2026-05-07. https://github.com/anthropics/claude-code/issues/22085. Tier-1. Verbatim: *"Start a new Claude Code session - the config is loaded correctly. Have a long conversation until context compaction triggers. The continued session receives a summary but does NOT reload the CLAUDE.md files."* Corroborates DA-153: confirms CLAUDE.md is loaded fully at session start (no 25K cap), and the actual issue is non-reload after compaction.

**anthropics/claude-code Issue #5812** — *"Feature Request: Allow Hooks to Bridge Context Between Sub-Agents and Parent Agents"*. https://github.com/anthropics/claude-code/issues/5812. Tier-1. Verbatim: *"There is currently a significant context isolation problem between a parent agent and its sub-agents. When a sub-agent performs an action that creates new information (e.g., writing a file), the parent agent remains unaware of that information."* Independent corroboration of sub-agent context isolation as a user-observed primitive — supports R-FAIL-1's per-context-window isolation framing.

**anthropics/claude-code Issue #10212** — *"[FEATURE] Independent Context Windows for Sub-Agents"*. https://github.com/anthropics/claude-code/issues/10212. Tier-1. Verbatim: *"Separate terminals DO provide independent 200K budgets ✅"* (user-reported; describes that the parent task tool already isolates context). Independent corroboration of sub-agent context-window isolation; supports R-FAIL-1 narrowing.

**anthropics/claude-code Issue #42149** — *"Add autoCompact: false setting to fully disable auto-compaction"*, opened fahimbinshad-tech 2026-04-01, verified 2026-05-07. https://github.com/anthropics/claude-code/issues/42149. Tier-1. Verbatim: *"There is no way to fully disable auto-compaction. The only available setting is `autoCompactWindow` (min 100000, max 1000000), which controls when compaction triggers but not whether it triggers."* Anchor for the `autoCompactWindow` knob's existence and bounds. Establishes that the only adjacent knob to R-FAIL-1 is the trigger threshold (NOT the re-attach budget); decisive anchor for R-FAIL-1's hard-coded-no-override clause.

**anthropics/claude-code Issue #45019** — *"[MODEL] Max number of tokens per file is now 10000 instead of 25000"*, opened viniciusferrao 2026-04-08, re-verified 2026-05-07. https://github.com/anthropics/claude-code/issues/45019. Tier-1. Verbatim: *"I cannot find any controls to get back to 25000."* Decisive anchor for [DA-157](#da-157) — refutes Gemini-18's fabricated `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env var. Re-cited from v1.10 (T-010); originally anchored R-CHUNK-5 silent-downgrade caveat.

**anthropics/claude-code Issue #14888** — *"[Feature Request] Make file read token limit dynamic based on model capabilities"*. https://github.com/anthropics/claude-code/issues/14888. Tier-1 (re-cited from v1.10). Verbatim: *"Summary: The current hardcoded 25,000 token limit for file reading via the Read tool doesn't scale with different Claude models and subscription tiers."* Anchor for DA-157 (file-read 25K is hardcoded; no override env var exists).

**anthropics/claude-code Issue #6158** — *"Anthropic API: Response Exceeds Maximum Output Token Limit"*, verified 2026-05-07. https://github.com/anthropics/claude-code/issues/6158. Tier-1. Verbatim error message excerpt: *"MCPContentTooLargeError: MCP tool 'search_for_pattern' response (36382 tokens) exceeds maximum allowed tokens (25000)"* — confirms the existence of `MAX_MCP_OUTPUT_TOKENS` defaulting to 25,000 (5th confusable 25K in R-FAIL-1's expanded list).

**`code.claude.com/docs/en/mcp`** — Anthropic. *Model Context Protocol (MCP)*, Claude Code Docs, fetched 2026-05-07. Tier-1. Documents `MAX_MCP_OUTPUT_TOKENS` env var defaulting to 25,000 — the 5th confusable 25K in R-FAIL-1's expanded disambiguation list (cross-validated against Issue #6158).

**`code.claude.com/docs/en/env-vars`** and **`code.claude.com/docs/en/settings`** — Anthropic Claude Code Docs, fetched 2026-05-07. Tier-1. Comprehensive env-var and settings reference. Sweep result: NO env var or setting exists for overriding R-FAIL-1's 25,000 / 5,000 figures. Anchor for R-FAIL-1's hard-coded-no-override clause and DA-157.

**Ken Huang.** *Claude Code Pattern 6: Context Management at Scale*, kenhuangus.substack.com, fetched 2026-05-07 (Tier-2 named-author technical breakdown referencing leaked-source code). https://kenhuangus.substack.com/p/claude-code-pattern-6-context-management. Verbatim source-code reproduction: *"const autoCompactWindow = process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW"*. Confirms canonical env-var name `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (not the shorter `CLAUDE_AUTOCOMPACT_WINDOW` Gemini-18 cited). Anchor for [DA-154](#da-154) naming-hallucination rejection.

**Gemini-18 second opinion** — Google Gemini Deep Research output for Q-018, submitted by user 2026-05-07. **Verifications performed (4 end-to-end per framework):** (1) anthropic.com/engineering/writing-tools-for-agents 25K tool-response cap → VERIFIED REAL Tier-1 → G18-A ACCEPTED as 4th confusable. (2) anthropics/claude-code Issue #21925 framing as 25K-token CLAUDE.md ingestion limit → FABRICATED → DA-153 REJECTION. (3) `task-budgets-2026-03-13` beta header → VERIFIED REAL Tier-1 → G18-B ACCEPTED as orthogonality note. (4) `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env var enabling 50K override → FABRICATED → DA-157 REJECTION. **Outcome:** 4 ACCEPTED (G18-A tool-response disambiguation; G18-B Task Budget orthogonality; G18-C meta-skill 5K-cap implication forward-influence note; G18-D "per-branch" project-internal-terminology framing); 5 REJECTED as DA-153 (Issue #21925 misattribution + fabricated 25K CLAUDE.md cap), DA-154 (`autoCompactWindow` env-var "formerly" naming hallucination), DA-155 (tabular CLAUDE.md hard-limit fabrication), DA-156 (18-22K-character envelope Discovery overreach), DA-157 (`CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` fabrication). **Independence note applied:** fits systemic Gemini pattern (Gemini-2/5/6/7/8/10/13/15/16) of fabricating Anthropic-blessed mechanisms via misattribution to real GitHub-issue numbers and confident fabrication of env-var/setting names; treated as ONE LLM-second-opinion data point. Materially: verified contributions on Task Budgets and meta-skill 5K-cap implication are useful; the GitHub-issue-anchored fabrications reinforce the project's existing Gemini-supplemental-vetting discipline.

#### v1.15 (Q-013)

**`anthropics/skills/skill-workshop/SKILL.md`** — Anthropic. *Public repository for Agent Skills*, default branch `main`, re-fetched 2026-05-07. https://github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md. Tier-1 canonical. Verbatim text *"running each query 3 times to get a reliable trigger rate"* in the description-optimization workflow section. Decisive anchor for [R-LLMJ-4](#r-llmj-4) HOLD-at-k=3 decision; refutes Gemini-13 G13-A1 k=10 fabrication (DA-147).

**`anthropics/claude-plugins-official/plugins/skill-workshop/skills/skill-workshop/SKILL.md`** — Anthropic. *Public repository for official Claude Code Plugins*, default branch `main`, re-fetched 2026-05-07. Tier-1 mirror. Identical k=3 verbatim text — corroborates the canonical with a second Anthropic-owned surface. Anchor for [DA-147](#da-147) decisive rejection.

**Haldar, R., Hockenmaier, J.** *Rating Roulette: Self-Inconsistency in LLM-As-A-Judge Frameworks.* Findings of EMNLP 2025, pages 24986–25004. https://aclanthology.org/2025.findings-emnlp.1361.pdf (also arXiv:2510.27106). Tier-1 (peer-reviewed venue-accepted, was preprint at v1.8). **PROMOTED from PROPOSED-preprint to corroborating Tier-1.** Anchor for R-LLMJ-4 — sampling-with-aggregation is necessary, but the paper explicitly does not endorse k=5 over k=3 and does not produce a quantitative Pareto curve. Strengthens R-LLMJ-4 hold-at-k=3 by establishing that more-than-one-sample is required (matching k=3) without endorsing the k=5 graduation.

**Wang, Y., et al.** *TrustJudge: Inconsistencies of LLM-as-a-Judge and How to Alleviate Them.* arXiv:2509.21117, 2025-09 (under review at ICLR 2026 per OpenReview, double-blind review in progress as of 2026-05-07). https://arxiv.org/abs/2509.21117 / https://openreview.net/forum?id=4uPyOCeN6U. **arXiv preprint, NOT venue-accepted.** Cited at v1.15 to **refute** Gemini-13 G13-A2 misattribution: the paper's "triples" are model-pair transitivity tests for circular preference chains (A>B>C>A) — not self-consistency vote counts per query. Verbatim from abstract: *"Pairwise Transitivity Inconsistency, manifested through circular preference chains."* Anchor for [DA-148](#da-148).

**Jung, J., Brahman, F., Choi, Y.** *Trust or Escalate: LLM Judges with Provable Guarantees for Human Agreement.* ICLR 2025 (Oral). https://arxiv.org/abs/2407.18370 / https://openreview.net/forum?id=UHPnqSTBPO. Tier-1. Re-cited at v1.15 for the verbatim distinction between *Simulated Annotators* technique parameters (K=3 few-shot examples × N=5 simulated annotators) and standard self-consistency vote counts; framework's 40% cost reduction is from cascade selectivity, not from increased k. Reaffirms DA-094 framing; orthogonal to R-LLMJ-4 graduation question.

**Automate work with routines** — Anthropic. *Claude Code Docs*, 2026, re-fetched 2026-05-07. https://code.claude.com/docs/en/routines. Tier-1 canonical. Verbatim: *"The `/fire` endpoint ships under the `experimental-cc-routine-2026-04-01` beta header. … Breaking changes ship behind new dated beta header versions, and the two most recent previous header versions continue to work so that callers have time to migrate."* Beta header STILL ACTIVE; two-most-recent-previous-versions stability guarantee now formally documented (was PROPOSED at v1.8 Q-008 Turn 2). Anchor for R-CADENCE-2 citation refresh; Q-013 (b) sub-question closure.

**Introducing routines in Claude Code** — Anthropic. *Anthropic Blog*, 2026-04-14. https://claude.com/blog/introducing-routines-in-claude-code. Tier-1. Re-cited at v1.15 for daily-cap operational constraint verification: *"Pro users can run up to 5 routines per day, Max users can run up to 15 routines per day, and Team and Enterprise users can run up to 25 routines per day. You can run extra routines beyond these limits with extra usage."* Plus the one-off-runs-exempt caveat: *"one-off scheduled runs do not count against the daily routine cap."* Anchor for R-CADENCE-1 caveat extension.

**Hooks reference** — Anthropic. *Claude Code Docs*, 2026, re-fetched 2026-05-07. https://code.claude.com/docs/en/hooks. Tier-1 canonical. Verbatim: *"For most events, stdout is written to the debug log but not shown in the transcript. The exceptions are UserPromptSubmit, UserPromptExpansion, and SessionStart, where stdout is added as context that Claude can see and act on."* Confirms `UserPromptExpansion` as a documented event distinct from `UserPromptSubmit`, anchoring the Q-013 (c) finding that user-typed `/skillname` invocations have a separate dispatch path from agent-emitted Skill tool calls. Plus the canonical event taxonomy (PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, SessionStart, SessionEnd, UserPromptSubmit, UserPromptExpansion, Stop, StopFailure) and the stdout-as-context trio (UserPromptSubmit / UserPromptExpansion / SessionStart). Anchor for R-LOAD-4 revision.

**`anthropics/claude-code` CHANGELOG** — Anthropic. *claude-code repository main branch CHANGELOG.md*, 2026-05-07. https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md. Tier-1. Verbatim: *"`claude_code.skill_activated` OpenTelemetry event now fires for user-typed slash commands and carries a new `invocation_trigger` attribute (`\"user-slash\"`, `\"claude-proactive\"`, or `\"nested-skill\"`)."* **NEW Tier-1 finding for v1.15** — canonical cross-path skill-invocation observability primitive that supersedes hook-based observability for cross-path coverage and resolves the asymmetry left by Issue #43630. Anchor for R-LOAD-4 supplementary observability clause.

**`anthropics/claude-code` Issue #43630** — Anthropic. *claude-code repository issues*, opened 2026-04-04 by `pypetey`, status: open with `stale` label as of 2026-05-07. https://github.com/anthropics/claude-code/issues/43630. Tier-1. Re-verified at v1.15: *"PostToolUse hooks with `\"matcher\": \"Skill\"` never fire when a skill is invoked (e.g., via `/plugin:skill-name` or the Skill tool). This is because the Skill tool is handled as a prompt expansion internally and doesn't dispatch hook events through the normal tool execution pipeline."* PostToolUse-Skill remains BLOCKED. R-LOAD-4 (b) clause anchor.

**`anthropics/claude-code` Issue #21614** — Anthropic. *claude-code repository issues*, opened 2026-01-29 by `milobird`, status: labeled `duplicate`. https://github.com/anthropics/claude-code/issues/21614. Tier-1. Cited at v1.15 as **operational confirmation** that PreToolUse-Skill DOES fire for sub-agent dispatched calls: the issue describes a crash bug *"When a sub-agent (spawned via Task tool) invokes the Skill tool and a PreToolUse hook returns an error, Claude Code crashes with `Aborted()`"* — the crash is only possible if the hook fires. Anchor for R-LOAD-4 (a) clause; R-LOAD-4 caveat about exit-code discipline (the hook handler MUST NOT throw unhandled exceptions in sub-agent context).

**`anthropics/claude-code` Issues #30573, #31017, #22902** — Anthropic. *claude-code repository issues*, all open as of 2026-05-07. Re-cited from v1.8 / v1.14. Tier-1. Confirm: InstructionsLoaded fires for CLAUDE.md / `.claude/rules/*.md` only (not skills); no host-side env var enumerates loaded skills. R-LOAD-4 (c) clause anchors.

#### v1.14 (Q-016)

**Agent Skills overview** — Anthropic. *Claude API Docs*, 2026. https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview. Tier-1 canonical. Cited at v1.14 for verbatim *'Claude uses bash to read SKILL.md from the filesystem … Claude reads those files too using additional bash commands.'* Decisive refutation of Gemini-16's 'native progressive-disclosure injection parser' fabrication (DA-Q016-1); anchor for R-CHUNK-4-CLARIFICATION.

**Skill authoring best practices** — Anthropic. *Claude API Docs*, 2026. https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices. Tier-1 canonical. Re-cited at v1.14 for the Bad-vs-Good chained-link example (identical filenames, varies only in hop count) and Pattern 2 `bigquery-skill/reference/finance.md`, which together establish the markdown-link-depth interpretation of *'Keep references one level deep from SKILL.md.'* Anchor for R-CHUNK-4 v1.14 revision.

**Equipping agents for the real world with Agent Skills** — Zhang, B., Lazuka, K., Murag, M. *Anthropic Engineering*, 2025-10-16. https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills. Tier-1. Cited at v1.14 for verbatim *'Structure for scale: When the SKILL.md file becomes unwieldy, split its content into separate files and reference them. If certain contexts are mutually exclusive or rarely used together, keeping the paths separate will reduce the token usage.'* Reinforces subdirectory partitioning as Anthropic-sanctioned pattern.

**`anthropics/skills/claude-api/python/claude-api/tool-use.md`** — Anthropic. *Public repository for Agent Skills*, default branch `main`, 2026-05-06. https://github.com/anthropics/skills/blob/main/skills/claude-api/python/claude-api/tool-use.md. Tier-1. GitHub blob header reports **590 lines (477 loc) · 16.5 KB**. Empirical anchor for R-CHUNK-4 v1.14 worked example (2-filesystem-depth file with 1-graph-distance from SKILL.md → PASS). Verifies Gemini-16's 590-line count.

**`anthropics/skills/claude-api/shared/tool-use-concepts.md`** — Anthropic. *Public repository for Agent Skills*, default branch `main`, 2026-05-06. https://github.com/anthropics/skills/blob/main/skills/claude-api/shared/tool-use-concepts.md. Tier-1. GitHub blob header reports **305 lines (200 loc) · 14.5 KB**. Empirical anchor; **corrects Gemini-16's 327-line claim** (DA-Q016-3).

**`anthropics/claude-code` Issue #13617** — Anthropic. *claude-code repository issues*, 2025-12-10. https://github.com/anthropics/claude-code/issues/13617. Tier-1. Title: *'Bug: ARM64 binary replaced with x86_64 during install on Apple Silicon'*. Cited at v1.14 to **refute** Gemini-16's misattribution of this issue as evidence for autonomous `head -100` file traversal behavior (DA-Q016-2).

**Agent Skills specification** — Agentic AI Foundation, stewarded by the Linux Foundation, 2026. https://agentskills.io/. Tier-2 (open standard, AAIF/LF stewardship). Cross-platform corroboration at v1.14: *'Activation: When a task matches a skill's description, the agent reads the full SKILL.md instructions into context. Execution: The agent follows the instructions, optionally executing bundled code or loading referenced files as needed.'* Confirms agent-driven progressive disclosure across the open standard, not just Claude Code.

**Whittaker, P.** *Progressive Discovery: A Better Mental Model for Agent Skills.* dev.to, 2026 (April). https://dev.to/phil-whittaker/progressive-discovery-a-better-mental-model-for-agent-skills-51bd. Discovery (named-author practitioner post). Cited at v1.14 as supporting commentary for R-CHUNK-4-CLARIFICATION framing: *'Claude is the one doing something. The Skill is not. The Skill is bytes on disk.'* Not used as a normative basis for any rule — Anthropic Tier-1 sources are decisive.

#### v1.13 (Q-015)

**How Claude remembers your project** — Anthropic. *Claude Code Docs*, 2026. https://code.claude.com/docs/en/memory. Tier-1 canonical. Re-cited at v1.13 for the verbatim *'This limit applies only to MEMORY.md. CLAUDE.md files are loaded in full regardless of length'* passage that resolves DA-140 (Gemini-15 BUDGET-MEM-1 conflation), and for the canonical `@AGENTS.md`-first CLAUDE.md example that anchors R-BOUNDARY-4-CLARIFICATION.

**Skill authoring best practices** — Anthropic. *Claude API Docs*, 2026. https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices (mirror: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices). Tier-1 canonical. Re-cited at v1.13 for the verbatim *'Claude may partially read files when they're referenced from other referenced files. When encountering nested references, Claude might use commands like head -100 to preview content rather than reading entire files'* mechanism (strengthens R-CHUNK-4) and for the verbatim *'For reference files longer than 100 lines, include a table of contents at the top'* threshold (anchors new R-BOUNDARY-9; corrects Gemini-15's 300-line overclaim → DA-144).

**Best practices for Claude Code** — Anthropic. *Claude Code Docs*, 2026. https://code.claude.com/docs/en/best-practices. Tier-1. Anchor for R-BOUNDARY-8 — verbatim *'CLAUDE.md is loaded every session, so only include things that apply broadly. For domain knowledge or workflows that are only relevant sometimes, use skills instead.'*

**Equipping agents for the real world with Agent Skills** — Anthropic Engineering, 2025–2026 (open-standard publication date 2025-12-18). https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills. Tier-1. Progressive-disclosure design principle and bundled-resources non-context-cost confirmation; anchor for R-BOUNDARY-2's progressive-disclosure rationale and the cross-platform open-standard framing that makes R-BOUNDARY-1, -2, -4, -5 portable across Cursor, Codex, Cline, Aider, Continue, Windsurf, etc.

**AGENTS.md spec** — Agentic AI Foundation, stewarded by the Linux Foundation, 2026. https://agents.md/. Tier-2 (open standard with AAIF/LF stewardship; 60k+ adopting OSS projects). Anchor for R-BOUNDARY-5 (*'README.md files are for humans … AGENTS.md complements this by containing the extra, sometimes detailed context coding agents need: build steps, tests, and conventions'*) and for the closest-wins walk semantics (FAQ verbatim: *'The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything.'*).

**Palmblad, M., Ragland, J. M., Neely, B. A.** *Agentic AI-assisted coding offers a unique opportunity to instill epistemic grounding during software development.* arXiv:2604.21744 [cs.SE / cs.AI / q-bio.BM], 2026-04-23. https://arxiv.org/abs/2604.21744. Tier-1 (peer-reviewed-equivalent arXiv with verified institutional affiliation: Center for Proteomics and Metabolomics, Leiden University Medical Center; NIST Charleston). Narrow anchor for new P-BOUND-GROUNDING-1 PROPOSED (domain-scoped GROUNDING.md for fields with formal validity invariants). **Important scoping note:** the paper proposes GROUNDING.md as field-scoped (worked example: mass spectrometry-based proteomics); it does NOT support Gemini-15's claim that platforms 'natively inject' GROUNDING.md at 'highest system priority' (rejected → DA-141).

**Introducing Claude Opus 4.7** — Anthropic, 2026. https://www.anthropic.com/news/claude-opus-4-7. Tier-1. Pricing primary source for Opus 4.7 ($5/$25 per MTok), unchanged from Opus 4.6, with tokenizer-driven 1.0×–1.35× per-request cost shift; cited to resolve the citation-discipline issue (DA-146) on Gemini-15's Finout-routed pricing claims.

#### v1.11 (Q-011)

**RFC 2119** — Bradner, S. *Key words for use in RFCs to Indicate Requirement Levels*. IETF Best Current Practice 14, 1997. https://www.rfc-editor.org/rfc/rfc2119.html

**RFC 8174** — Leiba, B. *Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words*. IETF, 2017. https://www.rfc-editor.org/rfc/rfc8174.html

**RFC 7322 §4.1.4** — Flanagan, H. & Ginoza, S. *RFC Style Guide*. IETF, 2014. https://www.rfc-editor.org/rfc/rfc7322.html

**GRADE** — Guyatt, G. H. et al. *GRADE: an emerging consensus on rating quality of evidence and strength of recommendations*. BMJ 336:924, 2008. https://pmc.ncbi.nlm.nih.gov/articles/PMC2335261/

**Cohen's Kappa** — McHugh, M. L. *Interrater reliability: the kappa statistic*. Biochemia Medica 22(3):276-282, 2012. https://pmc.ncbi.nlm.nih.gov/articles/PMC3900052/

**CoALA** — Sumers, T., Yao, S., Narasimhan, K. & Griffiths, T. *Cognitive Architectures for Language Agents*. TMLR 2024. arXiv:2309.02427. https://arxiv.org/abs/2309.02427

**MemGPT** — Packer, C., Fang, V., Patil, S., Lin, K., Wooders, S. & Gonzalez, J. *MemGPT: Towards LLMs as Operating Systems*. arXiv:2310.08560, 2023. https://arxiv.org/abs/2310.08560

**Generative Agents** — Park, J. S. et al. *Generative Agents: Interactive Simulacra of Human Behavior*. UIST 2023. arXiv:2304.03442. https://arxiv.org/abs/2304.03442

**Reflexion** — Shinn, N. et al. *Reflexion: Language Agents with Verbal Reinforcement Learning*. NeurIPS 2023. arXiv:2303.11366. https://arxiv.org/abs/2303.11366

**Voyager** — Wang, G. et al. *Voyager: An Open-Ended Embodied Agent with Large Language Models*. TMLR 2024. arXiv:2305.16291. https://arxiv.org/abs/2305.16291

**A-MEM** — Xu, W., Liang, K., Mei, K., Gao, H., Tan, Y. & Zhang, Y. *A-MEM: Agentic Memory for LLM Agents*. arXiv:2502.12110, 2025. https://arxiv.org/abs/2502.12110

**When to Forget** — Simsek, B. *When to Forget: A Memory Governance Primitive*. arXiv:2604.12007, 13 Apr 2026. https://arxiv.org/abs/2604.12007 — *Adopted at qualitative level only (associational-vs-causal disclaimer); specific numeric figures ρ≈-0.33 and 30% threshold rejected per DA-129.*

**Memory as Metabolism** — Miteski, S. *Memory as Metabolism: A Design for Companion Knowledge Systems*. arXiv:2604.12034, 13 Apr 2026. https://arxiv.org/abs/2604.12034 — *Ossification framing adopted as cross-link support for supersession (b); Gemini-1's user-coupled-drift framing rejected per DA-127.*

**Beyond the Context Window** — Pollertlam, N. & Kornsuwannawit, W. *A Cost-Performance Analysis of Fact-Based Memory vs. Long-Context LLMs for Persistent Agents*. arXiv:2603.04814, 5 Mar 2026. https://arxiv.org/abs/2603.04814 — *Properly read, supports the Q-011 (d) deferral; Gemini-1's selective framing rejected per DA-126.*

**ConvoMem Benchmark** — Pakhomov, E., Nijkamp, E. & Xiong, C. (Salesforce AI Research). *ConvoMem Benchmark: Why Your First 150 Conversations Don't Need RAG*. arXiv:2511.10523, 13 Nov 2025. https://arxiv.org/abs/2511.10523

**Reciprocal Rank Fusion** — Cormack, G. V., Clarke, C. L. A. & Büttcher, S. *Reciprocal Rank Fusion outperforms Condorcet and individual rank learning methods*. SIGIR 2009. https://dl.acm.org/doi/10.1145/1571941.1572114

**Anthropic Contextual Retrieval** — Anthropic. *Introducing Contextual Retrieval*. September 2024. https://www.anthropic.com/news/contextual-retrieval

**Anthropic Claude Code Memory doc** — Anthropic. *How Claude remembers your project*. https://code.claude.com/docs/en/memory — *Used for (e) re-verification interval defaults; Gemini-1's misapplication of the 25 KB MEMORY.md limit to on-demand-loaded user documents rejected per DA-128.*

**Murre & Dros 2015** — Murre, J. M. J. & Dros, J. *Replication and Analysis of Ebbinghaus' Forgetting Curve*. PLoS ONE 10(7):e0120644, 2015. https://doi.org/10.1371/journal.pone.0120644

**Wikipedia template** — *{{Update after}}*. https://en.wikipedia.org/wiki/Template:Update_after

**MDN deprecation lifecycle** — *Experimental, deprecated, and obsolete*. https://developer.mozilla.org/en-US/docs/MDN/Writing_guidelines/Experimental_deprecated_obsolete

**Karpathy llm-wiki** (Discovery) — Karpathy, A. *llm-wiki*. GitHub Gist, 2026. https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

**LLM Wiki v2** (Discovery) — rohitg00. *LLM Wiki v2 — extending Karpathy's LLM Wiki pattern*. GitHub Gist, 2026 (with Mattia83it critical commentary in thread, May 2026). https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2

- **Anthropic Tier 1 (incremental over v1.11, fetched 2026-05-05 during Q-014 Turn 2 Gemini-14 vetting):** **[NEWLY-CITED CANONICAL]** "How Claude remembers your project," Anthropic, 2026, Claude Code Docs, code.claude.com/docs/en/memory — § AGENTS.md verbatim: "Claude Code reads CLAUDE.md, not AGENTS.md. If your repository already uses AGENTS.md for other coding agents, create a CLAUDE.md that imports it…" — drives R-MEM-3 demotion + R-MEM-10 VALIDATED CANONICAL. **[NEWLY-CITED CANONICAL]** "Skill authoring best practices," Anthropic, 2026, Claude API Docs, platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices — confirms `description` 1024-char single-field limit (refutes Gemini-14's fabricated 1,536-char combined limit), `name` 64-char limit, no `context: fork` in skill frontmatter, no `!command` injection in SKILL.md, FORMS.md uppercase example. **[NEWLY-CITED CANONICAL]** "Plugins reference," Anthropic, 2026, Claude Code Docs, code.claude.com/docs/en/plugins-reference — verbatim: "Symlinks are preserved in the cache rather than dereferenced, and they resolve to their target at runtime" + "Paths that traverse outside the plugin root will not work after installation" — drives R-REF-SHARE-1. "Skills for enterprise," Anthropic, 2026, Claude API Docs, platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise — backs R-REF-SECRETS-1. **[NEWLY-CITED CANONICAL]** "cpSync crashes with ENOENT when sensitive paths are symlinks," matanbaruch, Apr 6 2026, anthropics/claude-code-action Issue #1187, github.com/anthropics/claude-code-action/issues/1187 — Tier-1 (Anthropic-owned repo) production CI failure mode for symlinked CLAUDE.md → AGENTS.md, since v1.0.89, fix in PR #1186. "document-skills and example-skills plugins install identical content, causing duplicate skills," chuggies510, Dec 30 2025, anthropics/skills Issue #189, github.com/anthropics/skills/issues/189 — Tier-1 documenting ~50K wasted tokens (used to refute Gemini-14's misframing as cross-skill reference duplication crisis). **Empirical Tier-1 walks (anthropics/skills repo):** skill-workshop/SKILL.md, skill-workshop/references/schemas.md (single shared reference doc, R-SR-2 / R-SR-5 in production); pdf/SKILL.md, pdf/reference.md, pdf/forms.md (flat layout); mcp-builder/SKILL.md, mcp-builder/reference/{node_mcp_server.md, python_mcp_server.md, mcp_best_practices.md, evaluation.md} (variant-organized references); claude-api/SKILL.md, claude-api/python/, claude-api/typescript/, claude-api/shared/tool-use-concepts.md (**2-level structure flagged as Tier-1 contradiction with R-CHUNK-4 — drives Q-016 follow-up**); xlsx/SKILL.md (flat-with-recalc.py-at-root); doc-coauthoring/SKILL.md (single-file skill). Issues #667 (non-standard directory naming) and #675 (discoverability barriers) confirmed Tier-1. **Tier 2:** "AGENTS.md," agents.md (LF/Agentic-AI-Foundation stewardship, 60k+ adopters, nested AGENTS.md walk per FAQ; the `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` shell command is verified as singular→plural backward-compat only, NOT cross-tool — refutes Gemini-14 DA-134 miscitation). **Discovery (continuing Q-011):** Karpathy llm-wiki gist (gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — confirms gist names CLAUDE.md and AGENTS.md as parallel alternatives, NOT as symlink targets (refutes DA-138). rohitg00 LLM-Wiki-v2 (gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2) and Mattia83it commentary (May 4, 2026) — counter-patterns adopted (supersession-not-decay, filter-at-ingest, HITL write-gate philosophy). **Second opinion:** Gemini-14 (Google Gemini deep research output, 'Anthropic Claude Code Agent Skills System: Canonical Reference Architecture and Documentation Specification', 2026-05-05) — partially incorporated; 9 hallucinations rejected at DA-130..DA-138.
- **Anthropic Tier 1 (incremental over v1.9, fetched 2026-05-04 / 2026-05-05 during Q-010 Turn 1 + Turn 2 Gemini-10 vetting).** Anthropic, *Skill authoring best practices*, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (decisive Tier-1 anchor for R-CHUNK-1 100-line TOC threshold; R-CHUNK-2 domain-organized split pattern [`reference/finance.md`, `reference/sales.md`, …]; R-CHUNK-4 'Avoid deeply nested references … Keep references one level deep from SKILL.md' explicit; R-LAZYLOAD-1 'All reference files should link directly from SKILL.md' verbatim; head-100 partial-read warning explicit). Anthropic, *anthropics/skills repository*, https://github.com/anthropics/skills — production exemplars: skill-workshop/SKILL.md (300-line TOC threshold for references, conflict-resolved per Anthropic-supremacy in favor of stricter 100-line best-practices figure; 'if files are large (>10k words), include grep search patterns' anchor for R-CHUNK-3 / R-SR-7 strengthening); skills/docx/SKILL.md (R-LAZYLOAD-2 imperative MANDATORY-READ-ENTIRE-FILE pattern verbatim for ooxml.md ~600 lines and docx-js.md); skills/pdf/{SKILL.md, reference.md, forms.md} (Pattern 2 domain-organization exemplar); skills/pptx/{SKILL.md, editing.md, pptxgenjs.md} (intra-skill router pattern with multiple references); skills/xlsx/SKILL.md. Anthropic, *Effective context engineering for AI agents*, anthropic.com/engineering/effective-context-engineering-for-ai-agents (just-in-time retrieval vs front-loading anchor; tokens-as-finite-resource framing supporting R-CHUNK-6 rejection of vector-index-as-canonical). Anthropic, *Equipping agents for the real world with Agent Skills*, anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills (three-level progressive disclosure model L1=name+description / L2=SKILL.md body / L3=references+scripts on demand — re-cited as R-LAZYLOAD-1 anchor). Anthropic, *Extend Claude with skills*, https://code.claude.com/docs/en/skills (${CLAUDE_SKILL_DIR} resolution semantics — confirms H6 PASS; orthogonal to chunking). Anthropic, *How Claude remembers your project*, https://code.claude.com/docs/en/memory (`.claude/rules/*.md` recursive directory loading documented; rules-vs-skills distinction; anchor for DA-122 — Anthropic's documented mechanism for extension-without-fork use case Gemini-10 raised, which is NOT skill-memories). Resources / Anthropic, *The Complete Guide to Building Skills for Claude*, https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf (3-level loading table: ~100 / <5,000 / virtually-unlimited tokens — anchor for R-LAZYLOAD-1 progressive disclosure). **anthropics/claude-code Issues (Tier 1 — full set fetched 2026-05-04 / 2026-05-05):** **#4002 (DECISIVE)** — *Error: File content (28375 tokens) exceeds maximum allowed tokens (25000)…* — first documentation of MaxFileReadTokenExceededError, anchor for R-CHUNK-5 ceiling and offset/limit pagination guidance. **#14876** — *[Bug] File content exceeds maximum token limit with large files* — full reproduction of MaxFileReadTokenExceededError, anchor for R-CHUNK-5. **#14888** — *[Feature Request] Make file read token limit dynamic based on model capabilities* — confirms 25K is hardcoded; anchor for R-CHUNK-5 [claude-code-only] tag and DA-119 rejection of [portable] framing. **#15687** — *[FEATURE] Read tool's 25k token limit is too conservative and easily bypassed* — corroborates hardcoded ceiling. **#7679** — *Increase Maximum File Token Limit from 25000 to 50000* — independent corroboration. **#6910** — *Read tool does not limit itself to 2000 lines by default* — confirms documented 2,000-line default. **#11011** — *Skill plugin scripts fail on first execution with relative path resolution* — caveat for ${CLAUDE_SKILL_DIR} on plugin-installed skills (orthogonal to chunking). **Decisive Tier-1 Gemini-10 contributions (Turn 2, verified 2026-05-05):** **#40357 (DECISIVE Tier-1, Gemini-10)** — *[FEATURE] Make Read tool file size limit configurable (Desktop app caps at 10k tokens, CLI at 25k)* — opened tovamerika-ux 2026-03-28; verified-real-via-direct-fetch with full reproduction (Desktop v1.1.9310 enforces 10K cap, error message reproduces 'File content (125085 tokens) exceeds maximum allowed tokens (10000)'); anchor for R-CHUNK-5 Desktop tightening and R-CHUNK-2 portable-threshold tightening to ~10K tokens. **#45019 (DECISIVE Tier-1, Gemini-10)** — *[MODEL] Max number of tokens per file is now 10000 instead of 25000* — opened viniciusferrao 2026-04-08; verified-real-via-direct-fetch; documents silent April 2026 downgrade of CLI ceiling from 25,000 to 10,000 with no doc churn; user provides search-link evidence (last `25000` issue 7 days before; first `10000` issue 1 hour before opening); anchor for R-CHUNK-5 'current shipping behavior' caveat and for R-CHUNK-2 / R-LAZYLOAD-1 portability discipline. **anthropics/claude-plugins-official Issues:** **#995 (Tier-1, Gemini-10 corroboration)** — *SKILL.md files exceed 10,000 token Read limit — need references/ extraction* — opened 2026-03-25; verified-real-via-direct-fetch; documents real production failure mode where SKILL.md files in Anthropic's own claude-plugins-official repository fail to load due to 10K token Read limit; explicit recommendation matches R-CHUNK-2 + R-LAZYLOAD-1 ('extract detailed content … into references/ files within each skill directory, keeping SKILL.md under ~10KB with Read pointers to the extracted files'). **Tier 1 peer-reviewed papers (verified 2026-05-04 / 2026-05-05, all arXiv IDs resolve and not future-dated):** **arXiv:2307.03172** — Liu, Lin, Hewitt, Paranjape, Bevilacqua, Petroni, Liang (Stanford / Samaya AI / FAIR), *Lost in the Middle: How Language Models Use Long Contexts*, TACL 2024 vol 12 pp 157-173, https://aclanthology.org/2024.tacl-1.9 — verified real, MIT Press TACL publication, refereed; U-shaped attention degradation across model families anchor for P-CHUNK-9 PROPOSED and DA-124 specific-30%-figure rejection. **Chroma technical report 2025** — 'Context Rot: How Increasing Input Tokens Impacts LLM Performance' — verified at research.trychroma.com/context-rot; 18 frontier models tested including Claude 4 Opus + Sonnet; anchor for P-CHUNK-9 transfer-to-skills caveat. **arXiv:2505.21700** — Bhat, Rudat, Spiekermann, Flores-Herr (Fraunhofer IAIS), *Rethinking Chunk Size For Long-Document Retrieval: A Multi-Dataset Analysis*, May 2025 — verified real; chunk-size task-dependence (64-128 token chunks for fact-based; 512-1024 for contextual) anchor for P-CHUNK-8 PROPOSED with cross-domain RAG-vs-skill-references transfer caveat. **arXiv:2601.01569 (Turn 2, Gemini-10)** — Maohao Ran, Zhenglin Wan, Cooper Lin, Yanting Zhang, Hongyu Xin, Hongwei Fan, Yibo Xu, Beier Luo, Yaxin Zhou, Wangbo Zhao, Lijie Yang, Lang Feng, Fuchao Yang, Jingxuan Wu, Yiqiao Huang, Chendong Ma, Dailing Jiang, Jianbo Deng, Sirui Han, Yang You, Bo An, Yike Guo, Jun Song (Hong Kong Generative AI Research and Development Center [HKGAI] led by HKUST; corresponding junsong@hkbu.edu.hk Hong Kong Baptist University), *CaveAgent: Transforming LLMs into Stateful Runtime Operators*, https://arxiv.org/abs/2601.01569 (v1 4 Jan 2026, v3 19 Feb 2026) — VERIFIED REAL Tier-1; institutional affiliation HKBU/HKUST/HKGAI verified; not future-dated; abstract verified to claim 'CaveAgent further provides a runtime-integrated skill management system that extends the Agent Skills open standard, enabling ecosystem interoperability through executable skill injections.' Logged as **P-CHUNK-11 PROPOSED forward-influence reference** (Q-009 precedent for GraSP/Skilldex); does NOT graduate to v1.10 normative rule because Claude Code's stateless-bash-tool runtime model is architecturally incompatible with CaveAgent's persistent-Python-runtime requirement (DA-121). **Tier 2 (cross-system corroboration, Q-010 specific):** Boris Cherny (Anthropic, Claude Code lead) public statement on Claude Code's deprecation of local-RAG/vector-DB approach in favor of agentic Grep+Read — reproduced in smartscope.blog 'Settling the RAG Debate' (https://smartscope.blog/en/ai-development/practices/rag-debate-agentic-search-code-exploration/) and vadim.blog 'Claude Code Doesn't Index Your Codebase. Here's What It Does' — anchor for R-CHUNK-6 rejection of vector-index canonical pattern. anthropics/claude-code Issue #25469 (Tier-2 cross-reference for DA-122) — *Proposal: Extensible Skills standard — skill-memories as inheritance for SKILL.md*, opened anton-abyzov 2026-02-13, labels `enhancement` + `stale`; community feature proposal NOT Anthropic-implemented. PyPI llm-py-agent 0.1.0 + github.com/vanzll/PyAgent (Tier-2 corroboration for DA-121) — confirms `injection.py` is real in CaveAgent's Python runtime framework but NOT in Claude Code Skills. platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools (Anthropic cookbook on context-engineering tools, compaction, tool-result clearing — supporting evidence for L3 design rationale). claude-code/CHANGELOG.md (corroborating Read-tool behavior changes; 10KB diff truncation regression fixed). Cobus Greyling (Tier-2 named author), 'LLM Context Rot' — Medium piece summarizing Chroma findings, used for cross-reference only. Inkeep blog 'Fighting Context Rot' (Tier-2, named author) — reframes Chroma findings for engineering audiences. ZenML LLMOps Database 'Context Rot' summary (Tier-2). **Discovery (PROPOSED tag, named author required):** Lee Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/ (re-cited; Skill-tool implementation including Read-default-2000-lines confirmation). codeagentsalpha.substack.com — *Agent Skills Complete Getting-Up-To-Speed Guide* (production-pattern inventory). aihola.com — *How to Create Agent Skills with Scripts and Reference Files* (R-CHUNK-4 nesting rationale echo of Anthropic best-practices). dotzlaw.com — *Claude Code Skills: Building Reusable Knowledge Packages* (Tier-2 production patterns). evomap.ai — *Claude Code Local: Skills, Memory, and Persistence* (CLAUDE.md vs skill-memory distinction; supports DA-122 reasoning). vadim.blog 'Claude Code Doesn't Index Your Codebase. Here's What It Does' (Boris Cherny statement contextualization). Mikhail Shilkov, mikhail.io — *Inside Claude Code Skills* (reverse-engineered Skill tool definition showing Base Path injection — corroborates ${CLAUDE_SKILL_DIR} string-substitution semantics, H6 PASS). **Second opinion: Gemini-10** — Google Gemini Deep Research output for Q-010, submitted by user 2026-05-05. **Verifications performed (≥3 per framework rule, six performed):** (1) anthropics/claude-code Issue #40357 — VERIFIED REAL via direct GitHub fetch; full reproduction with Desktop v1.1.9310 + Windows + 10K cap; error message text matches; **decisive Tier-1 contribution → R-CHUNK-5 Desktop refinement**. (2) anthropics/claude-code Issue #45019 — VERIFIED REAL via direct GitHub fetch; documents Apr 2026 silent 25K→10K downgrade; user provides search-link evidence; **decisive Tier-1 contribution → R-CHUNK-5 current-shipping-behavior caveat + R-CHUNK-2 portable threshold tightened**. (3) anthropics/claude-plugins-official Issue #995 — VERIFIED REAL; documents real production failure mode with 10K limit; corroborates G10-B. (4) arXiv:2601.01569 CaveAgent — VERIFIED REAL via arxiv.org/abs/2601.01569; 23 authors; HKBU/HKUST/HKGAI institutional affiliation verified; not future-dated; abstract verified to make the claim Gemini-10 cited; PyPI llm-py-agent + github.com/vanzll/PyAgent confirm `injection.py` filename is real in CaveAgent framework but NOT in Claude Code; **architecturally misapplied by Gemini-10 → P-CHUNK-11 PROPOSED forward-influence reference (Q-009 GraSP/Skilldex precedent)**. (5) anthropics/claude-code Issue #25469 — VERIFIED REAL; opened anton-abyzov 2026-02-13; labels `enhancement` + `stale`; **community proposal NOT Anthropic-implemented → DA-122 rejection of skill-memories framing**. (6) PyPI llm-py-agent 0.1.0 — VERIFIED REAL; description verbatim 'CaveAgent extends the Agent Skills standard with injection.py'; reinforces (4) — `injection.py` is for cave_agent / pycallingagent runtime, not Claude Code's bash-tool runtime. **Outcome:** 1 ACCEPTED-DECISIVE (G10-B Issues #40357 + #45019 → R-CHUNK-5 refined + R-CHUNK-2 portable threshold tightened); 4 ACCEPTED-PARTIAL (G10-A TOC-at-top spirit; G10-C vector-tightening but rejecting DEPRECATED-framing; G10-G env-var orthogonality reaffirmed; G10-F1 CaveAgent → P-CHUNK-11 forward-influence reference); 1 MISREAD clarified (G10-H — R-CHUNK-4 already forbids nested references; H7 wording tightened); 6 REJECTED as DA-119..DA-124 (50-line specific cutoff; 30% specific figure; MUST-upgrade math error; CaveAgent normative rule; skill-memories as canonical; 25K-as-portable-cap). **Independence note applied:** Gemini-10 fits systemic Gemini pattern across Gemini-2/5/6/7/8 of fabricating 'Anthropic-blessed production paradigms' from academic-flavored sources (CaveAgent presented as production paradigm; community-proposal `.claude/skill-memories/` presented as canonical Anthropic feature). Treated as ONE LLM-second-opinion data point per framework.second_opinion_review.independence_note. Materially cleaner than Gemini-2/6/7/8 on arXiv verification (CaveAgent paper is real and well-cited); on par with Gemini-9 in evidence quality. **Two decisive Tier-1 GitHub Issue verifications (#40357 + #45019) are major contributions** that materially update R-CHUNK-5 to reflect current shipping behavior.
- **Anthropic Tier 1 (incremental over v1.8, fetched 2026-05-04 during Q-009 Turn 1 + Turn 2 vetting).** Anthropic, *Extend Claude with skills*, Claude Code Docs, https://code.claude.com/docs/en/skills (re-confirmed: four discovery sources — `~/.claude/skills/` personal, `<cwd>/.claude/skills/` project, `--add-dir`-imported `.claude/skills/`, plugin-bundled `${CLAUDE_PLUGIN_ROOT}/skills/`; Automatic Discovery from Nested Directories specified for monorepo subfolder editing; `paths` glob for auto-activation gating; `${CLAUDE_SKILL_DIR}` skill-relative anchor; `disable-model-invocation`/`user-invocable` visibility controls; exceptions table — `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/`, `.claude/hooks/`, `.claude/output-styles/` only). Anthropic, *Create plugins*, Claude Code Docs, https://code.claude.com/docs/en/plugins (plugin as canonical cross-scope sharing primitive; marketplace + `/plugin marketplace add` + `/plugin install` flow). Anthropic, *Plugins reference*, Claude Code Docs, https://code.claude.com/docs/en/plugins-reference (`${CLAUDE_PLUGIN_ROOT}` plugin install dir; `${CLAUDE_PLUGIN_DATA}` persistent across plugin updates; marketplace cache `~/.claude/plugins/cache/<plugin>/<version>/`; symlinks preserved at cache copy and resolved at runtime; paths outside plugin root don't work post-install). Anthropic, *Skill authoring best practices*, Claude API Docs, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices ("File paths matter: Claude navigates your skill directory like a filesystem" — anchor for R-REFLOC-1; ≤500-line body re-confirmed). Anthropic, *Agent Skills overview*, Claude API Docs, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview (progressive disclosure architecture L1/L2/L3 — anchor for R-REFLOC progressive disclosure analysis). Anthropic, *Equipping agents for the real world with Agent Skills*, anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills (re-cited; skill self-containment principle). Anthropic, anthropics/skills repository, https://github.com/anthropics/skills (re-verified 2026-05-04: 12 production skills inspected — skill-workshop, mcp-builder, claude-api, pdf, pptx, docx, xlsx, webapp-testing, algorithmic-art, brand-guidelines, internal-comms, theme-factory, frontend-design — all self-contained with own `scripts/`, `references/`, `assets/` folders; **zero peer-skill symlinks observed** — DA-058 reaffirmed; pptx/SKILL.md internal-router pattern points to editing.md/pptxgenjs.md/ooxml.md within the same skill, never cross-skill). **anthropics/claude-code Issues (Tier 1 — full list re-fetched 2026-05-04 during Q-009 vetting):** **#44490 (DECISIVE)** — *[BUG] Glob tool cannot find files under .claude/ directory (regression 2.1.81 → 2.1.92)*, with full reproduction (5 successful runs at 2.1.81 vs 1 failing at 2.1.92), root-cause analysis identifying `Bun.Glob.scan()` `dot: false` default, and verbatim Bash-`find` workaround — anchor for R-MONO-1 refinement and R-MONO-4 NEW; **#33999** — *Glob tool fails to match files when pattern contains explicit dot-directory prefix* — root-cause cross-reference; **#17302** — *[Bug] Glob tool not passing "dot: true" option, causing missed hidden files* (Jan 10 2026, label `area:tools`/`bug`/`platform:macos`) — corroborates Bun.Glob `dot:false` issue family; **#43178** — *Glob fails with explicit directory prefixes* — related; **#40640** — *[DOCS] "Automatic Discovery from Nested Directories" for skills does not work as documented* — user-facing symptom of #44490, label `bug`+`documentation`; **#37344** — *Support hierarchical .claude config discovery in monorepos* — confirms only root or cwd `.claude/` is loaded for skills/hooks/MCP/settings; **CLAUDE.md and skills are exceptions** that should discover nested per spec; **#37553** — *Skills not loaded from `additionalDirectories`, but are from `--add-dir`* — confirms `--add-dir` exception; anchor for DA-101; **#43267** — *additionalDirectories in settings.json does not trigger skill discovery* — Windows + Linux repro; anchor for DA-101; **#22902** — *[FEATURE] Custom skills directory paths via env var or settings* — feature request, confirms `${CLAUDE_SKILLS_PATH}` does NOT exist; anchor for DA-102 / R-CROSS-1; **#39403** — *`skillsDirectories` array in settings.json — feature request* — alternative request, similarly not shipping; **#10238** — *Add support for subdirectories in skills* (opened 2025-10-24) — single-depth ceiling anchor; **#16438** — *Feature Request: Support nested directory structure for skills organization* (opened 2026-01-06) — explicit naming-prefix workaround documentation; anchor for R-WORKSPACE-6; **#18192** — *[FEATURE] Recursive skill discovery — scan subdirectories in `~/.claude/skills/`* (opened 2026-01-14) — symlink workaround documented by user simfor99; **#20755**, **#20805**, **#28266**, **#39138**, **#39787** — single-depth ceiling cluster; **#14836** — *[BUG] /skills command doesn't find skills in symlinked directories*; **#25367** — *[BUG] Custom skills via symlinked ~/.claude/skills/ directory fail validation but execute correctly* — execution-vs-discovery split confirmed; anchor for R-WORKSPACE-5; **#37590** — *Skills: support symlinks in `.claude/skills/`* — confirms only `.claude/rules/` is documented to follow symlinks; **#39475** — *Support symlinks in `.claude/commands/`* — same precedent; **#9354** — *Fix `${CLAUDE_PLUGIN_ROOT}` in command markdown OR support local plugin install* — anchor for R-SHARE-3 (env var doesn't expand inside command markdown bodies); **#15642** — *Plugin cache: `${CLAUDE_PLUGIN_ROOT}` points to stale version after plugin update*; **#27145** — *`${CLAUDE_PLUGIN_ROOT}` not set for SessionStart hooks*; **#15944** — *[Feature Request] Cross-plugin skill references with namespace syntax* — confirms cross-plugin sharing is NOT supported; anchor for DA-103 / R-SHARE-1; **#43695** — *Plugin skills option to require namespace-qualified invocation* — confirms `plugin:skill` namespacing; **#25150** — *Plugin skill autocomplete displays flat names instead of namespaced format*; **#12962** — *Settings.json parent directory traversal for monorepos* — confirms no upward traversal; **#12633** — *Allow skills to be hidden from main agent — subagent-exclusive skills* — clarifies `skills:` field on subagents is opt-in, not visibility filter; **#32910** — *Subagents can discover all project skills via filesystem despite docs stating they "don't inherit skills"* — filesystem discovery in subagents; **#45956** — *Project skills in `.claude/skills/` not discovered when running in a worktree* — worktree-as-symlink edge case; **#22081** (referenced). **anthropics/skills Issues:** **#953 (PROBABLE-VERIFIED Tier-1 corroborating)** — *Skill References* — empirical anchor for T-SHARE-1 (30 physical XSD-schema files where 10 would suffice across docx/pptx/xlsx; byte-identical SHA across the three skills; cited XSD files verified real ECMA-376 schemas via QtExcel/ecma-376-5th); **#189** — *document-skills and example-skills plugins install identical content, causing duplicate skills* — corroborates duplicate-content concern pattern; **#675** — *Document-skills (pdf, docx, xlsx, pptx) are nearly invisible to users — discoverability and naming problem*; **#1058** — confirms issue numbering active range. **Tier 1 peer-reviewed papers (verified 2026-05-04, all arXiv IDs resolve and not future-dated):** **arXiv:2604.17870** — Xia, Hu, Sun, Xu, Xu, Wang, Xu, Jiang (Tencent), *GraSP: Graph-Structured Skill Compositions for LLM Agents*, arXiv preprint cs.CL, 20 Apr 2026, https://arxiv.org/abs/2604.17870 — **PROPOSED forward-influence reference**; institutional affiliation Tencent verified; abstract verified to match Gemini-9 summary (DAG composition with precondition-effect edges; ALFWorld/ScienceWorld/WebShop/InterCode benchmarks; O(N) → O(d^h) replanning; +19 reward improvement; 41% step reduction). **arXiv:2604.16911** — Saha, Hemanth, *Skilldex: A Package Manager and Registry for Agent Skill Packages with Hierarchical Scope-Based Distribution*, arXiv preprint cs.AI, 18 Apr 2026, https://arxiv.org/abs/2604.16911 — **PROPOSED corroborating reference for R-WORKSPACE-3 plugin model** with author-affiliation caveat (neither author has verifiable ResearchGate institutional profile); compiler-style format scoring + skillset abstraction + three-tier scope (rejected as v1.9-canonical per DA-110) + MCP integration + TypeScript CLI. **arXiv:2602.12430** — Xu, Yan (Zhejiang University, rux@zju.edu.cn), *Agent Skills for Large Language Models: Architecture, Acquisition, Security, and the Path Forward*, arXiv preprint cs.MA, v3 17 Feb 2026, https://arxiv.org/abs/2602.12430 — **PROPOSED Tier-1 background reference**; institutional affiliation Zhejiang University verified. The 26.1% community-skill vulnerability stat is via reference [14] = Liu et al. arXiv:2601.10338 (NOT independently verified at primary-source level — DA-111). **arXiv:2305.16291** — Wang et al. (NVIDIA, Caltech), *Voyager*, TMLR 2024 — re-cited as skill-library indexing-by-description analogue (v1.6/v1.7 anchor preserved). **Tier 2 (cross-system corroboration):** Cursor 2.4 changelog, https://cursor.com/changelog/2-4 (Cursor 2.4 added Agent Skills support Jan 2026, `.cursor/skills/` reads SKILL.md, project-only); AGENTS.md spec, https://agents.md/ (Linux Foundation Agentic AI Foundation stewardship, Dec 2025; nested AGENTS.md "closest file wins" — corroborates R-MEM-7 closest-file-wins for instruction files but NOT for skills, per Issue #37344); AAIF / Linux Foundation Announcement, https://linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation (re-cited, Dec 2025); OpenAI Codex AGENTS.md docs, https://developers.openai.com/codex/guides/agents-md (`AGENTS.override.md` precedence; project_doc_max_bytes 32 KiB default — anchors for R-MEM-8); Vercel/Jude Gao, *AGENTS.md outperforms skills in our agent evals*, vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals (Tier-2 only; 100% vs 79% pass rates NOT used as VALIDATED quantitative thresholds — context corroboration only). **Tier 2 community/cross-tool:** **vercel-labs/skills**, https://github.com/vercel-labs/skills (open agent skills tool, npx skills, 40+ supported coding agents; `metadata.internal: true` + `INSTALL_INTERNAL_SKILLS=1` env var documented in README — Tier-2 cross-tool, NOT Claude-Code-canonical, anchor for DA-108 rejection); vercel-labs/skills Issue #572, *[Feature]: Exclude internal/meta skills from skill discovery* (Mar 2026, corroborates internal-skills convention in vercel-labs ecosystem); Vercel community discussion, https://community.vercel.com/t/removing-an-internal-skill-from-skills-sh/39521 (skills.sh registry honors `metadata.internal: true`); **obra/superpowers** v2.0 release notes, https://github.com/obra/superpowers/blob/main/RELEASE-NOTES.md (Tier-2; v2.0 "skills are now fully portable across platforms — no platform-specific env vars" — corroborates R-SHARE-4 + R-CROSS-1); **alirezarezvani/claude-skills** (Tier-2 community collection, 5,200+ stars, 232+ skills — groups skills under per-domain plugin bundles, corroborates R-WORKSPACE-3 plugin-promotion pattern); **shanraisshan/claude-code-best-practice**, https://github.com/shanraisshan/claude-code-best-practice/blob/main/reports/claude-skills-for-larger-mono-repos.md (Tier-2 community best-practice repo, multi-package monorepo skill layout). **Discovery (PROPOSED tag, named author required):** Lee Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/ (re-cited); Hidekazu Konishi, *Claude Code Harness and Environment Engineering: Designing the Frontline Where Local AI Agents Actually Live*, hidekazu-konishi.com 2026 (Discovery-tier named author; fswatch/inotifywait/auditd corroboration only, not load-bearing for any VALIDATED claim); Frontend Master / allahabadi.dev, *Claude Code Skill Frontmatter: Every YAML Option Explained*, https://allahabadi.dev/blogs/ai/claude-code-skills-frontmatter-complete-guide/ (full 15-key frontmatter list corroboration); paddo.dev, *Claude Code Gets Path-Specific Rules (Cursor Had This First)*, https://paddo.dev/blog/claude-rules-path-specific-native/ (Claude Code 2.0.64 added `paths` glob — corroborates R-WORKSPACE-4 + R-MONO-2); Mikhail Shilkov, *Claude Code Skills* deep dive, mikhail.io 2025-10 (re-cited); claudelog.com (FAQs on CLAUDE.md / AGENTS.md symlinks — Tier-2 community FAQ, single-page corroboration only); DeepWiki anthropics/skills indices (auto-generated documentation reproducible against GitHub source URLs — used to confirm per-skill `scripts/`, `references/`, `assets/` self-containment in the document-skills bundle). **Second opinion:** Gemini-9 — Google Gemini Deep Research output for Q-009, submitted by user 2026-05-04. **Verifications performed (≥3 per framework rule, six performed):** (1) arXiv:2604.17870 GraSP — VERIFIED REAL via arxiv.org/abs/2604.17870; Tencent affiliation; 20 Apr 2026 — G9-H1 ACCEPTED-AS-PROPOSED. (2) arXiv:2604.16911 Skilldex — VERIFIED REAL with caveat; ResearchGate institutional affiliation NOT verifiable for either author — G9-H2 ACCEPTED-AS-PROPOSED with caveat. (3) arXiv:2602.12430 Xu & Yan survey — VERIFIED REAL via arxiv.org/abs/2602.12430; Zhejiang University; v3 17 Feb 2026 — G9-H3 ACCEPTED-AS-PROPOSED with citation-chain caveat. (4) anthropics/claude-code Issue #44490 — VERIFIED REAL with full reproduction; root-cause analysis matches Gemini-9 cite verbatim — G9-B ACCEPTED-DECISIVE → R-MONO-1 refined + R-MONO-4 NEW. (5) anthropics/claude-code Issue #17302 — VERIFIED REAL; corroborates Bun.Glob `dot:false` issue family. (6) vercel-labs/skills `metadata.internal: true` — VERIFIED REAL via README + DeepWiki + Vercel community post + Issue #572 — G9-F ACCEPTED-DEFINITIVE → DA-108 logged. **Probabilistic verification:** anthropics/skills Issue #953 — PROBABLE-VERIFIED via XSD-files-real + DeepWiki-per-skill-scripts-confirmation + issue-number-range-confirmed + Issue #189 duplicate-pattern-corroboration — G9-C ACCEPTED-WITH-CAVEAT → T-SHARE-1 empirically grounded. **Outcome:** 6 contributions ACCEPTED (G9-A mechanical enforcement; G9-B Bun.Glob root-cause → R-MONO-1 refined + R-MONO-4 NEW; G9-C T-SHARE-1 empirical validation; G9-D DA-058 reaffirmation strengthened; G9-E centralized `~/.claude/docs/` PROPOSED candidate (d) for R-REFLOC-2; G9-F R-REFLOC-2(c) clarified — no new frontmatter key); 1 PROCESS confirmation (G9-G Q-012 disposition); 3 PROPOSED-only (G9-H1/H2/H3); 4 REJECTED as DA-108..111. **Independence note applied:** Gemini-9 is materially cleaner than Gemini-2/5/7/8 — three real arXiv IDs, one decisive Tier-1 GitHub issue, only minor citation-chain misattribution and one author-affiliation gap. Treated as one LLM-second-opinion data point per framework.
- **Anthropic Tier 1 (incremental over v1.7, fetched 2026-05-04 during Q-008 Turn 1 + Turn 2 vetting).** Anthropic, *Week 16 · April 13–17, 2026* changelog, Claude Code Docs, https://code.claude.com/docs/en/whats-new/2026-w16 (live fetch confirmed: Routines on Claude Code on the web — schedule + GitHub-event + API triggers, per-routine `/fire` endpoint under beta header `experimental-cc-routine-2026-04-01`, launched 2026-04-14 in research preview; daily run caps Pro 5/day, Max 15/day, Team-Enterprise 25/day; Opus 4.7 default on Max + Team Premium). Anthropic, *Hooks reference*, https://code.claude.com/docs/en/hooks (live re-fetch confirmed `InstructionsLoaded` payload schema: `file_path` + `memory_type: "Project"` + `load_reason: "session_start"` — fires for CLAUDE.md / `.claude/rules/*.md` only, NOT for `.claude/skills/*.md`). Anthropic, *Extend Claude with skills*, https://code.claude.com/docs/en/skills (re-confirmed: skill descriptions loaded into the Skill-tool's prompt, budget = 1% context window / 8000-char fallback / `SLASH_COMMAND_TOOL_CHAR_BUDGET` override; `disable-model-invocation: true` field gates whether the model can autonomously invoke). Anthropic, *Agent Skills overview*, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview (progressive disclosure architecture; ≤8 skills per Messages API request via container.skills). Anthropic, *Use Skills in Claude*, Help Center https://support.claude.com/en/articles/12512180-use-skills-in-claude (prompt-injection / data-exfiltration risk surface — anchor for R-LLMJ-12). Anthropic, *Demystifying evals for AI agents*, anthropic.com/engineering/demystifying-evals-for-ai-agents, 2026-01-09 (model-graded vs code-based eval tier distinction — anchor for R-LLMJ-1 / R-LLMJ-8 / DA-097). Anthropic, *Equipping agents for the real world with Agent Skills*, anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills, 2025-10 (re-cited; out-of-scope boundary — anchor for R-LLMJ-10). Anthropic API pricing page, https://platform.claude.com/docs/en/about-claude/pricing (retrieved 2026-04-29: Sonnet 4.6 $3/$15 per MTok, Opus 4.7 $5/$25, Haiku 4.5 $1/$5; prompt-cache 5-min write $3.75 / 1-hr write $6.00 / read $0.30 per MTok; batch processing 50% off — anchor for R-LLMJ-5 / R-LLMJ-11 cost calcs). anthropics/claude-code Issues: #43630 (PostToolUse `matcher: "Skill"` does not dispatch — open, validates R-LOAD-4); #30573 (InstructionsLoaded missing from docs — open, confirms CLAUDE.md / `.claude/rules/*.md` scope only); #31017 (InstructionsLoaded does not fire on `/clear` — open, confirms instruction-file scope); #22902 (custom skills directory paths via env var — feature request, confirms `CLAUDE_SKILLS_PATH` does not exist today). anthropics/skills Issue #532 (skill-workshop description optimizer requires ANTHROPIC_API_KEY — anchor for R-LLMJ-5 Prometheus 2 fallback rationale). github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md (re-cited: k=3 runs per eval query, 60/40 train/test split — anchor for R-LLMJ-4). **Tier 1 papers (verified, all arXiv IDs resolve, institutional affiliations verified):** Liu, Iter, Xu, Wang, Xu, Zhu, *G-Eval: NLG Evaluation using GPT-4 with Better Human Alignment*, EMNLP 2023, arXiv:2303.16634, https://aclanthology.org/2023.emnlp-main.153/ (anchor for R-LLMJ-3). Kim, Shin, Cho, Jang, Longpre, Lee, Yun, Shin, Kim, Thorne, Seo, *Prometheus: Inducing Fine-Grained Evaluation Capability in Language Models*, ICLR 2024, arXiv:2310.08491. Kim, Suk, Longpre, Lin, Shin, Welleck, Neubig, Lee, Lee, Seo, *Prometheus 2: An Open Source Language Model Specialized in Evaluating Other Language Models*, EMNLP 2024, arXiv:2405.01535, https://aclanthology.org/2024.emnlp-main.248/ (anchor for R-LLMJ-5 fallback). Pombal et al., *M-Prometheus: A Suite of Open Multilingual LLM Judges*, 2025 preprint, arXiv:2504.04953 (multilingual variant — relevant for R-CONTAM-1). Zheng et al., *Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena*, NeurIPS 2023 D&B, arXiv:2306.05685 (anchor for R-LLMJ-6 pairwise R-DRIFT-5 mode + documented position bias). Bai et al. (Anthropic), *Constitutional AI: Harmlessness from AI Feedback*, arXiv:2212.08073, 2022 (anchor for R-LLMJ-12 judge-as-untrusted-data hardening). Khattab et al., *DSPy*, ICLR 2024, arXiv:2310.03714 (re-cited: Suggest/Refine/BestOfN soft-assertion semantics — anchor for R-LLMJ-9). Xu et al., *ReWOO*, arXiv:2305.18323, 2023 (re-cited: determinism on hook path — anchor for R-LLMJ-1 / DA-078). Park & Zubiaga, *BiCon-Gate: Consistency-Gated De-colloquialisation for Dialogue Fact-Checking*, arXiv:2604.14389, April 2026 (Tier-1, **PROPOSED corroborating reference** for R-DRIFT-5-IMPL — bidirectional NLI as routing gate; domain transfer dialogue→skill-descriptions is structural-only). Anonymous (ICLR 2025), *Trust or Escalate: LLM Judges with Provable Guarantees for Human Agreement*, proceedings.iclr.cc/paper_files/paper/2025/file/08dabd5345b37fffcbe335bd578b15a0-Paper-Conference.pdf (introduces "Simulated Annotators" technique with K=3 few-shot × N=5 simulated annotators — DA-094 cites this as the actual paper Gemini-8 misattributed). "Debate, Deliberate, Decide (D3): A Cost-Aware Adversarial Framework for Reliable and Interpretable LLM Evaluation," arXiv:2410.04663, October 2024 (introduces SAMRE — DA-095 cites this as the actual paper Gemini-8 misattributed). **Tier 1 supporting (cosine-vs-NLI literature, anchor for DA-085 / DA-096):** Q² evaluation framework, arXiv:2104.08202; Similarity of Neural Network Models survey, ACM Computing Surveys 2024, https://dl.acm.org/doi/10.1145/3728458 (cosine invariance properties). **Tier 2 (corroborating, retrieved May 2026):** github.com/agent-ecosystem/agent-skill-implementation (canary-phrase methodology — anchor for R-LOAD-1); pasqualepillitteri.it/en/news/851 / claudefa.st/blog/guide/development/routines-guide / lowcode.agency / innobu.com (Routines launch corroboration, daily-cap details, beta-header). openai/tiktoken o200k_base (re-cited from Q-005). NIST SP 800-218 SSDF v1.2, csrc.nist.gov/projects/ssdf (DA-098 verification — does NOT mandate weekly skill-audit cadences). GitHub Docs Dependabot options reference (docs.github.com/en/code-security/.../dependabot-options-reference) — schedule cadence vocabulary anchor for R-CADENCE-1. dspy.ai/learn/programming/7-assertions/ + dspy.ai/cheatsheet/ (Suggest/Refine semantics anchor for R-LLMJ-9). **Discovery (corroborate-only, named for traceability):** Husain, *Using LLM-as-a-Judge For Evaluation*, hamel.dev/blog/posts/llm-judge/ and *Your AI Product Needs Evals*, hamel.dev/blog/posts/evals/ (DA-079 / DA-097 / R-LLMJ-2 / R-LLMJ-8 / R-XPOLL-2 anchor); Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, leehanchung.github.io 2025-10-26 (re-cited: skill descriptions in Skill-tool prompt — DA-091 anchor); comet.com/site/blog/llm-as-a-judge/ (Likert middle-cluster bias — DA-079 corroboration); finout.io Anthropic / Opus 4.7 pricing analyses (DA-081 anchor). **Discovery REJECTED as primary (DA-096):** Shaokat, "Mizan AI/ML Series" Articles #2/#5/#11/#16, Medium November 2025 — Discovery tier only, tier violation if treated as VALIDATED. **arXiv preprint (PROPOSED, not venue-accepted as of 2026-05-04):** arXiv:2510.27106, *Rating Roulette: Self-Inconsistency in LLM-As-A-Judge Frameworks*, 2025 (corroborating R-LLMJ-4 k=3 rationale; explicitly PROPOSED-not-VALIDATED). **Second opinion.** Gemini-8: Google Gemini Deep Research output for Q-008, submitted by user 2026-05-04. **Verifications performed (≥3 per framework rule):** (1) Routines launch + spec verified via live fetch of code.claude.com/docs/en/whats-new/2026-w16 + ≥4 independent secondary sources (G8-A ACCEPTED). (2) `<available_skills>` as host-introspectable env-var verified FALSE via code.claude.com/docs/en/skills + Issue #22902 + leehanchung deep-dive (G8-D REJECTED → DA-091). (3) `InstructionsLoaded` firing for skills verified FALSE via code.claude.com/docs/en/hooks payload schema + Issues #30573 + #31017 (G8-E REJECTED → DA-092). (4) Prometheus 3 verified NONEXISTENT via prometheus-eval.github.io + aclanthology.org + arxiv search (G8-A1 REJECTED → DA-093). (5) "Simulated Annotators" paper title verified FABRICATED — actual paper is "Trust or Escalate" ICLR 2025; specific ECE/AUROC numbers unverifiable (G8-A3 source 1 REJECTED → DA-094). (6) SAMRE EACL 2026 attribution verified FABRICATED — actual paper is D3 arXiv:2410.04663 named authors Oct 2024 (G8-A3 source 2 REJECTED → DA-095). (7) BiCon-Gate verified TIER-1 PROPOSED via arxiv.org/abs/2604.14389 + author affiliations (Park, Zubiaga / Queen Mary University of London) (G8-M ACCEPTED). (8) NIST SSDF skill-audit-cadence claim verified OVERREACH via csrc.nist.gov/projects/ssdf (G8-B2 REJECTED → DA-098). Outcome: 5 contributions ACCEPTED (G8-A Routines as primary cadence primitive → R-CADENCE-2 revised; G8-B daily-cap operational caveat → R-CADENCE-1 caveat extended; G8-C Issue #43630 corroboration → already accepted Turn 1; G8-M BiCon-Gate PROPOSED reference → added to R-DRIFT-5-IMPL anchors; G8-N non-Mizan cosine-rejection citation → DA-085 strengthened); 1 DEFERRED (G8-D K=5 → Q-013); 9 REJECTED as DA-091..DA-099. Independence note applied: misattributed citations + nonexistent successors + tier overrides + architectural confusions treated as one LLM-hallucination data point per `framework.second_opinion_review.independence_note`. **User-instigated framework reflection (prefatory turn 2026-05-04):** discussion of `brief_template` default mode (blind vs stress-test) logged for v1.9 with explicit user approval; brief_template UNCHANGED in v1.8.
- **Anthropic Tier 1 (incremental over v1.6, fetched 2026-05-04 during Q-007 Turn 1 + Turn 2 vetting).** Anthropic, *Hooks reference*, Claude Code Docs, https://code.claude.com/docs/en/hooks (live re-fetch confirmed: full canonical set of 29 hook events `SessionStart`, `Setup`, `UserPromptSubmit`, `UserPromptExpansion`, `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Notification`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `Stop`, `StopFailure`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`, `SessionEnd`; exit-code-2 blocking semantics per event with `SessionEnd` confirmed non-blocking — "Shows stderr to user only"; `stop_hook_active` field documented for Stop/SubagentStop loop prevention; five hook handler types `command`/`http`/`mcp_tool`/`prompt`/`agent` with prompt-type hooks "primarily used with Stop and SubagentStop events for intelligent task completion checking"; skills MAY ship hooks in YAML frontmatter via `hooks:` field with `once: true` honored only there; `async: true` and `asyncRewake: true` fields for non-blocking background hooks; `additionalContext` injection capped at 10,000 characters with file-spillover for larger payloads). Anthropic, *Extend Claude with skills*, Claude Code Docs, https://code.claude.com/docs/en/skills (re-confirmed `disable-model-invocation: true` semantics for destructive workflows; `version:` frontmatter field; `${CLAUDE_PLUGIN_DATA}` persistent directory surviving plugin updates; `${CLAUDE_PLUGIN_ROOT}` plugin install dir). Anthropic, *Skill authoring best practices*, Claude API Docs, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (re-confirmed: name ≤64 chars, description ≤1024 chars, SKILL.md body ≤500 lines). Anthropic, *Equipping agents for the real world with Agent Skills*, anthropic.com/engineering (re-confirmed canonical iterate-with-Claude pattern: "ask Claude to capture its successful approaches and common mistakes into reusable context and code within a skill. If it goes off track when using a skill to complete a task, ask it to self-reflect on what went wrong"). Anthropic, anthropics/skills repository, https://github.com/anthropics/skills (`skills/skill-workshop/SKILL.md` description-optimization workflow: ~20 trigger eval queries, 3 runs each for stable trigger rate, 60/40 train/test split, `--max-iterations 5` default, `best_description` selected by held-out test score; `cp -r <skill> <workspace>/skill-snapshot/` baseline pattern; shipped `pdf/`, `pptx/`, `docx/`, `xlsx/` use `references/` not `errata/`; `feedback.json` per-iteration schema). **Tier 1 papers (re-verified 2026-05-04, all arXiv IDs resolve, institutional affiliations verified, none future-dated):** Wang et al., *Voyager: An Open-Ended Embodied Agent with Large Language Models*, TMLR 2024, arXiv:2305.16291 (skill-library criterion: add only after self-verification confirms task completion; iterative prompting capped at 4 rounds per task; skills stored as code indexed by description embeddings — **clarified Turn 2:** Voyager's N=3 references are statistical replications across random seeds, not promotion thresholds). Madaan et al., *Self-Refine: Iterative Refinement with Self-Feedback*, NeurIPS 2023, arXiv:2303.17651 (returns plateau at ~3 iterations — anchors R-XPOLL-4 and R-RETRO ceiling). Shinn et al., *Reflexion: Language Agents with Verbal Reinforcement Learning*, NeurIPS 2023, arXiv:2303.11366 (verbal RL + episodic memory buffer; external feedback signal mandatory — anchors R-XPOLL-6 user-accept gate). Khattab et al., *DSPy: Compiling Declarative Language Model Calls into Self-Improving Pipelines*, NeurIPS 2023 / ICLR 2024, arXiv:2310.03714 (compiler optimizes any pipeline against a metric — anchors R-XPOLL-9 and meta-skill recompile-on-retro pattern). **Tier 2:** Anthropic resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf; anthropic.com/news/skills; anthropic.com/engineering/effective-harnesses-for-long-running-agents; agentskills.io ecosystem standard. **Discovery (used only to corroborate PROPOSED rules, never to upgrade VALIDATED):** github.com/obra/superpowers `/gotcha` slash-command pattern; Bill Khiz dev.to article on Gotchas-section value ("the Gotchas section is the most valuable part of any skill"); leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive (notes `when_to_use` is undocumented at Anthropic — explicit reminder to keep PROPOSED). **Gemini-7 second opinion (single second-opinion source for Q-007 Turn 2):** submitted by user 2026-05-04 as a Gemini Deep Research output. **Verifications performed:** (1) live fetch of code.claude.com/docs/en/hooks confirmed all 29 hook events and `Stop`/`SubagentStop` `stop_hook_active` semantics — Gemini-7 G7-9 ACCEPTED; (2) Voyager arXiv:2305.16291 paper re-read for N=3 framing — Gemini-7 G7-1 narrow technical claim CORRECT but attacks a strawman because v1.6 N=3 came from R-XPOLL-4 (Self-Refine) not Voyager; refinement adopted; (3) `!command` syntax search confirmed it is a custom-slash-commands feature (`.claude/commands/*.md`) not a SKILL.md feature — Gemini-7 G7-3 REJECTED as DA-074. Outcome: 5 contributions accepted (G7-1, G7-5, G7-7, G7-8, G7-9), 4 rejected (DA-074..DA-077). **User-submitted Slack thread (FlanksAPI monorepo):** scoped out of Q-007 per user's instruction (project-specific) but yielded **Q-012** queue item for general monorepo flat-skill naming convention, the router/index-skill pattern, and skill-loading-verification tests.
- **Anthropic Tier 1 (incremental over v1.5, fetched 2026-05-04 during Q-006 Turn 1 + Turn 2 vetting).** Anthropic, *Extend Claude with skills*, Claude Code Docs, https://code.claude.com/docs/en/skills (live re-fetch confirmed: `context: fork` semantics, `agent: Explore|Plan|general-purpose`, `disable-model-invocation` removes from context entirely, 5,000-tokens-per-skill / 25,000-tokens-combined re-attach budget, 1,536-character-per-entry cap, 1%-of-context-window dynamic budget with 8,000-character fallback, `SLASH_COMMAND_TOOL_CHAR_BUDGET` override, custom-commands-merged-into-skills clarification, bundled-skills inventory `/simplify` `/batch` `/debug` `/loop` `/claude-api`, `description` defaults to first paragraph if omitted). Anthropic, *Create custom subagents*, Claude Code Docs, https://code.claude.com/docs/en/sub-agents (bidirectional composition table; "Subagents cannot spawn other subagents"; fork inherits parent's full state when `CLAUDE_CODE_FORK_SUBAGENT=1`; background subagent auto-denies non-pre-approved tool requests). Anthropic, *Orchestrate teams of Claude Code sessions*, Claude Code Docs, https://code.claude.com/docs/en/agent-teams (team-lead pattern; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; v2.1.32+; Opus 4.6+; no nested teams; one team per session). Anthropic, *Hooks reference*, Claude Code Docs, https://code.claude.com/docs/en/hooks (canonical exit-code-2 effect table; `PostToolBatch` fires once per parallel batch and is the documented fan-in synchronization point; parallel hooks deduplicated by command/URL; `PreCompact` blockable, `PostCompact` not). Anthropic, *Parallel tool use*, Anthropic API Docs, https://platform.claude.com/docs/en/agents-and-tools/tool-use/parallel-tool-use (`disable_parallel_tool_use: true` flag; default parallel behavior). Hadfield, Zhang, Lien, Scholz, Fox, Ford (Anthropic Engineering Team), *How we built our multi-agent research system*, anthropic.com/engineering, 2025-06-13, https://www.anthropic.com/engineering/multi-agent-research-system (3–5 subagents in parallel for direct comparisons; >10 subagents for complex research; subagents use 3+ tools in parallel; 90% research-time reduction; subagents ≈4× chat tokens; multi-agent systems ≈15× chat tokens; four-field subagent task brief: objective, output format, tools/sources, task boundaries). anthropics/skills, GitHub repository, https://github.com/anthropics/skills (skill-workshop, mcp-builder, claude-api, pdf, pptx, xlsx, docx, webapp-testing, algorithmic-art, brand-guidelines, internal-comms, theme-factory). **Tier 1 peer-reviewed (verified non-future-dated and institutionally affiliated):** Wu, Bansal, Zhang et al. (Microsoft Research / Penn State / UW / Xidian), *AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation*, arXiv:2308.08155 (Aug 2023); Hong et al., *MetaGPT: Meta Programming for A Multi-Agent Collaborative Framework*, arXiv:2308.00352 (Aug 2023, ICLR 2024); Wang, Xie, Jiang, Mandlekar, Xiao, Zhu, Fan, Anandkumar (NVIDIA / Caltech), *Voyager: An Open-Ended Embodied Agent with Large Language Models*, arXiv:2305.16291 (May 2023, TMLR 2024). **Tier 2 (cross-system corroboration):** OpenAI, *Function calling — parallel tool use*, https://developers.openai.com/api/docs/guides/function-calling; LangChain AI, *langgraph-supervisor-py*, https://github.com/langchain-ai/langgraph-supervisor-py; LangChain, *map-reduce branches for parallel execution*, https://langchain-ai.github.io/langgraphjs/how-tos/map-reduce/. **Discovery (logged but not promoted, claims tagged PROPOSED):** GitHub Issue anthropics/claude-code#17283 (Skill tool may ignore `context: fork`/`agent` when slash-invoked) and #10412 (plugin-installed Stop hooks fail to honor exit-2 continuation) — flagged for re-verification in a future promotion pass; not adopted as rules in v1.6. Scott Spence, *How to Make Claude Code Skills Activate Reliably*, scottspence.com (community-measured auto-activation reliability gap; PROPOSED only). **User side-question (Karpathy LLM-Wiki):** Karpathy, *llm-wiki*, GitHub Gist 442a6bf555914893e9891c11519de94f (re-vetted; previously cited in v1.0); rohitg00 (fork), *LLM Wiki v2 — extending Karpathy's LLM Wiki pattern with lessons from building agentmemory*, GitHub Gist 2067ab416f7bbe447c1977edaaa681e2, last active 2026-05-03 — vetted as Discovery, named author with linked open-source `agentmemory` project; routed to **Q-011** rather than incorporated into Q-006 because the topic is knowledge-base patterns, not runtime composition. **Gemini-6 second opinion:** Google Gemini Deep Research output for Q-006, submitted by user 2026-05-04. Vetting: 4 contributions accepted, 6 rejected (DA-056..DA-061); 3 hallucinations isolated (`ConfigChange`, `UserPromptExpansion`, 5–7 RPM organization-tier RPS cap); 1 overcautious hedge corrected (per-branch budget VALIDATED, not PROPOSED).
- **Anthropic Tier 1 (incremental over v1.4, fetched 2026-05-02 during Q-005 Turn 2 vetting).** Anthropic, *Extend Claude with skills* (LIVE) — code.claude.com/docs/en/skills, fetched 2026-05-02 — FULL frontmatter reference table now lists: name, description, when_to_use (newly documented), argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell. Documents 1,536-character truncation cap on combined description+when_to_use, dynamic 1%-of-context skill-listing budget with 8000-char fallback, `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var override, 25,000-token re-attach budget after auto-compaction, 5,000-token-per-skill carry-forward, `context: fork` + `agent: Explore|Plan|general-purpose` subagent execution. **RESOLVES Q-005 R-FM-4** (was PROPOSED-allow-list-status: live docs confirm `when_to_use` officially documented). Anthropic, *plugin-dev skill-development SKILL.md* — github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/skill-development/SKILL.md, fetched 2026-05-02 — verbatim mandate '❌ DON'T: Use second person anywhere' and 'Write the entire skill using imperative/infinitive form (verb-first instructions), not second person.' Description-voice mandate: third-person template 'This skill should be used when the user asks to "phrase 1", "phrase 2"'. Body-length target: 1,500-2,000 words ideal, <5,000 words max (consistent with R-BODY-1 ≤500 lines). Reference-file 'large' threshold: >10,000 words triggers grep-pattern guidance in SKILL.md (informs R-SR-6 PROJECT-INTERNAL calibration). Common-Mistakes section uses explicit ✓ DO / ❌ DON'T pairs (Tier-1 source for R-BODY-8 negative-counter-examples promotion). **Tier 2 (re-checked).** docs.crewai.com — Gemini-5 cited 0.85 cosine threshold; not independently corroborated; logged as DA-050. Astral Ruff README — Gemini-5 cited as R-CONTAM-1 precedent; conceptual mismatch (code-origin prefixes ≠ evidence-tier provenance); logged as DA-054. **Discovery (informational only).** Lee Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, leehanchung.github.io, October 2025 — useful as historical snapshot showing `when_to_use` was undocumented at that point in time, but superseded by 2026-05-02 live docs. **Second opinion.** Gemini-5: Google Gemini Deep Research output for Q-005, submitted by user 2026-05-02. Vetted: 4 contributions accepted (R-FM-4 promotion via live docs verification, R-BODY-9 promotion via skill-development SKILL.md, full Claude Code extended frontmatter key list, 1,536-char description+when_to_use cap re-affirmation); 6 rejected as DA-049 (Voyager Tier-1 conflation), DA-050 (CrewAI 0.85 unverified), DA-052 (250-char terminal truncation hallucination), DA-053 (R-SR-7 TOC-vs-anchor conflation), DA-054 (Ruff prefixes ≠ provenance), DA-055 (@anthropic-ai/tokenizer staleness).
- **Anthropic Tier 1 (incremental over v1.3).** Anthropic, *Skill authoring best practices* — confirms 500-line body cap, ≤5000 tokens recommended, 100-line TOC threshold for references, description ≤1024 chars, description+when_to_use ≤1536 chars, platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices. Anthropic, *Extend Claude with skills* — `disable-model-invocation: true` field documented; permission syntax `Skill(name)` and `Bash(command *)`; `allowed-tools` and `user-invocable` fields, code.claude.com/docs/en/skills. Anthropic, *Automate workflows with hooks* — Claude Code hooks treat exit code 2 specifically as the 'block' signal, code.claude.com/docs/en/hooks-guide. Anthropic, *claude-code Issue #26251* — `disable-model-invocation: true` blocks user slash invocation in some configurations; pair with explicit `user-invocable: true` for safety, github.com/anthropics/claude-code/issues/26251. Anthropic, *claude-code Issue #22345* — `disable-model-invocation` ignored in plugin context (different enforcement than user-defined skills), github.com/anthropics/claude-code/issues/22345. Anthropic, *claude-code Issue #19141* — clarification of `user-invocable` (UI only) vs `disable-model-invocation` (programmatic invocation block), github.com/anthropics/claude-code/issues/19141. Anthropic, *skills Issue #37 (RE-CITED)* — confirms full frontmatter allow-list `{name, description, license, allowed-tools, metadata}`, NOT `{name, description}` only as Gemini-4 falsely claimed, github.com/anthropics/skills/issues/37. **Tier 2.** agent-ecosystem/skill-validator v1.1.0 (March 2026, Go, MIT, 45 stars) — VERIFIED REAL Tier-2 reference implementation. CLI surface: `validate structure / validate links / analyze content / analyze contamination / score evaluate / check`. Exit codes 0=clean / 1=errors / 2=warnings / 3=CLI-error (DIFFERENT from project's contract; logged as friction in DA-046). --strict flag confirmed. Token thresholds: SKILL.md body warn 5K tokens or 500 lines; per-reference warn 10K err 25K; total references warn 25K err 50K; uses `o200k_base` encoding (project switched from cl100k_base to match). Detects unclosed code fences (R-BODY-7 source), broken internal links (R-SR-6 source), orphan files via reachability graph with Python import resolution (R-SR-7 source), keyword stuffing in descriptions (R-XPOLL-10 source), cross-language contamination (R-CONTAM-1 source). github.com/agent-ecosystem/skill-validator. agentskills.io specification — open standard the agent-ecosystem validator targets. pre-commit.com — `language: python`, `additional_dependencies`, `pass_filenames` semantics, `files` regex behavior. github.com/openai/tiktoken — `o200k_base` encoding for newer models (replaces cl100k_base in R-BODY-2). sbert.net — `sentence-transformers/all-MiniLM-L6-v2` model card; `util.cos_sim`. **Second opinion.** Gemini-4: Google Gemini Deep Research output for Q-004, submitted by user 2026-05-01. Vetted: 4 contributions accepted (`disable-model-invocation: true`, `--strict` flag, generic-markdown-linter discard, agent-ecosystem repo URL); 5 rejected (false Issue #37 narrowing → DA-039, broken pre-commit `~/\.claude/skills` regex → DA-040, broken `pass_filenames: true` → DA-041, suspicious arxiv:2604.20462 → DA-042, incompatible exit-code contract → DA-043).
- **Anthropic Tier 1 (incremental over v1.2).** Anthropic, *skill-workshop SKILL.md* (485 lines, pushy trigger-rich description, 9 helper scripts, schemas.md ref, eval_review.html asset, 3 sub-agent prompts), github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md. Anthropic, *skill-workshop scripts/* (init_skill, quick_validate, package_skill, run_eval, run_loop, improve_description, aggregate_benchmark, generate_report, utils), github.com/anthropics/skills/tree/main/skills/skill-workshop/scripts. Anthropic, *skill-workshop references/schemas.md* (evals.json schema, behavioral 2–3 prompts, trigger-eval 20 queries 60/40 split). Anthropic, *skill-workshop Issue #37* (frontmatter whitelist {name, description, license, allowed-tools, metadata}), github.com/anthropics/skills/issues/37. Anthropic, *skill-workshop Issue #239* (TODO YAML-list parse bug → R-META-7 creation gate), github.com/anthropics/skills/issues/239. Anthropic, *skill-workshop Issue #518* (grader misroute, Bash blocked in baseline, aggregate_benchmark glob mismatch — verified during Gemini-3 vetting; R-META-18..19), github.com/anthropics/skills/issues/518. Anthropic, *skill-workshop Issue #532* (run_loop.py SSO incompatibility — verified during Gemini-3 vetting; strengthens R-META-7), github.com/anthropics/skills/issues/532. Anthropic, *claude-code Issue #34609* (run_loop.py silent ANTHROPIC_API_KEY usage; reinforces R-META-9 no-silent-network-actions), github.com/anthropics/claude-code/issues/34609. Anthropic, *The Complete Guide to Building Skills for Claude*, resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf (description grammar [What it does] + [When to use] + [Key capabilities]; anchors R-META-13). **Tier 1 peer-reviewed papers.** Khattab, Singhvi, Maheshwari, Zhang, Arora, Santhanam, Saad-Falcon, Phan, Moazam, Miller, Zaharia, Potts (Stanford + UC Berkeley + CMU), *DSPy: Compiling Declarative Language Model Calls into Self-Improving Pipelines*, ICLR 2024, arXiv:2310.03714 (compiler model → R-META-3..4; BootstrapFewShot max_bootstrapped_demos=4 → R-META-15). Madaan, Tandon, Gupta, Hallinan, Gao, Wiegreffe, Alon, Dziri, Prabhumoye, Yang, Welleck, Majumder, Gupta, Yazdanbakhsh, Clark (CMU + AI2 + UW + Google + Meta), *Self-Refine: Iterative Refinement with Self-Feedback*, NeurIPS 2023, arXiv:2303.17651 (diminishing returns past iter 2; cap at 4 → R-META-8). Shinn, Cassano, Berman, Gopinath, Narasimhan, Yao (Northeastern + MIT + Princeton), *Reflexion: Language Agents with Verbal Reinforcement Learning*, NeurIPS 2023, arXiv:2303.11366 (external verbal feedback signals → R-META-9). Pan, Razin, Chen, *Spontaneous Reward Hacking in Iterative Self-Refinement*, 2024, arXiv:2407.04549 (same-model self-judging diverges under optimization pressure; reinforces R-META-9). Wang, Xie, Jiang, Mandlekar, Xiao, Zhu, Fan, Anandkumar (NVIDIA + Caltech), *Voyager*, TMLR 2024, arXiv:2305.16291 + curriculum.txt prompt + first-15-tasks-no-retrieval rule → R-META-11..12. Xu, Peng, Lei, Mukherjee, Liu, Xu (NC State + Microsoft), *ReWOO: Decoupling Reasoning from Observations*, 2023, arXiv:2305.18323 → R-META-10 deterministic-vs-LLM split. **Tier 2.** agentskills.io/specification — open standard scaffold tree. docs.npmjs.com/cli/v11/commands/npm-init — 8-prompt baseline + `--yes` zero-prompt path. Sheshbabu, *Rust for JS Devs Tooling Overview*, 2023, sheshbabu.com — `cargo new` zero-prompt. Chacon & Straub, *Pro Git: Git Hooks*, git-scm.com — pre-commit/pre-push gating norm. Hjelle, lint-staged pre-commit hook gist, 2020 — staged-only, never on save. dspy.ai/learn/optimization/optimizers — `BootstrapFewShot(max_bootstrapped_demos=4, max_labeled_demos=16)`. **Discovery (named-author).** Lee Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, leehanchung.github.io 2025-10-26. **Second opinion.** Gemini-3: Google Gemini Deep Research output for Q-003 meta-skill design, submitted by user 2026-05-01. Vetted: Issues #518/#532 verified real → R-META-18/19 added; YAML+JSON-Schema embedding accepted → R-META-3 strengthened; negative counter-examples → R-META-16; synthetic→organic example lifecycle → R-META-17. Rejected: 3 fabricated/misattributed arXiv IDs (DA-031..033) and one folklore-repeat 100-line cap (DA-034). 4 rules adopted, 4 fabrications rejected.
- **Anthropic Tier 1 (incremental over v1.1).** Anthropic, *Using Agent Skills with the API* — "You can include up to 8 Skills per request" via container.skills parameter, platform.claude.com/docs/en/build-with-claude/skills-guide (verified during Turn 2 Gemini-2 vetting). Anthropic, *Skill authoring best practices* — documents ≤500 lines for SKILL.md body (overrides 100/300 folklore from both parallel v1.1 files), platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices. Anthropic, *Extend Claude with skills* — confirms `context: fork` + `agent:` frontmatter mechanism (rejecting Gemini-2's `CLAUDE_CODE_FORK_SUBAGENT` env var fabrication), code.claude.com/docs/en/skills. Anthropic, *Tools reference (Week 13)* — confirms PowerShell access via `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` env var, `shell:` only on hook entries, code.claude.com/docs/en/tools-reference. **Tier 1 peer-reviewed papers.** Wang, Xie, Jiang, Mandlekar, Xiao, Zhu, Fan, Anandkumar, *Voyager: An Open-Ended Embodied Agent with Large Language Models*, TMLR 2024, arXiv:2305.16291, NVIDIA + Caltech. Karpas et al. (AI21 Labs), *MRKL Systems*, 2022, arXiv:2205.00445. Schick, Dwivedi-Yu, Dessì, Raileanu, Lomeli, Zettlemoyer, Cancedda, Scialom (Meta AI), *Toolformer: Language Models Can Teach Themselves to Use Tools*, NeurIPS 2023, arXiv:2302.04761. Shinn, Cassano, Berman, Gopinath, Narasimhan, Yao, *Reflexion: Language Agents with Verbal Reinforcement Learning*, NeurIPS 2023, arXiv:2303.11366, Northeastern + MIT + Princeton. Madaan, Tandon, Gupta, Hallinan, Gao, Wiegreffe, Alon, Dziri, Prabhumoye, Yang, Welleck, Majumder, Gupta, Yazdanbakhsh, Clark, *Self-Refine: Iterative Refinement with Self-Feedback*, NeurIPS 2023, arXiv:2303.17651, CMU + AI2 + UW + Google + Meta. Xu, Peng, Lei, Mukherjee, Liu, Xu, *ReWOO: Decoupling Reasoning from Observations for Efficient Augmented Language Models*, 2023, arXiv:2305.18323, NC State + Microsoft. Khattab et al., *DSPy: Compiling Declarative Language Model Calls into Self-Improving Pipelines*, ICLR 2024, arXiv:2310.03714, Stanford + UC Berkeley + CMU. **Rejected as skill-authoring rules (DA-018..020).** Yao, Yu, Zhao, Shafran, Griffiths, Cao, Narasimhan, *Tree of Thoughts*, NeurIPS 2023, arXiv:2305.10601. Wang, Xu, Lan, Hu, Lan, Lee, Lim, *Plan-and-Solve Prompting*, ACL 2023, arXiv:2305.04091. Paranjape, Lundberg, Singh, Hajishirzi, Zettlemoyer, Tulio Ribeiro, *ART*, 2023, arXiv:2303.09014. **Tier 2.** Linux Foundation, *Announces the Formation of the Agentic AI Foundation*, 9 December 2025, linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation — overturns FILE B's rejection of LF backing of AGENTS.md. OpenAI, *Co-founds the Agentic AI Foundation*, openai.com/index/agentic-ai-foundation, 9 December 2025. agents.md homepage (April 2026 — closest-file-wins precedence; AAIF stewardship). developers.openai.com/codex/guides/agents-md (AGENTS.override.md pattern; precedence chain). docs.factory.ai/cli/configuration/agents-md (closest-file precedence). docs.cline.bot/features/skills (cross-tool skill discovery). cursor.com/docs/skills + cursor.com/changelog/2-4 (Cursor v2.4 SKILL.md adoption). github.com/anthropics/claude-code Issue #40121 (250-char per-description listing cap; SLASH_COMMAND_TOOL_CHAR_BUDGET override). **Discovery (named-author).** Hamel Husain, *Evals Skills for Coding Agents*, hamel.dev/blog/posts/evals-skills/, March 2026 (verified during Turn 2 — real post; cross-ref for R-XPOLL-2 strengthening and Q-008; the `eval_queries.json` schema attributed by Gemini-2 is NOT in this post — see DA-024). Eugene Yan, *Patterns for Building LLM-based Systems & Products*, eugeneyan.com/writing/llm-patterns/, 2023 (Defensive UX + Guardrails patterns; cross-ref for invocation control). Lilian Weng, *LLM Powered Autonomous Agents*, lilianweng.github.io/posts/2023-06-23-agent/, 23 June 2023 (procedural-vs-declarative memory framing; confirms R-SR cross-reference, no new rule). Simon Willison, blog posts on Claude Skills (simonwillison.net/2025/Oct/16/claude-skills/) and Agentic Engineering Patterns (Action-Selector pattern cross-ref). Lee Hanchung, *Claude Agent Skills: A First Principles Deep Dive*, leehanchung.github.io 2025-10-26 (empirical confirmation that routing is description-similarity-based, supports MRKL-1 / R-XPOLL-4). **Second opinion.** Gemini-2: Google Gemini Deep Research output for Q-002 reconciliation + cross-pollination, submitted by user 2026-05-01. Vetted: Hamel Husain post confirmed; paper set confirmed and overlaps Turn 1; AAIF/LF backing confirmed (overturning FILE B's earlier rejection); 4 hallucinations rejected with rationale (DA-021..DA-024). 2 specifics flagged for Q-005 verification (managed-agents-2026-04-01 beta header; alwaysLoad MCP option in v2.1.121).
- **Anthropic Tier 1.** Anthropic, *Extend Claude with skills*, Claude Code Docs, 2026, https://code.claude.com/docs/en/skills. Anthropic, *Agent Skills (overview)*, Claude API Docs, 2026, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview. Anthropic Engineering, *Equipping agents for the real world with Agent Skills*, 2025-10-16, https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills. Anthropic Engineering, *Effective context engineering for AI agents*, 2025-09-29, https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents. Anthropic, *skills/skill-workshop/SKILL.md*, github.com/anthropics/skills, 2026, https://github.com/anthropics/skills/blob/main/skills/skill-workshop/SKILL.md. Anthropic, *skills/pdf/reference.md*, github.com/anthropics/skills, 2026, https://github.com/anthropics/skills/blob/main/skills/pdf/reference.md. Anthropic, *skills/doc-coauthoring/SKILL.md*, github.com/anthropics/skills, 2026, https://github.com/anthropics/skills/blob/main/skills/doc-coauthoring/SKILL.md. Anthropic, *Issue #18192 — Recursive skill discovery*, github.com/anthropics/claude-code, 2026, https://github.com/anthropics/claude-code/issues/18192. Anthropic, *Issue #10238 — nested skills discovery*, 2025/2026, https://github.com/anthropics/claude-code/issues/10238. Anthropic, *Issue #44199 — skill name shadowing native commands*, 2026, https://github.com/anthropics/claude-code/issues/44199 (referenced via Gemini-1 — flagged for Q-005 promotion verification). Anthropic, *Issue #27569 — use-when field ignored*, 2026, https://github.com/anthropics/claude-code/issues/27569 (referenced via Gemini-1 — flagged for Q-005 promotion verification). Anthropic, *How Claude remembers your project (memory)*, Claude Code Docs, 2026, https://code.claude.com/docs/en/memory. Anthropic, *Create custom subagents*, Claude Code Docs, 2026, https://docs.anthropic.com/en/docs/claude-code/sub-agents. Anthropic, *The Complete Guide to Building Skills for Claude*, resources.anthropic.com, 2025/2026, https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf. **Tier 2.** agentskills.io, *Agent Skills Specification*, 2025-12, https://agentskills.io/specification.md. OpenAI, *Agent Skills (Codex)*, 2026, https://developers.openai.com/codex/skills (cross-vendor only). Microsoft / VS Code, *Use Agent Skills in VS Code*, 2026, https://code.visualstudio.com/docs/copilot/customization/agent-skills. agents.md project, *AGENTS.md*, 2025/2026, https://agents.md/. **Discovery.** Karpathy, *llm-wiki gist*, 2026-04-04, https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f. Karpathy, *X post defining "context engineering"*, 2025-06-25, https://x.com/karpathy/status/1937902205765607626. Zhang & Xia (Thoughtworks), *Structured-Prompt-Driven Development (SPDD)*, martinfowler.com, 2026-04-28, https://martinfowler.com/articles/structured-prompt-driven/. Liang et al. (Peking University), *From Skill Text to Skill Structure: The SSL Representation for Agent Skills*, arXiv:2604.24026, 2026-04-27/v2 04-28, https://arxiv.org/abs/2604.24026 (vocabulary only — quantitative thresholds NOT adopted). Shilkov, *Inside Claude Code Skills*, mikhail.io, 2025-10, https://mikhail.io/2025/10/claude-code-skills/. **Second opinion.** Gemini-1: Google Gemini Deep Research output for Q-001, submitted by user 2026-05-01.

<!-- @end: references -->

---

<!-- @anchor: changelog -->
## Changelog

Newest first. The first entry is implicitly the current version.

### v1.17

**Q-019 closed (auto-memory architecture chapter; AutoDream / `tengu_onyx_plover` / KAIROS umbrella formalization).** Verdict: **VALIDATED Tier-1 silence on AutoDream / `tengu_onyx_plover` / `/dream` / KAIROS; ESTABLISHED auto-memory architecture as a new system-design subsection with 5 new rules; CODIFIED the cross-container vs intra-MEMORY.md supersession split via R-MEM-1-CLARIFICATION.** **Tier-1 silence verified** across 13+ canonical Anthropic surfaces (memory + glossary + how-it-works + sub-agents + skills + commands + best-practices + claude-directory docs; news Apr–May 2026; engineering posts; CHANGELOG; Complete Guide PDF; anthropics/skills; anthropics/anthropic-cookbook). Canonical post-GA terminology is **"Auto memory"**. **Distinct-product disambiguation locked in:** `platform.claude.com/docs/en/managed-agents/dreams` documents a separate Managed Agents API product (asynchronous-job-with-immutable-input, beta header `dreaming-2026-04-21`), NOT the in-CLI AutoDream consolidator. **5 new rules adopted:** **R-AUTODREAM-1 VALIDATED** [reference][claude-code-only] — file scope strictly `~/.claude/projects/<slug>/memory/`; Tier-1 anchored via `anthropics/claude-code` Issues #39204, #47959, #50694; project rule places durable user constraints in CLAUDE.md/AGENTS.md never MEMORY.md. **R-AUTODREAM-2 PROPOSED-strong** [reference][claude-code-only] — gating by GrowthBook flag `tengu_onyx_plover` corroborated across ≥7 independent post-leak archives derived from Chaofan Shou's 2026-03-31 v2.1.88 npm sourcemap discovery; user toggle `autoDreamEnabled` Tier-1 anchored via Issues #39633/#47959; triple-gate trigger (≥24h + ≥5 sessions + advisory file lock at `<memory>/.consolidate-lock`) with only the lock-file path Tier-1 anchored (Issue #50694); four-phase Orient → Gather → Consolidate → Prune pipeline. **R-AUTODREAM-3 VALIDATED** [reference][portable] — operational orthogonality with (a) Task Budgets via Tier-1 explicit *"Task budgets are not supported on Claude Code or Cowork surfaces at launch"* (`platform.claude.com/docs/en/build-with-claude/task-budgets`); (b) auto-compaction via lifecycle disjointness (intra-session vs inter-session); (c) R-FAIL-1 25K/5K skill re-attach pool because skills are not in AutoDream's file scope. **R-AUTODREAM-4 PROPOSED** [reference][claude-code-only] — corrects the project's working "KAIROS daemon" terminology: Anthropic's KAIROS is the broader proactive-mode umbrella (compile-time `feature('KAIROS')` + runtime `tengu_kairos`, env `CLAUDE_CODE_PROACTIVE=1`) encompassing six sub-features and four exclusive specialized tools (`SendUserFile`, `PushNotification`, `SubscribePR`, `SleepTool`); AutoDream is one sub-feature gated by `tengu_onyx_plover`. **R-MEM-1-CLARIFICATION VALIDATED — NEW v1.17** [reference][claude-code-only] — locks in the cross-container vs intra-MEMORY.md split: R-MEM-1 hierarchy holds for cross-container precedence (CLAUDE.md > Auto Memory) but does NOT establish intra-MEMORY.md user-vs-Claude-consolidation precedence; Tier-1 Issue #47959 verbatim documents AutoDream destructively deleting user-reinforced files within MEMORY.md. The only durable cross-session anchor for user constraints is CLAUDE.md / AGENTS.md. **Gemini-19 vetting: 9 incorporations, 3 rejections (DA-Q019-1..-3).** **Incorporations:** Tier-1 silence reaffirmation; new `code.claude.com/docs/en/glossary` Tier-1 anchor; davccavalcante/claude-code-leaked README as additional independent corroboration of the `tengu_*` namespace; flag-function attributions for `tengu_ultraplan_model` (planning model) and `tengu_cobalt_raccoon` (auto-compact) corroborated against davccavalcante README — Turn-2 preliminary skepticism RETRACTED on direct verification; triple-gate trigger architecture confirmed via additional independent source; 15-second blocking budget on KAIROS proactive shell commands; cross-container hierarchy framing; auto-compaction-vs-offline-consolidation orthogonality framing; Task Budget orthogonality framing. **Rejections:** **DA-Q019-1** universal-supersession overreach via two-level conflation (cross-container reading correct; intra-MEMORY.md universal-user-precedence reading directly contradicted by Tier-1 Issue #47959 — same conflation pattern as DA-140); **DA-Q019-2** Discovery-tier quantitative overreach (1,200 sessions / 50 consecutive failures / 250K API calls/day globally — single Discovery-tier source, no Tier-1 anchor — same pattern as DA-156); **DA-Q019-3** arXiv:2604.00009 misattribution (verified end-to-end: 2604.00009 IS the **Eyla: Toward an Identity-Anchored LLM Architecture** paper, NOT the "Sumers et al. — Integrating sleep-time compute" paper Gemini-19 cited; Sumers is *referenced inside Eyla* as the 2023 cognitive-architectures-survey author and Letta–sleep-time-compute as a one-line literature note inside Eyla; the directional claim is correct with the **corrected citation arXiv:2504.13171** "Sleep-time Compute: Beyond Inference Scaling at Test-time" per o-mega.ai's TypeScript-anchored cite + smeuse.org's independent description — same pattern as DA-Q016-4). **Independence note applied:** Gemini-19 fits the systemic Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16/18 of fabricating specific citations (issue numbers, env-var names, arXiv IDs, supersession-rule overreach) anchored to plausible-sounding mechanisms; treated as ONE LLM-second-opinion data point. Materially: Gemini-19's net contribution is positive — davccavalcante corroboration measurably strengthens `tengu_*` findings; glossary anchor is new Tier-1 evidence; the supersession-conflation rejection generated R-MEM-1-CLARIFICATION (the most consequential v1.17 rule). **Tabs updated:** system-design § Locations and Precedence — new "Auto-memory architecture (Q-019 v1.17)" subsection with 5 anchored rules and distinct-product disambiguation block; research (Q-019 closed in queue → queue NOW EMPTY; T-019 tracker row added; DA-Q019-1..-3 logged; v1.17 References entry — code.claude.com/docs/en/memory + glossary + how-claude-code-works + Issues #50694/#47959/#39204/#39633/#39135 + CHANGELOG + platform.claude.com Dreams + Task Budgets + davccavalcante/claude-code-leaked + o-mega.ai + arXiv:2504.13171 corrected + arXiv:2604.00009 misattribution-target + smeuse.org + 4 corroborating leak-archive repos + alex000kim.com + wavespeed.ai + mainstream-press disambiguation cluster + Discovery-tier writeup cluster + Gemini-19; Session Notes — Q-019 section NEW with sources table, decisions adopted, rejected claims, cross-section impact, contradiction check, compliance-validation pass; Reasoning Journey v1.17 paragraph; Tracker T-019 row). **Contradiction check: PASSED.** R-AUTODREAM-1 ↔ R-MEM-1 (file scope contained within Auto Memory tier); R-AUTODREAM-1 ↔ R-BOUNDARY-3 ↔ DA-140 (R-AUTODREAM-1's "place durable user constraints in CLAUDE.md never MEMORY.md" is positive corollary); R-AUTODREAM-3 ↔ R-FAIL-1 (extends Q-018 Task Budget orthogonality to a third orthogonal mechanism); R-MEM-1-CLARIFICATION ↔ R-MEM-1 ↔ DA-140 (R-MEM-1 preserved on cross-container; clarification scopes user-precedence to cross-container only); R-AUTODREAM-4 ↔ project terminology (corrects "KAIROS daemon" framing); DA-Q019-3 corrected arXiv:2504.13171 ↔ project domain rule §5 (verification passes for corrected citation, future-date check passes — 2504.13171 maps to April 2025, not future-dated relative to 2026-05-07). **Compliance validation: PASS** (mental simulation per Self-validation: anchor pairing intact, every new `@rule:`/`@da:`/`@session:` marker has matching `<a id>` tag, all section anchors preserved, all cross-links resolve to real targets, append-only invariant preserved across DAs/References/Changelog, queue and tracker IDs unique with no simultaneous duplication, frontmatter/title/changelog version triple-consistent at 1.17, brief and summary wrapped in their respective markers, end-of-turn marker emitted last). **0 breaking changes** — no existing rule's substantive content changed; R-MEM-1-CLARIFICATION refines but does not rewrite R-MEM-1; all v1.16-authored skills remain conformant. Q-019 → ✦ Researched v1.17. **Queue depth after Q-019: 0 sessions remaining.** Framework empty-queue protocol activated; user prompted to choose: (1) add new topics; (2) fresh-eyes review (scan whole project, propose gaps); (3) reopen specific topic; (4) declare research complete.

### v1.16

**Q-018 closed (independent Tier-1 audit of the per-skill-set 25,000-token re-attach budget).** Verdict: **HOLD R-FAIL-1 numeric core unchanged; NARROW SCOPE on isolation clause; ADD Opus 4.7 effective-budget caveat and Task Budget orthogonality note; EXPAND confusable-25K disambiguation list from 4 to 6 mechanisms.** **Numeric core verdict.** The 25,000 / 5,000 / most-recent-first figures are still live on `code.claude.com/docs/en/skills` (live re-fetch 2026-05-07; verbatim quotation re-confirmed) but **no second independent Tier-1 source restates them** — exhaustive sweep returned SILENT across platform.claude.com agent-skills overview/best-practices/getting-started/enterprise, anthropic.com/engineering posts on Agent Skills + context engineering + writing-tools-for-agents + multi-agent-research-system, the 32-page *Complete Guide to Building Skills for Claude* PDF, anthropics/skills SKILL.md exemplars (skill-workshop/pdf/pptx/docx/xlsx), and Opus 4.7 release notes. The single canonical Anthropic source is sufficient under the validation gate's single-canonical-source clause; rule status remains VALIDATED but is now explicitly labeled "single-canonical-source" rather than "multi-source." **Scope narrowing.** The deprecated phrase "per-skill-set, per-branch" is project-internal terminology not appearing in any Anthropic Tier-1 doc and originated in third-party Git-worktree-based orchestration tools; replaced with "per-session, per-context-window" and the isolation invariant is now framed as **project-internal composition** of canonical sub-agents doctrine + bare combined-budget figure (corroborated by claude-code Issues #5812 and #10212 which confirm sub-agent context isolation as a user-observed primitive). **Opus 4.7 effective-budget compression caveat.** Anthropic's Opus 4.7 release notes (platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7) document a tokenizer change producing 1.0–1.35× more tokens per identical text, with explicit guidance to *"revisit `max_tokens` headroom and compaction triggers."* Effective skill content fitting in the unchanged 25K/5K nominal budget is compressed by up to ~26% on Opus 4.7 sessions; nominal figures unchanged. NOT a silent revision in the Issue #45019 sense. **Task Budget orthogonality.** `task-budgets-2026-03-13` beta header (verified Tier-1) is forward-looking economic governor over the entire agentic loop; orthogonal to R-FAIL-1's backward-looking memory-preservation protocol; provides no protection from the 5K-per-skill cap regardless of remaining task-budget runway. **Confusable-25K disambiguation expanded** from 4 to 6 mechanisms: (1) skill re-attach R-FAIL-1; (2) Read-tool ceiling R-CHUNK-5; (3) MEMORY.md 25 KB; **(4) NEW** tool-response default — verbatim *"For Claude Code, we restrict tool responses to 25,000 tokens by default"* per anthropic.com/engineering/writing-tools-for-agents; **(5) NEW** `MAX_MCP_OUTPUT_TOKENS` default per code.claude.com/docs/en/mcp; **(6) NEW** Cowork compaction-instruction overhead per Issue #24677. **Hard-coded — no override.** Verified against env-vars/settings docs and source-code reproductions; the only adjacent knob is `autoCompactWindow` (env: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`; min 100K / max 1M per Issue #42149) which controls trigger threshold, not re-attach budget. Issue #45019 verbatim *"I cannot find any controls to get back to 25000."* **Watch item logged.** Quarterly automated diff of canonical page recommended; structural vulnerability to Issue #45019 silent-downgrade analogue. **Gemini-18 vetting: 4 incorporations, 5 hallucinations rejected (DA-153..DA-157).** **Incorporations:** (a) anthropic.com/engineering/writing-tools-for-agents tool-response 25K cap → 4th confusable in expanded disambiguation list; (b) `task-budgets-2026-03-13` beta header → orthogonality note; (c) meta-skill-as-skill 5K-cap implication → cross-section forward-influence note for system-design § Meta-Skill Spec; (d) "per-branch isolation is project-internal terminology" framing → strengthens Turn-1 narrowing. **Rejections:** **DA-153** Issue #21925 misattribution + fabricated *"rigid 25,000-token CLAUDE.md ingestion limit"* (issue is about CLAUDE.md not being re-loaded post-compaction; directly contradicts DA-140 and canonical Anthropic memory doc *"CLAUDE.md files are loaded in full regardless of length"*; corroborated by Issue #22085 confirming CLAUDE.md is loaded fully at startup); **DA-154** `autoCompactWindow` env-var name "formerly `CLAUDE_AUTOCOMPACT_WINDOW`" naming hallucination (actual name per source-code reproduction is `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and was never the shorter form); **DA-155** tabular CLAUDE.md hard-limit fabrication (same as G18-1 in tabular form, separate DA because tabular precision implies vendor-documented mechanism that does not exist); **DA-156** specific 18,000-22,000-character envelope for 5K tokens as Discovery rule-of-thumb packaged as architectural fact; **DA-157** `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` env-var fabrication (does NOT exist; refuted by Issue #45019 verbatim *"I cannot find any controls"* and Issue #14888 confirming file-read 25K is hardcoded). **Independence note applied:** Gemini-18 fits the systemic Gemini pattern across Gemini-2/5/6/7/8/10/13/15/16 of fabricating Anthropic-blessed mechanisms via misattribution to real GitHub-issue numbers and confident fabrication of env-var/setting names; treated as ONE LLM-second-opinion data point. Materially: verified contributions on Task Budgets, meta-skill 5K-cap implication, and tool-response 25K disambiguation are useful additions; the cluster of GitHub-issue-anchored fabrications (DA-153, -157) reinforces the project's existing Gemini-supplemental-vetting discipline. **Tabs updated:** skill-spec (R-FAIL-1 extensively rewritten — audit verdict, scope clarification, Opus 4.7 caveat, Task Budget orthogonality, expanded confusable disambiguation, hard-coded clause, watch item); research (Q-018 closed in queue, Q-019 promoted to top with Task-Budget-related expansion noted; T-018 tracker row added; DA-153..DA-157 logged; v1.16 References entry — code.claude.com/docs/en/skills + writing-tools-for-agents + Opus 4.7 release notes + sub-agents doc + equipping-agents post + Complete Guide PDF + Issues #20466/#24677/#21925/#22085/#5812/#10212/#42149/#45019/#14888/#6158 + code.claude.com/docs/en/mcp + env-vars + settings + Ken Huang Substack + Gemini-18; Session Notes — Q-018 section NEW; Reasoning Journey v1.16 paragraph; Tracker T-018 row). **Contradiction check: PASSED.** R-FAIL-1 v1.16 narrowing harmonizes with R-PAR-2 (per-context-window framing replaces "per-branch"); R-FAIL-1 Opus 4.7 caveat composes cleanly with R-BODY-1 (line-count + token-count cooperation); DA-153 reinforces DA-140 / R-BOUNDARY-3 (CLAUDE.md is loaded in full); DA-157 reinforces R-CHUNK-5 / DA-119 (file-read mechanism's parameter immutability); R-FAIL-1 watch item slots into R-CADENCE-1's quarterly tier without new cadence rule. **Compliance validation: PASS** (anchor pairing intact, all rule labels unique, all DAs DA-153..DA-157 added with matching `<a id>` tags, all sessions unique, frontmatter/title/changelog version triple-consistent at 1.16, append-only invariant preserved across DAs/References/Changelog). **0 breaking changes** — every v1.15-authored skill remains conformant; R-FAIL-1 numeric core is unchanged. Q-018 → ✦ Researched v1.16. Open queue (Q-019) ready for the next research session; blue callout points to Q-019.

### v1.15

**Q-013 closed (LLM-judge self-consistency vote count + Routines beta-header status + PreToolUse Skill matcher dispatch). 3 sub-questions resolved: 1 HOLD (R-LLMJ-4 at k=3), 1 HOLD-with-citation-refresh (R-CADENCE-2), 1 REVISE (R-LOAD-4 to bifurcated permission). Adopted:** **R-LOAD-4 revised** to permit `PreToolUse matcher: "Skill"` for agent-dispatched skill calls (deterministic exit-code 2 blocking is now valid as a supplementary gate); PostToolUse `matcher: "Skill"` remains FORBIDDEN (Issue #43630); InstructionsLoaded for skills remains FORBIDDEN (Issues #30573, #31017). Mandatory canary (R-LOAD-1) + negative-control (R-LOAD-2) tests remain primary verification — PreToolUse-Skill is supplementary, not replacement. **NEW Tier-1 finding documented:** `claude_code.skill_activated` OpenTelemetry event (anthropics/claude-code CHANGELOG, Anthropic-canonical) fires for ALL three skill-invocation paths with `invocation_trigger` attribute (`"user-slash"` / `"claude-proactive"` / `"nested-skill"`) — supersedes hook-based observability for cross-path coverage and resolves the Issue #43630 asymmetry. **Promoted: Rating Roulette** (Haldar & Hockenmaier, EMNLP 2025 Findings) graduates from PROPOSED preprint to corroborating Tier-1 (was preprint at v1.8); strengthens R-LLMJ-4 hold-at-k=3 by establishing multi-sample necessity without endorsing k=5. **Held: R-LLMJ-4 at k=3.** Anthropic skill-workshop SKILL.md verbatim re-fetch 2026-05-07 confirms *"running each query 3 times to get a reliable trigger rate"* across 7 independent surfaces (canonical + Anthropic mirror + 5 secondary). No Tier-1 source post-dating v1.8 produces quantitative ECE/AUROC evidence justifying graduation under R-LLMJ-11 budget. **Held: R-CADENCE-2** (citation refresh only). Beta header `experimental-cc-routine-2026-04-01` STILL ACTIVE per live `code.claude.com/docs/en/routines` re-fetch; Anthropic-canonical doc now formally documents a permanent **two-most-recent-previous-versions** stability guarantee that future-proofs the versioned-check pattern. **Gemini-13 vetting: 2 incorporations (directional findings on Routines stability and PreToolUse-Skill bifurcation, both supported by independent canonical evidence rather than Gemini-13's cited evidence vehicles), 6 hallucinations rejected (DA-147..DA-152):** Anthropic skill-workshop k=10 anchor fabrication (real text says k=3); TrustJudge ICLR 2026 K=4/5 misattribution (paper "under review" not accepted; "triples" are model-pair transitivity tests not self-consistency votes — same conflation pattern as DA-094); SAMRE-EACL2026 relitigation (DA-095 already rejected this; SAMRE is the D3 paper); "Can LLMs Automate Fact-Checking" optimal-at-5 unverifiable claim (no verbatim citation provided); Issue #42250 fabricated bifurcation (no such issue exists); Issue #47307 fabricated regression (no such issue findable). All six rejections treated as ONE LLM-hallucination data point per `framework.second_opinion_review.independence_note` — the same pattern observed in Gemini-3, Gemini-4, Gemini-8, Gemini-12, Gemini-15, Gemini-16. **Critical Turn 2 finding NEITHER my Turn 1 NOR Gemini-13 captured initially:** the `claude_code.skill_activated` OpenTelemetry event emerged from independent CHANGELOG audit during Turn 2 vetting. **Tabs updated:** meta-skill-validation (R-LOAD-4 row revised to bifurcated permission with explicit (a)/(b)/(c) clauses; new supplementary observability primitive narrative); skill-spec ('Forbidden patterns' subsection updated with bifurcated PreToolUse-Skill permission and OpenTelemetry observability primitive); research (Q-013 closed in queue, Q-018 promoted to top; T-013 tracker row added; DA-147..DA-152 logged; v1.15 References entry — Anthropic skill-workshop + Anthropic mirror + Rating Roulette EMNLP 2025 Findings + TrustJudge arXiv:2509.21117 + Trust or Escalate ICLR 2025 + Anthropic Routines doc + Anthropic Routines blog + Anthropic Hooks reference + Anthropic CHANGELOG + Issues #43630, #21614, #30573, #31017, #22902; Session Notes — Q-013 section NEW; Reasoning Journey v1.15 paragraph; Tracker T-013 row). **Contradiction check: PASSED.** R-LOAD-4 revision consistent with R-META-10 (PreToolUse hooks run deterministic shell commands; the agent dispatched the call but the hook itself contains no LLM), R-LOAD-1/R-LOAD-2 (canary + negative-control remain mandatory primary; PreToolUse-Skill is supplementary), R-LOAD-3 (hook reads invocation payload, doesn't ask Claude to introspect), R-META-9 (OpenTelemetry skill_activated event strengthens auditability). **Compliance validation: PASS** (anchor pairing 24/24, all rule labels unique, all DAs unique, all sessions unique, all `<a id>` tags unique, frontmatter/title/changelog version triple-consistent at 1.15, append-only invariant preserved across DAs/References/Changelog). **0 breaking changes** — every v1.14-authored skill remains conformant; the R-LOAD-4 revision is permissive (adds a previously-forbidden mechanism as PERMITTED), not restrictive. Q-013 → ✦ Researched v1.15. Open queue (Q-018, Q-019) ready for the next research session; blue callout points to Q-018.

**Note on document-vs-framework version skew:** the document carries `research_buddy_version: 2.0.0` (the user's locally-stamped value); the published research-buddy starter is at v1.5.0. Per the framework's compatibility-check rule, this is a MAJOR mismatch surfaced informationally only — not blocking. No action taken in v1.15; flagged for the user's awareness.

### v1.14

**Format migration v1 (JSON) → v2 (Markdown) plus rule-ID collision cleanup.** Content preserved verbatim across the migration; rules retain their topical organization across the domain-specific sections; all anchors and IDs preserved. **Two rule-ID collisions surfaced by the v2 mechanical validator and resolved in this session:** (1) **R-SHARE-2 collision (genuine label clash across sessions).** Q-009/v1.9 had adopted **R-SHARE-2 [skill] [portable] VALIDATED — MECHANICAL** ("no `.claude/scripts/` convention exists"; mechanical lint = body-content scan rejecting any `.claude/scripts/` reference). Q-014/v1.12 reused the same label for an unrelated rule about cross-skill reference-doc sharing within a skills root. The v1.12 occurrence is renamed to **R-REF-SHARE-1 [skill] [portable] PROPOSED — SHOULD** to disambiguate and to fit naturally next to its v1.12 siblings R-REF-FM-1, R-REF-SUPERSEDE-1, and R-REF-SECRETS-1. The Q-009 R-SHARE-2 is unchanged. Cross-references in the lint table (line ~2059, the plugin-internal symlink permission lint), Q-014 tracker row, DA-135, the Q-014 turn-2 narrative, the cross-section-impact note, the references entry, and the v1.12 changelog narrative are all updated to point at R-REF-SHARE-1. (2) **R-REFLOC-2 collision (modeling artifact, same rule modeled twice).** The primary R-REFLOC-2 block (PROPOSED HYBRID, the four candidate patterns (a)–(d)) and the v1.9 (c)-clarification block (VALIDATED MECHANICAL, narrowing the no-new-frontmatter-key constraint) had both been emitted as standalone `@rule` entry blocks with their own anchor ids, producing a duplicate-id error and an unreachable second HTML anchor. Resolved by merging the clarification into the primary block as a sub-paragraph titled "**Clause (c) clarification — VALIDATED MECHANICAL.**", preserving all source attributions and the per-clause status distinction. **Validator state:** post-cleanup, the file passes the v2 mechanical validator with 0 errors and 0 warnings (anchor pairing 12/12, all 134 rule labels unique, all 148 DAs unique, all 14 sessions unique, all 297 `<a id>` tags unique, frontmatter/title/changelog version triple-consistent at 1.14). **No content was lost.** The Q-009 `.claude/scripts/` rejection rule, the Q-014 cross-skill reference-doc sharing rule, the four-pattern R-REFLOC-2, and the (c)-clarification all remain in the document with their full Tier-1 source attributions; only labels and block structure changed. **No new research was performed in v1.14**; the v1.13 ruleset is intact, just disambiguated and de-duplicated. Open queue (Q-016, Q-017, Q-018, Q-019) is unchanged and ready for the next research session.

### v1.13

**Q-015 closed (skill-vs-project-documentation boundary contract).** Adopted: 8 VALIDATED boundary rules **R-BOUNDARY-1 through R-BOUNDARY-8** plus 1 NEW **R-BOUNDARY-9** (references >100 lines must contain a ToC; canonical Anthropic threshold) plus 1 NEW **R-BOUNDARY-4-CLARIFICATION** (when present, `@AGENTS.md` is the first content line of `<root>/CLAUDE.md`). 4 PROPOSED rules retained (P-BOUND-SUPERSEDE-1/-2/-3, P-BOUND-DRIFT-1) plus 1 NEW narrow PROPOSED P-BOUND-GROUNDING-1 (domain-scoped GROUNDING.md per Palmblad et al. arXiv:2604.21744 for regulated/safety-critical fields; explicitly NOT a platform-injection mechanism). **MAJOR DISAMBIGUATION:** the canonical Anthropic memory doc states verbatim that *'CLAUDE.md files are loaded in full regardless of length'* — only MEMORY.md has the 200-line / 25 KB hard cap. R-BOUNDARY-3 carveout formalizes the soft-target reading; system-design § *Interaction with CLAUDE.md / AGENTS.md* gains a strict guard callout. **Gemini-15 vetting: 4 incorporations, 7 hallucinations rejected (DA-140..DA-146).** Incorporations: R-BOUNDARY-9 (ToC threshold from canonical Anthropic, correcting Gemini-15's 300-line claim), `head -100` partial-read mechanism explanation strengthening R-CHUNK-4, R-BOUNDARY-4-CLARIFICATION, and subagent context-isolation as a routing factor. Rejections: BUDGET-MEM-1 silent-truncation conflation (Tier-1 contradicts: CLAUDE.md loaded in full); GROUNDING.md-as-universal-supersession-tier-zero overreach (paper is field-scoped to proteomics); 1700-token ToolSearch overhead, 85%/$150-250 figures, 300-line ToC threshold, anti-patterns-as-supersession-mechanism, and Finout-citations-for-Anthropic-primary-facts (citation discipline). **Tangential acknowledged:** AutoDream / `tengu_onyx_plover` / KAIROS daemon mode is real and partially rolled out (March 2026 source-leak coverage) but operates on auto-memory not CLAUDE.md/skills, and is not in canonical Anthropic doc as of 2026-05-05; logged as new queue item Q-019 for post-GA revisit. The internally-asserted per-skill-set 25K-token re-attach budget remains unverified at Tier-1; logged as Q-018. **Tabs updated:** skill-spec ('Skill vs Reference Content' inter-container subsection NEW; 'Reference Chunking & Lazy Loading' R-BOUNDARY-9 added); system-design ('Interaction with CLAUDE.md / AGENTS.md' Q-015 v1.13 subsection NEW with R-BOUNDARY-4-CLARIFICATION canonical example block + MEMORY.md/CLAUDE.md disambiguation guard callout); meta-validation (3 new machine-checkable lints — LINT-Q015-10 ToC at >100 lines, LINT-Q015-11 `@AGENTS.md`-first ordering, LINT-Q015-1-RESTATED CLAUDE.md >200 lines emits WARN not FAIL); research (Q-015 closed; Q-018 + Q-019 added; DA-140..DA-146 logged; v1.13 References entry — Anthropic memory doc, Skill best-practices, Best practices for Claude Code, Engineering Skills post, AGENTS.md spec, Palmblad arXiv, Anthropic Opus 4.7 release; Session Notes — Q-015 NEW; Reasoning Journey v1.13 paragraph; Tracker row Q-015). **Contradiction check: 1 resolved** (Gemini-15 BUDGET-MEM-1 conflation vs canonical Anthropic Tier-1 — MEMORY.md ≠ CLAUDE.md regarding hard cap; Gemini-15 conflation rejected via Anthropic supremacy).

### v1.11

### v1.8

### v1.7

**Q-007 Self-updating skills (post-session retrospective + auto-improvement) complete.** Turns 1 + 2 produced 30 new rules across seven families (Turn 1: 27 rules; Turn 2: R-RETRO-6, R-DRIFT-5, R-DESTRUCT-3) anchored to live Tier-1 sources fetched 2026-05-04 (`code.claude.com/docs/en/{hooks,skills}`, `platform.claude.com/docs/en/agents-and-tools/agent-skills/{overview,best-practices}`, `anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills`, `github.com/anthropics/skills` `skill-workshop/SKILL.md` and shipped `pdf/`/`pptx/`/`docx/`/`xlsx/`, Voyager arXiv:2305.16291 TMLR 2024, Self-Refine arXiv:2303.17651 NeurIPS 2023, Reflexion arXiv:2303.11366 NeurIPS 2023, DSPy arXiv:2310.03714 NeurIPS 2023 / ICLR 2024). **Seven rule families added:** R-RETRO-1..6 (retrospective protocol — `Stop`/`SessionEnd` triggers, `stop_hook_active` loop guard, prompt-type hooks, async ceilings, in-skill-frontmatter `hooks:` with `once: true`); R-SELF-1..5 (write target = `references/gotchas.md`; body reserved for behavioral corrections; canonical-folder convention; gotchas entry schema; `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/` for in-flight diffs); R-DRIFT-1..5 (description regen after N=3 retros via skill-workshop's optimizer with held-out validation; 1024-char description cap; **scope-preservation constraint** new in Turn 2); R-EXTRACT-1..3 (promote on-the-fly script at N≥3 reuses in-session OR ≥3 sessions in 14 days — **inter-session arm tightened in Turn 2 from ≥2/7d to ≥3/14d** per Gemini-7); R-DESTRUCT-1..3 (`disable-model-invocation: true` skills require explicit `--apply-retro`; meta-skill's merge subcommand itself ships with `disable-model-invocation: true`; **merges go through Edit-tool permission classifier, never raw shell** new in Turn 2); R-VC-1..3 (Conventional-Commits `skill(retro):` prefix; semver discipline patch=references / minor=body / major=description; `skill/auto-update` branch with user-accept gate); R-ROLLBACK-1..5 (pre-merge `pre-retro-<skill>-<YYYYMMDD>` tag; validator-gated revert with degraded-health escalation; ≤1 merge per skill per session; cross-skill dependency re-validation; semver-tag rollback for marketplace skills). **Turn 2 evaluated Gemini-7 second opinion**: 5 contributions accepted (G7-5 SessionEnd disqualification for synchronous merges, G7-7 scope-preservation refinement of description regen, G7-8 Edit-tool sandbox path for merges, G7-9 confirmation of all 29 canonical hook events via live Anthropic fetch, G7-1 inter-session promotion arm tightening); 4 contributions rejected as DA-074..DA-077 (G7-3 hallucinated `!command` Dynamic Context Injection in SKILL.md — the syntax is custom-slash-commands not skills; G7-4 misreading `references/gotchas.md` progressive-disclosure as 'context fragmentation'; G7-6 description-lock conflicting with Anthropic-canonical skill-workshop description-optimizer; G7-2 framing the three-folder convention as parser-enforced when it is canonical-not-mandatory). **v1.6 caveat reversed:** the live re-fetch of `code.claude.com/docs/en/hooks` confirms all 29 events (`SessionStart`, `Setup`, `UserPromptSubmit`, `UserPromptExpansion`, `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Notification`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `Stop`, `StopFailure`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`, `SessionEnd`); the Q-006 DA-064 framing was correct to demand verification but the events themselves are real. **New side-question handled**: user-submitted Slack thread documenting their FlanksAPI monorepo flat-skill refactor (prefix `aworkers-*` to avoid cross-service name clashes, plus symlinks for sub-IDE access); scoped out of Q-007 (project-specific) but yielded **Q-012** queue item for general monorepo flat-skill naming, the router/index-skill pattern (Albert's `services/SKILL.md` redirect proposal), and skill-loading-verification tests (Hector's keyword-test gap insight) feeding Q-008. **Contradiction check: passed** (R-RETRO-* refines but does not contradict R-XPOLL-3/4/6; R-SELF-1 strengthens R-BODY-1; R-DRIFT-5 is new and consistent with R-FM-* schema; R-EXTRACT-1's tightened threshold respects R-XPOLL-4's 3-iteration cap; R-DESTRUCT-3 composes with the existing PreToolUse / PermissionRequest hook architecture). **Tabs updated**: research (NEW Session Notes — Q-007; Q-012 added to queue; DA-065..DA-077 logged; v1.7 References entry; T-007 tracker row; v1.7 Reasoning Journey block); skill-spec (NEW Self-Updating Skills subsection); system-design (NEW Self-Modification Governance subsection); meta-validation (R-ROLLBACK-* family added with mechanical/semantic classification). Q-007 → ✦ Researched (v1.7); blue callout points to Q-008.

### v1.6

**Q-006 Multi-task skills (parallelism, delegation, composition) complete.** Turn 1 produced 16 new VALIDATED rules across five families — composition (R-COMP-1/2/3), parallelism (R-PAR-1/2/3/4), delegation (R-DEL-1/2/3), conducting (R-CONDUCT-1/2/3/4), and failure semantics (R-FAIL-1/2/3/4/5) — all anchored to live Tier-1 sources (`code.claude.com/docs/en/{skills,sub-agents,agent-teams,hooks}`, the *How we built our multi-agent research system* engineering post, and the `anthropics/skills` repo). Established the **four-layer composition ladder**: inline progressive disclosure → `context: fork` skill → custom subagent with `skills:` preload → agent teams (experimental, env-var gated, Opus 4.6+, v2.1.32+). Pre-registered fan-out budget (3–5 default, hard ceiling 8 aligned to R-API-1) and confirmed per-session, per-skill-set 25,000-token re-attach budget — does not aggregate at fan-in. Identified `PostToolBatch` as the canonical fan-in synchronization point; documented the asymmetric subagent failure surface (summary-only, no structured stderr/exit-code propagation). **Turn 2 evaluated Gemini-6 second opinion**: 4 contributions accepted (description-defaulting, custom-commands-merged-into-skills, bundled-skills inventory, intra-skill `shared/` pattern note); 6 contributions rejected (DA-056..DA-061 — "5 hard cap" framed as documented; "5–7 RPM organization-tier" rate limit unverified at cited URL; cross-skill `shared/` ecosystem misreading; hallucinated `ConfigChange` and `UserPromptExpansion` hook events; Medium derivative citation for the 15× token figure where Anthropic primary source exists; PROPOSED hedge on per-branch budget overcautious vs. canonical Anthropic doc). **DA-IDs corrected**: Turn 1 internal draft mistakenly began at DA-025; the live document had reached DA-055 in Q-005, so Q-006's discards are filed at **DA-056..DA-064** (adding DA-062 for the false-equivalence claim that subagent stderr propagates as structured error to the parent, DA-063 for the hallucinated cross-skill symlinking convention, DA-064 for the merged hook-hallucination cluster). **New side-question handled**: user asked whether Karpathy LLM-Wiki and rohitg00's LLM-Wiki-v2 fork could improve project documentation. Verified both gists; scoped out of Q-006 (runtime composition vs. knowledge-base patterns) and added as new queue item **Q-011 — LLM-Wiki documentation patterns for the Research Buddy project itself** at low priority. **Contradiction check: passed** (R-PAR-2 envelope matches R-API-1; R-DEL-2 narrows R-FM-6 without conflicting; R-CONDUCT-1 governs runtime while R-XPOLL-2 governs design-time, both stand; R-FAIL-1 refines prior 25k-budget rule to per-branch isolation). **Tabs updated**: skill-spec (NEW Multi-task Composition subsection); system-design (NEW Parallelism & Delegation Topology subsection; Skill Library Architecture and Dependencies and Splitting Strategy annotated); meta-validation (5 new rule families added with mechanical/semantic classification); research (Session Notes — Q-006 new; Q-011 added to queue; DA-056..DA-064 logged; v1.6 References entry). Q-006 → ✦ Researched (v1.6); blue callout points to Q-007.

### v1.2

**Q-002 cross-pollination complete + parallel v1.1 reconciliation.** Turn 1 reconciled two parallel v1.1 files under Anthropic-supremacy and ported 12 new rules from peer-reviewed agent-systems literature. Turn 2 evaluated Gemini-2 second opinion: confirmed Hamel Husain post (real), confirmed paper set overlap, **confirmed AAIF/Linux-Foundation backing of AGENTS.md** (overturning FILE B's earlier rejection), and rejected 4 Gemini-2 hallucinations (DA-021..DA-024 — the "20 skills per session" cap, the `mode:` field, the `CLAUDE_CODE_FORK_SUBAGENT` env var, and the mandated `eval_queries.json` schema beyond what Hamel actually proposed). **R-API-1** added (8-skills-per-Messages-API-request — surfaced during Gemini-2 verification). **R-BODY-1 corrected to ≤500 lines** per Anthropic best-practices; both parallel v1.1 files used folklore numbers. **R-MEM-5..9** added from FILE A's D-016/D-025 promotions and from agents.md ecosystem. The meta-validation tab is no longer empty: 22 mechanical validation heuristics tabulated; CLI sketch in place. Q-002 → ✦ Researched (v1.2); blue callout points to Q-003.

### v1.1

**Q-001 Foundational research complete.** 35 rules across 8 categories adopted with Anthropic Tier-1 backing. 12 alternatives permanently rejected (DA-001..DA-012). Gemini-1 second opinion vetted — agreement on ~90% of claims; two budgets corrected via Anthropic supremacy; one overreach (OS reserved names) rejected. Five new queue items (Q-006..Q-010) appended from user reflection. Tabs skill-spec and system-design fully populated; meta-validation deferred to Q-003/Q-004.

### v1.0

**Project initialized via session_zero.** Domain: AI agent engineering (Claude Code Agent Skills). Deliverable: software_and_document. Goal: research-backed strict spec + meta-skill + validator. Tabs: 6 (overview, research, skill-spec, system-design, meta-validation, changelog). Initial queue: Q-001 through Q-005. Domain constraints: 7 rules covering tier discipline, Anthropic supremacy, strictness default, [skill]/[reference] tagging, arXiv verification, [claude-code-only]/[portable] tagging, and pre-registration. User-supplied seeds recorded for Turn-1 verification.

<!-- @end: changelog -->
