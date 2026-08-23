---
date: 2026-08-24
trigger: unexpected-tool-behavior
skill: claude-arsenal:core:session-end
severity: medium
---

**Signal:** `query_session_history.py --days 7` reported five
`user_corrections` this run and four were false positives. Two matched the
phrase "goes wrong" inside a SKILL.md body — `skill-workshop` and the older
`skill-creator`, whose `## Gotchas` sections open "Each entry says *what* goes
wrong AND *why*". A skill loaded through the Skill tool arrives as a user-role
message, so the detector reads the skill's own prose as if the user had typed
it. A third matched assistant text quoted back inside `prev_assistant`. One
entry was a genuine correction.

**Proposal:** filter injected content before phrase-matching. A user-role
message that begins with `Base directory for this skill:` is a Skill-tool
injection, and tool results are not user prose; neither should be scanned. The
cost of not filtering is not a noisy report — it is that the one real
correction sat fourth in a list of five, which is how a retrospective stops
being read.

**Affected files:**
`plugins/core/skills/session-end/scripts/query_session_history.py` (exclude
injected turns from the correction scan),
`plugins/core/skills/session-end/references/retrospective-rubric.md` (say what
counts as a user turn).
---
