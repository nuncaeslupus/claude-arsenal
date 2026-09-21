---
id: t-cbbe1bed
title: "Resident context budget has 37 tokens of headroom against a CI-enforced cap"
priority: 10
tags: [context-budget]
---

`make context-budget` reports the widest install at 4963 of 5000 resident
tokens — 37 tokens, under 1% headroom, on a cap CI hard-fails over. The next
skill added, or roughly ten more words in any one description, breaks the build
for whoever happens to touch it next.

Largest contributors in the listing: session-end 123, repo-audit 120,
coverage-gaps 117, dep-upgrade 107, gate-check 103.

CLAUDE.md is explicit that the answer is never to raise the cap — what grew
moves behind a reference or into a script. That makes this a real piece of work
rather than a config change.

Done means: meaningful headroom is restored by shortening descriptions or moving
content out of the resident tier, with the cap untouched.


## Acceptance gate

```bash
# Restore real headroom, without raising the cap.
out=$(make context-budget 2>&1) || { echo "$out" >&2; exit 1; }
head=$(echo "$out" | sed -n 's/.*(\([0-9]*\) headroom).*/\1/p' | tail -1)
[ -n "$head" ] || { echo "could not read headroom from make context-budget" >&2; exit 1; }
[ "$head" -ge 250 ] || { echo "headroom is only $head tokens" >&2; exit 1; }
```
