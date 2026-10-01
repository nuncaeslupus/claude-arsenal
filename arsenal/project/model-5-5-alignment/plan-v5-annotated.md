# Arsenal 5.0.0 — Specification (annotated edition)

> Generated 2026-10-01. This is the document with a **note slot** after every section. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# Plan V5

## Preamble & scope

**Date**: 2026-10-01
**Specification**: `arsenal/project/model-5-5-alignment/spec.md` (revision 2, approved)
**Author**: imarcos@gmail.com
**Revision**: 1
**Status**: approved (2026-10-01, revision 1) — without annotations
**Revision log**:
- r1 — first draft

> Review record as in `plan.md`. Approval is `approved (YYYY-MM-DD, revision N)`.

<!-- -->

> **✎ Notes** · `SPEC · intro`
> _(your notes here — replace this line)_

## Technical solution



<!-- -->

> **✎ Notes** · `SPEC › Technical solution`
> _(your notes here — replace this line)_

### Architecture overview

Rules first, then text. The G-rules become a shipped reference and scanner checks
(warnings), so every rewrite after that is checked by them; the last rewrite task
flips the checks to errors. The rewrite goes from the most expensive tier down:
resident (`AGENTS.md`, descriptions), then dispatched agents, then skill bodies and
references. The upgrade path (`model-upgrade` mode, research addendum, `MODELS.md`)
and the setup interview come last, because they describe the finished state.
One branch, one PR, one commit per task; only T11 bumps the version.

<!-- -->

> **✎ Notes** · `SPEC › Architecture overview`
> _(your notes here — replace this line)_

### Data flow

```text
model-prompting.md (G-rules) ──> validate.py style checks ──> every skills/ edit
                                         │
T4–T9 rewrites ──────────────────────────┘ (warnings → errors in T9)
/init interview ──> arsenal/config.toml (autonomy, verification, effort) ──> AGENTS.md / skills
```

<!-- -->

> **✎ Notes** · `SPEC › Data flow`
> _(your notes here — replace this line)_

### State changes

| Service | Database | Change | Description |
|---------|----------|--------|-------------|
| config | `arsenal/config.toml` | UPDATE | `autonomy` key; interview writes existing V keys |
| task files | `arsenal/tasks/*.md` | UPDATE | optional `label:` front-matter field |
| hooks | `tmp/arsenal-metrics/skill-loads.tsv` | CREATE | one row per skill load (canary hook) |

<!-- -->

> **✎ Notes** · `SPEC › State changes`
> _(your notes here — replace this line)_

### Technology choices

| Choice | Justification |
|--------|--------------|
| Regex table in `validate.py` | Same mechanism as today's content checks; one row per rule |
| `effort:` skill frontmatter | Documented Claude Code field; the session itself cannot change effort |

<!-- -->

> **✎ Notes** · `SPEC › Technology choices`
> _(your notes here — replace this line)_

### Out of scope

Harness items from Option C that need fleet measurement (time-budget lines in the
orchestrator, progress reminders); #477 reader fixes; any runtime model check.

<!-- -->

> **✎ Notes** · `SPEC › Out of scope`
> _(your notes here — replace this line)_

## Implementation tasks

| T# | Description | Service | Size | Depends | Gate | Tests |
|----|-------------|---------|------|---------|------|-------|
| T1 | `skill-workshop/references/model-prompting.md` (G1–G21, source links, load-when trigger); `docs/research/addendum-2026-10.md`; `audit_rule_drift.py` reads v1.17 + addenda | skill-workshop, docs | M | — | `failed_tests == 0` | `test_rule_drift_reads_addendum` in `plugins/skill-workshop/tests/test_rule_drift.py` — a rule ID only in the addendum is not reported as drift |
| T2 | Scanner: content loops → one `(slug, regex, msg)` table; `R-STYLE-1…8` + `content.ref-unconditional` as warnings; `skill-workshop` exemption narrowed to rule-ID/date detectors; rubric rows (R-STYLE, Q-REV-1/2, Q-SCOPE-1; reworded Q-PROC-1, Q-PROSE-1, R-XPOLL-6, R-CONDUCT-4, R-LLMJ-5) with research-coverage entries | `validate.py`, rubric | L | T1 | `failed_tests == 0` | `test_style_double_check_warns`, `test_style_caps_density_warns`, `test_ref_unconditional_warns`, `test_style_model_name_warns` in `plugins/skill-workshop/tests/test_style_rules.py` — each fixture SKILL.md yields exactly its warning |
| T3 | Skill-load hook: `PostToolUse` matcher `Skill` appends to `tmp/arsenal-metrics/skill-loads.tsv`; canaries kept | core hooks | S | — | `failed_tests == 0` | `test_skill_load_hook_records_row` in `plugins/core/tests/skill_load_hook_test.sh` — a Skill tool payload adds one row with the skill name |
| T4 | `AGENTS.md` rewrite: history and rationale out, pointers in; G4/G8/G13/G14 and task-label lines; 20 descriptions shortened (`Not for X`) | resident tier | L | T2 | `resident_tokens_minimal <= 3600` | `make context-budget` (minimal row) and `bundle_refs_test.sh` (AGENTS.md ≤ 250 lines) |
| T5 | Task labels: `label:` in task template and `queue-add`; `query_status.py` / `task_select.py` print `<label> (t-id)`, falling back to a truncated title | queue scripts | M | — | `failed_tests == 0` | `test_status_prints_label_before_id` in `plugins/core/tests/query_status_report_test.sh` — a task with `label: tag only green CI` prints `tag only green CI (t-…)` |
| T6 | Agents: `worker.md` (finish-the-task + scope rules, dedupe model/stash text to `worker-loop § Credit guards`), `reviewer.md` follow-up section → packet, model script removed | agents | M | T2 | `reviewer_chars <= 8520` | `bundle_refs_test.sh` plus `adversarial_review_test.sh` still green |
| T7 | `repo-audit`: fan-out sized to repo, no mandatory re-verify, no model menu, findings with severity + confidence | repo-audit | M | T2 | `failed_tests == 0` | validator clean on `plugins/repo-audit/skills` (0 fails, 0 style warnings) |
| T8 | Core skill bodies: calm phrasing; `har` grammar, `queue-next` claim gotchas, `github` stacking (made generic) → references; `init` script narration → one line; `execution` scope/finish lines; `effort:` frontmatter where it pays; references read on every invocation inlined | core skills | L | T2 | `on_invocation_tokens_sum <= 0.80 * baseline` | `make context-budget` (baseline recorded in the evidence log before T8) |
| T9 | `skill-workshop` body halved; `evidence-gates.md` / long references trimmed into `performance-tuning.md`; style checks flipped to errors | skill-workshop, references | L | T4, T6–T8 | `style_warnings == 0` | `make validate` exits 0 with style checks as errors; CAPS count ≤ 15 (grep in `bundle_refs_test.sh`) |
| T10 | Upgrade path + interview: `model-upgrade` mode (`references/model-upgrade.md` + SKILL.md section, this run as worked example); `docs/MODELS.md`; `/init` interview writing `autonomy`, `verification`, `review-budget-min`, `bot-wait-min`, `bot-triggers` (suggested from detected bots); `autonomy` read by `AGENTS.md` | skill-workshop, init | L | T9 | `failed_tests == 0` | `test_init_interview_skipped_writes_defaults` and `test_init_interview_answers_written` in `plugins/core/tests/init_test.sh` — skipping writes no override; answers land in config.toml |
| T11 | CHANGELOG `5.0.0` (breaking: review rounds, removed prose consumers relied on, new keys); `make bump LEVEL=major`; `make sync-version`; all checks | release | S | T1–T10 | `failed_tests == 0` | `make lint smoke test test-units sync-version-check context-budget audit-rule-drift queue-doctor` |

Every `skills/` edit is validated with the skill-workshop validator; T8/T9 record
token numbers before and after in the evidence log.

<!-- -->

> **✎ Notes** · `SPEC › Implementation tasks`
> _(your notes here — replace this line)_

## Evidence log

| T# | Gate | Measured | Command | SHA | Env | Date |
|----|------|----------|---------|-----|-----|------|
| T1 | `failed_tests == 0` | 0 | `uv run pytest plugins/skill-workshop` | PR head | local | 2026-10-01 |
| T2 | `failed_tests == 0` | 0 | `uv run pytest plugins/skill-workshop` | PR head | local | 2026-10-01 |
| T3 | `failed_tests == 0` | 0 | `bash plugins/core/tests/skill_load_hook_test.sh` | PR head | local | 2026-10-01 |
| T4 | `resident_tokens_minimal <= 3600` | 2765 (from 4162; AGENTS.md 3745 → 2408) | `make context-budget` | PR head | local | 2026-10-01 |
| T5 | `failed_tests == 0` | 0 | `bash plugins/core/tests/query_status_report_test.sh` | PR head | local | 2026-10-01 |
| T6 | `reviewer_chars <= 8520` | 5496 (from 10862) | `wc -c agents/reviewer.md` | PR head | local | 2026-10-01 |
| T7 | `failed_tests == 0` | 0 | `make smoke` | PR head | local | 2026-10-01 |
| T8 | `on_invocation_tokens_sum <= 0.80 * baseline` | 22876 vs baseline 38086 (0.60) | `context_budget.approx_tokens` over every SKILL.md | PR head | local | 2026-10-01 |
| T9 | `style_warnings == 0` | 0 (style checks are errors) | `make smoke` | PR head | local | 2026-10-01 |
| T10 | `failed_tests == 0` | 0 | `bash plugins/core/tests/init_test.sh` | PR head | local | 2026-10-01 |
| T11 | `failed_tests == 0` | 0 | `make lint smoke test test-units sync-version-check sync-sections-check sync-dupes context-budget audit-rule-drift queue-doctor` | PR head | local | 2026-10-01 |

<!-- -->

> **✎ Notes** · `SPEC › Evidence log`
> _(your notes here — replace this line)_

### Dependency graph

```text
T1 ─> T2 ─┬─> T4 ──────────┐
          ├─> T6 ──────────┤
          ├─> T7 ──────────┼─> T9 ─> T10 ─> T11
          └─> T8 ──────────┘
T3, T5 (independent) ─────────────────────> T11
```

<!-- -->

> **✎ Notes** · `SPEC › Dependency graph`
> _(your notes here — replace this line)_

## Sign-off

- [x] Plan reviewed by maintainer
- [x] Ready for execution

<!-- -->

> **✎ Notes** · `SPEC › Sign-off`
> _(your notes here — replace this line)_

