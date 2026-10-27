# Claude Arsenal — Plan (annotated edition)

> Generated 2026-10-27. This is the document with a **note slot** after every section that has text of its own. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# Plan

## Preamble & scope

**Date**: 2026-10-27
**Specification**: `arsenal/project/review-digest/spec.md` (approved r2; contracts and risks in §§ 5–6)
**Author**: nuncaeslupus (with Claude)
**Revision**: 2
**Status**: draft
**Revision log**:
- r2 — executed overnight at the owner's request ("continue working overnight") before plan sign-off; T1 config keys are flat `[review]` keys (spec r3)
- r1 — first draft, phase P1 only (P2 digest, P3 lean code, P4 overnight review + metrics planned after P1 merges)

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the `<repo>-plan-v<N>-<date>-notes.md`
> export it applied, committed beside this file in the same commit. Approval is
> `approved (YYYY-MM-DD, revision N)`, plus `— without annotations` when there
> were none.

<!-- -->

> **✎ Notes** · `PLAN · intro`
> _(your notes here — replace this line)_

## Technical solution

### Architecture overview

P1 makes risk decide who approves. One new pure module, `review_policy.py`,
classifies a PR's files into `low|medium|high` and maps the tier to an approval
requirement from `review-preset`, `[review.tiers]`, `[review.approval]` and
`always-human-paths`. `pr_audit.py` (behind `merge_ready.sh`) asks it for the
requirement and counts what the head actually has: an agent review (existing CLEAR
marker or bot review) and human approvals (GitHub APPROVED reviews from non-bot,
trusted, non-implementer users on the head SHA). `merge_ready.sh --body` writes the
result as merge-commit trailers, which P2's digest reads. `review_sources.py` keeps
deciding review depth, now from the same tier. `/init` asks one new question.

<!-- -->

> **✎ Notes** · `PLAN › Architecture overview`
> _(your notes here — replace this line)_

### Data flow

```text
PR files ──▶ review_policy.classify ──▶ tier + reasons
                                         │
config ──▶ review_policy.requirement ◀───┘──▶ approval need
                                         │
PR reviews/markers ──▶ pr_audit.audit_pr ┴──▶ ready? + provenance
                                                  │
                         merge_ready.sh --body ◀──┘──▶ trailers on the merge commit
```

<!-- -->

> **✎ Notes** · `PLAN › Data flow`
> _(your notes here — replace this line)_

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| `arsenal/config.toml` | file | UPDATE | New optional keys `review-preset`, `always-human-paths`, tables `[review.tiers]`, `[review.approval]` |
| merge commits | git | CREATE | Trailers `Risk-tier`, `Reviewed-by`, `Approved-by`, `Ratify` |

<!-- -->

> **✎ Notes** · `PLAN › State changes`
> _(your notes here — replace this line)_

### Technology choices

| Choice | Justification |
|--------|--------------|
| One module for tier + requirement | `explain` and the merge verdict read the same code, so they cannot disagree |
| Commit trailers for provenance | Durable, readable with `git log`, needs no GitHub to audit later — the digest's input |
| Stdlib only (`fnmatch`, `json`, `tomllib`) | Same as every other `scripts/` file |

<!-- -->

> **✎ Notes** · `PLAN › Technology choices`
> _(your notes here — replace this line)_

### Out of scope

- The digest, its records branch, decisions and `apply_decisions.py` (P2).
- `arsenal:awaiting-human` labelling and `task_select.py` changes (P2, with the digest that surfaces them).
- Lean-code rules and the `SCOPE` finding (P3); overnight review and metrics (P4).
- Any change to the pre-PR review protocol or its round cap.

<!-- -->

> **✎ Notes** · `PLAN › Out of scope`
> _(your notes here — replace this line)_

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | Config schema: `[review] preset` enum, `always-human-paths`, `low-paths`, `approval-<tier>` with validation | `scripts/arsenal_config.py` | S | — | `config_test_failures == 0` | `test_review_preset_unknown_value_exits_2` in `plugins/core/tests/arsenal_config_test.sh` — an unknown preset names the key and exits 2 · `test_review_approval_human_n_parses` — `human:2` parses to two required humans |
| T2 | `review_policy.py`: `classify`, `requirement`, CLI `tier` / `require` / `explain`; presets table | `scripts/review_policy.py` (new) | M | T1 | `review_policy_test_failures == 0` and `explain_lines <= 12` | `test_tier_mixed_docs_and_code_is_not_low` in `plugins/core/tests/review_policy_test.sh` — one code file in a docs diff yields medium · `test_tier_always_human_path_forces_high_and_one_human` — a match overrides `solo-trust` · `test_tier_same_input_same_output` — two runs are byte-identical · `test_explain_fits_twelve_lines` |
| T3 | `review_sources.py` derives `risk_high` from `classify` (tier high) without changing decisions for hosts with no preset | `scripts/review_sources.py` | S | T2 | `review_sources_test_failures == 0` | existing `plugins/core/tests/review_sources_test.sh` unchanged · `test_risk_from_tier_matches_legacy_assess` — same `risk_high` as before on its fixtures |
| T4 | `pr_audit.py`: per-tier verdict, human counting, provenance fields; legacy path untouched when no preset | `scripts/pr_audit.py` | M | T2 | `pr_audit_test_failures == 0` | `test_bot_approval_counts_zero_humans` in `plugins/core/tests/pr_audit_test.sh` · `test_same_session_approval_counts_zero_humans` · `test_human_approval_on_old_sha_is_stale` · `test_human_after_ready_with_agent_clear_sets_ratify` · `test_no_preset_verdicts_unchanged` — every existing fixture keeps its verdict |
| T5 | `merge_ready.sh --body` emits `Risk-tier` / `Reviewed-by` / `Approved-by` / `Ratify` trailers | `bin/merge_ready.sh` | S | T4 | `merge_ready_test_failures == 0` | `test_body_carries_tier_and_review_trailers` in `plugins/core/tests/merge_ready_test.sh` · `test_body_without_preset_unchanged` |
| T6 | `/init` interview question 5 + `--review-preset` / `--always-human-paths` flags; `init/SKILL.md` interview list (skill-workshop clean) | `init/scripts/init.py`, `init/SKILL.md` | S | T1 | `init_test_failures == 0` and `skill_workshop_findings == 0` | `test_interview_review_preset_written` in `plugins/core/tests/init_test.sh` — the answer lands in `config.toml` · `test_upgrade_does_not_ask_review_preset` |
| T7 | Docs: `github-automation.md` § Merge policy gains the tier/preset table and the trailer contract; CHANGELOG entry; minor bump + `make sync-version` | `assets/references/`, `CHANGELOG.md`, `.bundle-version` | S | T4, T5, T6 | `resident_token_delta <= 150` and `sync_version_drift == 0` | `make context-budget`, `make sync-version-check`, `make test` green |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1, then T2 and T6 (parallel), then T3 and T4 (parallel), then T5, then T7
**Branch pattern**: `review-digest-T<N>-description` from the default branch, stacked per `github` § stacking; only T7 bumps `.bundle-version`

<!-- -->

> **✎ Notes** · `PLAN › Implementation tasks`
> _(your notes here — replace this line)_

### Dependency graph

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies",
 "nodes": [
  {"id": "T1", "text": "T1\nConfig schema: review-preset enum,…"},
  {"id": "T2", "text": "T2\nreviewpolicy.py: classify, requirem…"},
  {"id": "T3", "text": "T3\nreviewsources.py derives riskhigh f…"},
  {"id": "T4", "text": "T4\npraudit.py: per-tier verdict, human…"},
  {"id": "T5", "text": "T5\nmergeready.sh --body emits Risk-tie…"},
  {"id": "T6", "text": "T6\n/init interview question 5 + --revi…"},
  {"id": "T7", "text": "T7\nDocs: github-automation.md § Merge…"}
 ],
 "edges": [
  {"from": "T1", "to": "T2"},
  {"from": "T2", "to": "T3"},
  {"from": "T2", "to": "T4"},
  {"from": "T4", "to": "T5"},
  {"from": "T1", "to": "T6"},
  {"from": "T5", "to": "T7"},
  {"from": "T6", "to": "T7"}
 ]}
```

<!-- -->

> **✎ Notes** · `PLAN › Dependency graph`
> _(your notes here — replace this line)_

## Evidence log

`execution` appends one row per task as it lands (RED → GREEN → RECORD).

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|

<!-- -->

> **✎ Notes** · `PLAN › Evidence log`
> _(your notes here — replace this line)_

## Sign-off

- [ ] Plan reviewed by the repo owner
- [ ] Contracts (spec § 5) agreed
- [ ] Ready for execution

<!-- -->

> **✎ Notes** · `PLAN › Sign-off`
> _(your notes here — replace this line)_

