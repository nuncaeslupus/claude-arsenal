# Overnight audit — budgeted, chunked, honest about what it covered

Load this when the user asks for an unattended audit ("audit it overnight", "run
a review while I sleep"), or for any audit too big to finish in one sitting. It is
the normal audit (SKILL.md steps 1–5), run in chunks inside a budget the user set.

## 1. Price it, then ask — before anything runs

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_estimate.py" <scope paths>    # default: the whole repo
```

Ask the user in one message:

- **Scope.** Paths, or the whole repo.
- **Token ceiling** for the run.
- **Where to stop.** At the ceiling, or at the session's budget stop
  (the vendored bundle's `budget_check.sh`, when the claude-arsenal bundle is
  installed), whichever comes first.

Show the estimate line beside the questions, and say plainly when it exceeds the
ceiling: "this scope is ≈ 1.2M tokens; with a 500k ceiling about 40% gets covered,
riskiest first". The estimate uses a starting value of 12 tokens per line. Nothing
starts until the user has answered. A run nobody priced is how a night's quota
disappears.

## 2. Run one subsystem at a time, riskiest first

Order the subsystems from the estimate's split: paths matching `risk-paths` (in
`arsenal/config.toml`) first, then the largest. Before each chunk, run the
bundle's `budget_check.sh` when it is installed (non-zero: stop now).

Also stop when the tokens spent so far, plus the next chunk's estimate, would pass
the ceiling. A chunk is the whole audit procedure for that subsystem, from
understanding through hunting to ledger rows. A finished chunk is reportable even
if the night ends right after it.

## 3. Stop cleanly, and never edit code

- Findings go through the normal ledger → queue steps (SKILL.md 4–5). The same
  run never fixes code: the maintainer decides what merges.
- Write the ledger with what was left out:

  ```json
  {"findings": [ ...the validated ledger rows... ],
   "not_covered": ["src/legacy", "tools"]}
  ```

  Validate `findings` with `validate_findings.py` before wrapping it.
- A stopped run reports the subsystems it did not cover. It never calls itself a
  whole-repo audit.

## 4. Hand it over in the morning digest

When the host has the review digest, add the ledger as a card above the night's PRs:

`digest.py render --audit <ledger.json>` (`claude-arsenal:core:init § references/digest.md`).

The card shows findings by severity × confidence, the top high-severity ones, how
many were queued, and what was not covered. Without the digest, put the same
lines in the session's closing message.
