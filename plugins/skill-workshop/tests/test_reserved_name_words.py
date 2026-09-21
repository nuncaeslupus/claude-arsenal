"""R-FM-2 reserves four words; the validator checked two of them.

The rule reserves `anthropic`, `claude`, `mcp` and `agent`. `validate.py`
tested the first two and its failure message enumerated only those, so a skill
named `mcp-bridge` or `agent-runner` passed the rule the validator exists to
enforce — and the message told an author the rule was narrower than it is.

Checked through the validator's own output rather than against the source, so
the assertion survives a refactor of how the words are spelled in the code.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

VALIDATE = (
    Path(__file__).resolve().parents[1] / "skills" / "skill-workshop" / "scripts" / "validate.py"
)

SKILL_MD = """\
---
name: {name}
description: When the user needs a fixture for the reserved-word check. Do NOT use for real work.
metadata:
  type: capability
---

# {name}

CANARY: demo-loaded-0000-00-00-0000000000000000

Body text.
"""


def findings(tmp_path: Path, name: str) -> list[dict]:
    skill = tmp_path / name
    skill.mkdir(parents=True, exist_ok=True)
    (skill / "SKILL.md").write_text(SKILL_MD.format(name=name), encoding="utf-8")
    out = subprocess.run(
        [sys.executable, str(VALIDATE), str(skill), "--json"],
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(out).get("issues", [])


def name_findings(tmp_path: Path, name: str) -> list[dict]:
    return [f for f in findings(tmp_path, name) if f.get("check") == "frontmatter.name"]


@pytest.mark.parametrize("word", ["anthropic", "claude", "mcp", "agent"])
def test_every_reserved_word_is_refused(tmp_path: Path, word: str) -> None:
    assert name_findings(tmp_path / word, f"{word}-bridge"), (
        f"a skill named {word!r} passed R-FM-2, which reserves it"
    )


def test_the_message_names_every_word_it_checks(tmp_path: Path) -> None:
    message = name_findings(tmp_path, "mcp-bridge")[0]["message"]
    for word in ("anthropic", "claude", "mcp", "agent"):
        assert word in message, f"the failure message does not mention {word!r}: {message}"


def test_an_ordinary_name_still_passes(tmp_path: Path) -> None:
    assert not name_findings(tmp_path, "queue-status"), "a name with no reserved word was refused"
