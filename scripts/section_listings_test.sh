#!/usr/bin/env bash
# section_listings_test.sh — what /init installs and what the docs say match.
#
# `pin-check` declares `section: python` and sections.json agrees there are six
# python skills. Both prose listings — docs/INSTALL.md's profile table and
# init.py's scaffolded config comment — named five, and INSTALL.md's verify step
# told a consumer to expect 17 skill folders where `--profile python` produces
# 18. So the walkthrough taught the consumer that a correct install was wrong.
#
# Checked against sections.json rather than a hand-kept number, because a
# hand-kept number is what drifted.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - "${REPO_ROOT}" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
data = json.loads((root / "plugins/core/skills/init/assets/sections.json").read_text())
sections = {s["name"]: [k["name"] for k in s.get("skills", [])] for s in data["sections"]}

install = (root / "docs/INSTALL.md").read_text(encoding="utf-8")
init_py = (root / "plugins/core/skills/init/scripts/init.py").read_text(encoding="utf-8")

problems = []

# 1. Every listing names every skill its section ships. INSTALL.md's table is
#    keyed by PROFILE, so each section is checked against the row that adds it.
for section, profile in (("workflow", "general"), ("python", "python")):
    row = re.search(rf"^\| `{profile}` \|(.*)$", install, re.M)
    if not row:
        problems.append(f"docs/INSTALL.md has no profile row for `{profile}`")
    blurb = re.search(rf"^#   {section}\s+(.*?)(?=\n#\s*$|\n#   [a-z])", init_py, re.S | re.M)
    if not blurb:
        problems.append(f"init.py's scaffolded config has no listing for `{section}`")
    for skill in sections[section]:
        if row and skill not in row.group(1):
            problems.append(f"docs/INSTALL.md's `{section}` row omits {skill}")
        if blurb and skill not in blurb.group(1):
            problems.append(f"init.py's `{section}` listing omits {skill}")

# 2. The verify step's folder counts are what each profile actually installs.
core = set(sections["core"])
counts = {
    "general": len(core | set(sections["workflow"])),
    "python": len(core | set(sections["workflow"]) | set(sections["python"])),
    "all": len({s for names in sections.values() for s in names}),
}
verify = re.search(r"\| `ls \.claude/skills` \|([^|]*)\|", install)
if not verify:
    problems.append("docs/INSTALL.md's verify step no longer states a folder count")
else:
    for profile, n in counts.items():
        if f"{n} for `{profile}`" not in verify.group(1):
            problems.append(f"docs/INSTALL.md's verify step should say {n} for `{profile}`")

# 3. Plugin count and sections named in the prose match the repo.
plugins = sorted(p.name for p in (root / "plugins").iterdir() if (p / ".claude-plugin").is_dir())
words = {1: "one", 2: "two", 3: "three", 4: "four", 5: "five"}
if f"project {words[len(plugins)]} plugins" not in install:
    problems.append(f"docs/INSTALL.md should say {words[len(plugins)]} plugins ({', '.join(plugins)})")
for plugin in plugins:
    if f"**`{plugin}`**" not in install:
        problems.append(f"docs/INSTALL.md does not describe the `{plugin}` plugin")
readme = (root / "README.md").read_text(encoding="utf-8")
for name in sections:
    if f"`{name}`" not in readme:
        problems.append(f"README.md does not name the `{name}` section")
    if name != "core" and f"`{name}`" not in install:
        problems.append(f"docs/INSTALL.md does not name the `{name}` section")
version = (root / "plugins/core/skills/init/assets/.bundle-version").read_text().strip()
for pin in re.findall(r"--branch v(\d+\.\d+\.\d+)", readme):
    if pin != version:
        problems.append(f"README.md pins --branch v{pin}; .bundle-version is {version}")

if problems:
    print("FAIL: the docs and sections.json disagree about what installs:", file=sys.stderr)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    sys.exit(1)
print(f"PASS: both listings name every shipped skill; profile folder counts {counts}")
PY
