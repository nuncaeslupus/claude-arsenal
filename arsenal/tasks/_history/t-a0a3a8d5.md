---
id: t-a0a3a8d5
title: "Six config.toml keys are validated and documented but nothing reads them"
priority: 5
tags: [config, api-design]
status: merged
---

arsenal_config.py scaffolds and validates keys that no consumer reads. A full
cross-reference of DEFAULTS against every --get call site and every direct
reader found six dead:

  test-discipline  execution reads only the CLAUDE.md marker
  session-end      create_handoff.py reads only the CLAUDE.md marker, and with
                   different vocabulary (handoff=yes|ticket|no vs handoff/ticket/none)
  home             cannot be read from the file that locates the file; ARSENAL_HOME
                   env is the only real channel
  import-label     issue_import.py hardcodes "arsenal:queue" (:64)
  task-label       queue_hooks.py hardcodes TASK_LABEL = "arsenal:task" (:68)
  claim-prefix     queue_hooks.py:71 / claim_task.sh:52 read ARSENAL_CLAIM_PREFIX env

Each one validates, round-trips through --explain, and changes nothing. The
worst is import-label: AGENTS.md:86-89 — resident in every session — documents
it as configurable, so a consumer who sets it silently imports nothing.

Done means: every key in DEFAULTS is either wired to its consumer or removed,
and a check exists that a key cannot be added without a reader.


## Acceptance gate

```bash
# Every key names the file that reads it, the three that were dead now
# change what runs, and a key the file cannot set is refused.
bash plugins/core/tests/config_keys_test.sh
```
