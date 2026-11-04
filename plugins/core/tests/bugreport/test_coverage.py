"""Every detector family has a fixture that fires it and a clean fixture that does not."""

from __future__ import annotations

import _detectors as det
from test_checkup import FIRES, LAYOUTS


def test_every_family_f1_to_f11_has_fire_and_nofire(built, cli):
    det.load()
    family = {fid: d.family for d in det.REGISTRY.values() for fid in d.findings}
    fired = {family[fid] for ids in FIRES.values() for fid in ids}
    assert set(det.FAMILIES) - fired == set()  # families_without_fire_nofire_fixture == 0
    for layout in LAYOUTS:
        code, doc, _ = cli("analyze_bugreport", "--input", str(built(layout)), "--limit", "0")
        assert code == 0 and doc["findings"] == [], layout
