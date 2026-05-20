# Research-rule coverage

## Contents

- [Scope decision](#scope-decision)
- [Per-skill checks (validate.py)](#per-skill-checks-validatepy)
- [Library-wide checks (audit_library.py)](#library-wide-checks-audit_librarypy)
- [Memory-layer checks (validate_memory.py)](#memory-layer-checks-validate_memorypy)
- [Soft warns](#soft-warns)
- [Deferred families and why](#deferred-families-and-why)
- [Deferred individual rule IDs](#deferred-individual-rule-ids)

Load when the validator misses a real failure mode you expected it to
catch, when planning to widen the rule set, or when defending a
deferred-rule decision.

The archived research doc carries hundreds of named rule citations.
This skill deliberately does **not** cite those identifiers in the
body — they evolve from version to version and stale citations rot.
This page describes each check by its *intent* instead. When you
need the underlying citation, open the archived research doc and
search for the matching prose.

## Scope decision

The current validator surface is the **mechanical** subset of the
research ruleset — checks that run without an LLM judge, embedding
model, or retrospective infrastructure. Other rule families exist
and matter; they are deferred to subsequent surfaces (semantic
review by the agent, smoke tests, memory-layer linting, plugin /
marketplace gates) rather than rolled into the per-skill validator.

The deferral list at the bottom of this page records *what* sits in
each skipped family and *why* it is skipped, so a future author can
either promote a family on demand or argue against it.

## Per-skill checks (`validate.py`)

Each row names what the check looks at and the severity at which it
trips. Severity `fail` blocks the skill; `warn` surfaces a message
without changing exit code (unless `--severity warn` is passed).

| Check | Severity | Looks at |
|---|---|---|
| Frontmatter parses | fail | UTF-8 read; `---\n` … `\n---\n` fence; valid YAML mapping; non-empty `name` + `description`. |
| Name shape | fail | `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 chars, no `anthropic` / `claude` substring. |
| Description length | fail | ≤1024 Unicode code points. |
| Description + when_to_use length | fail | If `when_to_use` is present, combined ≤1536. |
| HTML-unsafe characters | fail | No `<` / `>` in any frontmatter string; no `/` in `name`. |
| Frontmatter key allow-list | fail | Only documented keys. Profile-aware: a strict and an extended set. |
| File present and named exactly `SKILL.md` | fail | Case-sensitive. |
| Folder name = frontmatter `name` | fail | Single-depth layout enforced here. |
| Body line count | fail >500 / warn >400 | Frontmatter stripped first. |
| Windows-style backslash paths | fail | `\\.{1,80}\.(md\|py\|sh\|json)` outside fenced blocks. |
| Reference ToC | fail >100 lines / warn >200 | `## Contents` (or `## Table of Contents`) heading inside the first ~50 lines. |
| Forbidden filenames in folder | fail | No `README.md`, `Readme.md`, `readme.md`, or `AGENTS.md` inside the skill folder. |
| Balanced fenced code blocks | fail | Open / close fence parity (state machine). |
| Description trigger phrase | fail | One of `Use when`, `When the user`, `Triggered by`, `Activate when`, `Use this (skill\|when)` (case-insensitive). |
| Description negative trigger | warn | Recommends `Do NOT`, `Avoid`, `not for`, or `except for` to suppress false-positive triggers. |
| Imperative voice | warn | Body mentions `you` / `your` outside fenced blocks; description starts with a non-safe-listed imperative. |
| One-hop reference graph | warn | References do not link to other references. |
| Reference is mentioned in SKILL.md | fail | Each `references/**` filename appears verbatim in `SKILL.md`. |
| Relative markdown link target exists | fail | Each `./` or `references/...` link resolves on disk. |
| No cross-skill links | fail | No markdown link or path matching `.claude/skills/<other-skill>/...` in `SKILL.md` or its references. |
| No `..` traversal in markdown links | fail | Links from `SKILL.md` and references stay inside the skill folder. |
| No `@`-import directives in skill content | warn | `@<file>.md` or `@docs/...` not allowed at the skill layer. |
| Absolute home paths | fail | No `~/.claude/`, `/home/<user>/.claude/`, `/Users/<user>/.claude/` outside fenced blocks. |
| Script parent traversals | warn | No string literals containing `../../` (≥2 hops up) inside `scripts/`. |
| Secrets | fail | Standard high-entropy token regex set (`sk-ant-api03-…`, `AKIA…`, `ghp_…`, etc.). |
| Programmatic skill-call constructs | fail | No literal `Skill(` or JSON-RPC `Skill` invocation in plain text. |
| Symlinks pointing outside the skill folder | warn | Cross-skill references must use prose, not filesystem hops. |
| Loading verification eval present | fail | `evals/loading_verification.json` exists with `canary` and `negative_control` fields. |
| `main()` + `__main__` guard in scripts | warn | Each `<skill>/scripts/*.py` has both. |
| Script CLI argument names | warn | argparse args drawn from the canonical name set; flags forbidden synonyms. |
| Capability vs workflow taxonomy | warn | A skill described as fetching/querying owns ≥1 script; a skill described as routing/orchestrating owns 0. |

## Library-wide checks (`audit_library.py`)

These need every skill in the library at once, so they run from the
auditor, not the per-skill validator.

| Check | Severity | Looks at |
|---|---|---|
| Description-overlap (cosine) | warn ≥0.85 / fail ≥0.95 | Pairwise cosine across all `description` fields. Bag-of-words approximation today; an embedding model is a clean future swap. |
| Canary uniqueness | fail | Each skill's canary phrase is unique across the library. |
| Listing-budget | warn near ceiling | Sum of frontmatter `description` lengths approaching the documented Claude Code listing budget (~8 KiB). |
| Duplicate-group SHA drift | warn | Scripts declaring a sibling header with mismatched SHAs across copies. |

## Memory-layer checks (`validate_memory.py`)

CLAUDE.md / AGENTS.md at the repo root and any nested per-directory
pairs.

| Check | Severity | Looks at |
|---|---|---|
| `CLAUDE.md` line count | warn >200 (never fail) | Anthropic loads the file in full regardless of length, but adherence quality drops past 200 non-blank lines. |
| `@AGENTS.md` first-content-line | fail | If `@AGENTS.md` appears in `CLAUDE.md`, it must be the first non-frontmatter / non-comment / non-blank line. |
| `@`-import recursion depth | warn >5 | The `@`-import chain length cap. |
| Absolute home paths | fail | Same regex set as the per-skill check, applied here. |
| `CLAUDE.md` ↔ `AGENTS.md` symlink | fail | Symlinking these two files together is a documented failure mode. |

## Soft warns

These warn but never fail. Surface them so authors can fix
opportunistically — none should block a merge on its own.

- Negative-trigger phrase recommended in description.
- Second-person voice in body.
- `../../` traversals in scripts.
- Symlinks inside skill folder.
- Listing-budget headroom shrinking.
- Capability/workflow taxonomy mismatch.

## Deferred families and why

These rule families exist in the research and are *not* enforced
here. The third column tells the next maintainer where the family
should land if it ever needs to be promoted.

| Family | Why deferred | If you need it: where it lands |
|---|---|---|
| LLM-judge | The library does not run an LLM-judge to keep the validator fast and dependency-free. Semantic review happens conversationally inside this skill ("review this skill") and via scripted Claude Code probes in the smoke-test runner. | Live-session probes as a future extension of `plugins/skill-creator/skills/skill-creator/tests/skills_smoke.sh`, or a dedicated reviewer skill. |
| Retrospective hooks (Stop / SessionEnd) | Hook plumbing for the meta-skill is a separate concern; the validator stays decoupled from session lifecycle. | A retrospective skill or a dedicated hook layer in `.claude/settings.json`. |
| Rollback / semver-bump | Pre-retro git tags + semver-bump linting depend on a retrospective surface that does not exist yet. | Same surface as retrospective hooks. |
| Drift / extract counters | Pattern-detection across session transcripts requires session-scoped state under the plugin data dir. | Plugin-data-aware tooling, separate from the per-skill validator. |
| Parallel fan-out caps | The library does not currently spawn subagent fan-outs. Add when the first skill does. | Either an extension of `validate.py` or a dedicated lint script. |
| Cross-language contamination | The mechanical proxy is fragile; the canonical check is an LLM judge. | LLM-judge surface (above). |
| Auto Memory layer | Auto Memory is an Anthropic-side feature; we do not validate `MEMORY.md` content directly, only the always-loaded layer. | Outside the project. |
| Marketplace / plugin distribution gates | Plugin migration ships the namespacing. Eval-publication gates are deferred until then. | A plugin-publication CI step. |
| Stylistic meta-checks (organisation, governance) | These benefit from an LLM-judge or a peer review; mechanical proxies overfit. | The "review this skill" path inside this meta-skill. |
| Token-budget caps for body / references | Need a tokenizer. The line-count check is the canonical Anthropic surrogate today. | Add a `tiktoken` import to `validate.py` once a real bloat case appears. |
| `-ing` suffix preference for skill names | Anthropic recommends but does not require. This is a team-style decision; record here if revisited. | A team-style decision; record here if revisited. |

When a deferred entry becomes blocking in practice — a skill ships
with a token-bloated reference, or a retrospective workflow lands —
promote the family into the matching script and update this page.

## Deferred individual rule IDs

The list below lands one line per meta-only governance ID that the
research doc carries but the per-skill validator does not enforce.
Each row names the rule's *intent* and a `§ <section>` anchor pointing
into `docs/research/claude-skill-system_v1.17.md` so a future author
can pull the full text when promoting one of these into the rubric.

Group the rules by family. The canon for "did this rule make it into
the rubric or stay here?" is: author-checkable rules live in
`skill-rules.md`; rules that need an LLM judge, session-state
infrastructure, or marketplace plumbing live here.

### Meta-skill governance — R-META-1..19

Anchor: `docs/research/claude-skill-system_v1.17.md § Meta-Skill Spec`.

- R-META-1 — Meta-skill conforms to the same spec it generates. Validator self-test runs against the meta-skill.
- R-META-2 — Frontmatter trigger-rich `description` ≤1024 chars; whitelist `{name, description, license, allowed-tools, metadata}` (skills-API profile).
- R-META-3 — Declarative spec validates against JSON Schema before any LLM authorship.
- R-META-4 — Compiler step has a 7-stage strict order (scaffold → frontmatter → body → description → optimize → validate).
- R-META-5 — Scaffold drops minimum SKILL.md + `evals/evals.json`; conditional `scripts/`, `references/`, `assets/` only on `needs.*`.
- R-META-6 — Elicitation = exactly 4 prompts (what / when / output / evals).
- R-META-7 — Validator runs at two gates (creation, finalization); meta-skill body invokes validator.
- R-META-8 — Iteration cap = 3 for body refinement and description optimization.
- R-META-9 — External verification = validator PASS AND user accept; no silent auto-fix; no `--fix`.
- R-META-10 — Deterministic helpers do not import LLM SDKs (no `anthropic`, `openai`, `requests` in validator).
- R-META-11 — Meta-skill bundles ZERO example skills; retrieves user's prior skills by embedding.
- R-META-12 — 3-tier curriculum gated on prior-skill count (0 / 1–9 / 10+).
- R-META-13 — Compiler emits `description` of form `"<verb-phrase>. Use when <utterance triggers>."`.
- R-META-14 — Meta-skill body ≤400 lines (stricter than R-BODY-1's 500).
- R-META-15 — Eval set = 3 behavioural + 20 trigger (10 should / 10 should-not).
- R-META-16 — ≥1 behavioural example is a negative counter-example.
- R-META-17 — Synthetic-bootstrap → organic-trace lifecycle; `--inject-trace` swaps in real execution traces.
- R-META-18 — Refuse benchmark publication on missing Bash baseline, mis-placed `grading.json`, or aggregate script glob mismatch.
- R-META-19 — Meta-skill `allowed-tools` includes `Bash` OR body has a literal preflight `command -v bash`.

### Loading verification — R-LOAD-1..8

Anchor: `docs/research/claude-skill-system_v1.17.md § Validation Test Suite`.

- R-LOAD-1 — Each skill contains a unique canary phrase in body or referenced file.
- R-LOAD-2 — ≥1 negative-control test (folder rename or `disable-model-invocation: true` toggle).
- R-LOAD-3 — "List your loaded skills" probe forbidden as the only verification.
- R-LOAD-4 — Bifurcated permission for hook-based introspection; `PostToolUse Skill` warns, `PreToolUse Skill` advisory-only.
- R-LOAD-5 — `evals/loading_verification.json` exists and conforms to schema.
- R-LOAD-6 — ≥1 canary AND ≥1 negative-control entry in `loading_verification.json`.
- R-LOAD-7 — Both `evals/evals.json` (trigger-rate) AND `evals/loading_verification.json` present.
- R-LOAD-8 — **REJECTED as DA-099.** Multi-vector skill-loading introspection (`<available_skills>` array + `InstructionsLoaded` events) depends on rejected primitives DA-091 / DA-092. No working surface; loading verification is carried by R-LOAD-1, R-LOAD-2, R-LOAD-4.

### LLM-judge harness — R-LLMJ-1..12

Anchor: `docs/research/claude-skill-system_v1.17.md § Q-008 — Validation: LLM-based semantic checks + routine review cadence`.

- R-LLMJ-1 — Judge tier is `downstream`; pre-commit hook MUST NOT reference judge binary.
- R-LLMJ-2 — Judge output `verdict` ∈ `{pass, warn, fail}` (no Likert/numeric).
- R-LLMJ-3 — Per-rule judge prompt has task intro + pinned eval steps + structured JSON output schema.
- R-LLMJ-4 — `samples: 3`, `aggregation: majority_vote`.
- R-LLMJ-5 — Default `model: claude-sonnet-4-6`; Opus 4.7 requires `--high-precision` opt-in.
- R-LLMJ-6 — Default `mode: pointwise`; `pairwise` only for `R-DRIFT-5`.
- R-LLMJ-7 — Judge output JSON schema: `{rule_id, verdict, critique, samples[]}`.
- R-LLMJ-8 — Each rule ships `calibration/` with ≥10 hand-labelled examples; TPR/TNR ≥ 0.80.
- R-LLMJ-9 — Validator wraps judge calls in DSPy-Suggest shape (soft); not `Assert`.
- R-LLMJ-10 — Judge prompt MUST NOT evaluate domain-content factuality, runtime correctness, or any mechanical rule.
- R-LLMJ-11 — Per-skill audit budget ≤30K input + ≤6K output tokens.
- R-LLMJ-12 — Body delimited with `<untrusted_data>…</untrusted_data>` tags in judge prompt.

### Routine-based audit cadence — R-CADENCE-1..5

Anchor: `docs/research/claude-skill-system_v1.17.md § Routine-Based Audit Cadence`.

- R-CADENCE-1 — Cadence config defines monthly + quarterly + on-demand tiers.
- R-CADENCE-2 — Cadence implementation is Routines (primary) or GitHub Actions cron (fallback).
- R-CADENCE-3 — Off-cadence triggers configured for 5 events (skill-creator minor; validator major; ≥3 ROLLBACK; XPOLL-8 overlap; freshly-applied retro failure).
- R-CADENCE-4 — Each run emits `review-report.json` v1.0 schema.
- R-CADENCE-5 — Quarterly tier tags Conventional-Commits release `v<major>.<minor>.0-rules` on rule change.

### Self-updating retrospective hooks — R-RETRO-1..6

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Updating Skills`.

- R-RETRO-1 — Retrospective fires on `Stop` / `SessionEnd`; `SessionEnd` MUST NOT carry a merge step.
- R-RETRO-2 — Stop-hook checks `stop_hook_active` and exits 0 when true.
- R-RETRO-3 — User correction is inferred from transcript, not a programmatic event.
- R-RETRO-4 — Stop/SubagentStop retrospective hooks SHOULD use `type: prompt` or `type: agent`.
- R-RETRO-5 — Async retrospective writes preferred; sync ceiling <30s.
- R-RETRO-6 — `once: true` honoured only in skill / plugin frontmatter.

### Self-applied edits — R-SELF-1..5

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Updating Skills`.

- R-SELF-1 — Routine retros write to `references/gotchas.md`, not SKILL.md body.
- R-SELF-2 — Body edits only for behavioural corrections; require minor version bump.
- R-SELF-3 — No `errata/` at skill root; use `references/`.
- R-SELF-4 — `gotchas.md` entries include date, trigger event, evidence anchor, proposed fix, and status.
- R-SELF-5 — Pending-retro path is `${CLAUDE_PLUGIN_DATA}/<plugin>/pending-retros/<skill>-<timestamp>.diff`.

### Drift detectors — R-DRIFT-1..5

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Updating Skills`.

- R-DRIFT-1 — After N=3 accepted retros, invoke a skill-creator description-optimisation pass.
- R-DRIFT-2 — New description must not regress on a held-out test (40% split).
- R-DRIFT-3 — Description ≤1024 chars; no errata digest appended.
- R-DRIFT-4 — No hidden frontmatter fields (e.g. `applies_to_examples`).
- R-DRIFT-5 — Description regen preserves the original `when_to_use` scope-set.

### Extraction triggers — R-EXTRACT-1..3

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Updating Skills`.

- R-EXTRACT-1 — Same script reused N≥3 in one session or ≥3 sessions in 14 days → extraction trigger.
- R-EXTRACT-2 — Extraction performed by skill-creator.
- R-EXTRACT-3 — Newly extracted skill passes a ≥20-prompt trigger eval before marketplace publication.

### Destructive-edit guards — R-DESTRUCT-1..3

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Modification Governance`.

- R-DESTRUCT-1 — `disable-model-invocation: true` retros do not auto-apply.
- R-DESTRUCT-2 — Meta-skill merge subcommand uses `disable-model-invocation: true`.
- R-DESTRUCT-3 — No raw shell `patch` / `sed` / `awk` in merge subcommand source.

### Version-control hygiene — R-VC-1..3

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Modification Governance`.

- R-VC-1 — Self-update commits use prefix `skill(retro): <skill-name> <YYYY-MM-DD>`.
- R-VC-2 — Semver bump matches diff scope: references-only → patch; body → minor; description → major.
- R-VC-3 — Self-modifications land on `skill/auto-update`, not `main`.

### Rollback infrastructure — R-ROLLBACK-1..5

Anchor: `docs/research/claude-skill-system_v1.17.md § Self-Modification Governance`.

- R-ROLLBACK-1 — Pre-retro git tag `pre-retro-<skill>-<YYYYMMDD>` must exist.
- R-ROLLBACK-2 — After revert, re-validate; second consecutive failure → mark `health: degraded`.
- R-ROLLBACK-3 — ≤1 merge / ≤3 attempts per skill per session.
- R-ROLLBACK-4 — Retro touching a shared reference re-runs dependent skills' evals; regression blocks.
- R-ROLLBACK-5 — Marketplace skills' `version:` matches a `v<major>.<minor>.<patch>` git tag.

### System organisation — R-SYS-1..5

Anchor: `docs/research/claude-skill-system_v1.17.md § System Organization`.

- R-SYS-1 — Skills folders are single-depth (same shape as R-WORKSPACE-1).
- R-SYS-2 — Skills precedence: enterprise > personal > project; plugin-namespaced.
- R-SYS-3 — No top-level skills index file (`index.md`, `skills.json`) at the skills root.
- R-SYS-4 — Split a skill at >500 lines OR mutually-exclusive variants.
- R-SYS-5 — Cross-skill composition uses subagent `skills:` preload OR `context: fork`.

### AutoDream and memory layering — R-AUTODREAM-1..4, R-MEM-1..6, R-MEM-10

Anchor: `docs/research/claude-skill-system_v1.17.md § Q-019 — Auto memory & AutoDream`.

- R-AUTODREAM-1 — AutoDream operates on `~/.claude/projects/<slug>/memory/`; durable user constraints belong in CLAUDE.md / AGENTS.md, not MEMORY.md.
- R-AUTODREAM-2 — AutoDream gated by `tengu_onyx_plover` GrowthBook flag + `autoDreamEnabled` setting.
- R-AUTODREAM-3 — AutoDream is orthogonal to Task Budgets, auto-compaction, and the R-FAIL-1 re-attach pool.
- R-AUTODREAM-4 — Refer to the consolidator as "AutoDream"; KAIROS is the umbrella for proactive autonomous-agent mode.
- R-MEM-1 — Memory hierarchy is cross-container only; AutoDream MAY rewrite user-reinforced entries *within* MEMORY.md, but the cross-container precedence (CLAUDE.md > AGENTS.md > MEMORY.md) is invariant.
- R-MEM-2 — CLAUDE.md carries facts every session needs; skills carry procedures triggered on demand. Quantitative target: CLAUDE.md ≤200 lines, procedures >~10 lines migrate to skills. The fact-vs-procedure boundary is a semantic judgment, deferred to peer review rather than mechanical enforcement.
- R-MEM-3 — **DEMOTED at v1.12 per DA-130.** The PROPOSED `AGENTS.md` ↔ `CLAUDE.md` symlink convention is permanently rejected and superseded by R-MEM-10 (which uses `@AGENTS.md` import and is enforced by `validate_memory.py`).
- R-MEM-4 — Anti-duplication in CLAUDE.md: use `@import`; for path-scoped rules use `.claude/rules/*.md` with `paths:` frontmatter; reference skills by name, never copy skill content. Deferred to `validate_memory.py` (memory-layer surface).
- R-MEM-5 — CLAUDE.md is delivered as a USER message after the system prompt, not part of it; compliance is best-effort. Specificity beats CAPS-LOCK; the system-prompt-level escape hatch is the `--append-system-prompt` CLI flag. Documentary / infrastructural, not per-skill checkable.
- R-MEM-6 — Path-scoped instructions live at `.claude/rules/<topic>.md` with a `paths:` glob in frontmatter; the `InstructionsLoaded` hook logs which rules fire. Deferred to `validate_memory.py`.
- R-MEM-10 — Mechanical lint at `<root>/CLAUDE.md`: FAIL if it is a symlink to `<root>/AGENTS.md` or vice versa; PASS if body's first content line is `@AGENTS.md` and `<root>/AGENTS.md` exists. (This one *is* enforced — by `validate_memory.py` — and is listed here only for cross-reference with R-MEM-1.)

### Reference chunking and lazy-load topology — R-CHUNK-6, R-LAZYLOAD-2, R-LAZYLOAD-3

Anchor: `docs/research/claude-skill-system_v1.17.md § Reference Chunking & Lazy Loading`.

- R-CHUNK-6 — Reference graph stays one-hop from SKILL.md; ≤1 chained `Read` per task. (The mechanical proxy lives in `validate.py`'s one-hop check; the deeper semantic claim about read budgets is deferred.)
- R-LAZYLOAD-2 — Lazy-load order is deterministic and reproducible across sessions (no stochastic ordering).
- R-LAZYLOAD-3 — Lazy-load decision logged to the per-skill `findings.md` when an audit pass runs.

### Cross-language contamination — R-CONTAM-1

Anchor: `docs/research/claude-skill-system_v1.17.md § Q-008`.

- R-CONTAM-1 — Contamination score = `0.3·multi_interface_tools + 0.4·language_mismatch + 0.3·scope_breadth`. The mechanical proxy lives in the rubric (warn at ≥0.5); the canonical verdict requires an LLM judge.

### Helper-script governance — R-HELP-2..7

Anchor: `docs/research/claude-skill-system_v1.17.md § Helper Scripts`.

Most rows here restate facets of the helper-script contract already enforced by `R-HELP-1` (CLI surface + documented invocation + shebang + `main()` guard) or by adjacent rubric rules. Each row notes its rubric counterpart.

- R-HELP-2 — Helpers expose positional args + named flags, `--help`, machine-readable JSON stdout, and errors to stderr. CLI-surface basics are enforced by `R-HELP-1`; the JSON-vs-text stdout choice stays deferred because progress-style scripts (e.g. `audit_rule_drift.py`) legitimately emit human-readable output, so a hard "must be JSON" rule would false-positive.
- R-HELP-3 — Each helper invocation is documented in SKILL.md with command line, args, return shape, and when-vs-fallback reasoning. Covered by `R-HELP-1`.
- R-HELP-4 — Reference helpers via `${CLAUDE_SKILL_DIR}/scripts/<file>` so invocations survive bundling and CWD changes. Covered by `R-SHARE-4`.
- R-HELP-5 — Pre-approve deterministic helpers via the `allowed-tools` frontmatter field (e.g. `Bash(python *)`) to skip per-call approval prompts. Covered by `R-FM-7`.
- R-HELP-6 — Extract-when-repeated: when Claude reinvents the same helper ≥3 times within a session, it graduates into `scripts/`. Pattern detection needs session-transcript introspection; sibling of the already-deferred `R-EXTRACT-1..3` family.
- R-HELP-7 — Python helpers begin with `#!/usr/bin/env python3`; executable bit optional. Covered by `R-HELP-1`.

### Progressive disclosure architecture — R-CTX-1

Anchor: `docs/research/claude-skill-system_v1.17.md § Progressive Disclosure`.

- R-CTX-1 — Three-tier disclosure: metadata (always loaded) → SKILL.md body (≤5K tokens, on trigger) → `references/`, `scripts/`, `assets/` (on demand). This is an architectural claim already enforced piecewise by the rubric — `R-BODY-1` (line cap), `R-BODY-2` (token cap), `R-BODY-4` / `R-CTX-4` (front-load constraints likely to survive auto-compaction), `R-BODY-6` (per-reference budget), and `R-CHUNK-6` (one-hop reference graph). This row is the named research anchor; no separate validator surface is needed.

When one of these IDs becomes blocking in practice — a retro merge
ships, a CI gate needs a new rule — promote it into the matching
script or into `skill-rules.md` and remove the line from here.
