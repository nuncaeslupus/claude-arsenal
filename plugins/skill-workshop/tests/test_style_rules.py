"""Prompt-style checks: each fixture yields exactly its own warning.

The style checks encode the prompting guidance in
`references/model-prompting.md`. Each test writes a clean fixture skill, adds
one offending line, and asserts the validator reports that check and no other
style check, so a regex that starts matching its neighbours' fixtures fails
here rather than in a consumer's tree.
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
name: {name}
description: When the user needs a fixture for the style checks. Do NOT use for real work.
metadata:
  type: workflow
---

# {name}

CANARY: demo-loaded-0000-00-00-0000000000000000

## Notes

Run the build and read its last line.

{line}
"""

STYLE_PREFIXES = ("content.style-", "content.ref-unconditional")


def _module():
    spec = importlib.util.spec_from_file_location("_validate_style_under_test", VALIDATE)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _skill(tmp_path: Path, line: str, name: str = "demo") -> Path:
    skill = tmp_path / name
    skill.mkdir(parents=True, exist_ok=True)
    (skill / "SKILL.md").write_text(SKILL_MD.format(name=name, line=line), encoding="utf-8")
    (skill / "evals").mkdir(exist_ok=True)
    (skill / "evals" / "loading_verification.json").write_text(
        json.dumps(
            {
                "canary": "CANARY: demo-loaded-0000-00-00-0000000000000000",
                "negative_control": "an unrelated prompt",
            }
        ),
        encoding="utf-8",
    )
    return skill


def _run(skill: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATE), str(skill), "--json", *extra],
        capture_output=True,
        text=True,
    )


def _style(skill: Path) -> list[dict]:
    issues = json.loads(_run(skill).stdout)["issues"]
    return [i for i in issues if i["check"].startswith(STYLE_PREFIXES)]


def _checks(skill: Path) -> list[str]:
    return sorted({i["check"] for i in _style(skill)})


def test_clean_fixture_has_no_style_findings(tmp_path: Path) -> None:
    assert _checks(_skill(tmp_path, "Report the result.")) == []


def test_style_caps_density_warns(tmp_path: Path) -> None:
    line = "MUST run it. NEVER skip it. ALWAYS log it. IMPORTANT: keep it. CRITICAL: read it."
    assert _checks(_skill(tmp_path, line)) == ["content.style-caps"]


def test_style_caps_single_token_is_fine(tmp_path: Path) -> None:
    assert _checks(_skill(tmp_path, "Do NOT push to main, because CI tags it.")) == []


def test_style_if_in_doubt_warns(tmp_path: Path) -> None:
    line = "If in doubt, use the search tool."
    assert _checks(_skill(tmp_path, line)) == ["content.style-if-in-doubt"]


def test_style_always_use_warns(tmp_path: Path) -> None:
    assert _checks(_skill(tmp_path, "Always use the search tool.")) == ["content.style-if-in-doubt"]


def test_style_think_warns(tmp_path: Path) -> None:
    line = "Think step by step before you answer."
    assert _checks(_skill(tmp_path, line)) == ["content.style-think"]


def test_style_reasoning_in_response_warns(tmp_path: Path) -> None:
    line = "Explain your reasoning in the response."
    assert _checks(_skill(tmp_path, line)) == ["content.style-think"]


def test_style_double_check_warns(tmp_path: Path) -> None:
    line = "Double-check the output before reporting."
    assert _checks(_skill(tmp_path, line)) == ["content.style-double-check"]


def test_style_subagent_verify_warns(tmp_path: Path) -> None:
    line = "Spawn a subagent to verify the change."
    assert _checks(_skill(tmp_path, line)) == ["content.style-double-check"]


def test_style_double_check_with_real_command_is_exempt(tmp_path: Path) -> None:
    line = "Double-check by running `make test`; it exits 0."
    assert _checks(_skill(tmp_path, line)) == []


def test_style_severity_filter_warns(tmp_path: Path) -> None:
    line = "Only report high-severity findings."
    assert _checks(_skill(tmp_path, line)) == ["content.style-severity-filter"]


def test_style_be_conservative_warns(tmp_path: Path) -> None:
    line = "Be conservative about what counts as a bug."
    assert _checks(_skill(tmp_path, line)) == ["content.style-severity-filter"]


def test_style_hold_findings_warns(tmp_path: Path) -> None:
    line = "Hold all findings for the final message."
    assert _checks(_skill(tmp_path, line)) == ["content.style-restraint"]


def test_style_minimise_tool_calls_warns(tmp_path: Path) -> None:
    line = "Minimise tool calls while exploring."
    assert _checks(_skill(tmp_path, line)) == ["content.style-restraint"]


def test_style_model_name_warns(tmp_path: Path) -> None:
    line = "Dispatch the reviewer on Opus for this step."
    assert _checks(_skill(tmp_path, line)) == ["content.style-model-name"]


def test_style_model_id_in_script_warns(tmp_path: Path) -> None:
    skill = _skill(tmp_path, "Report the result.")
    scripts = skill / "scripts"
    scripts.mkdir()
    (scripts / "run_demo.py").write_text(
        'MODEL = "claude-sonnet-4-6"\n\ndef main():\n    return 0\n\n'
        'if __name__ == "__main__":\n    main()\n',
        encoding="utf-8",
    )
    assert _checks(skill) == ["content.style-model-name"]


def test_style_model_alias_default_is_exempt(tmp_path: Path) -> None:
    skill = _skill(tmp_path, "Report the result.")
    scripts = skill / "scripts"
    scripts.mkdir()
    (scripts / "run_demo.py").write_text(
        'DEFAULTS = {"models.workers": "sonnet"}\n\ndef main():\n    return 0\n\n'
        'if __name__ == "__main__":\n    main()\n',
        encoding="utf-8",
    )
    assert _checks(skill) == []


def test_style_turn_end_warns(tmp_path: Path) -> None:
    line = "End the turn with: Shall I continue with the next file?"
    assert _checks(_skill(tmp_path, line)) == ["content.style-turn-end"]


def test_ref_unconditional_warns(tmp_path: Path) -> None:
    skill = _skill(tmp_path, "- See `references/guide.md`.")
    (skill / "references").mkdir()
    (skill / "references" / "guide.md").write_text("# Guide\n\nDetails.\n", encoding="utf-8")
    assert _checks(skill) == ["content.ref-unconditional"]


def test_ref_with_trigger_is_fine(tmp_path: Path) -> None:
    skill = _skill(tmp_path, "- Load `references/guide.md` when the build fails.")
    (skill / "references").mkdir()
    (skill / "references" / "guide.md").write_text("# Guide\n\nDetails.\n", encoding="utf-8")
    assert _checks(skill) == []


def test_ref_in_numbered_step_is_positioned(tmp_path: Path) -> None:
    skill = _skill(tmp_path, "2. Open `references/guide.md` and apply it.")
    (skill / "references").mkdir()
    (skill / "references" / "guide.md").write_text("# Guide\n\nDetails.\n", encoding="utf-8")
    assert _checks(skill) == []


def test_skill_workshop_is_scanned_for_style(tmp_path: Path) -> None:
    skill = _skill(tmp_path, "Double-check the output.", name="skill-workshop")
    assert _checks(skill) == ["content.style-double-check"]


def test_style_findings_follow_the_severity_constant(tmp_path: Path) -> None:
    module = _module()
    skill = _skill(tmp_path, "Double-check the output before reporting.")
    proc = _run(skill, "--severity", "warn")
    others = [i for i in json.loads(proc.stdout)["issues"] if i["severity"] != "style"]
    finding = _style(skill)[0]
    if module.STYLE_SEVERITY == "warn":
        assert finding["severity"] == "style"
        assert not others, others
        assert proc.returncode == 0, "a style warning blocked the build"
    else:
        assert finding["severity"] == "fail"
        assert proc.returncode == 1


@pytest.mark.parametrize(
    "line",
    [
        "Run `make test`.",
        "Use the search tool when a name is unfamiliar, because names change.",
        "Report every finding with its severity.",
    ],
)
def test_ordinary_lines_are_clean(tmp_path: Path, line: str) -> None:
    assert _checks(_skill(tmp_path, line)) == []
