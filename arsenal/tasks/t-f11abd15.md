---
id: t-f11abd15
title: "Skill-edit gate is bypassed by a doubled slash or an unmodelled write tool"
priority: 5
tags: [security, hooks]
---

gate_target.py decides what a Bash command writes so the PreToolUse hook can
refuse edits inside a skill folder. Two independent bypasses, both reproduced
against the real module:

  cp … plugins/core/skills/init/SKILL.md    -> target: plugins/core/skills/init/SKILL.md  (blocked)
  cp … plugins//core/skills/init/SKILL.md   -> target: ""  (ALLOWED)
  cp … plugins/core/./skills/init/SKILL.md  -> target: ""  (ALLOWED)
  rsync … plugins/core/skills/init/SKILL.md -> target: ""  (ALLOWED)
  curl -o plugins/core/skills/init/SKILL.md -> target: ""  (ALLOWED)

1. SKILL_PATH/EMBEDDED_PATH (gate_target.py:46,52-54) match a canonical path
   form only, so any path-equivalent spelling — `//`, `/./`, `..` — is invisible
   even for a utility the file otherwise models correctly.
2. Write detection is a 13-name UTILITIES allowlist plus a Python/JS-shaped
   WRITERS denylist (:65-80, :91-101). rsync, curl -o, wget -O, tar -x, xargs,
   install, and anything else write-capable is treated as opaque.

This is a guardrail against a session casually reaching for a write, not a
sandbox boundary — so what matters is that these are ACCIDENTAL shapes. A
doubled slash falls out of naive path joining, and rsync/curl are tools a
session would reach for on its own.

Done means: normalise the destination before matching, and decide a posture for
an unmodelled command head — either widen coverage or return a sentinel that
makes the hook refuse rather than allow. Whichever is chosen, an unrecognised
write must not read as "nothing to gate".


## Acceptance gate

```bash
# Every one of these writes a real skill file; the gate must name a target for each.
G=plugins/skill-workshop/hooks/gate_target.py
for cmd in \
  "cp /tmp/x plugins//core/skills/init/SKILL.md" \
  "cp /tmp/x plugins/core/./skills/init/SKILL.md" \
  "rsync /tmp/x plugins/core/skills/init/SKILL.md" \
  "curl -o plugins/core/skills/init/SKILL.md http://x" ; do
  out=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"session_id":"t"}' "$cmd" | python3 "$G")
  [ -n "$out" ] || { echo "gate blind to: $cmd" >&2; exit 1; }
done
```
