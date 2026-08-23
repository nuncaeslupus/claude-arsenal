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

---
date: 2026-08-24
trigger: wrong-primitive
skill: claude-arsenal:core:session-end
severity: high
---

**Signal:** `references/auto-fire-setup.md` builds auto-fire on a `Stop` hook
and spends most of its length coping with the consequences — a
`CLAUDE_SESSION_END_AUTOFIRE` recursion guard, a one-shot skip sentinel, and a
fallback marker-file guard for harnesses that sanitize the hook environment.
All of that exists because `Stop` fires when the assistant finishes a response,
not when the session ends, so the naive form re-fires on every turn and
recurses through the sub-session it spawns.

The running build recognizes **`SessionEnd`** as a hook event in its own right:
`executeSessionEndHooks`, `getSessionEndHookTimeoutMs` and
`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` are all present, and the harness's own
error text lists it beside `Stop` — *"Common events: PreToolUse, PostToolUse,
UserPromptSubmit, SessionStart, SessionEnd, Stop."*

**Proposal:** rewrite auto-fire on `SessionEnd`. It fires once, at the moment
the doc is actually describing, which removes the reason the recursion guard
exists. Verify whether a spawned `claude --print` sub-session fires its own
`SessionEnd` before dropping the guard entirely — if it does, keep a guard but
say plainly that it covers the sub-session, not per-turn re-entry.

**Second, separable point.** The three steps do not share a cadence, and
bundling them behind one trigger is why two of them no-op. The retrospective
scans the last N days across sessions; firing it per session re-reads the same
transcripts and re-proposes the same findings. It wants a weekly schedule — a
routine, or a CI job — not a session hook. Only the handoff is genuinely
per-session, and the PR audit belongs wherever the queue already runs.

**Affected files:**
`plugins/core/skills/session-end/references/auto-fire-setup.md` (rewrite on
`SessionEnd`), `plugins/core/skills/session-end/SKILL.md` (the "Auto-fire
(opt-in)" section names the hook).
---
