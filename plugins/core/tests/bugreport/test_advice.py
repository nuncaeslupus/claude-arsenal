"""The advice reference and the detector catalogue stay in step with the registry."""

from __future__ import annotations

import re

import _detectors as det
from conftest import SCRIPTS

REFS = SCRIPTS.parent / "references"


def _registry_advice() -> set[str]:
    det.load()
    return {a for d in det.REGISTRY.values() for a in d.findings.values()}


def test_every_registry_advice_id_has_an_entry():
    headings = re.findall(r"^### (\S+)$", (REFS / "advice.md").read_text(), re.M)
    assert len(headings) == len(set(headings)), "duplicate advice heading"
    assert sorted(_registry_advice() - set(headings)) == []  # missing entries
    assert sorted(set(headings) - _registry_advice()) == []  # orphan headings


def test_advice_flag_prints_first_line_of_entry(built, cli):
    code, doc, err = cli(
        "analyze_bugreport", "--input", str(built("modern", ("low-storage",))), "--advice"
    )
    assert code == 0 and "no advice entry" not in err
    (f,) = doc["findings"]
    assert f["advice"] == "Clear the largest app caches and remove unused apps and media."


def test_detectors_reference_matches_registry():
    assert (REFS / "detectors.md").read_text() == det.catalogue_md(), (
        "references/detectors.md is stale: run `make sync-bugreport-detectors`"
    )
