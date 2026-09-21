---
id: t-389fbab4
title: "Issue-payload hardening never reached handle_sync.py and issue_import.py"
priority: 10
tags: [robustness]
status: merged
---

query_status.py:190-196 and task_select.py were hardened against a truncated
GitHub issue fetch after a real incident — their comments describe it exactly:
"a truncated {\"issues\": null} raised TypeError... the operator sees a
traceback instead of the one sentence". handle_sync.py:187-197 and
issue_import.py:253-255 read the identical payload and never got the fix.

Reproduced on the same input:

  handle_sync.py   -> TypeError: 'NoneType' object is not iterable     exit 1
  query_status.py  -> "not an issue list — expected a JSON array, or an
                       object with an 'issues' array"                  exit 2

Both scripts document exit 2 for unreadable input; both deliver a raw traceback
and exit 1 instead.

This is the third instance of one pattern in this audit: a fix lands in one copy
of a shape and not its siblings, and nothing detects the gap. The others are the
fail-open hook (t-d2ee8e49) and validate.py's partial reserved-word list.

Done means: both scripts reject a non-list payload the way their siblings do.


## Acceptance gate

```bash
# Every reader of a `gh issue list --json` payload rejects a wrong-shaped
# one with the documented exit 2, and there is only one such reader.
bash plugins/core/tests/issue_payload_test.sh
```
