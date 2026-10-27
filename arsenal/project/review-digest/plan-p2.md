# Plan: Review digest — P2, the digest and the decision loop

**Date**: 2026-10-27
**Specification**: `arsenal/project/review-digest/spec.md` (r4: § 5 "P2 — the digest", § 6 P2 rows)
**Author**: nuncaeslupus (with Claude)
**Revision**: 1
**Status**: approved (2026-10-27, revision 1) — without annotations
**Revision log**:
- r1 — first draft; P1 merged in 5.11.0

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the `<repo>-plan-p2-v<N>-<date>-notes.md`
> export it applied, committed beside this file in the same commit. Approval is
> `approved (YYYY-MM-DD, revision N)`, plus `— without annotations` when there
> were none.

---

## Technical solution

### Architecture overview

Three scripts and one marker:

- `digest.py record` writes each PR's facts into a machine block in its body when the PR opens,
  and rewrites it on every new head, merge or decision.
- `digest.py render` turns the open and recently merged PRs' blocks into one short page, HTML or
  Markdown, with a decision per PR.
- `apply_decisions.py` reads the exported decisions file and acts on it: approvals become SHA-bound
  decision markers, merges go through `merge_ready.sh` in dependency order, denials close or revert,
  and questions become PR comments.
- `pr_audit.py` counts a decision marker as a human approval only when `[review] digest-decisions`
  is on.
- The worker loop, `session-end` and the orchestrator tick each gain one pointer to
  `references/digest.md`, which is loaded on demand.

### Data flow

```text
review rounds (tmp/arsenal-review) + worker notes ──▶ digest.py record ──▶ PR body block
open + recently merged PRs' blocks ──▶ digest.py render ──▶ digest HTML / Markdown
human: approve / deny / question ──▶ decisions file ──▶ apply_decisions.py
   ├─ approve  ──▶ decision marker on head ──▶ pr_audit counts it (digest-decisions) ──▶ merge_ready ──▶ merge
   ├─ deny     ──▶ close PR + reopen task  |  revert PR for a merged human-after
   └─ question ──▶ PR comment ──▶ next worker answers ──▶ next digest
```

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| PR body | GitHub | UPDATE | `<!-- arsenal-digest {...} -->` block, rewritten in place |
| PR comments | GitHub | CREATE | `<!-- arsenal-decision: approve head=<sha> via=digest -->`, question comments |
| `arsenal/session/digest.json` | file | UPDATE | last render time (for `--since last`) |
| `arsenal/config.toml` | file | UPDATE | `digest-delivery`, `digest-every`, `[review] digest-decisions` |

### Technology choices

| Choice | Justification |
|--------|--------------|
| Record in the PR body (D-14) | Any session can read and write it; no second ref to push; survives the session and the container |
| HTML built by `digest.py`, reusing `create_reader.py`'s CSS tokens | One visual language for everything a human reads; no new dependency |
| Decisions as an exported file | Works on every surface (upload, paste, or "approve 42, deny 43" in chat); an interactive-page adapter can come later |
| Stdlib only | Same as every other `scripts/` file |

### Out of scope

- An interactive hosted page that saves decisions on click (a later adapter).
- `stack-on-pending`: dependents keep waiting for a pending PR as they do today. Revisit after P2 is used for real.
- Lean-code rules and the `SCOPE` finding (P3); overnight repo review and metrics (P4). The digest
  header leaves a slot for P4's metrics line.

---

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | Config keys `digest-delivery`, `digest-every`, `[review] digest-decisions`, validated | `scripts/arsenal_config.py` | S | — | `config_test_failures == 0` | `test_digest_delivery_unknown_value_exits_2` in `plugins/core/tests/arsenal_config_test.sh` |
| T2 | `digest.py record` / `check`: block schema, merge into the PR body without touching other text, findings from round files, mark derivation | `scripts/digest.py` (new) | M | T1 | `digest_test_failures == 0` | `test_record_preserves_body_text_outside_block` · `test_mark_red_for_high_with_open_finding` · `test_check_rejects_61_words` in `plugins/core/tests/digest_test.sh` |
| T3 | `digest.py render`: HTML and Markdown, sorted cards, deps list, decision controls, export with embedded JSON | `scripts/digest.py` | M | T2 | `digest_test_failures == 0` and `visible_words_10_records <= 900` | `test_render_ten_records_fits_900_words` · `test_render_sorts_red_first` · `test_export_carries_head_sha` (Playwright, skips without it) |
| T4 | `apply_decisions.py`: parse, stale-SHA check, markers, deny/close/revert, question comments, dependency-ordered merges through `merge_ready.sh`, manual mode | `scripts/apply_decisions.py` (new) | M | T3 | `apply_decisions_test_failures == 0` | `test_stale_approval_not_merged` · `test_denied_dep_blocks_dependent` · `test_merge_order_follows_deps` in `plugins/core/tests/apply_decisions_test.sh` (stubbed GitHub channel) |
| T5 | `pr_audit.py` counts a decision marker on the head as a human approval when `digest-decisions` is on | `scripts/pr_audit.py` | S | T1 | `pr_audit_test_failures == 0` | `test_digest_marker_counts_when_enabled` · `test_digest_marker_off_counts_zero` · `test_digest_marker_old_sha_counts_zero` |
| T6 | Wiring: `references/digest.md` (load-when trigger); one pointer each in the worker loop, `session-end` and the orchestrator tick; `/init` offers `digest-decisions` with the solo presets | references, `session-end/SKILL.md`, `init` | S | T4, T5 | `resident_token_delta <= 60` and `skill_workshop_findings == 0` | `make context-budget`, skill-workshop `validate.py` on each changed skill |
| T7 | Changelog, minor bump (5.12.0), `make sync-version` | `CHANGELOG.md`, `.bundle-version` | S | T6 | `sync_version_drift == 0` | `make test`, `make sync-version-check` |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1, then T2 and T5 in parallel, then T3, T4, T6, T7. One PR, since the session pushes to one branch.
**Branch pattern**: `claude/code-review-enforcement-sa12j9`, the designated branch.

### Dependency graph

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies",
 "nodes": [
  {"id": "T1", "text": "T1\nConfig keys digest-delivery, digest…"},
  {"id": "T2", "text": "T2\ndigest.py record / check: block sch…"},
  {"id": "T3", "text": "T3\ndigest.py render: HTML and Markdown…"},
  {"id": "T4", "text": "T4\napplydecisions.py: parse, stale-SHA…"},
  {"id": "T5", "text": "T5\npraudit.py counts a decision marker…"},
  {"id": "T6", "text": "T6\nWiring: references/digest.md (load-…"},
  {"id": "T7", "text": "T7\nChangelog, minor bump (5.12.0), mak…"}
 ],
 "edges": [
  {"from": "T1", "to": "T2"},
  {"from": "T2", "to": "T3"},
  {"from": "T3", "to": "T4"},
  {"from": "T1", "to": "T5"},
  {"from": "T4", "to": "T6"},
  {"from": "T5", "to": "T6"},
  {"from": "T6", "to": "T7"}
 ]}
```

## Evidence log

`execution` appends one row per task as it lands (RED → GREEN → RECORD).

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|

---

## Sign-off

- [ ] Plan reviewed by the repo owner
- [ ] D-14 (records in the PR body) agreed
- [ ] Ready for execution
