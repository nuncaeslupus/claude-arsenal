---
id: t-ee7abac7
title: "pypi-release: verify the install, not the checkout"
label: "pypi-release: verify step"
priority: 10
tags: [skills]
---

The description promises a version-bump step that the body never gives. The verify import at
`:59` and `:73` runs from the project root, so `import PKG` resolves to the local checkout
instead of the installed wheel. Run it from a temporary directory, for example with
`--directory "$(mktemp -d)"`.

Found by the semantic skill-workshop walk over all skills (2026-11-09).

## Acceptance gate

```bash
set -e
grep -qiE 'mktemp|--directory|cd /tmp' plugins/core/skills/pypi-release/SKILL.md
python3 plugins/skill-workshop/skills/skill-workshop/scripts/validate.py plugins/core/skills/pypi-release
```
