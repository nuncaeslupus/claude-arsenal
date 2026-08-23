---
date: 2026-08-24
trigger: unexpected-tool-behavior
skill: claude-arsenal:core:github
severity: low
---

**Signal:** `gh pr checks <n>` reported `CodeRabbit  pass  Review completed` on
four PRs in one session that each carried between one and four actionable
inline review comments. Two of those findings were real defects — an entry
violating its own file's format rule, and a merge instruction that told a
session to merge under two policy values that forbid it. Merging on the rollup
would have shipped both.

**Proposal:** one line in `references/pr-review-loop.md` saying a bot's
check-run conclusion is not its finding list, and that the comments endpoint is
the authority.

**Caveat, stated because it bounds the value:** the skill's own loop already
avoids this. `query_pr_state.py` fetches line comments directly and never
consults the check rollup, so a session running the documented loop cannot be
fooled. The trap only bites a session that checks PR status ad hoc with
`gh pr checks` — which is what happened here. This is a guard for the off-path
case, not a defect in the designed path, and it is proposed at low severity for
that reason.

**Affected files:**
`plugins/core/skills/github/references/pr-review-loop.md`.
---
