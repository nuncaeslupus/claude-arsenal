"""The trigger evals cover the description: positives, and each "Not for" trigger."""

from __future__ import annotations

import json
import re

from conftest import SCRIPTS

SKILL = SCRIPTS.parent


def test_trigger_evals_cover_positive_and_negative_prompts():
    evals = json.loads((SKILL / "evals" / "loading_verification.json").read_text())
    desc = re.search(r"^description: (.+)$", (SKILL / "SKILL.md").read_text(), re.M).group(1)
    negatives = re.search(r"Not for (.+?)\.$", desc).group(1).split(" or ")
    assert len(evals["load_prompts"]) >= 3
    prompts = " ".join(evals["no_load_prompts"]).lower()
    for trigger in negatives:
        words = {
            w
            for w in re.split(r"[\s-]+", trigger.lower())
            if w not in {"only", "files", "sessions", "live", "device"}
        }
        assert any(w in prompts for w in words), trigger
