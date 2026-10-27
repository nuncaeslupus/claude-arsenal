# Plan: Review digest — P4, overnight repo review and review metrics

**Date**: 2026-10-27
**Specification**: `arsenal/project/review-digest/spec.md` (r6: § 5 "P4", § 6 P4 rows)
**Author**: nuncaeslupus (with Claude)
**Revision**: 1
**Status**: draft
**Revision log**:
- r1 — first draft; P3 merged in 5.13.0

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the `<repo>-plan-p4-v<N>-<date>-notes.md`
> export it applied, committed beside this file in the same commit. Approval is
> `approved (YYYY-MM-DD, revision N)`, plus `— without annotations` when there
> were none.

---

## Technical solution

### Architecture overview

Two scripts and one reference, plus two small additions to the digest:

- `review_metrics.py` (core) reads the default branch's history, and the digest records when it
  has them. It answers "is our review keeping reverts down, and who finds the problems?" per risk
  tier.
- `audit_estimate.py` (repo-audit) prices an audit before it starts.
- `references/overnight.md` (repo-audit) turns the existing audit into a budgeted, chunked,
  resumable night run.
- The digest gets the metrics line in its header and an audit card.

### Data flow

```text
git log (default branch) ──▶ review_metrics.py ──▶ one line ──▶ digest header
PR digest records (optional) ─┘
scope ──▶ audit_estimate.py ──▶ cost line ──▶ user confirms ceiling
  └▶ per subsystem: budget_check.sh + ceiling ──▶ audit chunk ──▶ ledger
ledger ──▶ queue (existing) + digest --audit card (findings, queued, not covered)
```

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| audit ledger | file | CREATE | `tmp/audit/<date>-findings.json` (existing shape, plus `not_covered`) |

### Technology choices

| Choice | Justification |
|--------|--------------|
| Metrics from git trailers and commit messages | Free and offline; the P1 trailers already carry the tier |
| Tokens-per-line estimate with a documented starting value | Repos differ; a stated, tunable number beats a hidden one |
| Chunk per subsystem, with the budget checked between chunks | A stopped run still leaves complete, reportable chunks |

### Out of scope

- Dashboards or historical storage of metrics: the line is recomputed on demand.
- Automatic fixing of audit findings: findings are queued, never edited in the same run.

---

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | `review_metrics.py`: merges by tier from trailers, reverts, fix-ups ≤7d, rounds and finding sources from records, one line plus `--json` | `core/.../scripts/review_metrics.py` (new) | M | — | `review_metrics_test_failures == 0` | `test_revert_counted_against_its_tier` · `test_fixup_within_7_days_counted` · `test_untiered_merges_reported` in `plugins/core/tests/review_metrics_test.sh` (fixture git repo) |
| T2 | Digest header carries the metrics line (git-only, last 30 days) | `scripts/digest.py` | S | T1 | `digest_test_failures == 0` | `test_render_header_has_metrics_line` in `digest_test.sh` |
| T3 | `audit_estimate.py`: files, lines, tokens and subsystem split for a scope, skipping vendored, generated and lock files | `repo-audit/.../scripts/audit_estimate.py` (new) | S | — | `audit_estimate_test_failures == 0` | `test_estimate_skips_lockfiles_and_vendor` · `test_tokens_scale_with_flag` in `plugins/repo-audit/tests/audit_estimate_test.sh` |
| T4 | Overnight mode: `references/overnight.md`, plus one line in repo-audit `SKILL.md` (ask scope and ceiling, show the estimate, chunk, budget check, stop and report uncovered, never edit code) | repo-audit skill | S | T3 | `skill_workshop_findings == 0` | skill-workshop `validate.py plugins/repo-audit/skills/repo-audit` |
| T5 | Digest `render --audit FILE` card: severity × confidence counts, top 5, queued, not covered | `scripts/digest.py` | S | T4 | `digest_test_failures == 0` | `test_audit_card_lists_not_covered` in `digest_test.sh` |
| T6 | Changelog, minor bump (5.14.0), `make sync-version` | `CHANGELOG.md`, `.bundle-version` | S | T2, T5 | `resident_token_delta <= 30` and `sync_version_drift == 0` | `make context-budget`, `make test`, `make audit` |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1 and T3 in parallel, then T2 and T4, then T5, then T6. One PR.
**Branch pattern**: `claude/code-review-enforcement-sa12j9`, the designated branch.

### Dependency graph

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies",
 "nodes": [
  {"id": "T1", "text": "T1\nreviewmetrics.py: merges by tier fr…"},
  {"id": "T2", "text": "T2\nDigest header carries the metrics l…"},
  {"id": "T3", "text": "T3\nauditestimate.py: files, lines, tok…"},
  {"id": "T4", "text": "T4\nOvernight mode: references/overnigh…"},
  {"id": "T5", "text": "T5\nDigest render --audit FILE card: se…"},
  {"id": "T6", "text": "T6\nChangelog, minor bump (5.14.0), mak…"}
 ],
 "edges": [
  {"from": "T1", "to": "T2"},
  {"from": "T3", "to": "T4"},
  {"from": "T4", "to": "T5"},
  {"from": "T2", "to": "T6"},
  {"from": "T5", "to": "T6"}
 ]}
```

## Evidence log

`execution` appends one row per task as it lands (RED → GREEN → RECORD).

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|

---

## Sign-off

- [ ] Plan reviewed by the repo owner
- [ ] Ready for execution
