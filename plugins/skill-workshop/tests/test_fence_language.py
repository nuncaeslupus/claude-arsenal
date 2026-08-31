"""The untagged-fence check must be right about *where*.

This check shipped two defects in one review cycle, both of the same kind: it
was confidently wrong rather than silent. It reported the closing line of a
```` wrapper as an untagged block, and it counted lines from the post-frontmatter
body, so every number came out short by the height of the frontmatter. A warning
whose entire value is a line number has to get the line number right.

Lives in the pytest layer, not beside the plugin's shell tests, because
`validate.py` imports PyYAML. `make test` runs under the bare `python3` that
proves shipped consumer scripts need no toolchain — the validator is a dev tool
and is not one of those, so a shell test there crashed it and read the empty
stdout as "no findings". That is the same vacuous-pass failure this file's own
first revision had, twice over.
"""

from __future__ import annotations

import importlib.util
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
description: When the user needs a fixture skill for the fence check. Do NOT use for anything real.
metadata:
  type: capability
---

# demo

CANARY: demo-loaded-0000-00-00-0000000000000000

Body text.

{block}
"""


@pytest.fixture(scope="module")
def validate_module():
    """`validate.py` imported as a module, for checks on its helpers directly."""
    spec = importlib.util.spec_from_file_location("_validate_under_test", VALIDATE)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def skill(tmp_path):
    """A skill folder complete enough to reach the body checks.

    Without `evals/loading_verification.json` the validator reports that and
    stops short, so every assertion here would pass on an empty report — which
    is how an earlier revision of this test passed while the rule it covers was
    reverted.
    """
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

    def write(block: str) -> Path:
        (root / "SKILL.md").write_text(SKILL_MD.format(block=block))
        return root

    return write


def fence_findings(skill_dir: Path) -> list[str]:
    """Every `*.fence-language` message the validator emits for this skill."""
    proc = subprocess.run(
        [sys.executable, str(VALIDATE), str(skill_dir), "--severity", "warn", "--json"],
        capture_output=True,
        text=True,
    )
    assert proc.stdout, f"validator produced no report: {proc.stderr}"
    return [
        issue["message"]
        for issue in json.loads(proc.stdout)["issues"]
        if issue["check"].endswith("fence-language")
    ]


def test_untagged_fence_is_reported_at_its_line_in_the_file(skill):
    """The line number counts from the file, not from the post-frontmatter body."""
    findings = fence_findings(skill("```\nsome content\n```"))
    assert findings, "an untagged fence must be reported"
    # The fence is the 14th line of the rendered file — frontmatter included.
    assert "line 14:" in findings[0], findings[0]


def test_a_tagged_fence_is_not_reported(skill):
    assert fence_findings(skill("```bash\necho hi\n```")) == []


def test_four_backtick_wrapper_closes_on_its_own_marker(skill):
    """The documented way to show a fenced block inside one.

    Counting bare ``` opens reads the wrapper's closing line as a fresh untagged
    block, which is what the first version of this check did.
    """
    assert fence_findings(skill("````markdown\n```bash\necho hi\n```\n````")) == []


def test_four_space_indent_is_content_not_a_fence(validate_module):
    """CommonMark 4.5: at four spaces the backticks are literal content."""
    assert validate_module.untagged_fences("text\n\n    ```\n    not a fence\n    ```\n") == []


@pytest.mark.parametrize("pad", ["", " ", "  ", "   "])
def test_up_to_three_spaces_still_opens_a_fence(validate_module, pad):
    assert validate_module.untagged_fences(f"text\n\n{pad}```\n{pad}body\n{pad}```\n") == [3]
