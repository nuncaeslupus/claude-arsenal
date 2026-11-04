"""F11 battery health: learned capacity against the design capacity, from batterystats."""

from __future__ import annotations

import re
from collections.abc import Iterator
from typing import Any

from _detectors import Context, Finding, detector, view

DEGRADED = 0.8  # ponytail: starting value — the usual warranty line for a worn cell

_DESIGN = re.compile(r"Estimated battery capacity: (\d+) mAh")
_LEARNED = re.compile(r"Last learned battery capacity: (\d+) mAh")


def health(ctx: Context) -> dict[str, Any] | None:
    """None when the device reports no learned capacity (many do not)."""
    sl = ctx.section("batterystats")
    if sl is None:
        return None
    design, learned = _DESIGN.search(sl.text), _LEARNED.search(sl.text)
    if not design or not learned or not int(design.group(1)):
        return None
    ratio = int(learned.group(1)) / int(design.group(1))
    return {
        "design_mah": int(design.group(1)),
        "learned_mah": int(learned.group(1)),
        "ratio": round(ratio, 3),
        "evidence": [sl.at(design), sl.at(learned)],
    }


@detector(
    id="battery-health.capacity",
    family="F11",
    inputs=("batterystats",),
    findings={"battery-health.degraded": "battery-health.replace-battery"},
)
def detect_degraded(ctx: Context) -> Iterator[Finding]:
    h = health(ctx)
    if h is None or h["ratio"] >= DEGRADED:
        return
    yield Finding(
        "battery-health.degraded",
        "medium",
        1 - h["ratio"],
        f"Battery holds {h['learned_mah']} of {h['design_mah']} mAh design "
        f"({h['ratio']:.0%}) — the cell is worn",
        {k: h[k] for k in ("design_mah", "learned_mah", "ratio")},
        [],
        h["evidence"],
    )


@view("battery-health")
def battery_health_view(ctx: Context) -> dict[str, Any]:
    h = health(ctx) or {}
    return {k: v for k, v in h.items() if k != "evidence"}
