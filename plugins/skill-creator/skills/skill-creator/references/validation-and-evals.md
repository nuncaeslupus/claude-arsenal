# Validation and evals

## Contents

- [The validator's check list](#the-validators-check-list)
- [Severity policy](#severity-policy)
- [Evals format](#evals-format)
- [Loading verification — canary + negative control](#loading-verification--canary--negative-control)
- [The audit report](#the-audit-report)
- [Smoke tests](#smoke-tests)

Load when extending the validator, writing a new eval, or interpreting
an audit report.

## The validator's check list

`validate.py <skill_dir>` runs the checks below. Single-skill checks
fire on every run; library-level checks (cosine, listing budget,
duplicate-group drift) are deferred to `audit_library.py`.

| # | Check | Severity |
|---|---|---|
| 1 | Frontmatter shape — required keys, allow-list, length limits, no `<>` | fail |
| 2 | File / folder shape — `SKILL.md` only, kebab-case folder = `name`, single-depth | fail |
| 3 | Description trigger — at least one trigger phrase, third person | warn |
| 4 | Description-overlap (cosine) — pairwise across siblings | warn ≥0.85, fail ≥0.95 *(library-level)* |
| 5 | Body — ≤500 lines fail, ≤400 warn; balanced fences; no `README/AGENTS.md` | mixed |
| 6 | References — ToC for >100 lines; linked from SKILL with trigger; one-hop only | fail |
| 7 | Cross-skill safety — no markdown link or path matching peer-skill SKILL or scripts | fail |
| 8 | Path safety — no `..` in any link from SKILL or its references | fail |
| 9 | Scripts referenced exist — under `<skill>/scripts/` or whitelisted Docker path | fail |
| 10 | Script CLI conventions — argparse, allow-list args, forbidden synonyms, `main()` + guard | mixed |
| 11 | Duplication header — declares siblings; SHA mismatch warns *(library-level)* | warn |
| 12 | Taxonomy — capability ⇒ owns ≥1 script; workflow ⇒ owns 0 | warn |
| 13 | Evals — `loading_verification.json` with canary + negative control | fail |

## Severity policy

- `fail` ⇒ exit code 1; the skill cannot be merged.
- `warn` ⇒ exit code 0 but flagged in output; the agent must see it.
- `--severity warn` promotes warnings to failures (use in CI when
  the team is ready to block on a warning).

## Evals format

Every skill ships `evals/loading_verification.json`. Optional extra
evals (capability-specific) live alongside as `evals/<topic>.json`.

```json
{
  "skill": "<skill-name>",
  "canary": "<unique phrase that appears in SKILL.md>",
  "negative_control": "<a fact NOT in SKILL.md, used to detect hallucination>",
  "load_prompts": [
    "<a real user prompt that should activate this skill>"
  ],
  "no_load_prompts": [
    "<a real user prompt that should NOT activate this skill>"
  ]
}
```

The eval is consumed today by:

- `audit_library.py` — cross-checks canary uniqueness across the library.
- Reviewers and skill-creator's "review this skill" conversational path —
  read load_prompts and no_load_prompts to judge routing.

A future extension of `.claude/skills/skill-creator/tests/skills_smoke.sh`
will run live-session probes:

1. Issue a load_prompt to a fresh Claude Code session and assert the
   canary phrase is in the response (skill loaded).
2. Issue a no_load_prompt and assert the canary is **absent**
   (no false-positive trigger).
3. Rename the skill folder, repeat step 1, and assert the canary
   is now absent (negative control — guards against the model having
   memorised the canary from another source).

## Loading verification — canary + negative control

The canary phrase must:

- Appear verbatim **once** in `SKILL.md`.
- Be unique across the library — `audit_library.py` cross-checks.
- Not appear in the description (it must be earned by loading the
  body).
- Be machine-grep-friendly (no special regex chars).

The negative control is a deliberately false fact. If the model
"recalls" it without loading the body, the eval flags hallucination.

## The audit report

`audit_library.py` walks every skill and emits:

- Per-skill `validate.py` exit code summary.
- Description-overlap matrix (cosine ≥0.5 surfaced; ≥0.85 warns; ≥0.95
  fails).
- Listing-budget total in characters with per-skill breakdown.
  Hard ceiling ~8,000 chars (Claude Code listing budget).
- Duplicate-group SHA-status report — for each group of duplicated
  scripts, file SHAs and drift state.
- Aggregate exit code: `0` if all per-skill validates pass and no
  library-level fails; `1` otherwise; `2` on internal error.

## Smoke tests

`.claude/skills/skill-creator/tests/skills_smoke.sh` runs the
mechanical pieces today: per-library `audit_library.py` (which
invokes `validate.py` per skill plus library-level checks). The
scripted Claude Code probes described above are a planned
extension. The cross-library aggregate-budget check is owned by
ship and is invoked separately, not by this harness.
