# Claude Arsenal — Specification (annotated edition)

> Generated 2026-10-26. This is the document with a **note slot** after every section that has text of its own. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# Spec

## Preamble & scope

**Date**: 2026-10-26
**Ticket / PR**: branch `claude/code-review-enforcement-sa12j9`
**Author**: nuncaeslupus (with Claude)
**Revision**: 1
**Status**: draft
**Revision log**:
- r1 — first draft, from the brainstorm on Anthropic's "How the Claude Code team does code review" (Oct 2026)

<!-- -->

> **✎ Notes** · `SPEC · intro`
> _(your notes here — replace this line)_

## §1 Problem statement

LLM sessions now write, review and merge most of the code in a host repo, often
unattended overnight. The bundle already enforces a pre-PR cold review with a
round cap (`pre-pr-review.md`), a repo-wide `merge-policy`, and per-head verdicts —
but three things are missing. **(a) Risk does not decide who approves**: `risk-paths`
/ `risk-lines` only deepen the review, while `merge-policy` is one value for the whole
repo, so a solo developer and a large team get the same choice. **(b) The human has no
decision surface**: the only record of what was done is GitHub (PR bodies, threads,
checks), which a person who no longer opens an editor or GitHub cannot use; after a
night of work, what merged, what is waiting, what was fixed and by whom is scattered
or lost to compaction. **(c) Nothing pushes code to be small**, and nothing measures
whether the review a host chose is actually keeping reverts down. The outcome wanted:
a configurable, cheap flow where every change is reviewed before its PR exists, the
worker never stalls waiting for a human, and the human gets one short, durable,
severity-ranked digest from which approving or rejecting the whole night's work takes
minutes — with the responsibility for what merged clearly theirs.

Provenance: Anthropic's post reports six layers (pre-PR checks, required CI, AI
review, security review, risk-tiered human approval, merge queue + flags) with
rollback underneath; agent approval never counts as human approval; an approval binds
one commit; merged PRs doubled while reverts fell >40%. The source was read through
secondary summaries — the original was unreachable from the authoring session.

**Success criteria (measurable)**:

- [ ] `risk_tier.py` classifies a PR into `low|medium|high` deterministically: same diff + same config → same tier, covered by tests (`make test` green).
- [ ] Every merge made by an agent records provenance on the merge commit: `Reviewed-by: agent <verdict>@<sha>` and, when a human approved, `Approved-by: human@<sha> via digest`. A human approval whose SHA ≠ merged head is rejected by `apply_decisions.py` (tested).
- [ ] A PR whose tier policy requires a human never blocks the worker: the worker moves to the next task with no unmet dep in the same session (tested on `task_select.py` with an awaiting-human PR present).
- [ ] Digest entry, folded: ≤ 3 sentences and ≤ 60 words of visible text per PR plus a one-line status row (tier, severity mark, state, deps). Checked by `digest.py --check`.
- [ ] A digest of 10 PRs, all folded, renders in ≤ 900 visible words (one screen of skimming).
- [ ] The digest survives compaction and session end: it is rebuilt from durable per-PR records (`arsenal/digest/entries/*.json`) with no chat history, verified by deleting session state and re-rendering.
- [ ] Applying decisions merges every approved PR whose deps are approved/merged in topological order with one command; denied PRs and their dependents are reported, not merged (tested).
- [ ] Review rounds stay finite: unchanged `review-max-rounds` cap; a PR that hits the cap lands in the digest as `needs-decision` instead of stopping the worker.
- [ ] `/init` asks the review questions (preset, tier thresholds, digest delivery, overnight budget) before writing them, and `review_policy.py --explain` prints the effective flow in ≤ 12 lines.
- [ ] Context cost: `make context-budget` always-installed tier grows ≤ 150 tokens; every new reference has a "load this when…" trigger; no new SKILL.md body over the skill-workshop size rules.
- [ ] Every new or changed skill passes `/skill-workshop:skill-workshop` with zero findings and `make audit` keeps ≥ 50 % listing headroom on the default install.
- [ ] Lean-code rules: the reviewer rubric has a `SCOPE` finding class, and the digest shows `+added/-removed` lines per PR with a flag when the diff exceeds the task's stated size by > 2×. Judged on 3 real PRs during rollout.
- [ ] `review_metrics.py` reports per tier: PRs merged, reverts, fix-up PRs within 7 days, mean review rounds, findings by source (self/cold-reviewer/bot/CI/human); its one-line summary heads the digest.

<!-- -->

> **✎ Notes** · `SPEC §1`
> _(your notes here — replace this line)_

## §2 Systems & Impact

| System | Type | Role | Needs changes? | Impact | Severity |
|--------|------|------|----------------|--------|----------|
| `init` (`SKILL.md`, `init.py`, interview) | Primary | Asks setup questions, writes `arsenal/config.toml` | Yes | New review questions + presets; existing installs keep current behaviour until they opt in | Med |
| `arsenal_config.py` | Primary | Config schema + validation | Yes | New keys: `review-preset`, `[review.tiers]`, `[review.approval]`, `digest-*`, `overnight-*` | Med |
| `scripts/risk_tier.py` (new) | Primary | Deterministic tier classifier | New | Builds on `risk-paths`/`risk-lines`; adds `low-paths` (docs, tests-only) | Med |
| `pr_audit.py` / `merge_ready.sh` | Primary | Merge verdict | Yes | Verdict becomes per-tier; distinguishes agent vs human approval; enforces SHA binding | High |
| `pre-pr-review.md`, `agents/reviewer.md` | Primary | Cold reviewer protocol + rubric | Yes | Writes structured findings (what, who found, how fixed, commit) into the PR record; adds `SCOPE` class | Med |
| `scripts/digest.py` (new) | Primary | Records per-PR entries, renders digest, checks size | New | HTML (folded entries, severity marks, deps graph, approve/deny/question controls, export) + Markdown/chat form | High |
| `scripts/apply_decisions.py` (new) | Primary | Applies an exported decisions file | New | Topo-ordered merges via `merge_ready.sh`; denial → close PR or reopen task; uses `rebase_stack.sh` | High |
| `references/lean-code.md` (new) | Primary | Rules for writing and reviewing small code | New | Loaded by worker at implement time and by reviewer; on demand only | Low |
| `repo-audit` skill | Dependent | Whole-repo audit | Yes | `--overnight` mode: token budget, scope, findings into digest + queue | Med |
| `scripts/review_metrics.py` (new) | Primary | Revert/rounds/finding-source metrics from git + PR data | New | Feeds digest header; justifies loosening or tightening a tier | Low |
| `task_select.py`, worker loop, orchestrator tick | Dependent | Pick next task, merge preconditions | Yes | Awaiting-human PR = unresolved dep; optional stack-on-pending | Med |
| `execution`, `ship`, `review`, `github` skills | Dependent | Point at the protocol | Validate; small pointer edits | Must keep pointing at one protocol page, not restate it | Low |
| `AGENTS.md` (vendored) | Dependent | Resident rules | Yes, ≤ 5 lines | Resident cost — capped | Med |
| `quota-governance.md`, `usage_report.py` | Shared resource | Token budget stop | Validate | Overnight review must respect it; digest shows tokens per PR when known | Low |
| `CHANGELOG.md`, `.bundle-version` | Infrastructure | Release | Yes | Minor bump (new scripts, flags, flow) | Low |

**Risk if nothing changes**: overnight merges keep landing with no human-readable
record; responsibility for what shipped is implicit; a solo user and a team must pick
the same policy; review effort cannot be tuned against reverts because nothing
measures them.

<!-- -->

> **✎ Notes** · `SPEC §2`
> _(your notes here — replace this line)_

## §3 Options

### Option A: PR-body brief + chat summary (Conservative)

- **Description**: Standardise a short "decision brief" in every PR body (what/why, findings fixed and by whom, riskiest spot, how to undo). At session end, print a Markdown digest in chat. Add `risk_tier.py` and a per-tier `merge-policy`.
- **Scope**: `pre-pr-review.md`, `open_task_pr.sh` template, `session-end`, `arsenal_config.py`, `pr_audit.py`.
- **Effort**: Small
- **Tradeoffs**: Cheap, but the chat digest is lost to compaction or a long night; decisions are typed back by hand; GitHub is still the only durable record — fails the "never open GitHub" requirement.
- **Compatibility**: Fully backward compatible.

<!-- -->

> **✎ Notes** · `SPEC › Option A: PR-body brief + chat summary (Conservative)`
> _(your notes here — replace this line)_

### Option B: Durable digest + tier policy + decision loop (Recommended)

- **Description**: Everything in A, plus:
  1. **Tiers and presets.** `risk_tier.py` → tier; `[review.approval]` maps tier → `auto` (CI/gates only) / `agent` (cold-reviewer CLEAR) / `human` (N human approvals) / `human-after` (agent merges, human ratifies in digest). Presets set all of it at once: `solo-trust` (agent merges every tier, high tier flagged for ratification), `solo-gated` (human approves medium+high), `team` (0/1/2 humans by tier, agent approval never counts), `manual` (`never`). `/init` explains each preset in one line and asks.
  2. **Durable per-PR records.** When a PR opens (and on every new head, merge or decision) `digest.py record` writes `arsenal/digest/entries/<pr>.json`: tier, severity mark, state (`merged-awaiting-ratification` / `awaiting-approval` / `needs-decision` / `blocked-by-dep`), 2–3 sentence summary, deps, size `+/-`, review rounds, findings (what, who found, how fixed, commit), open RISK notes, how to undo, tokens spent when known. Entries live on a dedicated branch (`arsenal/digest`) so they never wait on a PR to merge and survive any session.
  3. **The digest.** `digest.py render` builds one HTML page — the annotatable-reader pattern: header line from `review_metrics.py`, a dependency graph, then one folded card per PR sorted by severity; unfold for the detail; per card **Approve / Deny / Question** controls and a free note; Export writes a decisions file. `--format md` gives the same digest as chat text. Size is enforced by `digest.py --check`.
  4. **Delivery that does not get lost.** Configurable `digest-delivery`: `file` (committed HTML on the digest branch, path printed), `chat` (Markdown at session end and on demand), `artifact` (an adapter for surfaces that host interactive pages and keep their state), `issue` (one pinned issue, for hosts that live in GitHub). Delivery runs at session end, when the session's token budget stops it, and every `digest-every` merged PRs, so a crash still leaves a current digest. `digest-notify` uses the surface's push notification when one exists.
  5. **Applying decisions.** The user returns the export (upload, paste, or "approve 1,3; deny 2" in chat). `apply_decisions.py` checks each approval's SHA against the current head, merges approved PRs in topological order through `merge_ready.sh`, rebases stacked dependents, and turns denials into a closed PR + reopened task (or a revert PR for an already-merged `human-after` entry). Questions become a task note the next worker answers in the next digest.
  6. **Unbroken flow.** A PR awaiting a human is labelled `arsenal:awaiting-human`; `task_select.py` treats it as an unmet dep, so the worker picks independent work. `stack-on-pending = yes` lets dependent work branch on the pending PR instead of waiting (merge order then follows the graph).
  7. **Lean code.** `references/lean-code.md`: a short rule list (smallest diff that meets the gate; delete before add; no speculative abstraction, options or defensive code for impossible states; reuse existing helpers; no comment restating code; no unrequested refactor). Worker loads it when implementing; reviewer rubric gains `SCOPE` (code the task did not need) as a finding class; digest flags size over 2× the task's estimate.
  8. **Overnight repo review.** `repo-audit --overnight`: asks scope and a token ceiling up front, prints the estimated cost before starting, stops at `quota-governance`'s budget, writes findings to the digest (severity, confidence) and queues the real ones as tasks — never edits code in the same run.
  9. **Metrics.** `review_metrics.py` (reverts, fix-ups, rounds, finding sources per tier) so a user can see whether loosening a tier is safe.
- **Scope**: as § 2; new scripts carry the logic, references carry the prose.
- **Effort**: Large (phased: P1 tiers/policy/provenance/interview → P2 records/digest/decisions → P3 lean-code + SCOPE → P4 overnight review + metrics).
- **Tradeoffs**: More moving parts; a second branch to maintain; the HTML export round-trip is one manual step on surfaces without an interactive adapter. In exchange it meets every requirement: durable, short, decision-ready, configurable, cheap (scripts, not prose).
- **Compatibility**: Backward compatible. Absent `review-preset`, `merge-policy` keeps its current meaning; the digest is opt-in at upgrade (the upgrade banner offers the interview).

<!-- -->

> **✎ Notes** · `SPEC › Option B: Durable digest + tier policy + decision loop (Recommended)`
> _(your notes here — replace this line)_

### Option C: Hosted live dashboard (if applicable)

- **Description**: Make the digest a hosted interactive page with shared state (decisions saved on click, no export), plus a mobile-friendly view.
- **Scope**: B plus a hosting integration.
- **Effort**: Large
- **Tradeoffs**: Best UX on surfaces that support it, but ties the core flow to one host and violates "everything shipped is generic"; users without that surface get nothing.
- **Compatibility**: Surface-specific.

<!-- -->

> **✎ Notes** · `SPEC › Option C: Hosted live dashboard (if applicable)`
> _(your notes here — replace this line)_

### Comparison

| | Option A | Option B | Option C |
|---|---|---|---|
| Effort | Small | Large (4 phases) | Large+ |
| Risk | Low | Medium | High (host lock-in) |
| Completeness | Partial — digest not durable, no decision loop | Full | Full on one surface only |
| Compatibility | Full | Full (opt-in) | Surface-specific |
| Maintenance | Low | Medium | High |

<!-- -->

> **✎ Notes** · `SPEC › Comparison`
> _(your notes here — replace this line)_

## §4 Recommendation

**Recommended option**: Option B — the only one that keeps the digest durable across
a night of work, gives the human a decision surface outside GitHub, and stays generic.
Option C's live page becomes B's `artifact` delivery adapter, not the core.

**Immediate next action**: approve this spec, then run `design` for phase P1 (risk
tiers, approval presets, provenance trailers, `/init` interview and `--explain`).
P2 (digest) is planned once P1's config keys are fixed, since every digest field
reads them.

**Open questions**:
- [ ] Digest branch vs committed under `arsenal/digest/` on the default branch via each PR — the branch avoids PR churn but is one more ref; recommend the branch.
- [ ] Denial of an already-merged `human-after` PR: auto-open a revert PR, or queue a task to decide? Recommend the revert PR (undo is cheap, the decision was already made).
- [ ] Should `solo-trust` still require a human for a path list the user names (`always-human-paths`), even if they otherwise trust the agent? Recommend offering it, empty by default.
- [ ] The ponytail plugin installed on the author's machine — what rules does it apply? If useful, fold them into `lean-code.md` as provenance, without naming it as a norm.
- [ ] Severity mark vocabulary: reuse the reviewer's `BLOCKER/RISK/NOTE` plus tier, or a 3-colour mark (red/amber/green)? Recommend the colour mark derived from tier × open findings.

**Decisions log**:

| ID | Decision | Status | Date |
|----|----------|--------|------|
| D-1 | For the author's own repos: agent merges high-risk PRs alone; they appear in the digest for ratification (`solo-trust`). | agreed | 2026-10-26 |
| D-2 | Review runs before the PR opens; the round cap stays finite; a capped PR becomes a digest decision, never an infinite loop. | agreed | 2026-10-26 |
| D-3 | The human decision surface must not require opening GitHub or an editor. | agreed | 2026-10-26 |
| D-4 | The worker never stalls on a human: waiting PRs are parked, independent work continues, dependents may stack. | agreed | 2026-10-26 |
| D-5 | Digest is short by construction (2–3 sentences folded, detail on unfold), severity-ranked, with approve/deny per PR and a dependency view. | agreed | 2026-10-26 |
| D-6 | Every level of review and detail is configurable and asked at `/init`, with presets for solo through team; the effective flow is printable. | agreed | 2026-10-26 |
| D-7 | Token cost is stated before costly modes (overnight review); everything new is script-first and on-demand; skill-workshop gates every skill change. | agreed | 2026-10-26 |
| D-8 | Security review is an optional layer, off in solo presets. | agreed | 2026-10-26 |


> Sections 5–6 (contracts, risks) are appended by `design`.

<!-- -->

> **✎ Notes** · `SPEC §4`
> _(your notes here — replace this line)_

