---
id: t-d2ee8e49
title: "Sync check_skill_workshop_loaded.sh \u2014 the two copies have drifted"
priority: 10
tags: [tooling, hooks]
---

sync_duplicates.py --check's secondary .sh scan (repo-wide, unaffected by --library) currently reports real drift between the two shipped copies of check_skill_workshop_loaded.sh:

  plugins/core/skills/init/assets/bin/check_skill_workshop_loaded.sh   sha256[:12]=47147248cf5e
  plugins/skill-workshop/hooks/check_skill_workshop_loaded.sh          sha256[:12]=6ccd3d7c38eb

Pre-existing, unrelated to PR #396. The skill-workshop/hooks/ copy is the one the hook actually runs from in this repo; core/skills/init/assets/bin/ is the vendored copy /init installs into consumer repos, the same split documented for gate_target.py and detect_surface.sh in pyproject.toml's [tool.mypy] comment.

Suggested direction: diff the two files, confirm skill-workshop/hooks/ is canonical, and sync the vendored copy — by hand or via sync_duplicates.py --apply <canonical-path>.


## Acceptance gate

```bash
diff -q plugins/core/skills/init/assets/bin/check_skill_workshop_loaded.sh \
        plugins/skill-workshop/hooks/check_skill_workshop_loaded.sh
```
