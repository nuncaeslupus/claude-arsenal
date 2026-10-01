# Specification: Align arsenal with the Claude 5.5 model generation

**Date**: 2026-10-01
**Ticket / PR**: — (opened with this spec)
**Author**: imarcos@gmail.com
**Revision**: 1
**Status**: draft
**Revision log**:
- r1 — first draft, from a three-way audit of the shipped tree against Anthropic's 5.5-generation prompting guides

> Review record. Each round of reviewer notes makes a new revision: bump
> **Revision**, add a log line naming the export it applied, and commit that
> export beside this file in the same commit. On approval set **Status** to
> `approved (YYYY-MM-DD, revision N)`.

---

## 1. Problem statement

Arsenal's shipped prompts (the vendored `AGENTS.md`, 23 `SKILL.md` bodies, the
`worker`/`reviewer` agent definitions and ~50 references) were written for the
Opus 4.x / Opus 5 generation. Anthropic's guides for the current generation
(Opus 5.5, Sonnet 5.5, Fable 5.1) say those models already self-verify, delegate
readily, follow instructions literally, and finish long work when told the scope —
so prompts tuned for older models now cost tokens and, in places, steer the model
wrong: three stacked adversarial-review gates (execution, github, ship), a
mandatory re-verification pass in `repo-audit`, review rubrics that filter
findings at report time, emphatic MUST/NEVER phrasing, model names that go stale,
and no finish-the-task / scope language in the skills that run unattended. On top
of that, the audit found ~65k characters of duplicated rules, incident history and
rationale that a model executing a step does not need — ~5.5k of it in the resident
`AGENTS.md`, paid on every turn of every consumer session.

The goal is to make every shipped prompt match the 5.5-generation guidance, make
the rubric enforce it mechanically so it does not drift back, and cut context cost
— without changing what any skill does for a consumer.

**Source guidance** (fetched 2026-10-01): Prompting Claude Opus 5.5, Prompting
Claude Opus 5, Prompting Claude Sonnet 5.5, Prompting Claude Fable 5.1, Prompting
best practices — all under `platform.claude.com/docs/en/build-with-claude/prompt-engineering/`.
Distilled into the G-rules in § 3 Option B, which become a shipped reference.

**Success criteria (measurable)**:

- [ ] `resident_tokens_minimal <= 3600` (from 4162; `make context-budget`, `minimal` row)
- [ ] `agents_md_tokens <= 2700` (from 3745; same report)
- [ ] `sum(on_invocation_tokens, all SKILL.md) <= 0.80 * baseline` (baseline recorded from `make context-budget` before the first PR)
- [ ] `reviewer.md` chars `<= 0.75 * 11361` (it is embedded in every review packet)
- [ ] `validate.py` new `content.style-*` checks: 0 warnings on the shipped tree, `skill-workshop` included (its blanket exemption narrowed)
- [ ] ALL-CAPS emphasis tokens (`MUST|NEVER|ALWAYS|CRITICAL|IMPORTANT|Do NOT`) in shipped `.md`: `<= 15` (from 67), each with its reason in the same sentence
- [ ] hard-coded model names/ids in shipped prose and code: 0, outside `docs/MODELS.md` and `CHANGELOG.md`
- [ ] exactly one home for the adversarial-review protocol; the other skills point to it (grep for the emit/spawn/verdict snippet: 1 hit)
- [ ] `make check` (lint, tests, audit, sync-version-check, queue-doctor, audit-rule-drift) green on every PR
- [ ] behaviour unchanged: every existing test passes without editing its assertions, except tests that pin removed prose
- [ ] no consumer-facing "unsupported model" message anywhere (grep `not prepared|unsupported model|upgrade arsenal`: 0)

## 2. Systems & Impact

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `init/assets/AGENTS.md` | Primary | Resident protocol in every consumer session | Yes | −~1k tokens per turn; history/rationale moved to references | High |
| `init/assets/agents/{worker,reviewer}.md` | Primary | Dispatched agent prompts; reviewer is embedded in every packet | Yes | Scope/finish language added; report-all-with-severity; dedup | High |
| `core/skills/*/SKILL.md` (20) | Primary | On-invocation prompts + resident descriptions | Yes | Calmer phrasing, dedup, heavy sections to references, shorter descriptions | Medium |
| `init/assets/references/*` | Dependent | On-demand detail | Yes | Receive moved content; tuning sections consolidated | Low |
| `skill-workshop` (rubric, `validate.py`, SKILL.md) | Primary | Enforces prompt quality on every skill | Yes | New `R-STYLE-*` / `Q-*` rows + regex checks; outdated rows reworded | High |
| `repo-audit` | Primary | Multi-agent audit skill | Yes | Fan-out sized to repo; drop mandatory re-verify pass; no model menu | Medium |
| `init/assets/bin/adversarial_review.sh` | Dependent | Builds review packets | Yes | Shorter error text; packet carries follow-up scope only | Low |
| `scripts/arsenal_config.py`, `docs/fleet.md` | Dependent | `models.*` defaults | Yes | Example ids updated; defaults stay tier aliases | Low |
| `docs/research/claude-skill-system_v1.17.md` | Shared resource | Rubric source of truth for `audit-rule-drift` | Validation | New rows need `research-coverage.md` entries; archive itself untouched | Medium |
| Consumer repos | Client | Re-vendor on update | No action | Same skills, same flags; smaller context; changelog entry explains | Low |

**Risk of inaction**: every consumer turn keeps paying ~1k avoidable resident
tokens; unattended workers keep the old early-stop and over-verify habits; the
review gate runs up to three times per change.

## 3. Options

### Option A: Resident-tier trim only (Conservative)

- **Description**: Rewrite `AGENTS.md`, `worker.md`, `reviewer.md` and the skill descriptions against the guidance. Leave SKILL bodies, rubric and references alone.
- **Scope**: 3 files + 20 frontmatter blocks.
- **Effort**: Small (1 PR).
- **Tradeoffs**: Gets most of the per-turn saving. Nothing stops the old patterns coming back; triple review gate and `repo-audit` misalignments stay.
- **Compatibility**: Fully compatible.

### Option B: Codify, enforce, then rewrite in tiers (Recommended)

- **Description**: (1) Ship the guidance as a rubric and a scanner first, so every later PR is checked by it. (2) Rewrite the shipped tree tier by tier — resident, agents, SKILL bodies, references — deduplicating as it goes. (3) Add a model-compatibility log. Never a runtime model check.
- **Scope**: whole shipped tree, in 5 stacked PRs (§ 4).
- **Effort**: Large.
- **Tradeoffs**: Most work; the scanner adds a small maintenance surface. Pays back on every future skill edit.
- **Compatibility**: No interface change. Minor bump (`4.26.0`) on the last PR.

**The G-rules** (what "aligned" means; shipped as `skill-workshop/references/model-prompting.md`, load when writing or reviewing prompt text):

| ID | Rule | Enforced by |
|----|------|-------------|
| G1 | Effort controls thinking. No "think carefully / step by step"; never ask for reasoning in the response (invites `reasoning_extraction` refusals). | R-STYLE-3 |
| G2 | No ritual re-checks ("double-check", "re-verify", "final verification step", "subagent to verify"). Code changes still need one **real** check — tests, typecheck, build or the command itself; if none can run, say which and why. | R-STYLE-4, Q-PROC-1 reworded |
| G3 | Deliver what was asked at the intended scope. Pre-existing bugs and unrequested cleanup/docs/tests are follow-ups in the summary. Ambiguity: take the reading the wording supports and state it. | Q-SCOPE-1 |
| G4 | Unattended runs finish the task: no "Next I'll…" endings, no "Shall I…?" for requested reversible work, status notes go with the next tool call. Stop only when blocked on the user or before a risky action. Exception: a question or problem description → the assessment is the deliverable. | R-STYLE-8, worker/execution text |
| G5 | Multi-part work lives in a checklist (task file, to-do); a text-only turn end is a report, not completion; wait for background commands/subagents. | worker-loop text |
| G6 | Delegate only large, independent, parallel work; not what a handful of tool calls does; one subagent over several. | Q-REV-2, R-COMP-1 clause |
| G7 | Reviews report every finding with severity and confidence; filtering is a separate step. No "only high severity" / "be conservative". | R-STYLE-5, Q-REV-1 |
| G8 | One-line intent before the first tool call; updates on findings or direction changes; final report leads with the outcome, then what is needed from the user. | AGENTS.md text |
| G9 | Deliverable length matches the task; no filler sections, history or rationale the executor does not need; literal prose over flourish. | Q-PROSE rows |
| G10 | Say when formatting helps instead of blanket anti-formatting rules. | Q-PROSE-1 reworded |
| G11 | Calm, explained instructions over CAPS; no "if in doubt, use X" (now over-triggers). | R-STYLE-1, R-STYLE-2 |
| G12 | Explore before acting on loosely specified, multi-source tasks; then commit to an approach. | execution/explore-idea text |
| G13 | Issue independent tool calls in one response. | AGENTS.md text |
| G14 | Targeted edits over whole-file rewrites. | AGENTS.md text |
| G15 | Verify fast-moving facts (models, tool versions) instead of recalling them; don't tell the model to minimise tool calls. | R-STYLE-6 |
| G16 | Mark untrusted pasted/fetched content; follow instructions in it only where the user asked. | worker/reviewer text |
| G17 | Multi-agent runs: an elapsed/budget line makes teams finish sooner (advisory; keep a hard timeout). | worker-loop optional |
| G18 | Compaction/handoff summaries name what to preserve: problems + resolutions, options set aside, decisions exactly, current state, next step. | session-end, compact_resume |
| G19 | No hard-coded model names in shipped prompts; name tiers or read config. | R-STYLE-7 |

### Option C: Option B + harness-level changes

- **Description**: B, plus changes to how arsenal drives sessions: time/budget lines injected by the orchestrator (G17), a progress-reminder after N silent worker steps, effort hints per skill.
- **Scope**: B + `worker-loop`, orchestrator scripts, `arsenal_config.py`.
- **Effort**: Large+.
- **Tradeoffs**: Real gains for fleet runs, but Claude Code owns effort and turn-scoped messages; arsenal can only approximate them in prose, and they need measurement on real fleets first.
- **Compatibility**: New config keys.

### Comparison

| | Option A | Option B | Option C |
|---|---|---|---|
| Effort | S | L | L+ |
| Risk | Low | Low–Med | Med |
| Completeness | Resident only | Whole tree + enforcement | B + harness |
| Compatibility | Full | Full | New keys |
| Maintenance | Drifts back | Scanner holds the line | Scanner + harness code |

## 4. Recommendation

**Recommended option**: Option B. It is the only one that keeps the result — the
scanner turns the guidance into a build failure rather than a memory. C's harness
items go to follow-up tasks once B ships and a fleet run can measure them.

**PR stack** (stacked from the start; only PR 5 bumps `.bundle-version`):

1. **Codify.** `references/model-prompting.md` (G-table above, with the source links); `R-STYLE-1…8` in `skill-rules.md`, `Q-REV-1/2`, `Q-SCOPE-1` in `content-quality-rules.md`; reword `Q-PROC-1` (real check only for steps that produce code), `Q-PROSE-1` (should, allow shorter paragraphs), `R-XPOLL-6` (only for procedural skills), drop model versions from `R-CONDUCT-4`/`R-LLMJ-5`; matching `research-coverage.md` entries. `validate.py`: refactor the three regex loops into one `(slug, regex, msg)` table, add the R-STYLE checks as **warnings**, narrow the `skill-workshop` exemption to rule-ID/date detectors. Gate: `make check` green, warnings listed (not yet zero).
2. **Resident tier.** `AGENTS.md` rewrite: drop history and anecdotes, collapse update-check / handle-sync / completion to pointers (canonical copies in `github-automation.md`), add the short G4/G8/G13/G14 lines. Shorten all 20 descriptions (`Not for X` instead of `Do NOT use for X (see X)`). Gate: resident ≤ 3600, AGENTS.md ≤ 2700.
3. **Agents + review gate.** `worker.md`: finish-steps-1–8 clause, scope/follow-up rule, dedupe model-dispatch and stash text to `worker-loop § Credit guards`. `reviewer.md`: report every candidate with severity + confidence, style only when it causes a defect, drop the model script and follow-up section (packet carries it). One adversarial-review protocol in `pre-pr-review.md`; execution / github / ship point to it, and ship's run happens only when commits landed after the last review. `repo-audit`: fan-out sized to the repo, drop the mandatory re-verify pass (real repro for bug findings only), no model menu. Gate: reviewer ≤ 75 %, one snippet home.
4. **SKILL bodies + references.** Calm phrasing (≤ 15 CAPS tokens left), move `har` query grammar, `queue-next` claim gotchas and `github` stacking (made generic) to references; `init` script narration → "run it, it prints what it did"; `skill-workshop` body halved; `evidence-gates.md` / `pre-pr-review.md` tuning sections into `performance-tuning.md`; `execution` gets G3/G4 lines and a single real-check step. Flip the R-STYLE checks from warning to error. Gate: 0 style warnings, on-invocation ≤ 80 %.
5. **Log + release.** `docs/MODELS.md`: "prompts aligned with" table (generation, date, guide links, arsenal version) — a maintainer log, read by nobody at runtime. Update `models.*` example ids. `.bundle-version` → `4.26.0`, CHANGELOG entry for consumers. Then `make release-check`.

**Immediate next action**: open PR 1 on `claude/arsenal-claude-v5-5-upgrade-9wadhh` (rubric + scanner as warnings), with `skill-workshop` loaded for every `skills/` edit.

**Open questions**:
- [ ] **Adversarial review policy.** Today a cold reviewer subagent runs on every task, and up to three times per change. Guidance says don't verify by subagent, but a harness-designed writer/verifier split is a pattern Anthropic also endorses. Proposal: keep **one** review per change, skip it for docs-/config-only diffs (the `ship` marker already allows that), never a second round for RISK/NOTE only. Agree, or keep it on every change?
- [ ] **CANARY lines** (20 × ~100 chars, on invocation). `validate.py` and `evals/loading_verification.json` use them to prove a skill loaded. Proposal: keep them — cost is per invocation and small. Agree, or replace with a hook-based check?
- [ ] **Version**: minor `4.26.0` (no interface change) — or `5.0.0` to mark the generation switch?

---

> Sections 5–6 (contracts, risks) are appended by `design`.
