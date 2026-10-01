# Specification: Align arsenal with the Claude 5.5 model generation

**Date**: 2026-10-01
**Ticket / PR**: #476
**Author**: imarcos@gmail.com
**Revision**: 2
**Status**: approved (2026-10-01, revision 2) — without annotations
**Revision log**:
- r1 — first draft, from a three-way audit of the shipped tree against Anthropic's 5.5-generation prompting guides
- r2 — applied `arsenal-5-5-alignment-spec-notes-2026-10-01-r1.md`: Option C chosen; verification redesign promoted to workstream V and shipped first; model-upgrade meta-skill (workstream U); reference-file usage rule; research addendum; task short labels; setup interview; per-skill effort/model; canaries kept plus a load hook; target 5.0.0

> Review record. Each round of reviewer notes makes a new revision: bump
> **Revision**, add a log line naming the export it applied, and commit that
> export beside this file in the same commit. On approval set **Status** to
> `approved (YYYY-MM-DD, revision N)`.

---

## 1. Problem statement

Four problems, one release:

1. **Prompts tuned for older models.** The shipped prompts (vendored `AGENTS.md`, 23 `SKILL.md` bodies, the `worker`/`reviewer` agents, ~50 references) predate the current generation (Opus 5.5, Sonnet 5.5, Fable 5.1). Those models self-verify, delegate readily, follow instructions literally and finish long work when told the scope. Prompts written for older models now waste tokens and in places steer them wrong: ritual re-checks, review rubrics that filter at report time, CAPS emphasis, stale model names, no finish-the-task or scope language in unattended skills.
2. **Verification never ends.** One PR took 8 adversarial reviews of ~40 min each. Measured causes (file:line in § 2): the reviewer has no time limit and may run tests and mutations; the round counter resets on every rebase or base merge; four skills each start their own review cycle; the post-PR bot loop has no timeout, so a bot that skipped, is rate-limited or unpaid is waited on forever; the full suite runs at 3–4 points per PR on top of CI. Nothing detects which external checks (CI, review bots) are actually working, so local checks never stand down when external ones cover the change, and never step in cleanly when they fail.
3. **Context cost.** ~65k chars of duplicated rules, incident history and rationale the executing model does not need; ~5.5k of it in the resident `AGENTS.md`, paid on every turn of every consumer session. Some references are loaded on every invocation, so splitting them out of `SKILL.md` saved nothing.
4. **No repeatable upgrade path.** This review was done by hand. The next model generation needs the same process — read the newest guides, update the rules, audit, fix — run by a tool, with `skill-workshop` at the centre, since it is what validates every skill.

Plus two maintainer-facing gaps: task IDs (`t-0663f708`) appear in outputs and questions without a readable label, and there is no setup interview for how much a session should ask, how strict verification should be, or which effort levels to use.

**Source guidance** (fetched 2026-10-01): Prompting Claude Opus 5.5, Opus 5, Sonnet 5.5, Fable 5.1 and Prompting best practices (`platform.claude.com/docs/en/build-with-claude/prompt-engineering/`); Claude Code skills, sub-agents and hooks docs (`code.claude.com/docs/en/`).

**Success criteria (measurable)**:

*Verification (V)*
- [ ] review rounds per PR `<= 2` (one full, one follow-up for BLOCKERs only); the counter is keyed to the PR/branch and survives rebases and base merges
- [ ] every reviewer round carries a wall-clock budget (default 10 min) and a test budget (targeted tests only; no full suite, no mutation runs unless the profile is `strict`)
- [ ] full-suite runs per head tree `<= 1` locally: `host-gate` writes a receipt keyed by tree hash, and later steps (orchestrator, ship, `fast_gate --full`) reuse it
- [ ] local full suite skipped when CI is detected healthy and will run on the head (profile `fast`/`balanced`)
- [ ] bot wait bounded: after `bot-wait` (default 20 min) with no response, one manual trigger (e.g. a mention command) is sent where the bot supports it; still nothing → bot marked unavailable for this PR and the local fallback review runs
- [ ] `review_sources.py` reports each source (CI, each review bot) as `ok | skipped | rate-limited | absent` with the evidence line, and has tests for skip notices, rate-limit notices and silence
- [ ] replaying the incident scenario in a test fixture (rebase ×3, silent bot, no preflight gate): total review rounds `<= 2`, bot wait ends, full suite runs once per tree

*Prompts and context (P)*
- [ ] `resident_tokens_minimal <= 3600` (from 4162); `agents_md_tokens <= 2700` (from 3745)
- [ ] `sum(on_invocation_tokens) <= 0.80 * baseline`; `reviewer.md` `<= 0.75 * 11361` chars
- [ ] `validate.py` `content.style-*` checks: 0 warnings on the shipped tree, `skill-workshop` included
- [ ] ALL-CAPS emphasis tokens in shipped `.md`: `<= 15` (from 67), each with its reason
- [ ] hard-coded model names in shipped prose and code: 0 outside `docs/MODELS.md`, `CHANGELOG.md` and config examples that are tier aliases
- [ ] every reference link in a `SKILL.md` has a conditional "load when" trigger; a reference loaded unconditionally is inlined or the skill is shrunk (`content.ref-unconditional`: 0)

*Upgrade path (U) and usability*
- [ ] `skill-workshop` `model-upgrade` mode runs end to end on a dry run: fetches guides, diffs them against `model-prompting.md`, lists rule changes, runs the audit, writes a spec through `specify`
- [ ] research addendum exists and `audit-rule-drift` reads v1.17 plus the addendum
- [ ] every task mention in skill output and questions shows its short label: `query_status.py` / `task_select.py` print `<label> (t-xxxx)`; task files carry `label:` (≤ 5 words)
- [ ] `/init` interview writes `autonomy`, `verification` and `effort` keys; defaults apply when skipped
- [ ] `make check` green on every PR; existing tests pass without editing their assertions, except tests pinning removed prose
- [ ] no consumer-facing "unsupported model" message (grep: 0)

## 2. Systems & Impact

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `bin/adversarial_review.sh` | Primary | Review rounds | Yes | Counter keyed to PR/branch (today reset on base change, l.508-521); time budget in packet | High |
| `agents/reviewer.md` | Primary | Reviewer prompt, embedded in every packet | Yes | No full-suite/mutation runs by default (today l.98-105, 181-185); report all with severity; −25 % | High |
| `github` / `pr-review-loop.md`, `query_pr_state.py` | Primary | Post-PR bot loop | Yes | Bot-wait timeout, manual trigger, availability states (today: no timeout, waits forever) | High |
| new `review_sources.py` | Primary | Detect CI and bot health per PR | New | Reads checks, bot comments (skip / rate-limit notices), past-PR activity | High |
| `open_task_pr.sh`, `fast_gate.sh`, `orchestrator-tick.md`, `ship` | Dependent | Full-suite call sites | Yes | Reuse the tree-hash receipt instead of re-running (today 3–4 runs per PR) | High |
| `execution`, `github`, `ship`, `worker.md` | Dependent | Four separate review call sites | Yes | One protocol in `pre-pr-review.md`; callers point to it | Medium |
| `scripts/arsenal_config.py` | Shared resource | Config keys + `CONSUMER` map | Yes | New `verification`, `autonomy`, `effort`, `bot-wait`, `review-budget-min` keys; `config_keys_test.sh` | Medium |
| `init/assets/AGENTS.md` | Primary | Resident protocol | Yes | −~1k tokens/turn; task-label rule; outcome-first reports | High |
| `core/skills/*/SKILL.md` (20) | Primary | Skill prompts + resident descriptions | Yes | Calmer, deduplicated; `effort:` frontmatter where it pays | Medium |
| `skill-workshop` (rubric, `validate.py`, SKILL.md) | Primary | Validation of every skill | Yes | New style/ref rules; `model-upgrade` mode; narrower self-exemption | High |
| `docs/research/` | Shared resource | Rubric source for `audit-rule-drift` | Yes | v1.17 kept; addendum added; drift script reads both | Medium |
| `query_status.py`, `task_select.py`, task template | Dependent | Board and task output | Yes | `label:` field; `<label> (t-id)` everywhere | Low |
| `repo-audit` | Primary | Multi-agent audit | Yes | Fan-out sized to repo; no mandatory re-verify; no model menu | Medium |
| Consumer repos | Client | Re-vendor on update | Config migrates with defaults | Faster PRs, smaller context; 5.0.0 CHANGELOG entry | Medium |

**Risk of inaction**: PRs keep stalling in review loops (measured: 8 × 40 min on one PR); every consumer turn keeps paying ~1k avoidable tokens; the next model generation repeats this manual review.

## 3. Options

### Option A: Resident-tier trim only (Conservative)

- **Description**: Rewrite `AGENTS.md`, `worker.md`, `reviewer.md` and the descriptions against the guidance.
- **Scope**: 3 files + 20 frontmatter blocks.
- **Effort**: Small.
- **Tradeoffs**: Most of the per-turn saving. Leaves the verification loop as is, and nothing stops drift.
- **Compatibility**: Full.

### Option B: Codify, enforce, rewrite in tiers

- **Description**: Guidance shipped as rules and scanner checks; the tree rewritten tier by tier; a compatibility log.
- **Scope**: Whole shipped tree.
- **Effort**: Large.
- **Tradeoffs**: Fixes the prompts durably, but treats verification as prompt text only. The incident's causes are in scripts (counter reset, no timeout, repeated full suites).
- **Compatibility**: Full.

### Option C: B + verification redesign + upgrade tooling (Chosen, r2)

- **Description**: B, plus workstream V (verification is detected, budgeted and done once), workstream U (`model-upgrade` mode, research addendum), the setup interview, per-skill effort and task labels.
- **Scope**: B + review scripts, config, `skill-workshop`, `/init`.
- **Effort**: Large+.
- **Tradeoffs**: Most work. Adds config keys and one detection script. Fixes the problem the maintainer ranks first.
- **Compatibility**: New config keys with defaults; review behaviour changes (fewer rounds) → **5.0.0**.

**Workstream V — verification, designed:**

1. **Detect** (`review_sources.py`, run once per PR, cached per head): CI = workflows exist and a run reported on the head or the base recently; each bot = configured in `review-bots` *and* active on recent PRs. Per PR it classifies each source from evidence: `ok` (reviewed this head), `skipped` (a skip notice, e.g. a bot that does not auto-review small repos), `rate-limited` (a limit notice), `absent` (silence past `bot-wait`). Each state names its next action.
2. **Decide** (one policy, the `verification` profile: `fast | balanced | strict`, default `balanced`):

   | External coverage on this PR | `balanced` local action |
   |---|---|
   | CI `ok` and a bot `ok` | no local adversarial round unless the diff is high-risk (security paths, migrations, > N lines) |
   | CI `ok`, bots `skipped`/`rate-limited`/`absent` | one local round on the diff, targeted tests only |
   | CI absent or broken | one local round + one local full suite, receipt recorded |
   | docs-/config-only diff | no adversarial round in any profile but `strict` |

3. **Budget**: `review-max-rounds` default 2, counted per PR/branch and kept across rebases; follow-up round only for BLOCKERs. Each round's packet states its time budget (`review-budget-min`, default 10) as an elapsed/budget line (Anthropic reports agents pace to such lines); the orchestrator keeps a hard timeout at 2× the budget. The reviewer reads gate receipts and runs at most targeted tests; mutation testing only under `strict`.
4. **Run tests once**: `host-gate` writes a receipt keyed by tree hash; `open_task_pr`, the orchestrator, `ship` and `fast_gate --full` reuse it while the tree is unchanged. With CI healthy, the local full suite is skipped in `fast`/`balanced`.
5. **Bounded bot loop**: wait at most `bot-wait` (default 20 min); then send the bot's manual trigger once, where `review-bots` declares one; still nothing → `absent` for this PR, run the fallback row above, continue. The loop ends after the final state is reached, never on silence alone.
6. **Coherence**: session, workers and reviewers read the same `verification` block; the packet carries the profile and remaining budget, and the reviewer prompt says rounds are the orchestrator's decision, not the reviewer's. Workers never start rounds of their own.

**Workstream U — next model generation:**

- `skill-workshop` gets a `model-upgrade` mode (no consumer cost; skill-workshop is not vendored): fetch the newest prompting guides → diff against `references/model-prompting.md` → propose rule and scanner changes → run the three-part audit (resident, agents/skills, workshop/docs) → write the spec through `specify` → hand off to `design`. This revision is its first run, recorded as the worked example.
- `docs/research/claude-skill-system_v1.17.md` stays frozen. New findings go to `docs/research/addendum-YYYY-MM.md` (first: this generation's guidance and the reference-usage rule); `audit_rule_drift.py` reads both.
- `docs/MODELS.md`: maintainer log of which generation the prompts were aligned with, when, and from which guides. Nothing reads it at runtime.

**G-rules** (the alignment target; shipped as `skill-workshop/references/model-prompting.md`, loaded when writing or reviewing prompt text):

| ID | Rule | Enforced by |
|----|------|-------------|
| G1 | Effort controls thinking; no "think carefully"; never ask for reasoning in the response | R-STYLE-3 |
| G2 | No ritual re-checks; code changes need one real check (tests/typecheck/build/the command), or say which could not run | R-STYLE-4, Q-PROC-1 reworded |
| G3 | Deliver the asked scope; unrequested fixes/cleanup are summary follow-ups | Q-SCOPE-1 |
| G4 | Unattended runs finish: no "Next I'll…" endings, no "Shall I…?" for requested reversible work; stop only when blocked or before risk | R-STYLE-8 |
| G5 | Multi-part work lives in a checklist; a text-only turn end is a report; wait for background work | worker-loop |
| G6 | Delegate only large, independent, parallel work | Q-REV-2 |
| G7 | Reviews report every finding with severity + confidence; filter separately | R-STYLE-5, Q-REV-1 |
| G8 | Reports lead with the outcome; sections (done / not done / questions / next) only when non-empty; short | AGENTS.md |
| G9 | Length matches the task; no history or rationale the executor does not need | Q-PROSE |
| G10 | When-to-format rules, not blanket anti-formatting | Q-PROSE-1 reworded |
| G11 | Calm, explained instructions; no "if in doubt, use X" | R-STYLE-1/2 |
| G12 | Explore loosely specified tasks first, then commit to an approach | execution |
| G13 | Independent tool calls in one response | AGENTS.md |
| G14 | Targeted edits over rewrites | AGENTS.md |
| G15 | Verify fast-moving facts; don't tell the model to minimise tool calls | R-STYLE-6 |
| G16 | Mark untrusted pasted/fetched content | worker/reviewer |
| G17 | Time signals (elapsed/budget) for multi-agent runs; keep a hard timeout | V.3 |
| G18 | Compaction/handoff summaries name what to preserve | session-end, `compact_resume.sh` (landed 4.25.0) |
| G19 | No hard-coded model names; tiers or config | R-STYLE-7 |
| G20 | A reference read on every invocation belongs in `SKILL.md` (or the skill is too big); every reference link states when to load it | `content.ref-unconditional` |
| G21 | Name tasks by short label with the id in brackets | AGENTS.md, `query_status.py` |

**Model and effort per skill**: Claude Code lets a `SKILL.md` and an agent definition set `model:` and `effort:` in frontmatter, and the Agent tool takes a per-dispatch `model`. A running session cannot change its own model or effort; the user does that (`/model`, effort setting). So arsenal sets effort per skill where it pays (e.g. `low` for `queue-status`, `pin-check`; `high` for `review`), keeps `models.workers` / `models.reviewers` as tier aliases, and the interview lets the user override.

**Setup interview** (`/init`, skippable, defaults shown): `autonomy` = `ask-when-blocked` (alternatives `ask-often`, `autonomous`); `verification` = `balanced`; `effort` = per-skill defaults or one override; `review-budget-min` = 10; `bot-wait` = 20. Written to arsenal config; every key already has a default, so existing consumers need no action.

**Canaries**: kept. A `PostToolUse` hook on the `Skill` tool (the mechanism `skill-workshop` already uses) records each load, so loading verification no longer depends on the model echoing the canary.

### Comparison

| | Option A | Option B | Option C |
|---|---|---|---|
| Effort | S | L | L+ |
| Fixes the review loop | No | Prose only | Yes, in scripts |
| Prevents drift | No | Scanner | Scanner + upgrade mode |
| Compatibility | Full | Full | New keys, defaults; 5.0.0 |

## 4. Recommendation

**Chosen option**: C (maintainer, r1 notes).

**Delivery** — V first, because PRs are stalling now:

1. **PR 1 — Verification (V), released alone as `4.26.0`.** `review_sources.py`; `verification` profile + `bot-wait` + `review-budget-min` keys; counter keyed to PR/branch; tree-hash gate receipt; bounded bot loop with manual trigger; single protocol in `pre-pr-review.md`; reviewer test budget. Incident-replay test fixture.

Then a stack where only the last PR bumps to **`5.0.0`**:

2. **Codify** — `model-prompting.md`; R-STYLE / Q-REV / Q-SCOPE / ref-unconditional rules; scanner table in `validate.py` (warnings); narrower self-exemption; research addendum + drift script; canary load hook.
3. **Resident tier** — `AGENTS.md` rewrite; descriptions shortened; task `label:` field and `<label> (t-id)` output.
4. **Agents and skills** — `worker`/`reviewer`, `repo-audit`, SKILL bodies and references rewritten; unconditional references inlined; `effort:` frontmatter; style checks flipped to errors.
5. **Upgrade path and release** — `model-upgrade` mode; `/init` interview; `docs/MODELS.md`; CHANGELOG; `.bundle-version` → `5.0.0`; `make release-check`.

**Immediate next action**: after approval, `design` appends contracts and risks; PR 1 starts with the incident-replay fixture, which fails today.

**Open questions**:
- [ ] **Ship the review fix (PR 1) on its own as `4.26.0` first**, rather than waiting for 5.0.0? Recommended: yes, since PRs are stalling today.
- [ ] **`balanced` defaults**: 2 rounds, 10 min per round, 20 min bot wait, and no local adversarial round when CI and a bot both passed (unless high-risk). Accept, or tighten?

**Decisions log**:

| ID | Decision | Status | Date |
|----|----------|--------|------|
| D-1 | Option C over B | agreed | 2026-10-01 |
| D-2 | Keep CANARY lines; add a `Skill` load hook | agreed | 2026-10-01 |
| D-3 | Release as 5.0.0 | agreed | 2026-10-01 |
| D-4 | No runtime model check or "unsupported model" message; `docs/MODELS.md` is a maintainer log | agreed | 2026-10-01 |
| D-5 | Verification redesign is in scope now and ships first | agreed | 2026-10-01 |
| D-6 | `skill-workshop` owns the model-upgrade process; research v1.17 frozen, addendum for new findings | agreed | 2026-10-01 |
| D-7 | Token reduction and short outputs are standing goals for every change | agreed | 2026-10-01 |

---

## 5. Contracts

Scope: workstream V (PR 1, `4.26.0`). Workstreams P and U get their own contracts when their plan is written.

### Configuration (`arsenal/config.toml`)

| Key | Type / values | Default | Read by |
|-----|---------------|---------|---------|
| `verification` | `fast` \| `balanced` \| `strict` | `balanced` | `review_sources.py`, `fast_gate.sh`, `adversarial_review.sh` |
| `review-max-rounds` | int ≥ 1 | **2** (was 3) | `adversarial_review.sh` |
| `review-budget-min` | int ≥ 1 | 10 | `adversarial_review.sh` (packet line) |
| `bot-wait-min` | int ≥ 1 | 20 | `review_sources.py`, `query_pr_state.py` |
| `bot-triggers` | table `bot = "comment"` | `{}` (starting value; `/init` suggests known commands for the bots in `review-bots`) | `review_sources.py --trigger` |
| `risk-paths` | list of globs | `[]` | `review_sources.py` |
| `risk-lines` | int ≥ 1 | 400 | `review_sources.py` |

Every key enters `DEFAULTS`, the enum/int validators and the `CONSUMER` map (`config_keys_test.sh`).

### `review_sources.py` (new, `init/assets/scripts/`)

```text
review_sources.py --pr N [--repo owner/name] [--json] [--trigger]
```

Prints one line per source, then the decision. Exit 0 on a classification, 2 on an error (no `gh`, unreadable config).

```text
ci              ok            3 checks green on 1a2b3c4
bot:<name>      skipped       "does not receive automatic reviews" (comment 5929979667)
bot:<name>      rate-limited  "rate limit exceeded" (comment …)
bot:<name>      absent        no activity 24 min after head push (bot-wait-min 20)
decision        local-review=diff  full-suite=skip  reason=ci ok, no bot review, 212 changed lines
```

States: CI `ok | failing | pending | absent`; bot `ok | pending | skipped | rate-limited | absent`. `--trigger` posts the bot's `bot-triggers` comment once per PR head for a `skipped` or first-time `absent` bot and records it under `tmp/arsenal-review/pr-<N>/`; a second absence after the trigger is final. `decide(profile, ci, bots, risk, docs_only)` is a pure function implementing the § 3 table: `local-review ∈ {none, diff, full}`, `full-suite ∈ {skip, run}`.

### `adversarial_review.sh` changes

- Round state moves to `tmp/arsenal-review/<branch-slug>/round.env` (`round`, `tree`, `base`). The count survives base moves and rebases; it resets only on a different branch or `--reset`.
- Packet header gains: `Budget: round R of M · B min · profile P. Targeted tests only (changed files, --checks); no full suite; no mutation runs unless profile is strict. Further rounds are the orchestrator's call.`

### Gate receipt

`fast_gate.sh --full` and `open_task_pr.sh`'s host-gate write `tmp/arsenal-gate/receipts/<tree-hash>` (`exit=0`, gate command, UTC time) after a passing run on a clean tree. Before running the full gate they look for a receipt for the current tree and reuse it (`fast_gate: host-gate passed on this tree at <time> — reused`). Dirty tree → no reuse. With CI green on the PR head SHA and a profile other than `strict`, the merge-time full run is skipped and the CI result is named as the evidence.

### `query_pr_state.py` changes

Bot classification comes from `review_sources.py` (shared module). New states `bot_skipped`, `bot_rate_limited`, `bot_absent`; none of them blocks `ready_to_merge` once the local fallback that `decide()` requires has a recorded verdict. `waiting` can no longer last past `bot-wait-min` plus one trigger.

## 6. Risks & Validation

| Risk | Likelihood | Impact | Mitigation | Validation |
|------|-----------|--------|------------|------------|
| A real bug merges because a local review was skipped on "CI + bot ok" | Medium | High | `risk-paths`/`risk-lines` force a local round; `strict` keeps today's depth; the decision line is logged on the PR | unit tests of `decide()`; incident-replay fixture |
| Bot skip/limit notices change wording | High | Medium | Regexes in one table with fixtures; unmatched bot text → `pending` then `absent` after the wait, never a hang | fixture per known notice + one unknown |
| Trigger comment spams a PR | Low | Low | Once per head per bot, recorded on disk | unit test |
| Stale receipt reused after a change | Low | High | Keyed by tree hash; clean tree only | `fast_gate_test.sh` case: edit → rerun |
| Counter keyed to branch never resets on a genuinely new change on the same branch | Medium | Low | `--reset`, and the cap message names it | `adversarial_review_test.sh` |
| Consumers relying on 3 rounds | Low | Low | Key stays configurable; CHANGELOG says so | — |
