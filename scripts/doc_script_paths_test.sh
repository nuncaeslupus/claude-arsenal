#!/usr/bin/env bash
# doc_script_paths_test.sh — a documented bundle script has to be a script we ship.
#
# `check_update.sh` told every consumer whose subtree merged without refreshing
# the skills to run `claude-arsenal/scripts/vendor-skills.sh`. That step was
# removed in v2.0.0 and the file has not shipped since, so the remedy printed at
# the one moment a consumer is half-upgraded pointed at nothing — and the real
# remedy on the next line read like an afterthought to it. `docs/UPDATE.md`
# carried the same dead path.
#
# Nothing caught it because the reference is consumer-side: in a consumer repo
# `claude-arsenal/` is the vendored bundle, so the path is well-formed and
# resolves to nothing here. It has one deterministic upstream location, though —
# the bundle is built from `plugins/core/skills/init/assets/` — so the check is
# just that mapping, applied to every doc and shipped reference.
#
# Only the PREFIXED spelling is checked, and that is the point rather than a
# limitation. Writing `claude-arsenal/scripts/x.sh` is a claim that the path is
# there to run; naming `vendor-skills.sh` on its own is prose about a thing that
# once existed, which `docs/UPDATE.md` legitimately does when explaining what a
# pre-v2.0.0 install looked like. Write history with the bare name, remedies
# with the path.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}" || { echo "FAIL: cannot enter ${ROOT}" >&2; exit 1; }

missing=$(python3 - <<'PY'
import re
from pathlib import Path

BUNDLE = Path("plugins/core/skills/init/assets")
SOURCES = [
    *Path("docs").rglob("*.md"),
    *BUNDLE.rglob("*.md"),
    *BUNDLE.joinpath("bin").rglob("*.sh"),
    Path("README.md"),
    Path("CLAUDE.md"),
]
# `claude-arsenal/<path>.sh|.py` — the vendored-bundle prefix. Allow ${PREFIX}
# too: check_update.sh spells the same path through its own variable.
PAT = re.compile(r"(?:claude-arsenal|\$\{PREFIX\})/([\w./-]+\.(?:sh|py))")

bad = []
for src in SOURCES:
    if not src.is_file():
        continue
    for lineno, line in enumerate(src.read_text(encoding="utf-8").splitlines(), 1):
        for rel in PAT.findall(line):
            # The upstream tree is not a bundle: a doc may name a real repo path
            # that happens to sit under this prefix in a consumer.
            if (BUNDLE / rel).is_file() or Path(rel).is_file():
                continue
            bad.append(f"{src}:{lineno}: claude-arsenal/{rel} -> no {BUNDLE / rel}")
print("\n".join(sorted(set(bad))))
PY
)

if [[ -n "${missing}" ]]; then
    echo "FAIL: documented bundle scripts that upstream does not ship:" >&2
    echo "${missing}" >&2
    exit 1
fi
echo "PASS: doc_script_paths_test — every documented bundle script exists"
