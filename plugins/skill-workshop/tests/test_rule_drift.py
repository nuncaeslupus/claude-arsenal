"""The drift audit reads the frozen research doc plus every dated addendum.

New rubric rows cite findings recorded after the archive was frozen, in
`docs/research/addendum-YYYY-MM.md`. A rule ID that only an addendum
documents is a documented rule, not drift.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

DRIFT = (
    Path(__file__).resolve().parents[1]
    / "skills"
    / "skill-workshop"
    / "scripts"
    / "audit_rule_drift.py"
)


def _repo(tmp_path: Path, *, addendum: bool) -> Path:
    (tmp_path / ".claude-plugin").mkdir()
    (tmp_path / ".claude-plugin" / "marketplace.json").write_text("{}", encoding="utf-8")
    refs = tmp_path / "plugins" / "skill-workshop" / "skills" / "skill-workshop" / "references"
    refs.mkdir(parents=True)
    (refs / "skill-rules.md").write_text("| R-OLD-1 | must | x |\n| R-NEW-1 | should | y |\n")
    (refs / "content-quality-rules.md").write_text("")
    (refs / "research-coverage.md").write_text("")
    research = tmp_path / "docs" / "research"
    research.mkdir(parents=True)
    (research / "claude-skill-system_v1.17.md").write_text("R-OLD-1 is documented here.\n")
    if addendum:
        (research / "addendum-2099-01.md").write_text("## R-NEW-1\n\nDocumented later.\n")
    return tmp_path


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(DRIFT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_rule_drift_reads_addendum(tmp_path: Path) -> None:
    proc = _run(_repo(tmp_path, addendum=True))
    assert proc.returncode == 0, proc.stderr
    assert "R-NEW-1" not in proc.stderr


def test_rule_only_in_rubric_is_still_drift(tmp_path: Path) -> None:
    proc = _run(_repo(tmp_path, addendum=False))
    assert proc.returncode == 1
    assert "R-NEW-1" in proc.stderr
