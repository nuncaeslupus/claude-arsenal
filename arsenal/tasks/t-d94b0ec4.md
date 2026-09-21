---
id: t-d94b0ec4
title: "ARSENAL_HOME is documented as relocating the tree but four scripts ignore it"
priority: 10
tags: [config, queue]
---

arsenal_config.py documents ARSENAL_HOME as relocating the whole host-owned
tree, and init.py honours it. Four board readers do not: query_status.py:139,
task_select.py:561, handle_sync.py:177 and issue_import.py:229 each default
--tasks-dir to the literal Path("arsenal/tasks"). Every canonical invocation in
AGENTS.md:67,89 and worker-loop.md omits --tasks-dir, so the default is what runs.

Failure scenario: a consumer sets ARSENAL_HOME=host exactly as documented.
Session start runs normally and every board read reports zero tasks and zero
problems — indistinguishable from a legitimately empty backlog. Nothing errors,
nothing warns, and the queue silently does not exist.

Done means: the four scripts derive their default from the same resolution
init.py uses, or refuse to run when ARSENAL_HOME is set and they cannot honour it.


## Acceptance gate

```bash
# With ARSENAL_HOME set, the board must still be found.
set -e
T=$(mktemp -d); mkdir -p "$T/host/tasks"
cp arsenal/tasks/*.md "$T/host/tasks/" 2>/dev/null || true
n=$(cd "$T" && ARSENAL_HOME=host python3 "$OLDPWD/plugins/core/skills/init/assets/scripts/query_status.py" 2>&1 | grep -c '^tasks: 0' || true)
rm -rf "$T"
[ "$n" -eq 0 ] || { echo "ARSENAL_HOME ignored: board read as empty" >&2; exit 1; }
```
