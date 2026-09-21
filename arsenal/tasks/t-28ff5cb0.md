---
id: t-28ff5cb0
title: "_resolve_sections never adds a newly shipped section to an existing config"
priority: 10
tags: [vendoring]
---

_resolve_sections returns early when a [skills] table is already recorded
(init.py:885-889), bypassing the _write_sections_table call at :914.

Failure scenario: a consumer's arsenal/config.toml was written under an older
bundle. Upstream then ships a new section. Every later silent init.py run
computes it as disabled correctly, but never appends `<section> = false` to the
file. So the section stays permanently invisible in the very file consumers are
told to edit, unless they happen to pass --sections or --profile explicitly.

This contradicts _write_sections_table's own stated purpose: "a consumer opting
a section back in should find the line already there to flip."

Done means: a section shipped after a consumer's config was written appears in
that config on the next run, defaulted off.


## Acceptance gate

<!-- Replace this with a fenced bash block. A gate that is only prose runs
     nothing, and a gate that runs nothing passes everything — `task_select.py`
     reports gate: false for a task with no block, so an unenforced gate is
     visible rather than quietly inert. -->

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
# e.g. bash tests/surface_probe_test.sh
false
```
