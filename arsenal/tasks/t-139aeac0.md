---
id: t-139aeac0
title: "review: INSTALL understates prerequisites: python3, gh/GitHub access and uv are needed in practice"
priority: 5
requires: [human:gate]
---

Imported from issue #602

**Severity:** medium · **Confidence:** high · **Category:** docs

**Where:** `docs/INSTALL.md:27-37, plugins/core/skills/init/assets/AGENTS.md:42-75, plugins/core/skills/specify/SKILL.md:118, plugins/core/skills/design/SKILL.md:97, plugins/core/skills/init/assets/scripts/render_diagrams.py:63-72`

### Finding
Prerequisites say Python is for 'scripts shipped under skill-workshop/scripts' and that consumers 'only need Claude Code and git', with uv optional. The session protocol runs `python3 .claude/skills/init/scripts/init.py` and five other Python scripts every session, the reader step in specify/design requires `uv run --with markdown` (PyPI access), diagrams need `uvx drawspec`, har capture needs `uv run --with playwright`, and the queue needs a GitHub channel. A consumer on python 3.10 without uv hits failures mid-workflow.

### Evidence
pyproject.toml requires-python >=3.12 and ci.yml:124-127 says shipped scripts need that floor; create_reader_test.sh:16-18 states `markdown` is not a dependency.

### Suggested direction
State the real floor (python3 >= 3.12 on PATH, gh or GitHub tools, uv for reader/diagrams) and have init check them up front.

_From the full repo review of 2026-11-11 (finding #18). Not fixed yet; verify before acting._

## Acceptance gate

<!-- This task came from an issue, so its "gate" is prose. Write a real check
     below, then DELETE the `requires: [human:gate]` line in the front matter.
     Until that line is gone the selector will not offer this task, which is
     deliberate: a prose gate runs nothing, and a gate that runs nothing passes
     everything. -->

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
false
```
