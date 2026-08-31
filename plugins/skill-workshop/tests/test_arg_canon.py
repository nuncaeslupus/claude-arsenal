"""The argument-canon check must not be silenceable by a comment.

The canon exists so two skills cannot spell one concept two ways. It is only
worth having if a non-canonical flag is *reported*, and the check reads argparse
with a regex that allowed only whitespace between `add_argument(` and the first
option string. A comment there made the whole call invisible, so the flag was
not approved — it was unseen.

That is the expensive kind of miss: it looks exactly like a pass. It was found
while adding an explanatory comment above a flag being migrated onto the canon,
which silently took that flag out of the check's view in the same commit that
claimed to fix it.

Lives in the pytest layer for the reason `test_fence_language.py` gives: the
validator imports PyYAML, and `make test` runs under a bare `python3` that
deliberately has no packages installed.
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
name: demo
description: When the user needs a fixture skill for the argument canon check.
  Do NOT use for real work.
metadata:
  type: capability
---

# demo

CANARY: demo-loaded-0000-00-00-0000000000000000

Body text.
"""


@pytest.fixture
def skill(tmp_path):
    """A skill folder complete enough to reach the script checks."""
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
    (root / "SKILL.md").write_text(SKILL_MD)
    (root / "scripts").mkdir()

    def write(body: str) -> Path:
        """Write `body` as the skill's one script and return the skill dir."""
        (root / "scripts" / "query_demo.py").write_text(body)
        return root

    return write


def arg_findings(skill_dir: Path) -> list[str]:
    """Every `arg-canon` / `arg-synonym` message the validator emits."""
    proc = subprocess.run(
        [sys.executable, str(VALIDATE), str(skill_dir), "--severity", "warn", "--json"],
        capture_output=True,
        text=True,
    )
    assert proc.stdout, f"validator produced no report: {proc.stderr}"
    return [
        issue["message"]
        for issue in json.loads(proc.stdout)["issues"]
        if "arg-canon" in issue["check"] or "arg-synonym" in issue["check"]
    ]


NONCANONICAL = (
    "import argparse\n"
    "p = argparse.ArgumentParser()\n"
    "p.add_argument(\n"
    "{lead}"
    '    "--frobnicate",\n'
    ")\n"
)


def test_a_non_canonical_flag_is_reported(skill):
    """The baseline. Without this the comment case below could pass vacuously."""
    findings = arg_findings(skill(NONCANONICAL.format(lead="")))
    assert any("--frobnicate" in f for f in findings), findings


def test_a_comment_does_not_hide_a_non_canonical_flag(skill):
    """A comment above the option string used to make the call invisible.

    Unseen and approved look identical in the report, so the check has to read
    past comments rather than stop at the first line it does not recognise.
    """
    findings = arg_findings(skill(NONCANONICAL.format(lead="    # explaining myself\n")))
    assert any("--frobnicate" in f for f in findings), findings


def test_several_comment_lines_do_not_hide_it_either(skill):
    """One comment is the common case; the check should not care how many."""
    lead = "    # one\n    # two\n    # three\n"
    findings = arg_findings(skill(NONCANONICAL.format(lead=lead)))
    assert any("--frobnicate" in f for f in findings), findings


def test_a_canonical_flag_is_not_reported(skill):
    """The check fires on the vocabulary, not on `add_argument` as such."""
    body = NONCANONICAL.format(lead="").replace("--frobnicate", "--output")
    assert arg_findings(skill(body)) == []


def test_a_canonical_flag_keeps_a_deprecated_alias_quiet(skill):
    """The migration this check should reward.

    Canonical name first, the old spelling trailing, so existing invocations
    keep working. The check reads the first option string, which is the one the
    canon is about.
    """
    body = NONCANONICAL.format(lead="").replace('"--frobnicate"', '"--limit", "--max"')
    assert arg_findings(skill(body)) == []
