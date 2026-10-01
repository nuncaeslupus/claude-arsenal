# Arsenal 5.5 alignment — Plan (annotated edition)

> Generated 2026-10-01. This is the document with a **note slot** after every section. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# Plan

## Preamble & scope

**Date**: 2026-10-01
**Specification**: `arsenal/project/model-5-5-alignment/spec.md` (revision 2, § 3 workstream V, § 5–6)
**Author**: imarcos@gmail.com
**Revision**: 1
**Status**: approved (2026-10-01, revision 1) — without annotations
**Revision log**:
- r1 — first draft

> Review record, kept the way the spec keeps its own: each round of notes bumps
> **Revision** with a log line naming the export it applied, committed beside
> this file in the same commit. Approval is `approved (YYYY-MM-DD, revision N)`.

<!-- -->

> **✎ Notes** · `PLAN · intro`
> _(your notes here — replace this line)_

## Technical solution



<!-- -->

> **✎ Notes** · `PLAN › Technical solution`
> _(your notes here — replace this line)_

### Architecture overview

One decision point replaces four independent review habits. `review_sources.py`
looks at what external checks actually did on the PR, `decide()` turns that plus
the `verification` profile and the change's risk into one instruction (no local
review / diff review / full review; run or skip the local full suite), and every
caller — `execution`, `github`, `ship`, `worker`, the orchestrator — reads that
line instead of choosing for itself. Rounds are counted per branch, each round
carries a time and test budget, and a passing full-suite run is recorded by tree
hash so nothing pays for it twice.

<!-- -->

> **✎ Notes** · `PLAN › Architecture overview`
> _(your notes here — replace this line)_

### Data flow

```text
push → CI + bots act on PR
        ↓
review_sources.py --pr N [--trigger]   (reads checks, reviews, bot comments; posts one trigger if needed)
        ↓ decision line
caller: none → merge path | diff/full → adversarial_review.sh emit (budget line) → reviewer → verdict
        ↓
merge precondition: CI green on head SHA, or a gate receipt for the tree
```

<!-- -->

> **✎ Notes** · `PLAN › Data flow`
> _(your notes here — replace this line)_

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| `adversarial_review.sh` | `tmp/arsenal-review/<branch>/round.env` | UPDATE | Counter keyed to branch, not base |
| `review_sources.py` | `tmp/arsenal-review/pr-<N>/trigger-<bot>` | CREATE | One trigger per head per bot |
| `fast_gate.sh`, `open_task_pr.sh` | `tmp/arsenal-gate/receipts/<tree>` | CREATE | Passing full-gate receipt |
| config | `arsenal/config.toml` | UPDATE | New keys, defaults (spec § 5) |

<!-- -->

> **✎ Notes** · `PLAN › State changes`
> _(your notes here — replace this line)_

### Technology choices

| Choice | Justification |
|--------|--------------|
| Python for `review_sources.py`, sharing a module with `query_pr_state.py` | Both already parse `gh` JSON; one classifier, one place for notice regexes |
| Files under `tmp/` for state | Same convention as the existing review state; nothing new to clean up |

<!-- -->

> **✎ Notes** · `PLAN › Technology choices`
> _(your notes here — replace this line)_

### Out of scope

Prompt rewrites (workstream P), `model-upgrade` mode (U), task labels, setup
interview — later PRs. No change to `merge-policy` semantics.

<!-- -->

> **✎ Notes** · `PLAN › Out of scope`
> _(your notes here — replace this line)_

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | New config keys, validators, `CONSUMER` entries; `review-max-rounds` default 2 | `arsenal_config.py` | S | — | `failed_tests == 0` | `test_config_verification_invalid_value_exits_2` in `plugins/core/tests/arsenal_config_test.sh` — `verification = "loose"` is refused with exit 2 |
| T2 | Round counter keyed to branch; `--reset` | `adversarial_review.sh` | S | T1 | `failed_tests == 0` | `test_round_counter_after_base_move_keeps_counting` in `plugins/core/tests/adversarial_review_test.sh` — after a base change the next emit is round 2, and round 3 is refused at max 2 |
| T3 | Budget line in packet; reviewer runs targeted tests only unless `strict` | `adversarial_review.sh`, `agents/reviewer.md` | S | T1 | `failed_tests == 0` | `test_packet_includes_budget_line` in `plugins/core/tests/adversarial_review_test.sh` — packet contains `Budget: round 1 of 2 · 10 min · profile balanced` |
| T4 | `review_sources.py`: classifier, `decide()`, CLI, `--trigger` once | new script | M | T1 | `failed_tests == 0` | `test_classify_skip_notice_returns_skipped`, `test_classify_rate_limit_returns_rate_limited`, `test_classify_silence_past_wait_returns_absent`, `test_decide_ci_ok_bot_ok_low_risk_returns_none`, `test_trigger_posts_once_per_head` in `plugins/core/tests/review_sources_test.sh` — each fixture yields the stated state/decision |
| T5 | `query_pr_state.py` uses the shared classifier; new bot states; wait bounded | `github/scripts/query_pr_state.py`, `pr-review-loop.md` | M | T4 | `failed_tests == 0` | `test_silent_bot_after_wait_is_not_waiting` in `plugins/core/tests/review_sources_test.sh` — a bot silent past `bot-wait-min` + trigger reports `bot_absent`, not `waiting` |
| T6 | Gate receipt by tree hash; reuse in `fast_gate --full` and `open_task_pr`; CI-green-on-head counts at merge | `fast_gate.sh`, `open_task_pr.sh`, `orchestrator-tick.md` | M | T1 | `failed_tests == 0` | `test_full_gate_twice_same_tree_runs_once` and `test_receipt_ignored_after_edit` in `plugins/core/tests/fast_gate_test.sh` — second run prints `reused`; after an edit the gate runs again |
| T7 | One review protocol in `pre-pr-review.md` driven by the decision line; `execution`, `github`, `ship`, `worker.md` point to it; ship reviews only if commits landed after the last review | references + 4 prompts | M | T4, T6 | `review_snippet_homes == 1` | `test_review_protocol_has_one_home` in `plugins/core/tests/bundle_refs_test.sh` — the emit/spawn/verdict snippet appears in exactly one file |
| T8 | Incident-replay fixture; CHANGELOG `4.26.0`; `.bundle-version`; `make sync-version` | tests, release files | S | T2–T7 | `failed_tests == 0` | `test_incident_replay_bounded` in `plugins/core/tests/review_sources_test.sh` — 3 base moves + silent bot + no preflight gate → rounds ≤ 2, bot wait ends, full gate runs once per tree |

Every `skills/` edit runs with `skill-workshop` loaded; `make check` is the gate before the PR.

<!-- -->

> **✎ Notes** · `PLAN › Implementation tasks`
> _(your notes here — replace this line)_

## Evidence log

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | `failed_tests == 0` | 0 | `bash plugins/core/tests/arsenal_config_test.sh` | PR #476 head | local | 2026-10-01 |
| T2 | `failed_tests == 0` | 0 | `bash plugins/core/tests/adversarial_review_test.sh` | PR #476 head | local | 2026-10-01 |
| T3 | `failed_tests == 0` | 0 | `bash plugins/core/tests/adversarial_review_test.sh` | PR #476 head | local | 2026-10-01 |
| T4 | `failed_tests == 0` | 0 | `bash plugins/core/tests/review_sources_test.sh` | PR #476 head | local | 2026-10-01 |
| T5 | `failed_tests == 0` | 0 | `bash plugins/core/tests/review_sources_test.sh` | PR #476 head | local | 2026-10-01 |
| T6 | `failed_tests == 0` | 0 | `bash plugins/core/tests/fast_gate_test.sh` | PR #476 head | local | 2026-10-01 |
| T7 | `review_snippet_homes == 1` | 1 | `bash plugins/core/tests/bundle_refs_test.sh` | PR #476 head | local | 2026-10-01 |
| T8 | `failed_tests == 0` | 0 | `make test` | PR #476 head | local | 2026-10-01 |

<!-- -->

> **✎ Notes** · `PLAN › Evidence log`
> _(your notes here — replace this line)_

### Dependency graph

```text
T1 ──┬─> T2 ──────────────┐
     ├─> T3 ──────────────┤
     ├─> T4 ──┬─> T5 ─────┼─> T8
     │        └─> T7 ─────┤
     └─> T6 ──────┘       │
```

<!-- -->

> **✎ Notes** · `PLAN › Dependency graph`
> _(your notes here — replace this line)_

## Sign-off

- [x] Plan reviewed by maintainer
- [x] Ready for execution

T8 note: the incident replay is covered by three tests rather than one fixture — rounds across two base moves (`adversarial_review_test.sh`), bot wait ending (`review_sources_test.sh`), one full gate per tree (`fast_gate_test.sh`).

<!-- -->

> **✎ Notes** · `PLAN › Sign-off`
> _(your notes here — replace this line)_

