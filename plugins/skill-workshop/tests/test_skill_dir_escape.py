"""`${CLAUDE_SKILL_DIR}/..` fails the validator, fenced block or not.

The inline `..` check only warns and only reads inline-code spans, so seven
fenced commands reaching into sibling skills passed it and surfaced only in the
semantic walk. This form is never documentation of something else.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

VALIDATE = (
    Path(__file__).resolve().parents[1] / "skills" / "skill-workshop" / "scripts" / "validate.py"
)

SKILL_MD = """\
---
name: demo
description: When the user needs a fixture skill for the escape check. Do NOT use for anything real.
metadata:
  type: capability
---

# demo

CANARY: demo-loaded-0000-00-00-0000000000000000

{block}
"""


def escape_findings(tmp_path: Path, block: str) -> list[dict[str, str]]:
    root = tmp_path / "demo"
    (root / "evals").mkdir(parents=True)
    (root / "evals" / "loading_verification.json").write_text(
        json.dumps(
            {
                "canary": "demo-loaded-0000-00-00-0000000000000000",
                "negative_control": "an unrelated prompt",
            }
        )
    )
    (root / "SKILL.md").write_text(SKILL_MD.format(block=block))
    proc = subprocess.run(
        [sys.executable, str(VALIDATE), str(root), "--severity", "warn", "--json"],
        capture_output=True,
        text=True,
    )
    assert proc.stdout, f"validator produced no report: {proc.stderr}"
    return [i for i in json.loads(proc.stdout)["issues"] if i["check"].endswith("skill-dir-escape")]


def test_fenced_escape_fails(tmp_path: Path) -> None:
    found = escape_findings(
        tmp_path, '```bash\npython3 "${CLAUDE_SKILL_DIR}/../other/scripts/x.py"\n```'
    )
    assert len(found) == 1


def test_own_scripts_path_passes(tmp_path: Path) -> None:
    assert not escape_findings(tmp_path, '```bash\npython3 "${CLAUDE_SKILL_DIR}/scripts/x.py"\n```')
