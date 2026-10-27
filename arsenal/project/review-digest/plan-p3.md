# Plan: Review digest — P3, lean code

**Date**: 2026-10-27
**Specification**: `arsenal/project/review-digest/spec.md` (r5: § 5 "P3 — lean code", § 6 P3 rows)
**Author**: nuncaeslupus (with Claude)
**Revision**: 1
**Status**: approved (2026-10-27, revision 1) — without annotations
**Revision log**:
- r1 — first draft; P2 merged in 5.12.0

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the `<repo>-plan-p3-v<N>-<date>-notes.md`
> export it applied, committed beside this file in the same commit. Approval is
> `approved (YYYY-MM-DD, revision N)`, plus `— without annotations` when there
> were none.

---

## Technical solution

### Architecture overview

Three small changes. Most of the text goes in one on-demand reference, so the per-turn cost
stays flat:

- `references/lean-code.md` holds the ladder, the rules and the never-cut list.
- `execution`'s GREEN step points the implementer at it.
- `agents/reviewer.md` gains one line making unneeded code a `SCOPE`-tagged `RISK`.
- `digest.py` compares a PR's size with the worker's own estimate and flags anything over 2×.

### Data flow

```text
task size ──▶ worker estimate (expected_lines) ──▶ digest --notes ──▶ record.size.expected
implement ──▶ lean-code ladder ──▶ diff
cold reviewer ──▶ RISK | SCOPE: … ──▶ author removes or answers ──▶ record.findings
render ──▶ "⚠ N× expected size" + amber mark when add+del > 2 × expected
```

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| digest record | PR body | UPDATE | `size.expected` (optional) |

### Technology choices

| Choice | Justification |
|--------|--------------|
| SCOPE as a tag on `RISK`, not a new severity | The verdict grammar and its parser stay as they are; it never blocks on its own |
| The worker's own estimate, not a fixed lines-per-size table | Repos differ too much for one table; the estimate is made before the code exists, so it's honest |
| Rules in a reference, not the rubric | `agents/reviewer.md` is embedded in every review packet; a reference costs nothing until it's opened |

### Out of scope

- An intensity knob (lite/full) or a blocking SCOPE mode. Add one only if the non-blocking tag proves too weak.
- Overnight repo review and metrics (P4).

---

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | `references/lean-code.md`: ladder, rules with reasons, never-cut list, load trigger | `init/assets/references` | S | — | `skill_workshop_findings == 0` | `bundle_refs_test.sh` resolves the new reference · skill-workshop `validate.py plugins/core/skills/init` |
| T2 | Reviewer rubric: SCOPE line in "What to hunt" item 1 | `init/assets/agents/reviewer.md` | S | T1 | `reviewer_md_line_delta <= 4` | `test_rubric_names_scope_tag` in `plugins/core/tests/adversarial_review_test.sh` — the emitted packet carries the SCOPE line |
| T3 | `execution` GREEN step points at the reference | `execution/SKILL.md` | S | T1 | `skill_workshop_findings == 0` | skill-workshop `validate.py plugins/core/skills/execution` |
| T4 | Digest: `expected_lines` → `size.expected`, oversize flag in the status row, green → amber | `scripts/digest.py`, `references/digest.md` | S | — | `digest_test_failures == 0` | `test_oversize_flags_and_turns_amber` · `test_no_estimate_no_flag` in `plugins/core/tests/digest_test.sh` |
| T5 | Changelog, minor bump (5.13.0), `make sync-version` | `CHANGELOG.md`, `.bundle-version` | S | T2, T3, T4 | `resident_token_delta <= 30` and `sync_version_drift == 0` | `make context-budget`, `make test` |

**Status legend**: ☐ not started · ◐ in progress · ☑ merged

**Merge order**: T1 and T4 in parallel, then T2 and T3, then T5. One PR, since the session pushes to one branch.
**Branch pattern**: `claude/code-review-enforcement-sa12j9`, the designated branch.

### Dependency graph

```drawspec
{"version": 1, "kind": "flow", "title": "Task dependencies",
 "nodes": [
  {"id": "T1", "text": "T1\nreferences/lean-code.md: ladder, ru…"},
  {"id": "T2", "text": "T2\nReviewer rubric: SCOPE line in \"Wha…"},
  {"id": "T3", "text": "T3\nexecution GREEN step points at the…"},
  {"id": "T4", "text": "T4\nDigest: expectedlines → size.expect…"},
  {"id": "T5", "text": "T5\nChangelog, minor bump (5.13.0), mak…"}
 ],
 "edges": [
  {"from": "T1", "to": "T2"},
  {"from": "T1", "to": "T3"},
  {"from": "T2", "to": "T5"},
  {"from": "T3", "to": "T5"},
  {"from": "T4", "to": "T5"}
 ]}
```

## Evidence log

`execution` appends one row per task as it lands (RED → GREEN → RECORD).

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | `skill_workshop_findings == 0` | 0 | `validate.py plugins/core/skills/init` | HEAD | local | 2026-10-27 |
| T2 | `reviewer_md_line_delta <= 4` | 3 | `git diff --stat origin/main -- agents/reviewer.md` (+4 −1) | HEAD | local | 2026-10-27 |
| T3 | `skill_workshop_findings == 0` | 0 | `validate.py plugins/core/skills/execution` | HEAD | local | 2026-10-27 |
| T4 | `digest_test_failures == 0` | 0 | `bash plugins/core/tests/digest_test.sh` | HEAD | local | 2026-10-27 |
| T5 | `resident_token_delta <= 30` | 24 | `make context-budget` (minimal 2708 → 2732) | HEAD | local | 2026-10-27 |

---

## Sign-off

- [ ] Plan reviewed by the repo owner
- [ ] Ready for execution
